# Landing Redirect Fix (v3)

1) Replace files from this pack:
   - `index.html` (hero + wallpaper)
   - `pages/index.html` (redirect to `/`)
   - `.github/workflows/overseers-wallpapers-manifest.yml`
   - `scripts/overseers/build-wallpapers-manifest.ps1`
   - `pages/app.css` and `pages/manifest.webmanifest` (if missing)
   - `Cody's Memory.yaml` (v1.13.2)

2) Commit + push.

3) Run Actions → Overseers — Wallpapers Manifest (once).
   This writes `asset/textures/wallpapers/manifest.json`.

4) Open https://fairiesofavalon.com/?v=20250917a (cache-busted).
   You should see the wallpaper hero and CTA buttons.

If you still see the old 'Avalon Pages' list, your browser is serving a cached page.
Use a hard refresh or open in a private window.
