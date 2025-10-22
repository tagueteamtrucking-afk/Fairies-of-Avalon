// scripts/charlotte/crawler.mjs
import fs from 'fs';
import path from 'path';

const OUT = 'pages/apps/charlotte/crawler/index.json';
const QUERIES = [
  'TripoSR in:name,description,readme stars:>100',
  'InstantMesh in:name,description,readme stars:>100',
  'threestudio in:name,description,readme stars:>100',
  'Open-Sora video generation in:name,description,readme',
  'text-to-video diffusion in:name,description,readme',
  'realistic faceless video generator in:name,description'
];

const headers = Object.fromEntries(Object.entries({
  'Accept': 'application/vnd.github+json',
  'Authorization': process.env.GITHUB_TOKEN ? `Bearer ${process.env.GITHUB_TOKEN}` : undefined,
  'X-GitHub-Api-Version': '2022-11-28'
}).filter(([,v])=>v!==undefined));

async function githubSearch(q){
  const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(q)}&sort=stars&order=desc&per_page=10`;
  const res = await fetch(url, { headers });
  if(!res.ok) throw new Error('GitHub search failed: '+res.status);
  const data = await res.json();
  return (data.items||[]).map(r => ({
    name: r.full_name,
    url: r.html_url,
    description: r.description,
    stars: r.stargazers_count,
    license: r.license?.spdx_id || r.license?.name || null,
    updated_at: r.updated_at,
    topics: r.topics || []
  }));
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

(async () => {
  const results = {};
  for (const q of QUERIES){
    try{ results[q] = await githubSearch(q); }
    catch(e){ results[q] = [{ error: String(e) }]; }
  }
  ensureDir(OUT);
  fs.writeFileSync(OUT, JSON.stringify({ generated_at: new Date().toISOString(), source: 'GitHub API', results }, null, 2));
  console.log('Charlotte crawler wrote:', OUT);
})();