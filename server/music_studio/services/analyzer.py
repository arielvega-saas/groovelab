"""Audio analysis service using librosa.

Provides BPM detection, chord detection, section detection,
pitch shifting, and tempo change.
"""

from __future__ import annotations

import logging
import os
from typing import List, Optional

import librosa
import numpy as np
import soundfile as sf

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Chord templates (major and minor triads across all 12 pitch classes)
# ---------------------------------------------------------------------------

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

def _build_chord_templates() -> dict:
    """Build normalized chord templates for major/minor triads."""
    templates: dict[str, np.ndarray] = {}
    for root in range(12):
        # Major triad: root, major third (+4), fifth (+7)
        major = np.zeros(12, dtype=np.float32)
        major[root] = 1.0
        major[(root + 4) % 12] = 1.0
        major[(root + 7) % 12] = 1.0
        major /= np.linalg.norm(major)
        templates[NOTE_NAMES[root]] = major

        # Minor triad: root, minor third (+3), fifth (+7)
        minor = np.zeros(12, dtype=np.float32)
        minor[root] = 1.0
        minor[(root + 3) % 12] = 1.0
        minor[(root + 7) % 12] = 1.0
        minor /= np.linalg.norm(minor)
        templates[f"{NOTE_NAMES[root]}m"] = minor

    return templates


CHORD_TEMPLATES = _build_chord_templates()


class AudioAnalyzer:
    """Provides audio analysis functionality via librosa."""

    # ------------------------------------------------------------------
    # BPM Detection
    # ------------------------------------------------------------------

    def detect_bpm(self, audio_path: str) -> dict:
        """Detect BPM and beat positions.

        Returns:
            dict with keys: bpm, confidence, beat_times.
        """
        logger.info("Detecting BPM for %s", audio_path)

        y, sr = librosa.load(audio_path, sr=22050, mono=True)
        tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)

        # librosa may return an array; extract scalar
        if hasattr(tempo, "__len__"):
            tempo = float(tempo[0]) if len(tempo) > 0 else 0.0
        else:
            tempo = float(tempo)

        beat_times = librosa.frames_to_time(beat_frames, sr=sr).tolist()

        # Estimate confidence from beat strength
        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        if len(beat_frames) > 0 and len(onset_env) > 0:
            valid_frames = beat_frames[beat_frames < len(onset_env)]
            if len(valid_frames) > 0:
                beat_strengths = onset_env[valid_frames]
                confidence = float(np.clip(np.mean(beat_strengths) / (np.max(onset_env) + 1e-8), 0, 1))
            else:
                confidence = 0.0
        else:
            confidence = 0.0

        result = {
            "bpm": round(tempo, 2),
            "confidence": round(confidence, 3),
            "beat_times": [round(t, 4) for t in beat_times],
        }
        logger.info("Detected BPM: %.1f (confidence: %.2f)", result["bpm"], result["confidence"])
        return result

    # ------------------------------------------------------------------
    # Chord Detection
    # ------------------------------------------------------------------

    def detect_chords(
        self,
        audio_path: str,
        hop_length: int = 2048,
        min_duration: float = 0.3,
    ) -> List[dict]:
        """Detect chords using chroma features and template matching.

        Returns:
            List of dicts with keys: time, duration, chord, confidence.
        """
        logger.info("Detecting chords for %s", audio_path)

        y, sr = librosa.load(audio_path, sr=22050, mono=True)
        chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)
        # shape: (12, T)

        frame_duration = hop_length / sr
        template_names = list(CHORD_TEMPLATES.keys())
        template_matrix = np.array([CHORD_TEMPLATES[n] for n in template_names])  # (N_chords, 12)

        # Normalize chroma columns
        chroma_norm = chroma / (np.linalg.norm(chroma, axis=0, keepdims=True) + 1e-8)

        # Compute similarities: (N_chords, T)
        similarities = template_matrix @ chroma_norm

        best_indices = np.argmax(similarities, axis=0)
        best_scores = np.max(similarities, axis=0)

        # Build raw frame-level chord sequence
        raw_chords = []
        for frame_idx in range(len(best_indices)):
            chord_name = template_names[best_indices[frame_idx]]
            score = float(best_scores[frame_idx])
            t = frame_idx * frame_duration
            raw_chords.append((t, chord_name, score))

        # Merge consecutive identical chords
        merged: List[dict] = []
        if raw_chords:
            current_chord = raw_chords[0][1]
            current_start = raw_chords[0][0]
            scores = [raw_chords[0][2]]

            for t, chord, score in raw_chords[1:]:
                if chord == current_chord:
                    scores.append(score)
                else:
                    duration = t - current_start
                    if duration >= min_duration:
                        merged.append({
                            "time": round(current_start, 3),
                            "duration": round(duration, 3),
                            "chord": current_chord,
                            "confidence": round(float(np.mean(scores)), 3),
                        })
                    current_chord = chord
                    current_start = t
                    scores = [score]

            # Last segment
            final_time = len(best_indices) * frame_duration
            duration = final_time - current_start
            if duration >= min_duration:
                merged.append({
                    "time": round(current_start, 3),
                    "duration": round(duration, 3),
                    "chord": current_chord,
                    "confidence": round(float(np.mean(scores)), 3),
                })

        logger.info("Detected %d chord segments", len(merged))
        return merged

    # ------------------------------------------------------------------
    # Section Detection
    # ------------------------------------------------------------------

    def detect_sections(self, audio_path: str, n_sections: int = 8) -> List[dict]:
        """Detect structural sections via spectral novelty and peak picking.

        Returns:
            List of dicts with keys: start, end, label.
        """
        logger.info("Detecting sections for %s", audio_path)

        y, sr = librosa.load(audio_path, sr=22050, mono=True)
        duration = librosa.get_duration(y=y, sr=sr)

        # Compute mel spectrogram
        S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=128, hop_length=512)
        S_db = librosa.power_to_db(S, ref=np.max)

        # Spectral novelty via cosine distance between consecutive frames
        S_norm = S_db / (np.linalg.norm(S_db, axis=0, keepdims=True) + 1e-8)
        novelty = np.zeros(S_norm.shape[1])
        for i in range(1, S_norm.shape[1]):
            novelty[i] = 1.0 - np.dot(S_norm[:, i], S_norm[:, i - 1])
        novelty = np.maximum(novelty, 0)

        # Smooth novelty curve
        kernel_size = 31
        kernel = np.ones(kernel_size) / kernel_size
        novelty_smooth = np.convolve(novelty, kernel, mode="same")

        # Pick peaks
        from scipy.signal import find_peaks

        min_distance = int(4.0 * sr / 512)  # at least 4 seconds apart
        peaks, properties = find_peaks(
            novelty_smooth,
            distance=min_distance,
            prominence=np.std(novelty_smooth) * 0.3,
        )

        # Convert peak frames to times
        boundary_times = [0.0]
        frame_times = librosa.frames_to_time(peaks, sr=sr, hop_length=512)
        boundary_times.extend(frame_times.tolist())
        boundary_times.append(duration)

        # Limit to a reasonable number of sections
        if len(boundary_times) > n_sections + 2:
            # Keep only the most prominent boundaries
            if len(peaks) > 0 and "prominences" in properties:
                prominences = properties["prominences"]
                top_indices = np.argsort(prominences)[-n_sections:]
                top_peaks = np.sort(peaks[top_indices])
                boundary_times = [0.0]
                boundary_times.extend(
                    librosa.frames_to_time(top_peaks, sr=sr, hop_length=512).tolist()
                )
                boundary_times.append(duration)

        # Assign labels heuristically
        section_labels = [
            "intro", "verse", "chorus", "verse", "chorus",
            "bridge", "chorus", "outro",
        ]
        sections = []
        for i in range(len(boundary_times) - 1):
            label = section_labels[i] if i < len(section_labels) else f"section_{i}"
            sections.append({
                "start": round(boundary_times[i], 3),
                "end": round(boundary_times[i + 1], 3),
                "label": label,
            })

        logger.info("Detected %d sections", len(sections))
        return sections

    # ------------------------------------------------------------------
    # Pitch Shift
    # ------------------------------------------------------------------

    def pitch_shift(
        self,
        audio_path: str,
        output_path: str,
        semitones: float,
    ) -> str:
        """Shift the pitch of an audio file by the given number of semitones.

        Returns:
            Path to the output file.
        """
        logger.info("Pitch shifting %s by %+.1f semitones", audio_path, semitones)

        y, sr = librosa.load(audio_path, sr=None, mono=False)

        # Try pyrubberband first (higher quality), fall back to librosa
        try:
            import pyrubberband as pyrb

            if y.ndim == 1:
                shifted = pyrb.pitch_shift(y, sr, semitones)
            else:
                # Process each channel
                channels = []
                for ch in range(y.shape[0]):
                    channels.append(pyrb.pitch_shift(y[ch], sr, semitones))
                shifted = np.stack(channels)
        except ImportError:
            logger.warning("pyrubberband not available, using librosa pitch_shift")
            if y.ndim == 1:
                shifted = librosa.effects.pitch_shift(y=y, sr=sr, n_steps=semitones)
            else:
                channels = []
                for ch in range(y.shape[0]):
                    channels.append(
                        librosa.effects.pitch_shift(y=y[ch], sr=sr, n_steps=semitones)
                    )
                shifted = np.stack(channels)

        # Write output
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        if shifted.ndim == 1:
            sf.write(output_path, shifted, sr, subtype="PCM_16")
        else:
            sf.write(output_path, shifted.T, sr, subtype="PCM_16")

        logger.info("Pitch-shifted file saved to %s", output_path)
        return output_path

    # ------------------------------------------------------------------
    # Tempo Change
    # ------------------------------------------------------------------

    def tempo_change(
        self,
        audio_path: str,
        output_path: str,
        factor: float,
    ) -> str:
        """Change the tempo of an audio file by the given factor.

        A factor of 2.0 makes it twice as fast, 0.5 makes it half speed.

        Returns:
            Path to the output file.
        """
        logger.info("Changing tempo of %s by factor %.2f", audio_path, factor)

        y, sr = librosa.load(audio_path, sr=None, mono=False)

        try:
            import pyrubberband as pyrb

            if y.ndim == 1:
                stretched = pyrb.time_stretch(y, sr, factor)
            else:
                channels = []
                for ch in range(y.shape[0]):
                    channels.append(pyrb.time_stretch(y[ch], sr, factor))
                stretched = np.stack(channels)
        except ImportError:
            logger.warning("pyrubberband not available, using librosa time_stretch")
            if y.ndim == 1:
                stretched = librosa.effects.time_stretch(y=y, rate=factor)
            else:
                channels = []
                for ch in range(y.shape[0]):
                    channels.append(librosa.effects.time_stretch(y=y[ch], rate=factor))
                stretched = np.stack(channels)

        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        if stretched.ndim == 1:
            sf.write(output_path, stretched, sr, subtype="PCM_16")
        else:
            sf.write(output_path, stretched.T, sr, subtype="PCM_16")

        logger.info("Tempo-changed file saved to %s", output_path)
        return output_path


# Module-level singleton
_analyzer: Optional[AudioAnalyzer] = None


def get_analyzer() -> AudioAnalyzer:
    global _analyzer
    if _analyzer is None:
        _analyzer = AudioAnalyzer()
    return _analyzer
