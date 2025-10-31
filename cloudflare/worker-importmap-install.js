export default { async fetch(req, env) {
  if (req.method !== 'POST') return new Response('POST required', { status: 405 });
  const { imports } = await req.json();
  if (!imports || typeof imports !== 'object') return new Response('Invalid payload', { status: 400 });
  // TODO: Use env.GITHUB_* to open PR updating importmap.json
  return new Response(JSON.stringify({ok:true}), { headers: {'content-type':'application/json'} });
}}