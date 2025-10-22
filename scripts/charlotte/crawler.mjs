// scripts/charlotte/crawler.mjs
import fs from 'fs';

const OUT = 'pages/apps/charlotte/crawler/index.json';
const QUERIES = [
  'TripoSR in:name,description,readme stars:>100',
  'InstantMesh in:name,description,readme stars:>100',
  'threestudio in:name,description,readme stars:>100',
  'stable diffusion android client in:name,description,readme',
  'Open-Sora video generation in:name,description,readme',
  'Wan2.2 text-to-video in:name,description,readme'
];

const headers = {
  'Accept': 'application/vnd.github+json',
  'Authorization': process.env.GITHUB_TOKEN ? `Bearer ${process.env.GITHUB_TOKEN}` : undefined,
  'X-GitHub-Api-Version': '2022-11-28'
};

async function githubSearch(q){
  const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(q)}&sort=stars&order=desc&per_page=10`;
  const res = await fetch(url, { headers });
  if(!res.ok) throw new Error('GitHub search failed: '+res.status);
  const data = await res.json();
  return data.items.map(r => ({
    name: r.full_name,
    url: r.html_url,
    description: r.description,
    stars: r.stargazers_count,
    license: r.license?.spdx_id || r.license?.name || null,
    updated_at: r.updated_at,
    topics: r.topics || []
  }));
}

function ensureDir(p){ fs.mkdirSync(require('path').dirname(p), { recursive:true }); }

(async () => {
  const results = {};
  for (const q of QUERIES){
    try{ results[q] = await githubSearch(q); }
    catch(e){ results[q] = [{ error: String(e) }]; }
  }
  ensureDir(OUT);
  const payload = { generated_at: new Date().toISOString(), source: 'GitHub API', queries: QUERIES, results };
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2));
  console.log('Charlotte crawler wrote:', OUT);
})();