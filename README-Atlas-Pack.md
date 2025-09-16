# Regional Atlas Pack (Alexandria)

This pack adds a **Regional Atlas** system with clarifying questions and option lists you can edit, roll from, or extend with your own values.

## Files (place at repo root)

- `pages/apps/alexandria/atlas.html` — interactive microapp (Q&A, choose/roll/custom lists, draft save, download JSON).
- `pages/apps/alexandria/knowledge/atlas-taxonomy.json` — default editable lists (dimensions, biomes, climates, hazards, resources, gates…).
- `scripts/overseers/alexandria-atlas.ps1` — server-side atlas generator (LLM enrichment optional).
- `.github/workflows/alexandria-atlas.yml` — safe workflow committing to `/pages/apps/alexandria/worlds/atlas/`.

## How to use

1. Generate a seed (Worldbuilding Studio or workflow).
2. Open `/apps/alexandria/atlas.html`:
   - Load a seed (URL or paste).
   - Set region count; for each region choose from lists, **roll 🎲**, or type your own.
   - Edit lists via the **Taxonomies** dialog, or **download** them as JSON.
   - Add **portals** and **ley lines**, roll them, or edit by hand.
   - **Save Draft** (browser) and **Download atlas.json**.
3. In GitHub → **Actions → “Alexandria — Build Regional Atlas”**:
   - Leave `seed_path` blank to use the latest seed.
   - Set `regions` as desired; `mode` = `auto` (LLM if key exists) or `fallback-only`.
   - The workflow writes:
     - `/pages/apps/alexandria/worlds/atlas/<slug>.atlas.json`
     - `/pages/apps/alexandria/worlds/atlas/latest.json`
     - updates `/pages/apps/alexandria/worlds/atlas/index.json`

## Notes

- LLM enrichment (short lore per region) is optional and guarded by `OPENAI_API_KEY` in Actions. Deterministic fallback otherwise.
- CI is Linux-safe and commits only when files change.
- The microapp stores custom lists and drafts in `localStorage` (no secrets).
