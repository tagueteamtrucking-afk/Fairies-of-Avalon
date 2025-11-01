# Fairies-of-Avalon Updated Cleanup & Upgrade Plan (2025-11-01)

## 1. High Level Goals
- Clean up repository by removing obsolete files and duplicates.
- Preserve critical files and directories for assets and memory.
- Restructure repository layout for clarity and maintainability.
- Upgrade micro-apps and site, using modern frameworks, dynamic data, and accessible design.
- Ensure workflow automation, fallback mechanisms, and clear documentation.
- Use `assets/` (plural) as top-level directory for models, wings, textures; not `asset/`.

## 2. Repository Cleanup
### Files/Directories to Delete:
- All files in `memory-history` except the latest snapshot: `memory-history/Codys-Memory-20251021T064919Z.yaml`.
- All stub micro-app directories that belong to merged or deprecated characters: 
  - `pages/apps/clarice`, `pages/apps/themis`, `pages/apps/odessa`, `pages/apps/sorcha`.
- Redundant or obsolete micro-app pages: files within `pages/apps/{fairy}/old` or `compliance` duplicates; remove stubs that only show “Example rendering” or “Point this at your JSON”.
- Duplicate assets or unused design files flagged in `memory/cleanup-proposals.json` (e.g., duplicate wallpapers or models).
- Temporary files and system artifacts (e.g., `__MACOSX/`, `Thumbs.db`, `.DS_Store`, `*.tmp`).
- Empty or placeholder documents such as `docs/BUILD-PATH.md`, `docs/RULES.md` and unused generated reports.
- Unused scripts or old workflows under `.github/workflows` that have been superseded.

### Files/Directories to Keep:
- `assets/**`: all asset models, wings, textures, and wallpaper images. Always keep them under `assets/`.
- `memory/**`: particularly `owners.json`, `fairy_function_matrix.json`, `cleanup-rules.json`, `evolution-merge.patch.yaml`, `site-map.json` (to be regenerated).
- Latest memory snapshot: `memory-history/Codys-Memory-20251021T064919Z.yaml`.
- `pages/**`: micro-apps for active characters: 
  `pages/apps/nina`, `pages/apps/charlotte`, `pages/apps/billie`, 
  `pages/apps/carol`, `pages/apps/jem`, `pages/apps/alexandria`,
  `pages/apps/stella`, `pages/apps/tracy`, and the city map under `pages/_city`.
- Root-level files essential for GitHub Pages: `index.html`, `404.html`, `.nojekyll`, `CNAME`, `importmap.json`.
- `.github/workflows/**` and other automation scripts that remain valid.
- `cloudflare`, `scripts`, `workers`, and `ui` directories for infrastructure.

## 3. Repository Restructure
- Ensure that the root directory only contains: 
  - `index.html`, `404.html`, `.nojekyll`, `CNAME`, `importmap.json`, service-worker files, and CI scripts.
  - All other site files should be moved under `pages/`.
- Rename and update references from `asset/` to `assets/` across the codebase and import statements.
- Consolidate import maps: ensure a single `importmap.json` at root and remove duplicates.

## 4. Micro‑App & Site Upgrades
- Implement each micro-app using a modern framework (e.g. Svelte or vanilla JS with modules). Use dynamic data sources; provide default sample data if API is missing.
- Fix the city map: add `xmlns:xlink` attribute to the SVG and link buildings to actual pages using `city-registry.json`.
- Generate `site-map.json` automatically after build; use it to power overview and security pages.
- Remove “Preflight” warnings from UI; rely on CI to validate builds.
- Integrate the Carol meal planner guidelines from the 20251021 memory snapshot.

## 5. Workflow Automation
- Create or update scripts (e.g., `cleanup.sh`) to automate deletion of obsolete files based on `cleanup-rules.json`.
- Ensure workflows fallback gracefully on API or AI rate limits; never fail the deployment due to missing data.
- Provide a script to regenerate site data (e.g., VRM importer, social analytics fetcher) and update pages.

## 6. Documentation
- Add a `CONTRIBUTING.md` summarizing guidelines: use `assets/`, maintain import maps, run cleanup scripts, avoid plain-text secrets, etc.
- Update `README.md` with a high-level overview of the project’s purpose, directory structure, and how to run the site locally.

## 7. Next Steps for the User
1. Download the `cleanup.sh` script and run it at the root of the repository to remove unnecessary files (if using bash).
2. Verify that the `assets` directory contains all needed models, wings, textures, and other resources.
3. Move or rename files according to this plan (e.g., relocate stray HTML files into `pages/`).
4. Use the provided `FILES_TO_DELETE.txt` and `FILES_TO_SAVE.txt` lists as checklists during manual cleanup.
5. After cleanup, run the build process and deploy via GitHub Pages (CI should pass).
