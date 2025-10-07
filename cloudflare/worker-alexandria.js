export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('POST only', { status: 405 });
    const { text, sessionId, tts, voice } = await req.json().catch(() => ({}));
    if (!text) return new Response(JSON.stringify({ error: 'missing text' }), { status: 400, headers: { 'content-type': 'application/json' } });

    const apiKey = env.OPENAI_API_KEY;
    const model = env.OPENAI_MODEL || 'gpt-4.1';
    const body = {
      model,
      temperature: 0.4,
      messages: [
        { role: 'system', content: 'You are Alexandria, a kind DM for collaborative storytelling. Keep responses concise, suggest a next move, and ask for dice rolls when helpful.' },
        { role: 'user', content: text }
      ]
    };
    const r = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'authorization': `Bearer ${apiKey}`, 'content-type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!r.ok) {
      const err = await r.text();
      return new Response(JSON.stringify({ error: 'upstream', detail: err }), { status: 502, headers: { 'content-type': 'application/json' } });
    }
    const j = await r.json();
    const reply = j.choices?.[0]?.message?.content ?? '(no content)';
    let audio = null;
    if (tts) {
      const ttsBody = { model: env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts', input: reply, voice: voice || 'alloy', format: 'mp3' };
      const a = await fetch('https://api.openai.com/v1/audio/speech', {
        method: 'POST',
        headers: { 'authorization': `Bearer ${apiKey}`, 'content-type': 'application/json' },
        body: JSON.stringify(ttsBody)
      });
      if (a.ok) {
        const buf = await a.arrayBuffer();
        const b64 = btoa(String.fromCharCode(...new Uint8Array(buf)));
        audio = `data:audio/mpeg;base64,${b64}`;
      }
    }
    return new Response(JSON.stringify({ reply, sessionId, audio }), { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });
  }
}
