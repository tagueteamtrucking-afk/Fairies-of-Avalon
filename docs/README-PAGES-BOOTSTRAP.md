# Avalon — Pages/Apps Bootstrap v2

## Install
1. Upload these files to repo root and commit to **main**.
2. Actions → run **Workflows — Sanity**.
3. Actions → run **Avalon Run All**.

## What gets written
- `pages/apps/alexandria/worlds/<id>/*`  (seed, timeline, codex, atlas, bible, figures, scenes, checklist, latest.txt)
- `pages/apps/tracy/artboards/<id>/*`
- `pages/apps/overseers/vrm-index.json`
- `pages/apps/charlotte/pipelines/<id>/plan.json`

## Alexandria Microapp
Open `/pages/apps/` on your Pages site → Alexandria. Choose / roll / custom for every field. Export JSON and upload it under `pages/apps/alexandria/worlds/` (or keep for reference).

## Next (LLM/TTS/STT)
- Add keys as repo secrets and we’ll wire a server-side LLM Bridge workflow (off by default).
- TTS suggestions: Azure Neural Voices, Google Cloud TTS, ElevenLabs; STT: Whisper or Google STT. We’ll keep secrets server-side only.

