// scripts/overseers/memory-index.mjs
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

const ROOT = process.cwd();
const OUT = 'pages/apps/overseers/memory/index.json';
const IGNORE_DIRS = new Set(['.git','.github','node_modules','.DS_Store','dist','out','_site','.next','.vercel','.cache']);

const IMG_EXT = new Set(['.png','.jpg','.jpeg','.webp','.gif','.avif']);
const VRM_EXT = new Set(['.vrm']);

function walk(dir){
  const entries = fs.existsSync(dir) ? fs.readdirSync(dir, { withFileTypes:true }) : [];
  let files = [];
  for (const e of entries){
    const abs = path.join(dir, e.name);
    const rel = path.relative(ROOT, abs).replaceAll('\\','/');
    if (IGNORE_DIRS.has(e.name)) continue;
    if (e.isDirectory()){
      files = files.concat(walk(abs));
    } else if (e.isFile()){
      files.push(rel);
    }
  }
  return files;
}
function sha1Of(p){
  try{
    const b = fs.readFileSync(p);
    return crypto.createHash('sha1').update(b).digest('hex');
  }catch{ return null; }
}

function classify(rel){
  const lower = rel.toLowerCase();
  if (lower.startsWith('pages/apps/')){
    if (lower.includes('/overseers/hub/')) return 'microapp';
    if (lower.includes('/carol/')) return 'microapp';
    return 'page';
  }
  if (lower.startsWith('.github/workflows/')) return 'workflow';
  if (lower.startsWith('asset/models')) return 'model';
  if (lower.startsWith('asset/winged-models') || lower.startsWith('asset/wings')) return 'wings';
  if (lower.startsWith('asset/textures/wallpapers')) return 'wallpaper';
  const ext = path.extname(lower);
  if (ext === '.html') return 'html';
  if (ext === '.css') return 'style';
  if (ext === '.js' || ext === '.mjs') return 'script';
  if (ext === '.json') return 'data';
  return 'other';
}

function countWallpapers(list){
  return list.filter(f => f.toLowerCase().startsWith('asset/textures/wallpapers') && IMG_EXT.has(path.extname(f).toLowerCase())).length;
}

const files = walk('.');
const index = files.map(rel => ({
  path: rel,
  bytes: (fs.existsSync(rel) && fs.statSync(rel).isFile()) ? fs.statSync(rel).size : 0,
  sha1: sha1Of(rel),
  type: classify(rel)
}));

const byType = new Map();
for (const it of index){
  byType.set(it.type, (byType.get(it.type)||0) + 1);
}

const summary = {
  count: index.length,
  byType: Object.fromEntries(byType.entries()),
  wallpapers: countWallpapers(files),
  generated_at: new Date().toISOString()
};

fs.mkdirSync(path.dirname(OUT), { recursive:true });
fs.writeFileSync(OUT, JSON.stringify({ summary, files: index }, null, 2));
console.log('Wrote', OUT);
