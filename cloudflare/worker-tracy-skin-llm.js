export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('POST required', { status: 405 });
    const { prompt } = await req.json().catch(()=>({prompt:''}));
    const css = `/* Generated: ${prompt} */\n:root{--accent:#5a3dd5;--bg:#faf8ff;--ink:#222}`;
    return new Response(css, { headers:{'content-type':'text/css'} });
  }
}