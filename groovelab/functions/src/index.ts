import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { initializeApp } from "firebase-admin/app";
import { createHash } from "crypto";

initializeApp();
const db = getFirestore();

// ── Secrets (configured via `firebase functions:secrets:set`) ──
const LALAL_API_KEY = defineSecret("LALAL_API_KEY");
const R2_ACCOUNT_ID = defineSecret("R2_ACCOUNT_ID");
const R2_ACCESS_KEY = defineSecret("R2_ACCESS_KEY");
const R2_SECRET_KEY = defineSecret("R2_SECRET_KEY");
const R2_BUCKET = defineSecret("R2_BUCKET");

// ── Stem Separation via LALAL.AI ──
export const separateStems = onCall(
  {
    memory: "2GiB",
    timeoutSeconds: 300,
    minInstances: 1, // Eliminate cold start
    secrets: [LALAL_API_KEY],
  },
  async (request) => {
    // 1. Verify auth
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const uid = request.auth.uid;

    // 2. Get audio URL or data
    const { audioUrl, fileName, stemTypes } = request.data;
    if (!audioUrl) {
      throw new HttpsError("invalid-argument", "audioUrl required");
    }

    const requestedStems = stemTypes || ["vocals", "drums", "bass", "other"];

    // 3. Compute hash for caching
    const hash = createHash("sha256").update(audioUrl).digest("hex").slice(0, 16);

    // 4. Check cache in Firestore
    const cacheRef = db.doc(`users/${uid}/songs/${hash}`);
    const cached = await cacheRef.get();
    if (cached.exists && cached.data()?.stems) {
      return {
        cached: true,
        stems: cached.data()?.stems,
        bpm: cached.data()?.bpm,
        key: cached.data()?.key,
      };
    }

    // 5. Call LALAL.AI API
    const apiKey = LALAL_API_KEY.value();

    // Upload to LALAL.AI
    const uploadResponse = await fetch("https://www.lalal.ai/api/upload/", {
      method: "POST",
      headers: {
        Authorization: `license ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        url: audioUrl,
        stem: "auto", // Let LALAL.AI detect best separation
        filter: 1, // Enhanced quality
      }),
    });

    if (!uploadResponse.ok) {
      const error = await uploadResponse.text();
      throw new HttpsError("internal", `LALAL.AI upload failed: ${error}`);
    }

    const uploadResult = (await uploadResponse.json()) as Record<string, unknown>;
    const taskId = uploadResult.id as string;

    if (!taskId) {
      throw new HttpsError("internal", "LALAL.AI did not return task ID");
    }

    // 6. Poll for completion (max 5 minutes)
    let completed = false;
    let resultData: Record<string, unknown> | null = null;
    const maxAttempts = 60; // 60 * 5s = 5 minutes

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, 5000));

      const statusResponse = await fetch(
        `https://www.lalal.ai/api/check/?id=${taskId}`,
        {
          headers: { Authorization: `license ${apiKey}` },
        }
      );

      if (statusResponse.ok) {
        const status = (await statusResponse.json()) as Record<string, unknown>;
        if (status.status === "done") {
          resultData = status;
          completed = true;
          break;
        } else if (status.status === "error") {
          throw new HttpsError(
            "internal",
            `LALAL.AI processing failed: ${status.error || "unknown"}`
          );
        }
      }
    }

    if (!completed || !resultData) {
      throw new HttpsError("deadline-exceeded", "Stem separation timed out");
    }

    // 7. Build stem results
    const stems: Record<string, string> = {};
    const result = resultData.result as Record<string, unknown> | undefined;
    if (result) {
      for (const stemType of requestedStems) {
        const stemUrl = (result as Record<string, unknown>)[stemType] as string | undefined;
        if (stemUrl) {
          stems[stemType] = stemUrl;
        }
      }
    }

    // 8. Save metadata to Firestore
    await cacheRef.set(
      {
        fileName: fileName || "unknown",
        stems,
        bpm: (resultData as Record<string, unknown>).bpm || null,
        key: (resultData as Record<string, unknown>).key || null,
        processedAt: FieldValue.serverTimestamp(),
        source: "lalal.ai",
      },
      { merge: true }
    );

    return {
      cached: false,
      stems,
      bpm: (resultData as Record<string, unknown>).bpm || null,
      key: (resultData as Record<string, unknown>).key || null,
    };
  }
);

// ── R2 Presigned URL Generator ──
export const getUploadUrl = onCall(
  {
    secrets: [R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET],
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const { S3Client, PutObjectCommand } = await import("@aws-sdk/client-s3");
    const { getSignedUrl } = await import("@aws-sdk/s3-request-presigner");

    const { fileHash, mimeType } = request.data;
    if (!fileHash) {
      throw new HttpsError("invalid-argument", "fileHash required");
    }

    const r2 = new S3Client({
      region: "auto",
      endpoint: `https://${R2_ACCOUNT_ID.value()}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: R2_ACCESS_KEY.value(),
        secretAccessKey: R2_SECRET_KEY.value(),
      },
    });

    const key = `users/${request.auth.uid}/songs/${fileHash}/original`;
    const url = await getSignedUrl(
      r2,
      new PutObjectCommand({
        Bucket: R2_BUCKET.value(),
        Key: key,
        ContentType: mimeType || "audio/wav",
      }),
      { expiresIn: 3600 }
    );

    return { url, key };
  }
);

export const getDownloadUrl = onCall(
  {
    secrets: [R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET],
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const { S3Client, GetObjectCommand } = await import("@aws-sdk/client-s3");
    const { getSignedUrl } = await import("@aws-sdk/s3-request-presigner");

    const { key } = request.data;
    if (!key) {
      throw new HttpsError("invalid-argument", "key required");
    }

    // Verify user owns this file
    if (!key.startsWith(`users/${request.auth.uid}/`)) {
      throw new HttpsError("permission-denied", "Cannot access this file");
    }

    const r2 = new S3Client({
      region: "auto",
      endpoint: `https://${R2_ACCOUNT_ID.value()}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: R2_ACCESS_KEY.value(),
        secretAccessKey: R2_SECRET_KEY.value(),
      },
    });

    const url = await getSignedUrl(
      r2,
      new GetObjectCommand({
        Bucket: R2_BUCKET.value(),
        Key: key,
      }),
      { expiresIn: 86400 }
    );

    return { url };
  }
);
