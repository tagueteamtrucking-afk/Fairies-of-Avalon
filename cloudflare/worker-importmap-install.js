export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('POST required', { status: 405 });
    const { imports } = await req.json().catch(()=>({}));
    if (!imports || typeof imports !== 'object') return new Response('Invalid payload', { status: 400 });
    return new Response(JSON.stringify({ ok:true, keys:Object.keys(imports) }), { headers:{'content-type':'application/json'} });
  }
}