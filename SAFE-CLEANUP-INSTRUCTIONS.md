# SAFE CLEANUP INSTRUCTIONS

**Do NOT delete your assets.** Heavy binaries live under:
- `asset/models/**`
- `asset/wings/**`
- `pages/apps/alexandria/worlds/**` (generated)

This pack includes a safe cleaner that **defaults to dry‑run**:

```pwsh
pwsh scripts/overseers/clean-repo.ps1 -RepoRoot .   # dry‑run
pwsh scripts/overseers/clean-repo.ps1 -RepoRoot . -Apply   # actually delete
```

It preserves the `preserve_globs` from `repo-structure.json` and the explicit allowlist.
