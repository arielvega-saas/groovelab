"""Demucs htdemucs_6s stem separation service.

Separates audio into 6 stems: vocals, drums, bass, guitar, piano, other.
Uses lazy model loading and supports progress callbacks.
"""

from __future__ import annotations

import logging
import os
import shutil
from pathlib import Path
from typing import Callable, List, Optional

import numpy as np
import soundfile as sf
import torch

logger = logging.getLogger(__name__)

# Stem names produced by htdemucs_6s
STEM_NAMES_6S = ["vocals", "drums", "bass", "guitar", "piano", "other"]


class StemSeparator:
    """Wraps Facebook/Meta Demucs for 6-stem separation."""

    def __init__(self) -> None:
        self._model = None
        self._device: Optional[str] = None

    # ------------------------------------------------------------------
    # Lazy loading
    # ------------------------------------------------------------------

    def _ensure_model(self, quality: str = "high") -> None:
        """Load the Demucs model on first use."""
        if self._model is not None:
            return

        logger.info("Loading Demucs htdemucs_6s model (this may take a moment)...")

        from demucs.pretrained import get_model
        from demucs.apply import BagOfModels

        model_name = "htdemucs_6s"
        self._model = get_model(model_name)

        # Choose device
        if torch.cuda.is_available():
            self._device = "cuda"
        elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            self._device = "mps"
        else:
            self._device = "cpu"

        self._model.to(self._device)
        self._model.eval()
        logger.info("Demucs model loaded on %s", self._device)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def separate(
        self,
        audio_path: str,
        output_dir: str,
        quality: str = "high",
        progress_callback: Optional[Callable[[float, str], None]] = None,
    ) -> List[dict]:
        """Separate an audio file into stems.

        Args:
            audio_path: Path to the input audio file (WAV preferred).
            output_dir: Directory to write stem WAV files into.
            quality: "fast" uses fewer overlaps, "high" uses more.
            progress_callback: Optional ``fn(percent, message)`` called during processing.

        Returns:
            List of dicts with keys: name, file_path, duration_sec, sample_rate, size_bytes.
        """
        from demucs.apply import apply_model
        from demucs.audio import AudioFile

        def _progress(pct: float, msg: str) -> None:
            if progress_callback:
                progress_callback(pct, msg)

        _progress(0, "Loading separation model")
        self._ensure_model(quality)

        _progress(5, "Reading audio file")

        # Load audio via demucs AudioFile helper
        audio_path_obj = Path(audio_path)
        wav = AudioFile(audio_path_obj).read(
            streams=0,
            samplerate=self._model.samplerate,
            channels=self._model.audio_channels,
        )
        ref = wav.mean(0)
        wav = (wav - ref.mean()) / (ref.std() + 1e-8)
        wav = wav.to(self._device)

        _progress(15, "Separating stems")

        # Configure overlap/shifts based on quality
        if quality == "fast":
            overlaps = 0.1
            shifts = 1
        else:
            overlaps = 0.25
            shifts = 5

        # Run model
        with torch.no_grad():
            sources = apply_model(
                self._model,
                wav[None],
                device=self._device,
                shifts=shifts,
                overlap=overlaps,
                progress=False,
            )[0]

        # De-normalize
        sources = sources * ref.std() + ref.mean()
        sources = sources.cpu().numpy()

        _progress(75, "Saving stems")

        # Save each stem
        os.makedirs(output_dir, exist_ok=True)
        stem_results = []
        source_names = self._model.sources  # list of stem names from the model

        for idx, stem_name in enumerate(source_names):
            _progress(75 + (idx / len(source_names)) * 20, f"Saving {stem_name}")

            stem_audio = sources[idx]  # shape: (channels, samples)
            stem_file = os.path.join(output_dir, f"{stem_name}.wav")

            # soundfile expects (samples, channels)
            sf.write(
                stem_file,
                stem_audio.T,
                samplerate=self._model.samplerate,
                subtype="PCM_16",
            )

            file_size = os.path.getsize(stem_file)
            duration = stem_audio.shape[1] / self._model.samplerate

            stem_results.append({
                "name": stem_name,
                "file_path": stem_file,
                "duration_sec": round(duration, 3),
                "sample_rate": self._model.samplerate,
                "size_bytes": file_size,
            })

        _progress(100, "Separation complete")
        logger.info("Separated %d stems into %s", len(stem_results), output_dir)
        return stem_results


# Module-level singleton
_separator: Optional[StemSeparator] = None


def get_separator() -> StemSeparator:
    """Return the module-level separator singleton."""
    global _separator
    if _separator is None:
        _separator = StemSeparator()
    return _separator
