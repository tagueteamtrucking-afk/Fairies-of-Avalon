export default { async fetch(req, env){
  if (req.method !== 'POST') return new Response('POST required', {status:405});
  const { text } = await req.json();
  // TODO: call provider with env.TTS_API_KEY; return audio or URL
  return new Response(JSON.stringify({ok:true, text}), {headers:{'content-type':'application/json'}});
}}