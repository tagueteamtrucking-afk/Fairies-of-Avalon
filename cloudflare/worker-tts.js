// cloudflare/worker-tts.js
export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return new Response('Use POST {text}', {status:400});
    if (!env.TTS_ENDPOINT || !env.TTS_API_KEY) return new Response('Connect Account: set TTS_ENDPOINT/TTS_API_KEY', {status:501});
    const { text } = await request.json().catch(()=>({}));
    if (!text) return new Response('Bad Request: text', {status:400});
    const body = JSON.stringify({ input: text, model: env.TTS_MODEL||'default', voice: env.TTS_VOICE||'alloy', format: env.TTS_FORMAT||'audio/mpeg' });
    const r = await fetch(env.TTS_ENDPOINT, { method:'POST', headers:{ 'Authorization':`Bearer ${env.TTS_API_KEY}`,'Content-Type':'application/json' }, body });
    if (!r.ok) return new Response('Upstream error '+(await r.text()), {status:502});
    return new Response(r.body, { headers:{'Content-Type': env.TTS_FORMAT||'audio/mpeg'} });
  }
};