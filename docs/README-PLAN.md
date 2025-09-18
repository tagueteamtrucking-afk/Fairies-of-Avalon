# Avalon — Clean Bootstrap Plan (v1)

This pack restores **functional generation** without touching your UI. It is **offline-first**.

## What you get
- **Workflows:** `00-sanity` and `Avalon Run All` (manual run).
- **Scripts:** offline generators for Alexandria, Tracy, Nina, Charlotte, Carol, Jem.
- **Data outputs:** written under `data/**`.
- **Memory v2.0.0:** includes rules + structure after the cleanup.

## How to install
1. Upload this zip’s contents to the repo root (so files land in `.github/workflows/` and `scripts/overseers/`).
2. Commit directly to `main`.
3. Go to **Actions**:
   - Run **Workflows — Sanity** once.
   - Run **Avalon Run All** with defaults.

## What gets created
- `data/alexandria/worlds/<world-id>/{seed,timeline,npc-codex,atlas,lore-bible,notable-figures,continuity-checklist,scene-seeds}.json`
- `data/tracy/artboards/<world-id>/artboard-*.json`
- `data/overseers/vrm-index.json`
- `data/charlotte/pipelines/<world-id>/plan.json`
- `data/carol/plans/mealplan-*.json`
- `data/jem/programs/program-*.json`

## Next steps (after green)
- Add **microapps** for conversation UIs (Alexandria chat, pickers, dice-rolls) when you’re ready.
- Wire optional APIs (LLM/TTS/STT) via repo secrets; scripts already work offline.

## Safe deletions
- Delete any older workflows with `peter-evans/workflow-dispatch`.
- Delete broken/non-used workflow YAMLs not included here.

