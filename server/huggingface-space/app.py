"""
GrooveLab Stem Separator — Hugging Face Space
==============================================
Gradio app that uses Demucs htdemucs for stem separation.
Exposes both Gradio UI and a REST API endpoint.

Deploy: Create a new Space on huggingface.co, select "Gradio",
        upload this file + requirements.txt.
"""

import os
import tempfile
import base64
import json
import io
import gradio as gr
import numpy as np
import soundfile as sf

# Use demucs for separation
import torch
import torchaudio
from demucs.pretrained import get_model
from demucs.apply import apply_model

# Load model at startup
print("[GrooveLab] Loading Demucs model...")
model = get_model("htdemucs")
model.eval()
if torch.cuda.is_available():
    model.cuda()
    print("[GrooveLab] Using GPU")
else:
    print("[GrooveLab] Using CPU")

STEM_NAMES = model.sources  # ['drums', 'bass', 'other', 'vocals']
print(f"[GrooveLab] Model loaded. Stems: {STEM_NAMES}")


def audio_array_to_base64_wav(audio_np: np.ndarray, sr: int) -> str:
    """Convert numpy array (channels, samples) to base64 WAV string."""
    buf = io.BytesIO()
    # soundfile expects (samples, channels)
    if audio_np.ndim == 2:
        sf.write(buf, audio_np.T, sr, format="WAV", subtype="PCM_16")
    else:
        sf.write(buf, audio_np, sr, format="WAV", subtype="PCM_16")
    buf.seek(0)
    return base64.b64encode(buf.read()).decode("utf-8")


def separate_stems(audio_path: str) -> str:
    """
    Separate audio file into stems.
    Returns JSON string with base64-encoded WAV stems.
    """
    if not audio_path:
        return json.dumps({"success": False, "error": "No audio file provided"})

    try:
        # Load audio
        wav, sr = torchaudio.load(audio_path)

        # Resample to model's sample rate if needed
        if sr != model.samplerate:
            wav = torchaudio.transforms.Resample(sr, model.samplerate)(wav)
            sr = model.samplerate

        # Ensure stereo
        if wav.shape[0] == 1:
            wav = wav.repeat(2, 1)
        elif wav.shape[0] > 2:
            wav = wav[:2]

        # Add batch dimension
        wav = wav.unsqueeze(0)

        # Move to device
        device = next(model.parameters()).device
        wav = wav.to(device)

        # Separate
        print(f"[GrooveLab] Separating: {audio_path}, shape: {wav.shape}")
        with torch.no_grad():
            sources = apply_model(model, wav, overlap=0.25, progress=True)

        # sources shape: (batch=1, stems, channels, samples)
        sources = sources.squeeze(0).cpu().numpy()
        duration = sources.shape[-1] / sr

        # Build response
        stems = {}
        for i, name in enumerate(STEM_NAMES):
            stem_audio = sources[i]  # (channels, samples)
            stems[name] = audio_array_to_base64_wav(stem_audio, sr)
            print(f"[GrooveLab] Stem '{name}': shape {stem_audio.shape}")

        result = {
            "success": True,
            "stems": stems,
            "stemNames": list(STEM_NAMES),
            "sampleRate": sr,
            "duration": round(duration, 3),
        }

        print(f"[GrooveLab] Separation complete: {len(stems)} stems, {duration:.1f}s")
        return json.dumps(result)

    except Exception as e:
        print(f"[GrooveLab] Error: {e}")
        return json.dumps({"success": False, "error": str(e)})


# Gradio Interface
with gr.Blocks(title="GrooveLab Stem Separator") as demo:
    gr.Markdown("# 🎵 GrooveLab Stem Separator")
    gr.Markdown("Upload an audio file to separate it into stems (vocals, drums, bass, other).")

    with gr.Row():
        audio_input = gr.Audio(type="filepath", label="Upload Audio")

    with gr.Row():
        separate_btn = gr.Button("Separate Stems", variant="primary")

    with gr.Row():
        output_json = gr.Textbox(label="Result (JSON)", lines=5)

    separate_btn.click(
        fn=separate_stems,
        inputs=[audio_input],
        outputs=[output_json],
    )

# Also expose as API endpoint
demo.launch(
    server_name="0.0.0.0",
    server_port=7860,
    share=False,
)
