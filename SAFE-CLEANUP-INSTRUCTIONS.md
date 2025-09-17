# SAFE CLEANUP INSTRUCTIONS

**DO NOT DELETE your assets.** This snapshot **preserves**:
- `asset/models/**`
- `asset/wings/**`
- `asset/textures/**`   ← wallpapers live here
- `pages/apps/alexandria/worlds/**` (generated)

Run dry‑run first:
```pwsh
pwsh scripts/overseers/clean-repo.ps1 -RepoRoot .
```
Then apply:
```pwsh
pwsh scripts/overseers/clean-repo.ps1 -RepoRoot . -Apply
```