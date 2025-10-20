# Cloudflare Auth Worker — Deployment Notes

## What this does
- Provides **real access control** for Avalon using an edge session cookie.
- Endpoints:
  - `POST /auth/login`  with `{ "pin": "####" }` → sets signed session cookie.
  - `GET  /auth/whoami` → returns `{ role, name, exp }` or 401 if not logged-in.
  - `POST /auth/logout` → clears session cookie.

## Secrets (set in Cloudflare via GitHub Actions)
- `SESSION_SECRET`: long random string for HMAC (signs sessions).
- `PIN_RAY`: `"1775"` (Dev; Ray).
- `PIN_BLANCA`: `"4406"` (User; Blanca).

## Routing
- Proxy your domain (e.g., `fairiesofavalon.com`) through Cloudflare.
- Add a worker route: `fairiesofavalon.com/*` → this worker.
- The worker proxies all non-/auth paths to origin; client pages call `/auth/*`.

## Login flow on pages
- Include `/pages/apps/shared/auth-gate.js` on pages you want gated.
- The script calls `/auth/whoami`; if 401, it shows a PIN modal that POSTS to `/auth/login`.

## Stronger gating (optional)
- To fully block unauthenticated users from app paths, add path checks in the Worker before `fetch(request)`:
  - e.g., if `url.pathname.startsWith("/pages/apps")` and no valid session → redirect to `/login`.
