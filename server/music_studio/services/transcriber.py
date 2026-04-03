"""Whisper-based lyrics transcription service.

Provides word-level timestamps via OpenAI Whisper.
Uses lazy model loading to avoid startup cost.
"""

from __future__ import annotations

import logging
import os
from typing import List, Optional

logger = logging.getLogger(__name__)

# Default model size; override with WHISPER_MODEL_SIZE env var
DEFAULT_MODEL_SIZE = "small"


class LyricsTranscriber:
    """Transcribes vocals/audio to timestamped lyrics using Whisper."""

    def __init__(self, model_size: Optional[str] = None) -> None:
        self._model = None
        self._model_size = model_size or os.getenv("WHISPER_MODEL_SIZE", DEFAULT_MODEL_SIZE)

    # ------------------------------------------------------------------
    # Lazy loading
    # ------------------------------------------------------------------

    def _ensure_model(self) -> None:
        """Load the Whisper model on first use."""
        if self._model is not None:
            return

        logger.info("Loading Whisper model '%s' (this may take a moment)...", self._model_size)

        import whisper

        self._model = whisper.load_model(self._model_size)
        logger.info("Whisper model '%s' loaded successfully", self._model_size)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def transcribe(
        self,
        audio_path: str,
        language: Optional[str] = None,
    ) -> List[dict]:
        """Transcribe audio to word-level timestamped segments.

        Args:
            audio_path: Path to the audio file (WAV, MP3, etc.).
            language: Optional ISO language code (e.g. "en", "es").
                      If None, Whisper auto-detects.

        Returns:
            List of dicts with keys: start, end, text.
        """
        logger.info("Transcribing %s", audio_path)
        self._ensure_model()

        options = {
            "word_timestamps": True,
            "verbose": False,
        }
        if language:
            options["language"] = language

        result = self._model.transcribe(audio_path, **options)

        segments: List[dict] = []

        for segment in result.get("segments", []):
            # Try word-level timestamps first
            words = segment.get("words")
            if words:
                for word_info in words:
                    segments.append({
                        "start": round(float(word_info.get("start", 0)), 3),
                        "end": round(float(word_info.get("end", 0)), 3),
                        "text": word_info.get("word", "").strip(),
                    })
            else:
                # Fall back to segment-level
                text = segment.get("text", "").strip()
                if text:
                    segments.append({
                        "start": round(float(segment.get("start", 0)), 3),
                        "end": round(float(segment.get("end", 0)), 3),
                        "text": text,
                    })

        # Filter out empty entries
        segments = [s for s in segments if s["text"]]

        logger.info("Transcribed %d segments from %s", len(segments), audio_path)
        return segments


# Module-level singleton
_transcriber: Optional[LyricsTranscriber] = None


def get_transcriber() -> LyricsTranscriber:
    """Return the module-level transcriber singleton."""
    global _transcriber
    if _transcriber is None:
        _transcriber = LyricsTranscriber()
    return _transcriber
