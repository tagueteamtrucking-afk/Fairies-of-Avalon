# Avalon — Cooperative Helpers (Alexandria + Tracy + Nina + Charlotte)

**No UI changes.** These are workflows + scripts that generate artifacts the AIs can share.

## Workflows
- **Alexandria — Helpers Suite** → figures, continuity, scenes, bundle
- **Tracy — Art Suite** → artboard briefs (JSON)
- **Nina — 3D Suite** → vrm-index + scene stubs
- **Charlotte — Pipelines Suite** → TTS SSML, offline translations, pipeline plan
- **Avalon — Run All Helpers** → orchestrates all of the above

## Runbook
1. Actions → *Alexandria — Helpers Suite* (optional first run creates seed).
2. Actions → *Tracy — Art Suite* (artboards for regions/themes).
3. Actions → *Nina — 3D Suite* (reads your assets; creates vrm-index + SceneKit).
4. Actions → *Charlotte — Pipelines Suite* (SSML + translations plan).
5. Optional: *Avalon — Run All Helpers* to do it in one click.

All outputs are written under `pages/apps/alexandria/worlds/**` or `pages/apps/overseers/vrm-index.json`.
