---
title: GrooveLab Stem Separator
emoji: 🎵
colorFrom: green
colorTo: blue
sdk: gradio
sdk_version: 4.44.0
app_file: app.py
pinned: false
---

# GrooveLab Stem Separator

Separates audio into stems (vocals, drums, bass, other) using Demucs.

## API Usage

```bash
curl -X POST https://YOUR-SPACE.hf.space/api/predict \
  -H "Content-Type: application/json" \
  -d '{"data": ["path/to/audio.mp3"]}'
```
