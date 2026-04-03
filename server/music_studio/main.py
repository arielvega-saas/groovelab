"""GrooveLab Music Studio - FastAPI Backend.

Main application with all REST endpoints, WebSocket progress broadcasting,
background task processing, and project directory management.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import shutil
import uuid
import zipfile
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set

import librosa
import soundfile as sf
from fastapi import (
    FastAPI,
    File,
    HTTPException,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from models import (
    BPMRequest,
    BPMResult,
    ChordRequest,
    LyricsRequest,
    PitchRequest,
    ProgressEvent,
    ProgressStage,
    ProjectMeta,
    SeparateRequest,
    StemInfo,
    StemName,
    TempoRequest,
    YouTubeRequest,
)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("groovelab")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROJECTS_DIR = os.getenv("PROJECTS_DIR", "./projects")
os.makedirs(PROJECTS_DIR, exist_ok=True)

# In-memory project store (persists project metadata as JSON on disk)
_projects: Dict[str, ProjectMeta] = {}


# ---------------------------------------------------------------------------
# WebSocket Manager
# ---------------------------------------------------------------------------

class ConnectionManager:
    """Manages WebSocket connections and broadcasts progress events."""

    def __init__(self) -> None:
        self._active: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._active.add(ws)
        logger.info("WebSocket client connected (%d total)", len(self._active))

    async def disconnect(self, ws: WebSocket) -> None:
        async with self._lock:
            self._active.discard(ws)
        logger.info("WebSocket client disconnected (%d remaining)", len(self._active))

    async def broadcast(self, event: ProgressEvent) -> None:
        """Send a progress event to all connected clients."""
        payload = event.model_dump_json()
        dead: List[WebSocket] = []
        async with self._lock:
            for ws in self._active:
                try:
                    await ws.send_text(payload)
                except Exception:
                    dead.append(ws)
            for ws in dead:
                self._active.discard(ws)

    async def send_progress(
        self,
        project_id: str,
        stage: ProgressStage,
        progress: float,
        message: str = "",
        detail: Optional[str] = None,
    ) -> None:
        event = ProgressEvent(
            project_id=project_id,
            stage=stage,
            progress=progress,
            message=message,
            detail=detail,
        )
        await self.broadcast(event)


ws_manager = ConnectionManager()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _project_dir(project_id: str) -> str:
    return os.path.join(PROJECTS_DIR, project_id)


def _stems_dir(project_id: str) -> str:
    return os.path.join(_project_dir(project_id), "stems")


def _meta_path(project_id: str) -> str:
    return os.path.join(_project_dir(project_id), "meta.json")


def _save_meta(project: ProjectMeta) -> None:
    """Persist project metadata to disk."""
    path = _meta_path(project.id)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(project.model_dump_json(indent=2))


def _load_meta(project_id: str) -> Optional[ProjectMeta]:
    """Load project metadata from disk."""
    path = _meta_path(project_id)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return ProjectMeta.model_validate_json(f.read())


def _get_project(project_id: str) -> ProjectMeta:
    """Get project from memory or disk, raise 404 if not found."""
    if project_id in _projects:
        return _projects[project_id]
    meta = _load_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_id}' not found")
    _projects[project_id] = meta
    return meta


def _load_all_projects() -> None:
    """Scan PROJECTS_DIR and load all project metadata."""
    if not os.path.isdir(PROJECTS_DIR):
        return
    for name in os.listdir(PROJECTS_DIR):
        meta_file = os.path.join(PROJECTS_DIR, name, "meta.json")
        if os.path.isfile(meta_file):
            try:
                with open(meta_file) as f:
                    project = ProjectMeta.model_validate_json(f.read())
                _projects[project.id] = project
            except Exception as exc:
                logger.warning("Failed to load project %s: %s", name, exc)


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown logic."""
    _load_all_projects()
    logger.info("Loaded %d existing projects from %s", len(_projects), PROJECTS_DIR)
    yield
    logger.info("Shutting down GrooveLab server")


# ---------------------------------------------------------------------------
# FastAPI App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="GrooveLab Music Studio",
    version="1.0.0",
    description="Professional music studio backend with stem separation, analysis, and more.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "projects": len(_projects),
        "version": "1.0.0",
    }


# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    """Upload an audio file and create a new project."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")

    project_id = uuid.uuid4().hex[:12]
    proj_dir = _project_dir(project_id)
    os.makedirs(proj_dir, exist_ok=True)

    # Save the uploaded file
    original_name = file.filename
    safe_name = original_name.replace("/", "_").replace("\\", "_")
    original_path = os.path.join(proj_dir, safe_name)

    with open(original_path, "wb") as f:
        content = await file.read()
        f.write(content)

    # Get audio metadata
    try:
        y, sr = librosa.load(original_path, sr=None, mono=True, duration=5)
        info = sf.info(original_path)
        duration = info.duration
        sample_rate = info.samplerate
    except Exception:
        duration = 0.0
        sample_rate = 44100

    project = ProjectMeta(
        id=project_id,
        name=os.path.splitext(safe_name)[0],
        original_file=original_path,
        duration_sec=round(duration, 3),
        sample_rate=sample_rate,
        created_at=datetime.now(timezone.utc).isoformat(),
        status="uploaded",
    )

    _projects[project_id] = project
    _save_meta(project)

    logger.info("Uploaded project %s: %s (%.1fs)", project_id, safe_name, duration)

    return {
        "project_id": project_id,
        "name": project.name,
        "duration_sec": project.duration_sec,
        "sample_rate": project.sample_rate,
    }


# ---------------------------------------------------------------------------
# YouTube Download
# ---------------------------------------------------------------------------

@app.post("/api/youtube")
async def youtube_download(req: YouTubeRequest):
    """Download audio from a YouTube URL and create a project."""
    project_id = uuid.uuid4().hex[:12]
    proj_dir = _project_dir(project_id)
    os.makedirs(proj_dir, exist_ok=True)

    async def _do_download():
        try:
            await ws_manager.send_progress(
                project_id, ProgressStage.downloading, 0, "Starting download"
            )

            from services.downloader import get_downloader

            downloader = get_downloader()

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None,
                lambda: downloader.download(req.url, output_dir=proj_dir),
            )

            # Get audio info
            try:
                info = sf.info(result["file_path"])
                duration = info.duration
                sample_rate = info.samplerate
            except Exception:
                duration = result.get("duration_sec", 0)
                sample_rate = 44100

            project = ProjectMeta(
                id=project_id,
                name=result.get("title", "YouTube Download"),
                original_file=result["file_path"],
                duration_sec=round(duration, 3),
                sample_rate=sample_rate,
                created_at=datetime.now(timezone.utc).isoformat(),
                status="uploaded",
            )

            _projects[project_id] = project
            _save_meta(project)

            await ws_manager.send_progress(
                project_id, ProgressStage.complete, 100, "Download complete"
            )
        except Exception as exc:
            logger.error("YouTube download failed: %s", exc)
            await ws_manager.send_progress(
                project_id, ProgressStage.error, 0, str(exc)
            )

    asyncio.create_task(_do_download())

    return {"project_id": project_id, "status": "downloading"}


# ---------------------------------------------------------------------------
# Stem Separation
# ---------------------------------------------------------------------------

@app.post("/api/separate")
async def separate_stems(req: SeparateRequest):
    """Start background stem separation for a project."""
    project = _get_project(req.project_id)

    if not os.path.exists(project.original_file):
        raise HTTPException(status_code=404, detail="Original audio file not found")

    async def _do_separate():
        try:
            await ws_manager.send_progress(
                req.project_id, ProgressStage.loading_model, 0, "Loading separation model"
            )

            from services.separator import get_separator

            separator = get_separator()
            output_dir = _stems_dir(req.project_id)

            async def _progress(pct: float, msg: str):
                await ws_manager.send_progress(
                    req.project_id, ProgressStage.separating, pct, msg
                )

            # Run separation in thread pool (CPU-bound)
            loop = asyncio.get_event_loop()

            # We need a sync callback that schedules async broadcast
            def sync_progress(pct: float, msg: str):
                asyncio.run_coroutine_threadsafe(
                    ws_manager.send_progress(
                        req.project_id, ProgressStage.separating, pct, msg
                    ),
                    loop,
                )

            stem_results = await loop.run_in_executor(
                None,
                lambda: separator.separate(
                    audio_path=project.original_file,
                    output_dir=output_dir,
                    quality=req.quality.value,
                    progress_callback=sync_progress,
                ),
            )

            # Update project metadata
            project.stems = [
                StemInfo(
                    name=StemName(s["name"]),
                    file_path=s["file_path"],
                    duration_sec=s["duration_sec"],
                    sample_rate=s["sample_rate"],
                    size_bytes=s["size_bytes"],
                )
                for s in stem_results
            ]
            project.status = "separated"
            _save_meta(project)

            await ws_manager.send_progress(
                req.project_id, ProgressStage.complete, 100, "Separation complete"
            )

        except Exception as exc:
            logger.error("Separation failed for %s: %s", req.project_id, exc, exc_info=True)
            project.status = "error"
            _save_meta(project)
            await ws_manager.send_progress(
                req.project_id, ProgressStage.error, 0, f"Separation failed: {exc}"
            )

    asyncio.create_task(_do_separate())

    return {"project_id": req.project_id, "status": "separating"}


# ---------------------------------------------------------------------------
# Chord Detection
# ---------------------------------------------------------------------------

@app.post("/api/chords")
async def detect_chords(req: ChordRequest):
    """Detect chords in the project audio."""
    project = _get_project(req.project_id)

    if not os.path.exists(project.original_file):
        raise HTTPException(status_code=404, detail="Original audio file not found")

    async def _do_chords():
        try:
            await ws_manager.send_progress(
                req.project_id, ProgressStage.analyzing, 0, "Detecting chords"
            )

            from services.analyzer import get_analyzer

            analyzer = get_analyzer()

            loop = asyncio.get_event_loop()
            chords = await loop.run_in_executor(
                None, lambda: analyzer.detect_chords(project.original_file)
            )

            project.chords = [
                {"time": c["time"], "duration": c["duration"], "chord": c["chord"], "confidence": c["confidence"]}
                for c in chords
            ]
            _save_meta(project)

            await ws_manager.send_progress(
                req.project_id, ProgressStage.complete, 100,
                f"Detected {len(chords)} chord segments"
            )
        except Exception as exc:
            logger.error("Chord detection failed: %s", exc, exc_info=True)
            await ws_manager.send_progress(
                req.project_id, ProgressStage.error, 0, str(exc)
            )

    asyncio.create_task(_do_chords())

    return {"project_id": req.project_id, "status": "analyzing"}


# ---------------------------------------------------------------------------
# Lyrics Transcription
# ---------------------------------------------------------------------------

@app.post("/api/lyrics")
async def transcribe_lyrics(req: LyricsRequest):
    """Transcribe lyrics from the project audio or vocals stem."""
    project = _get_project(req.project_id)

    # Prefer vocals stem if available, otherwise use original
    audio_path = project.original_file
    for stem in project.stems:
        if stem.name == StemName.vocals and os.path.exists(stem.file_path):
            audio_path = stem.file_path
            break

    if not os.path.exists(audio_path):
        raise HTTPException(status_code=404, detail="Audio file not found")

    async def _do_lyrics():
        try:
            await ws_manager.send_progress(
                req.project_id, ProgressStage.transcribing, 0, "Loading transcription model"
            )

            from services.transcriber import get_transcriber

            transcriber = get_transcriber()

            loop = asyncio.get_event_loop()
            segments = await loop.run_in_executor(
                None, lambda: transcriber.transcribe(audio_path)
            )

            project.lyrics = [
                {"start": s["start"], "end": s["end"], "text": s["text"]}
                for s in segments
            ]
            _save_meta(project)

            await ws_manager.send_progress(
                req.project_id, ProgressStage.complete, 100,
                f"Transcribed {len(segments)} segments"
            )
        except Exception as exc:
            logger.error("Transcription failed: %s", exc, exc_info=True)
            await ws_manager.send_progress(
                req.project_id, ProgressStage.error, 0, str(exc)
            )

    asyncio.create_task(_do_lyrics())

    return {"project_id": req.project_id, "status": "transcribing"}


# ---------------------------------------------------------------------------
# BPM Detection
# ---------------------------------------------------------------------------

@app.post("/api/bpm")
async def detect_bpm(req: BPMRequest):
    """Detect BPM of the project audio."""
    project = _get_project(req.project_id)

    if not os.path.exists(project.original_file):
        raise HTTPException(status_code=404, detail="Original audio file not found")

    async def _do_bpm():
        try:
            await ws_manager.send_progress(
                req.project_id, ProgressStage.analyzing, 0, "Detecting BPM"
            )

            from services.analyzer import get_analyzer

            analyzer = get_analyzer()

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None, lambda: analyzer.detect_bpm(project.original_file)
            )

            project.bpm = BPMResult(**result)
            _save_meta(project)

            await ws_manager.send_progress(
                req.project_id, ProgressStage.complete, 100,
                f"BPM: {result['bpm']}"
            )
        except Exception as exc:
            logger.error("BPM detection failed: %s", exc, exc_info=True)
            await ws_manager.send_progress(
                req.project_id, ProgressStage.error, 0, str(exc)
            )

    asyncio.create_task(_do_bpm())

    return {"project_id": req.project_id, "status": "analyzing"}


# ---------------------------------------------------------------------------
# Pitch Shift
# ---------------------------------------------------------------------------

@app.post("/api/pitch")
async def pitch_shift(req: PitchRequest):
    """Pitch-shift a stem by the given number of semitones."""
    project = _get_project(req.project_id)

    # Find the stem
    stem_info = None
    for s in project.stems:
        if s.name == req.stem:
            stem_info = s
            break

    if stem_info is None or not os.path.exists(stem_info.file_path):
        raise HTTPException(status_code=404, detail=f"Stem '{req.stem.value}' not found")

    from services.analyzer import get_analyzer

    analyzer = get_analyzer()

    # Output to a new file
    stem_dir = os.path.dirname(stem_info.file_path)
    sign = "up" if req.semitones > 0 else "down"
    output_name = f"{req.stem.value}_pitch_{sign}{abs(req.semitones):.0f}.wav"
    output_path = os.path.join(stem_dir, output_name)

    loop = asyncio.get_event_loop()
    result_path = await loop.run_in_executor(
        None,
        lambda: analyzer.pitch_shift(stem_info.file_path, output_path, req.semitones),
    )

    return {
        "project_id": req.project_id,
        "stem": req.stem.value,
        "semitones": req.semitones,
        "output_file": os.path.basename(result_path),
        "download_url": f"/api/stems/{req.project_id}/{os.path.basename(result_path)}",
    }


# ---------------------------------------------------------------------------
# Tempo Change
# ---------------------------------------------------------------------------

@app.post("/api/tempo")
async def tempo_change(req: TempoRequest):
    """Change the tempo of a stem by the given factor."""
    project = _get_project(req.project_id)

    stem_info = None
    for s in project.stems:
        if s.name == req.stem:
            stem_info = s
            break

    if stem_info is None or not os.path.exists(stem_info.file_path):
        raise HTTPException(status_code=404, detail=f"Stem '{req.stem.value}' not found")

    from services.analyzer import get_analyzer

    analyzer = get_analyzer()

    stem_dir = os.path.dirname(stem_info.file_path)
    output_name = f"{req.stem.value}_tempo_{req.factor:.2f}x.wav"
    output_path = os.path.join(stem_dir, output_name)

    loop = asyncio.get_event_loop()
    result_path = await loop.run_in_executor(
        None,
        lambda: analyzer.tempo_change(stem_info.file_path, output_path, req.factor),
    )

    return {
        "project_id": req.project_id,
        "stem": req.stem.value,
        "factor": req.factor,
        "output_file": os.path.basename(result_path),
        "download_url": f"/api/stems/{req.project_id}/{os.path.basename(result_path)}",
    }


# ---------------------------------------------------------------------------
# Project Listing
# ---------------------------------------------------------------------------

@app.get("/api/projects")
async def list_projects():
    """List all projects."""
    # Refresh from disk
    _load_all_projects()

    projects = []
    for pid, meta in sorted(_projects.items(), key=lambda x: x[1].created_at, reverse=True):
        projects.append({
            "id": meta.id,
            "name": meta.name,
            "duration_sec": meta.duration_sec,
            "status": meta.status,
            "stems_count": len(meta.stems),
            "created_at": meta.created_at,
        })

    return {"projects": projects, "total": len(projects)}


# ---------------------------------------------------------------------------
# Single Project
# ---------------------------------------------------------------------------

@app.get("/api/projects/{project_id}")
async def get_project(project_id: str):
    """Get full project details including stems, chords, lyrics, etc."""
    project = _get_project(project_id)
    return project.model_dump()


# ---------------------------------------------------------------------------
# Stem File Streaming
# ---------------------------------------------------------------------------

@app.get("/api/stems/{project_id}/{stem_name}")
async def get_stem_file(project_id: str, stem_name: str):
    """Stream a stem WAV file."""
    stems_path = _stems_dir(project_id)

    # Support both bare stem names ("vocals") and full filenames ("vocals.wav")
    if not stem_name.endswith(".wav"):
        stem_name = f"{stem_name}.wav"

    file_path = os.path.join(stems_path, stem_name)

    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail=f"Stem file not found: {stem_name}")

    return FileResponse(
        path=file_path,
        media_type="audio/wav",
        filename=stem_name,
        headers={"Accept-Ranges": "bytes"},
    )


# ---------------------------------------------------------------------------
# Export (ZIP of all stems)
# ---------------------------------------------------------------------------

@app.get("/api/export/{project_id}")
async def export_project(project_id: str):
    """Export all stems as a ZIP file."""
    project = _get_project(project_id)

    if not project.stems:
        raise HTTPException(status_code=400, detail="No stems available for export")

    zip_path = os.path.join(_project_dir(project_id), f"{project.name}_stems.zip")

    # Create ZIP
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for stem in project.stems:
            if os.path.exists(stem.file_path):
                arcname = f"{project.name}/{stem.name.value}.wav"
                zf.write(stem.file_path, arcname)

        # Include metadata
        meta_json = project.model_dump_json(indent=2)
        zf.writestr(f"{project.name}/metadata.json", meta_json)

    if not os.path.exists(zip_path):
        raise HTTPException(status_code=500, detail="Failed to create ZIP export")

    return FileResponse(
        path=zip_path,
        media_type="application/zip",
        filename=f"{project.name}_stems.zip",
    )


# ---------------------------------------------------------------------------
# WebSocket Progress
# ---------------------------------------------------------------------------

@app.websocket("/ws/progress")
async def websocket_progress(ws: WebSocket):
    """WebSocket endpoint for real-time progress updates."""
    await ws_manager.connect(ws)
    try:
        while True:
            # Keep connection alive; client can send pings or subscribe to projects
            data = await ws.receive_text()
            # Optional: handle client messages (e.g., subscribe to specific project)
            try:
                msg = json.loads(data)
                if msg.get("type") == "ping":
                    await ws.send_text(json.dumps({"type": "pong"}))
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        await ws_manager.disconnect(ws)
    except Exception:
        await ws_manager.disconnect(ws)


# ---------------------------------------------------------------------------
# Run directly
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=os.getenv("ENV", "production") == "development",
        workers=1,
        log_level="info",
    )
