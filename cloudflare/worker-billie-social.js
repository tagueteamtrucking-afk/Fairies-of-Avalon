export default { async fetch(req, env){
  if (req.method !== 'POST') return new Response('POST required', {status:405});
  const payload = await req.json();
  // TODO: route to platform using env keys (X/Threads/YouTube)
  return new Response(JSON.stringify({queued:true, payload}), {headers:{'content-type':'application/json'}});
}}