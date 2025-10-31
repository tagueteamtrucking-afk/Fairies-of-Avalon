export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('POST required', { status: 405 });
    const body = await req.json().catch(() => ({}));
    const imports = body?.imports;
    if (!imports || typeof imports !== 'object') {
      return new Response('Invalid payload', { status: 400 });
    }
    // TODO: use env.GITHUB_TOKEN (fine-grained PAT) to open PR on importmap.json
    return new Response(JSON.stringify({ ok: true, keys: Object.keys(imports) }), { headers: { 'content-type': 'application/json' } });
  }
}