import fs from 'node:fs';
import path from 'node:path';

const SOURCES = 'pages/apps/charlotte/sources.json';
const OUTPUT = 'pages/apps/charlotte/finds.json';

const GH_TOKEN = process.env.GH_TOKEN || process.env.GITHUB_TOKEN || '';

async function gh(pathname){
  const url = new URL('https://api.github.com'+pathname);
  const r = await fetch(url, { headers: {
    'Accept':'application/vnd.github+json',
    'Authorization': GH_TOKEN ? `Bearer ${GH_TOKEN}` : undefined,
    'X-GitHub-Api-Version':'2022-11-28'
  }});
  if(!r.ok) throw new Error('GitHub API error '+r.status+': '+await r.text());
  return r.json();
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

async function main(){
  if(!fs.existsSync(SOURCES)) throw new Error('Missing '+SOURCES+' (seed queries).');
  const seeds = JSON.parse(fs.readFileSync(SOURCES, 'utf8'));
  const allow = new Set(seeds.license_allow || ['MIT','Apache-2.0','BSD-2-Clause','BSD-3-Clause','MPL-2.0']);
  const groups = [
    { name: 'Image / Art', match: ['stable diffusion webui','ComfyUI','InvokeAI'], items: []},
    { name: 'Video (faceless / gen)', match: ['AnimateDiff','stable video diffusion','text2video zero'], items: []},
    { name: '3D / VRM / Mesh', match: ['three-vrm','three.js editor','instant-ngp','gaussian splatting','TripoSR','Meshroom photogrammetry'], items: []},
  ];
  for(const q of seeds.queries){
    const query = encodeURIComponent(q.q);
    const data = await gh(`/search/repositories?q=${query}&per_page=${Math.max(1, Math.min(q.max||5, 10))}`);
    for(const rep of data.items||[]){
      const lic = rep.license?.spdx_id || 'Unknown';
      if(lic!=='NOASSERTION' && lic!=='Unknown' && !allow.has(lic)) continue;
      const item = {
        title: rep.full_name,
        url: rep.html_url,
        license: lic,
        stars: rep.stargazers_count,
        to: q.route || []
      };
      const g = groups.find(g => g.match.includes(q.q));
      if(g) g.items.push(item);
    }
  }
  ensureDir(OUTPUT);
  fs.writeFileSync(OUTPUT, JSON.stringify({ generated_at: new Date().toISOString(), groups }, null, 2));
  console.log('Wrote curated finds to', OUTPUT);
}

main().catch(e=>{ console.error(e); process.exit(1); });
