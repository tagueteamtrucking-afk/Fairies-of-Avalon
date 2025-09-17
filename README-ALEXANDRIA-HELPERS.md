# Alexandria — Helpers Suite (No UI Changes)

This adds an **all-in-one workflow** that generates per-town **Notable Figures**, runs a **Continuity Check**, writes **Author scenes**, and creates a **WorldBundle zip** — all without touching your pages.

## Files
- `.github/workflows/alexandria-helpers.yml`
- `scripts/overseers/alexandria-suite.ps1`
- `scripts/overseers/alexandria-notable-figures.ps1`
- `scripts/overseers/alexandria-continuity-check.ps1`
- `scripts/overseers/alexandria-author-handoff.ps1`
- `scripts/overseers/alexandria-export-bundle.ps1`
- `Cody's Memory.yaml` (v1.14.0, updated and complete for these parts)

## How to run
1. Commit these files.
2. In GitHub → Actions → **Alexandria — Helpers Suite** → Run workflow.
   - Leave "World" blank to auto-pick the latest seed (or create a minimal one).
   - Choose "per_town" (default 3).
   - "force_fallback" defaults to **true** (offline).

## Outputs
- `pages/apps/alexandria/worlds/codex/figures-<world>.json`
- `pages/apps/alexandria/worlds/reports/continuity-<world>.json`
- `pages/apps/alexandria/worlds/exports/Scenes-<world>.md`
- `pages/apps/alexandria/worlds/exports/WorldBundle-<world>.zip`

No front-end pages are modified by this Suite.
