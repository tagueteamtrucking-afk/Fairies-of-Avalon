# Alexandria Choices / Taxonomy Library

Centralized lists for worldbuilding: dimensions, biomes, climates, gate types, hazards, resources, magic, tech, NPC roles/traits/motives/secrets, cultures, currencies, etc.

## Files
- `pages/apps/alexandria/knowledge/choices.json` — master editable lists.
- `pages/apps/alexandria/knowledge/choices.html` — browse, roll, draft-edit, and download.
- `scripts/overseers/alexandria-choices-prepare.ps1` — validates `choices.json`, derives per-app taxonomies.
- `.github/workflows/alexandria-choices.yml` — validates & merges; commits only if changed.

## Derived outputs
- `pages/apps/alexandria/knowledge/atlas-taxonomy.json` — used by Regional Atlas.
- `pages/apps/alexandria/knowledge/npc-taxonomy.json` — used by NPC Codex.

## Usage
1. Edit `choices.json` (locally or in the `choices.html` draft then commit).
2. Run **Actions → “Alexandria — Update Choices Library”**.
3. Atlas & NPC tools will pick up the derived taxonomies automatically.
