// scripts/charlotte/crawler.mjs (Node 20 ESM, no require)
import * as fs from 'node:fs';
import * as fsp from 'node:fs/promises';
import path from 'node:path';

const ROOT = process.cwd();
const OUT_DIR = path.join('pages','apps','charlotte','crawler');
const RES_DIR = path.join(OUT_DIR, 'results');

const QUERIES = [
  { id:'image_gen', q:'(ai image generator) OR stable-diffusion in:name,description,readme language:JavaScript language:Python stars:>100' },
  { id:'text_to_3d', q:'("text to 3d" OR text-to-3d OR "gaussian splatting" OR nerfstudio) in:name,description,readme stars:>50' },
  { id:'text_to_video', q:'("text to video" OR text-to-video OR "video diffusion") in:name,description,readme stars:>50' }
];

async function gh(url){
  const r = await fetch(url, {
    headers: { 'Authorization': process.env.GITHUB_TOKEN ? `token ${process.env.GITHUB_TOKEN}` : undefined,
               'Accept':'application/vnd.github+json' }
  });
  if(!r.ok) throw new Error('GitHub API error: '+r.status+' '+url);
  return r.json();
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function pickFields(repo){
  return {
    id: repo.id,
    name: repo.full_name,
    desc: repo.description,
    url: repo.html_url,
    stars: repo.stargazers_count,
    license: repo.license?.spdx_id || repo.license?.key || null,
    last_push: repo.pushed_at,
    topics: repo.topics || []
  };
}

async function searchOne(q){
  const api = 'https://api.github.com/search/repositories?q=' + encodeURIComponent(q) + '&sort=stars&order=desc&per_page=15';
  const data = await gh(api);
  return (data.items||[]).map(pickFields);
}

async function main(){
  const ts = new Date().toISOString().replace(/[:.]/g,'-');
  const outJson = path.join(RES_DIR, `results-${ts}.json`);

  const results = {};
  for(const q of QUERIES){
    try{
      results[q.id] = await searchOne(q.q);
    }catch(e){
      results[q.id] = { error: e.message };
    }
  }

  ensureDir(outJson);
  await fsp.writeFile(outJson, JSON.stringify({ generated_at: new Date().toISOString(), results }, null, 2), 'utf8');

  // write index.html to browse
  const idx = path.join(OUT_DIR,'index.html');
  const html = `<!doctype html><html><head><meta charset="utf-8"><title>Charlotte • AI Projects Crawler</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>body{font:14px system-ui;margin:16px;}h1{margin:0 0 8px;} .b{border:1px solid #ddd;border-radius:8px;padding:8px 12px;margin:12px 0;}
  a{color:#06c;text-decoration:none}.g{display:grid;grid-template-columns:1fr 1fr;gap:8px}@media(max-width:900px){.g{grid-template-columns:1fr}}
  .t{font-size:12px;color:#666}</style></head><body>
  <h1>Charlotte • AI Projects Crawler</h1>
  <p class="t">Latest snapshot: ${ts}</p>
  ${Object.keys(results).map(k=>{
    const arr = results[k];
    if(arr?.error) return `<div class="b"><h2>${k}</h2><p class="t">Error: ${arr.error}</p></div>`;
    return `<div class="b"><h2>${k}</h2><div class="g">${
      arr.map(r=>`<div><a href="${r.url}"><strong>${r.name}</strong></a><div class="t">${r.desc||''}</div><div class="t">★ ${r.stars} • ${r.license||'NO-LICENSE'} • ${r.topics.slice(0,6).join(', ')}</div></div>`).join('')
    }</div></div>`;
  }).join('')}
  <p class="t">Data source: GitHub repository search. Next step: add connectors for model hubs and papers.</p>
  </body></html>`;
  ensureDir(idx);
  await fsp.writeFile(idx, html, 'utf8');

  console.log('Crawler completed:', { outJson, index_html: idx });
}

main().catch(e=>{ console.error(e); process.exit(1); });
