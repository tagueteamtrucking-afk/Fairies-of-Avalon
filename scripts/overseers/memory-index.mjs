// scripts/overseers/memory-index.mjs
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

const OUT = 'pages/apps/overseers/memory/index.json';
const SKIP_DIRS = new Set(['.git','node_modules','dist','out','_site','.next','.vercel','.cache']);

function walk(dir){
  const ents = fs.readdirSync(dir, { withFileTypes:true });
  let out = [];
  for (const e of ents){
    if (SKIP_DIRS.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(walk(p));
    else out.push(p.replace(/\\/g,'/'));
  }
  return out;
}

function sha1(p){ return crypto.createHash('sha1').update(fs.readFileSync(p)).digest('hex'); }

function classify(p){
  const lower = p.toLowerCase();
  const ext = path.extname(p).toLowerCase();
  const area = lower.startsWith('pages/') ? 'page'
             : lower.startsWith('scripts/') ? 'script'
             : lower.startsWith('asset/models') ? 'model'
             : lower.startsWith('asset/wings') ? 'wings'
             : lower.startsWith('asset/textures/wallpapers') ? 'wallpaper'
             : lower.startsWith('.github/workflows') ? 'workflow'
             : 'other';
  let type = 'other';
  if (['.html','.htm'].includes(ext)) type='html';
  else if (['.js','.mjs','.ts','.tsx'].includes(ext)) type='code';
  else if (['.json'].includes(ext)) type='data';
  else if (['.yml','.yaml'].includes(ext)) type='workflow';
  else if (['.vrm'].includes(ext)) type='model';
  else if (['.png','.jpg','.jpeg','.webp'].includes(ext)) type='image';

  let purpose = '';
  if (lower === 'cname') purpose='Custom domain for GitHub Pages';
  else if (lower.includes('kill-sw.html')) purpose='Service worker cache buster';
  else if (lower.includes('pages/apps/carol/plans/shopping-quantized.json')) purpose='Aggregated shopping list (2 people)';
  else if (lower.includes('pages/apps/carol/index.json')) purpose='Carol pointer to plan & shopping JSON';
  else if (lower.includes('pages/apps/carol/menu.html')) purpose='Carol UI — 14-day event timeline (no placeholders)';
  else if (lower.includes('pages/apps/carol/shopping.html')) purpose='Carol UI — shopping list viewer';
  else if (lower.includes('scripts/carol/build-shopping.mjs')) purpose='Build shopping list from embedded plan items';
  else if (lower.includes('scripts/charlotte/crawler.mjs')) purpose='Charlotte crawler — GitHub OSS queries';
  else if (lower.includes('pages/apps/charlotte/index.html')) purpose='Charlotte crawler viewer';
  else if (lower.includes('scripts/overseers/repo-sweep.mjs')) purpose='Manifests + WPI builder';
  else if (lower.includes('pages/apps/overseers/hub/index.html')) purpose='Overseers Hub quick links';
  else if (lower.includes('.github/workflows/overseers-manifests.yml')) purpose='Workflow — build manifests + WPI';
  else if (lower.includes('.github/workflows/charlotte-crawler.yml')) purpose='Workflow — run Charlotte crawler';
  else if (lower.includes('.github/workflows/carol-generate-shopping.yml')) purpose='Workflow — generate Carol shopping list';
  else if (lower.includes('.github/workflows/overseers-repo-doctor.yml')) purpose='Workflow — Repo doctor & CNAME';

  return { area, type, purpose };
}

(function main(){
  const files = walk('.').sort();
  const items = files.map(p => ({
    path: p,
    size: fs.statSync(p).size,
    sha1: sha1(p),
    ...classify(p)
  }));
  const meta = {
    generated_at: new Date().toISOString(),
    counts: {
      total: items.length,
      byType: Object.fromEntries(items.reduce((m,it)=>m.set(it.type,(m.get(it.type)||0)+1), new Map())),
      byArea: Object.fromEntries(items.reduce((m,it)=>m.set(it.area,(m.get(it.area)||0)+1), new Map()))
    }
  };
  fs.mkdirSync(path.dirname(OUT), { recursive:true });
  fs.writeFileSync(OUT, JSON.stringify({ meta, items }, null, 2));
  console.log('Memory index written:', OUT, 'files:', items.length);
})();
