// Cloudflare Worker: Stella TTS
// Provide provider-specific TTS integration; keep keys in Worker env
export default { async fetch(){ return new Response('TTS worker placeholder.'); } }