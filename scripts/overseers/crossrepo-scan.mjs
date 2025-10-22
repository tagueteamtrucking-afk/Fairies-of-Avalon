// scripts/overseers/crossrepo-scan.mjs
import fs from 'fs';
import path from 'path';

const SECOND_DIR = 'second_repo';
const OUT = 'pages/apps/overseers/crossrepo/second_repo_index.json';
const IGNORE_DIRS = new Set(['.git','.github','node_modules','.DS_Store','dist','out','_site','.next','.vercel','.cache']);

function walk(dir){
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes:true });
  let files = [];
  for (const e of entries){
    const abs = path.join(dir, e.name);
    if (IGNORE_DIRS.has(e.name)) continue;
    if (e.isDirectory()){
      files = files.concat(walk(abs));
    } else if (e.isFile()){
      files.push(abs.replaceAll('\\','/'));
    }
  }
  return files;
}

const files = walk(SECOND_DIR);
const rel = files.map(f => f.startsWith(SECOND_DIR + '/') ? f.substring(SECOND_DIR.length + 1) : f);
const byDir = new Map();
for (const f of rel){
  const top = f.split('/')[0] || '';
  byDir.set(top, (byDir.get(top)||0) + 1);
}

const out = {
  repo: process.env.SECOND_REPO || 'unknown',
  generated_at: new Date().toISOString(),
  total_files: rel.length,
  top_dirs: Object.fromEntries([...byDir.entries()].sort((a,b)=>b[1]-a[1]).slice(0,12)),
  sample: rel.slice(0,200)
};

fs.mkdirSync(path.dirname(OUT), { recursive:true });
fs.writeFileSync(OUT, JSON.stringify(out, null, 2));
console.log('Wrote', OUT);
