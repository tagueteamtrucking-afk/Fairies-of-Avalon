# Cloudflare Worker — Alexandria DM Proxy
1) Cloudflare Dashboard → Workers & Pages → Create Worker
2) Replace code with `worker-alexandria.js`
3) Add Secrets:
   - OPENAI_API_KEY
4) Add Variables (optional):
   - OPENAI_MODEL (e.g., gpt-4.1)
   - OPENAI_TTS_MODEL (e.g., gpt-4o-mini-tts)
5) Deploy and copy the Worker URL.
6) In repo file `pages/apps/alexandria/dm/config.json`, set:
{
  "api_url": "https://<your-worker>.workers.dev",
  "tts": { "enabled": true, "voice": "alloy" }
}
7) Commit and deploy pages. Open /pages/apps/alexandria/dm/play.html
