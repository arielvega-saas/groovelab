"""
GrooveLab — Demucs Stem Separation Server
==========================================
FastAPI server that uses Demucs v4 (htdemucs_6s) for real stem separation.

Deploy on Railway, Render, or any Docker host.

Usage:
  pip install -r requirements.txt
  uvicorn main:app --host 0.0.0.0 --port 8000

Endpoint:
  POST /separate
  - Accepts: multipart/form-data with 'file' field (MP3, WAV, M4A)
  - Returns: JSON with base64-encoded WAV stems
"""

import base64
import io
import os
import tempfile
import shutil
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import soundfile as sf
import numpy as np

app = FastAPI(title="GrooveLab Stem Separator", version="1.0.0")

# CORS — allow GrooveLab web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict to your domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Demucs model (loaded on first request)
_separator = None
_model_name = os.getenv("DEMUCS_MODEL", "htdemucs_6s")


def get_separator():
    """Lazy-load Demucs separator."""
    global _separator
    if _separator is None:
        try:
            from demucs.api import Separator
            _separator = Separator(model=_model_name, segment=40)
            print(f"[Demucs] Model '{_model_name}' loaded successfully")
        except Exception as e:
            print(f"[Demucs] Failed to load model: {e}")
            raise HTTPException(status_code=500, detail=f"Model load failed: {e}")
    return _separator


def audio_to_base64_wav(audio_array: np.ndarray, sample_rate: int) -> str:
    """Convert numpy audio array to base64-encoded WAV."""
    buf = io.BytesIO()
    # audio_array shape: (channels, samples) -> transpose for soundfile
    if audio_array.ndim == 2:
        sf.write(buf, audio_array.T, sample_rate, format="WAV", subtype="FLOAT")
    else:
        sf.write(buf, audio_array, sample_rate, format="WAV", subtype="FLOAT")
    buf.seek(0)
    return base64.b64encode(buf.read()).decode("utf-8")


@app.get("/health")
async def health():
    return {"status": "ok", "model": _model_name}


@app.post("/separate")
async def separate_stems(file: UploadFile = File(...)):
    """
    Separate an audio file into stems using Demucs.

    Returns JSON:
    {
      "success": true,
      "stems": {
        "vocals": "<base64 WAV>",
        "drums": "<base64 WAV>",
        "bass": "<base64 WAV>",
        "guitar": "<base64 WAV>",
        "piano": "<base64 WAV>",
        "other": "<base64 WAV>"
      },
      "sampleRate": 44100,
      "duration": 180.5
    }
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")

    # Validate file type
    ext = Path(file.filename).suffix.lower()
    if ext not in {".mp3", ".wav", ".m4a", ".ogg", ".flac", ".aac"}:
        raise HTTPException(status_code=400, detail=f"Unsupported format: {ext}")

    # Save uploaded file to temp directory
    tmp_dir = tempfile.mkdtemp(prefix="groovelab_")
    tmp_path = os.path.join(tmp_dir, f"input{ext}")

    try:
        # Write uploaded file
        content = await file.read()
        with open(tmp_path, "wb") as f:
            f.write(content)

        print(f"[Demucs] Processing: {file.filename} ({len(content)} bytes)")

        # Run Demucs separation
        separator = get_separator()
        _, outputs = separator.separate_audio_file(tmp_path)

        # Convert stems to base64 WAV
        stems = {}
        sample_rate = 44100  # Demucs default
        duration = 0.0

        # htdemucs_6s outputs: vocals, drums, bass, guitar, piano, other
        stem_names = ["vocals", "drums", "bass", "guitar", "piano", "other"]

        for name, audio_tensor in outputs.items():
            # audio_tensor shape: (channels, samples)
            audio_np = audio_tensor.cpu().numpy()
            stems[name] = audio_to_base64_wav(audio_np, sample_rate)
            duration = max(duration, audio_np.shape[-1] / sample_rate)
            print(f"[Demucs] Stem '{name}': {audio_np.shape}")

        # Ensure all expected stem names are present
        for expected in stem_names:
            if expected not in stems:
                stems[expected] = ""

        print(f"[Demucs] Separation complete: {len(stems)} stems, {duration:.1f}s")

        return JSONResponse(content={
            "success": True,
            "stems": stems,
            "sampleRate": sample_rate,
            "duration": round(duration, 3),
        })

    except Exception as e:
        print(f"[Demucs] Separation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        # Cleanup temp files
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
