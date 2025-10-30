// Cloudflare Worker: Tracy LLM Skin
// ENV required: LLM_ENDPOINT, LLM_API_KEY, LLM_MODEL
export default { async fetch(req, env){ return new Response('Add LLM credentials to generate CSS from prompt.'); } }