export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('POST only', { status: 405 });
    const { text, sessionId } = await req.json().catch(() => ({}));
    if (!text) return new Response(JSON.stringify({ error: 'missing text' }), { status: 400, headers: { 'content-type': 'application/json' } });

    const apiKey = env.OPENAI_API_KEY;
    const model = env.OPENAI_MODEL || 'gpt-4.1-mini';
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
    return new Response(JSON.stringify({ reply, sessionId }), { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });
  }
}
