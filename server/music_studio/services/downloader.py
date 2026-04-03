"""yt-dlp wrapper for downloading audio from YouTube and other URLs.

Downloads audio, converts to WAV via ffmpeg, and returns
the file path along with basic metadata.
"""

from __future__ import annotations

import logging
import os
import re
import uuid
from typing import Optional

logger = logging.getLogger(__name__)


def sanitize_filename(name: str) -> str:
    """Remove or replace characters unsafe for filenames."""
    name = re.sub(r'[<>:"/\\|?*]', "_", name)
    name = re.sub(r"\s+", "_", name.strip())
    name = name[:120]  # limit length
    return name or "download"


class AudioDownloader:
    """Downloads audio from YouTube/URLs using yt-dlp and converts to WAV."""

    def __init__(self, output_dir: str = "/tmp/groovelab_downloads") -> None:
        self._output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)

    def download(
        self,
        url: str,
        output_dir: Optional[str] = None,
        progress_callback=None,
    ) -> dict:
        """Download audio from a URL and convert to WAV.

        Args:
            url: YouTube URL or other supported URL.
            output_dir: Override output directory.
            progress_callback: Optional ``fn(percent, message)``.

        Returns:
            dict with keys: file_path, title, duration_sec, url.

        Raises:
            RuntimeError: If download or conversion fails.
        """
        import yt_dlp

        dest_dir = output_dir or self._output_dir
        os.makedirs(dest_dir, exist_ok=True)

        # Temporary filename with unique ID to avoid collisions
        temp_id = uuid.uuid4().hex[:8]
        temp_template = os.path.join(dest_dir, f"dl_{temp_id}_%(title)s.%(ext)s")

        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": temp_template,
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "wav",
                    "preferredquality": "0",
                }
            ],
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
        }

        # Add progress hook if callback provided
        if progress_callback:
            def _hook(d):
                if d["status"] == "downloading":
                    total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
                    downloaded = d.get("downloaded_bytes", 0)
                    if total > 0:
                        pct = (downloaded / total) * 80  # 0-80% for download
                        progress_callback(pct, "Downloading audio")
                elif d["status"] == "finished":
                    progress_callback(80, "Converting to WAV")

            ydl_opts["progress_hooks"] = [_hook]

        metadata = {}

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Extract info first to get metadata
                info = ydl.extract_info(url, download=False)
                metadata["title"] = info.get("title", "Unknown")
                metadata["duration_sec"] = info.get("duration", 0) or 0
                metadata["url"] = url

                # Perform download
                ydl.download([url])

        except Exception as exc:
            logger.error("yt-dlp download failed for %s: %s", url, exc)
            raise RuntimeError(f"Download failed: {exc}") from exc

        # Find the output WAV file
        wav_path = None
        for fname in os.listdir(dest_dir):
            if fname.startswith(f"dl_{temp_id}_") and fname.endswith(".wav"):
                wav_path = os.path.join(dest_dir, fname)
                break

        if wav_path is None or not os.path.exists(wav_path):
            raise RuntimeError("WAV file not found after download/conversion")

        # Rename to a clean filename
        safe_title = sanitize_filename(metadata.get("title", "download"))
        final_name = f"{safe_title}.wav"
        final_path = os.path.join(dest_dir, final_name)

        # Handle name collisions
        if os.path.exists(final_path) and final_path != wav_path:
            base, ext = os.path.splitext(final_name)
            final_path = os.path.join(dest_dir, f"{base}_{temp_id}{ext}")

        if wav_path != final_path:
            os.rename(wav_path, final_path)

        metadata["file_path"] = final_path

        if progress_callback:
            progress_callback(100, "Download complete")

        logger.info("Downloaded: %s -> %s", url, final_path)
        return metadata


# Module-level singleton
_downloader: Optional[AudioDownloader] = None


def get_downloader(output_dir: str = "/tmp/groovelab_downloads") -> AudioDownloader:
    """Return the module-level downloader singleton."""
    global _downloader
    if _downloader is None:
        _downloader = AudioDownloader(output_dir=output_dir)
    return _downloader
