"""Pydantic models for GrooveLab Music Studio API."""

from __future__ import annotations

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class StemName(str, Enum):
    vocals = "vocals"
    drums = "drums"
    bass = "bass"
    guitar = "guitar"
    piano = "piano"
    other = "other"


class SeparationQuality(str, Enum):
    fast = "fast"
    high = "high"


class ProgressStage(str, Enum):
    queued = "queued"
    loading_model = "loading_model"
    separating = "separating"
    analyzing = "analyzing"
    transcribing = "transcribing"
    downloading = "downloading"
    complete = "complete"
    error = "error"


# ---------------------------------------------------------------------------
# Core data models
# ---------------------------------------------------------------------------

class StemInfo(BaseModel):
    """Metadata for a single separated stem."""
    name: StemName
    file_path: str
    duration_sec: float = 0.0
    sample_rate: int = 44100
    size_bytes: int = 0


class ChordEvent(BaseModel):
    """A detected chord at a specific time position."""
    time: float = Field(..., description="Start time in seconds")
    duration: float = Field(..., description="Duration in seconds")
    chord: str = Field(..., description="Chord label, e.g. 'Am', 'G', 'Cmaj7'")
    confidence: float = Field(0.0, ge=0.0, le=1.0)


class LyricSegment(BaseModel):
    """A word-level or phrase-level lyric segment."""
    start: float = Field(..., description="Start time in seconds")
    end: float = Field(..., description="End time in seconds")
    text: str


class BPMResult(BaseModel):
    """Result of BPM detection."""
    bpm: float
    confidence: float = Field(0.0, ge=0.0, le=1.0)
    beat_times: List[float] = Field(default_factory=list)


class SectionInfo(BaseModel):
    """A detected structural section (intro, verse, chorus, etc.)."""
    start: float
    end: float
    label: str = Field(..., description="Section label, e.g. 'intro', 'verse', 'chorus'")


class ProjectMeta(BaseModel):
    """Full metadata for a project."""
    id: str
    name: str
    original_file: str
    duration_sec: float = 0.0
    sample_rate: int = 44100
    stems: List[StemInfo] = Field(default_factory=list)
    bpm: Optional[BPMResult] = None
    chords: List[ChordEvent] = Field(default_factory=list)
    lyrics: List[LyricSegment] = Field(default_factory=list)
    sections: List[SectionInfo] = Field(default_factory=list)
    created_at: str = ""
    status: str = "uploaded"


class ProgressEvent(BaseModel):
    """WebSocket progress update."""
    project_id: str
    stage: ProgressStage
    progress: float = Field(0.0, ge=0.0, le=100.0, description="Percentage 0-100")
    message: str = ""
    detail: Optional[str] = None


# ---------------------------------------------------------------------------
# Request / Response helpers
# ---------------------------------------------------------------------------

class YouTubeRequest(BaseModel):
    url: str


class SeparateRequest(BaseModel):
    project_id: str
    quality: SeparationQuality = SeparationQuality.high


class ChordRequest(BaseModel):
    project_id: str


class LyricsRequest(BaseModel):
    project_id: str


class BPMRequest(BaseModel):
    project_id: str


class PitchRequest(BaseModel):
    project_id: str
    stem: StemName
    semitones: float = Field(..., description="Semitones to shift (positive=up, negative=down)")


class TempoRequest(BaseModel):
    project_id: str
    stem: StemName
    factor: float = Field(..., gt=0.0, description="Tempo factor (e.g. 1.5 = 50%% faster)")
