# Cloudflare Worker — Alexandria DM Proxy

1) In Cloudflare Dashboard → **Workers & Pages** → **Create Worker**
2) Replace default code with `worker-alexandria.js` content.
3) Add **Secrets**:
   - `OPENAI_API_KEY` (required)
4) Add **Variables** (optional):
   - `OPENAI_MODEL` (e.g., `gpt-4.1`)
5) Deploy. Copy the Worker URL (e.g., `https://alexandria.your-subdomain.workers.dev`).
6) Edit `pages/apps/alexandria/dm/dm.js` and set:
   ```js
   window.ALEXANDRIA_API_URL = 'https://alexandria.your-subdomain.workers.dev';
   ```
7) Commit, Deploy Pages, open `/pages/apps/alexandria/dm/play.html` on your phone.
