// scripts/overseers/memory-index.mjs
import fs from 'fs';
import path from 'path';

const IGNORE = new Set(['.git','node_modules','.DS_Store','dist','out','_site','.vercel','.cache']);
const ROOT = process.cwd();
const OUT = 'pages/apps/overseers/memory/index.json';

function classify(p){
  const l = p.toLowerCase();
  if (l.includes('/pages/apps/carol/')) return 'carol';
  if (l.includes('/pages/apps/charlotte/')) return 'charlotte';
  if (l.startsWith('.github/workflows/')) return 'workflow';
  if (l.startsWith('asset/')) return 'asset';
  if (l.endsWith('.html')) return 'page';
  if (l.endsWith('.mjs')||l.endsWith('.js')) return 'script';
  if (l.endsWith('.json')||l.endsWith('.yml')||l.endsWith('.yaml')) return 'data';
  return 'other';
}

function walk(dir){
  const ents = fs.readdirSync(dir, {withFileTypes:true});
  let items = [];
  for (const e of ents){
    if (IGNORE.has(e.name)) continue;
    const p = path.join(dir, e.name);
    const rel = path.relative(ROOT, p).replace(/\\/g,'/');
    if (e.isDirectory()) items = items.concat(walk(p));
    else items.push(rel);
  }
  return items;
}

function briefPurpose(rel){
  if (rel === 'pages/apps/carol/menu.html') return 'Menu timeline viewer for plan JSON (printable)';
  if (rel === 'pages/apps/carol/shopping.html') return 'Shopping list viewer for generated shopping JSON';
  if (rel === 'pages/apps/carol/index.json') return 'Pointer to plan & shopping files';
  if (rel.startsWith('scripts/overseers/')) return 'Overseers helper script';
  if (rel.startsWith('scripts/carol/')) return 'Carol helper script';
  if (rel.startsWith('.github/workflows/')) return 'GitHub Actions workflow';
  return '';
}

function main(){
  const files = walk(ROOT);
  const index = files.map(f=>{
    const st = fs.statSync(f);
    return {
      path: f,
      size: st.size,
      type: classify(f),
      purpose: briefPurpose(f)
    };
  });
  fs.mkdirSync(path.dirname(OUT), {recursive:true});
  fs.writeFileSync(OUT, JSON.stringify({ generated_at: new Date().toISOString(), count:index.length, files:index }, null, 2));
  console.log(`Memory index written to ${OUT} (${index.length} files)`);
}
main();
