# Avalon — Fixes + Health Suites (v2)

This pack fixes fragile workflows and adds **Carol** and **Jem** helper suites (data-only). No UI changes.

## Fixed Workflows
- `.github/workflows/alexandria-build-all.yml` — splatting (no backticks), numeric parsing, safe commit
- `.github/workflows/alexandria-helpers.yml` — same
- `.github/workflows/tracy-art-suite.yml` — safe `[int]` parsing for `boards`
- `.github/workflows/nina-3d-suite.yml` — safe `[int]` parsing and tolerant `git add`

## New Suites
- **Carol — Meal Plan Suite** → `pages/apps/carol/plans/mealplan-*.json`
- **Jem — Program Suite** → `pages/apps/jem/programs/program-*.json`

## How to run (Actions)
- Actions → *Carol — Meal Plan Suite* → set `days`, `kcal_target`, `diet_style`
- Actions → *Jem — Program Suite* → set `weeks`, `days_per_week`, `goal`, `equipment`

## Local (PowerShell)
```powershell
# Carol
pwsh -File scripts/overseers/carol-meal-plan.ps1 -RepoRoot . -Days 7 -KcalTarget 2200 -DietStyle balanced

# Jem
pwsh -File scripts/overseers/jem-program-plan.ps1 -RepoRoot . -Weeks 8 -DaysPerWeek 4 -Goal recomp -Equipment minimal
```

All outputs are JSON files under `pages/apps/carol/plans` and `pages/apps/jem/programs`.
