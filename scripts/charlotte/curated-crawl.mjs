import { writeFileSync, mkdirSync } from 'node:fs';

const token = process.env.GITHUB_TOKEN;
const headers = token ? { Authorization: `Bearer ${token}` } : {};

const QUERIES = [
  'topic:threejs vrm',
  'topic:comfyui extensions',
  'meshy OR text-to-3d language:python stars:>200',
  'topic:stable-video-diffusion',
  'faceless video generator open source stars:>200'
];

async function search(q){
  const u = new URL('https://api.github.com/search/repositories');
  u.searchParams.set('q', q);
  u.searchParams.set('per_page','10');
  const r = await fetch(u, { headers });
  if(!r.ok) throw new Error('GitHub search failed '+r.status);
  const data = await r.json();
  return (data.items||[]).map(x=>({ full_name:x.full_name, description:x.description, stars:x.stargazers_count, license:x.license?.spdx_id||'UNKNOWN', html_url:x.html_url }));
}

function routeToFairies(rec){
  const name = (rec.full_name||'').toLowerCase() + ' ' + (rec.description||'').toLowerCase();
  const out = [];
  if(name.includes('3d') || name.includes('vrm') || name.includes('three')) out.push('nina','tracy');
  if(name.includes('video')) out.push('sorcha','billie','tracy');
  if(name.includes('ai art') || name.includes('image')) out.push('tracy');
  return Array.from(new Set(out));
}

async function main(){
  const results = [];
  for(const q of QUERIES){
    const items = await search(q);
    for(const rec of items){
      const route = routeToFairies(rec);
      if(!route.length) continue;
      if(['MIT','Apache-2.0','BSD-2-Clause','BSD-3-Clause','MPL-2.0'].includes(rec.license)){
        results.push({ ...rec, route });
      }
    }
  }
  mkdirSync('pages/apps/charlotte', { recursive:true });
  writeFileSync('pages/apps/charlotte/finds.json', JSON.stringify({ generated_at:new Date().toISOString(), results }, null, 2));
  console.log('Curated finds:', results.length);
}
main().catch(e=>{ console.error(e); process.exit(1); });
