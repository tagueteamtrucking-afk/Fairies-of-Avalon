# Timeline Builder Pack (Alexandria)

Adds:
- **/apps/alexandria/timeline.html** — microapp to preview/download timelines and browse committed ones.
- **scripts/overseers/alexandria-timeline.ps1** — builds a timeline JSON from the newest (or specified) world seed.
- **.github/workflows/alexandria-timeline.yml** — safe workflow with deterministic fallback and commit-only-if-changed.

Usage:
1) Generate a seed; 2) Run **Alexandria — Build Timeline** in Actions; 3) Browse `/apps/alexandria/timeline.html`.
