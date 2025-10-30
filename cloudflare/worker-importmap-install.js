export default { async fetch(req, env){
  if (req.method!=='POST') return new Response('POST JSON {imports}',{status:400});
  if (!env.GITHUB_TOKEN||!env.GITHUB_OWNER||!env.GITHUB_REPO) return new Response('Connect Account: set env', {status:501});
  const {imports} = await req.json().catch(()=>({})); if (!imports) return new Response('Bad Request',{status:400});
  const api='https://api.github.com', H={'Authorization':`Bearer ${env.GITHUB_TOKEN}`,'Accept':'application/vnd.github+json'};
  const repo=await (await fetch(`${api}/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`,{headers:H})).json();
  const base=repo.default_branch||'main';
  const ref=await (await fetch(`${api}/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/git/refs/heads/${base}`,{headers:H})).json();
  const branch=`importmap-install-${Date.now()}`;
  await fetch(`${api}/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/git/refs`,{method:'POST',headers:H,body:JSON.stringify({ref:`refs/heads/${branch}`,sha:ref.object.sha})});
  const imap=await (await fetch(`${api}/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/contents/importmap.json?ref=${base}`,{headers:H})).json();
  const content=JSON.parse(atob(imap.content)); const ex=content.imports||{}; Object.assign(ex, imports);
  const sorted=Object.fromEntries(Object.entries(ex).sort((a,b)=>a[0].localeCompare(b[0])));
  const b64=btoa(JSON.stringify({...content,imports:sorted},null,2));
  await fetch(`${api}/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/contents/importmap.json`,{method:'PUT',headers:H,body:JSON.stringify({message:'importmap: install via Worker',content:b64,branch,sha:imap.sha})});
  const pr=await (await fetch(`${api}/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/pulls`,{method:'POST',headers:H,body:JSON.stringify({title:'importmap: install via Worker',head:branch,base})})).json();
  return new Response(JSON.stringify({message:`PR #${pr.number} created`}),{headers:{'Content-Type':'application/json'}});
}}