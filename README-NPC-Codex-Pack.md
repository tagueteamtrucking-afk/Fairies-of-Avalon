# NPC Codex Pack (Alexandria)

Adds:
- **/apps/alexandria/codex.html** — microapp to browse, filter, and search NPCs; lists committed codices.
- **scripts/overseers/alexandria-npc-codex.ps1** — generates an NPC codex from a seed (LLM enrichment optional).
- **.github/workflows/alexandria-npc-codex.yml** — safe workflow with deterministic fallback and commit-only-if-changed.

Usage:
1) Generate a seed; 2) Run **Alexandria — Build NPC Codex** in Actions; 3) Browse `/apps/alexandria/codex.html`.
