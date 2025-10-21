// scripts/overseers/repo-sweep.mjs
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import child_process from 'child_process';

const ROOT = process.env.INPUT_DIR ? path.resolve(process.env.INPUT_DIR) : process.cwd();
const OUT_FILE_INDEX = process.env.OUT_FILE_INDEX || 'memory/file-index.json';
const OUT_PROGRESS   = process.env.OUT_PROGRESS   || 'pages/apps/overseers/progress.json';
const MODELS_JSON    = process.env.OUT_MODELS     || 'asset/models/models.json';
const WINGS_JSON     = process.env.OUT_WINGS      || 'asset/wings/manifest.json';
const DEADENDS_JSON  = process.env.OUT_DEADENDS   || 'memory/deadends.json';

const IGNORE_DIRS = new Set(['.git', '.github', 'node_modules', '.DS_Store', 'dist', 'out', '_site', '.next', '.vercel', '.cache']);
const IMAGE_EXT = new Set(['.png','.jpg','.jpeg','.webp','.gif','.avif']);
const VRM_EXT = new Set(['.vrm']);
const WING_TEXTURE_DIR = 'asset/wings';

function walk(dir, relBase = ''){
  const entries = fs.existsSync(dir) ? fs.readdirSync(dir, { withFileTypes: true }) : [];
  let files = [];
  for (const e of entries){
    if (IGNORE_DIRS.has(e.name)) continue;
    const abs = path.join(dir, e.name);
    const rel = path.join(relBase, e.name).replaceAll('\\','/');
    if (e.isDirectory()){
      files = files.concat(walk(abs, rel));
    } else if (e.isFile()){
      files.push(rel);
    }
  }
  return files;
}

function sha1OfFile(absPath){
  try {
    const data = fs.readFileSync(absPath);
    return crypto.createHash('sha1').update(data).digest('hex');
  } catch {
    return null;
  }
}

function classify(rel){
  const p = rel.toLowerCase();
  if (p.startsWith('pages/apps/')) return 'microapp';
  if (p.startsWith('pages/')) return 'page';
  if (p.startsWith('.github/workflows/')) return 'workflow';
  if (p.startsWith('asset/models')) return 'model';
  if (p.startsWith('asset/wings')) return 'wings';
  if (p.startsWith('asset/textures/wallpapers')) return 'wallpaper';
  if (p === 'cname') return 'cname';
  if (p.endsWith('.json') || p.endsWith('.yaml') || p.endsWith('.yml')) return 'data';
  if (p.endsWith('.html')) return 'html';
  if (p.endsWith('.js') || p.endsWith('.mjs')) return 'script';
  if (p.endsWith('.css')) return 'style';
  return 'other';
}

function purposeFromPath(rel){
  const p = rel.toLowerCase();
  if (p.includes('/overseers/hub')) return 'Overseers Hub UI';
  if (p.includes('/progress.json')) return 'Telemetry (WPI, counters)';
  if (p.includes('/permissions/')) return 'Permissions state';
  if (p.endsWith("cody's memory.yaml") || p.endsWith('cody’s memory.yaml')) return 'Canonical project memory';
  if (p.startsWith('asset/textures/wallpapers')) return 'Wallpaper image';
  if (p.startsWith('asset/models')) return 'VRM model';
  if (p.startsWith('asset/wings')) return 'Wings model/texture';
  if (p.startsWith('.github/workflows/')) return 'GitHub Actions workflow';
  if (p === 'cname') return 'Custom domain for GitHub Pages';
  return '';
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function countWallpapers(files){
  return files.filter(f => f.toLowerCase().startsWith('asset/textures/wallpapers') && IMAGE_EXT.has(path.extname(f).toLowerCase())).length;
}

function buildModels(files){
  const list = [];
  for (const f of files){
    const ext = path.extname(f).toLowerCase();
    if (!VRM_EXT.has(ext)) continue;
    const lower = f.toLowerCase();
    let wings = false;
    if (lower.startsWith('asset/models/with-wings') || lower.startsWith('asset/winged-models')) wings = true;
    else if (lower.startsWith('asset/models/') && !lower.includes('/with-wings/') && !lower.includes('/wingless/')){
      // legacy rule: wingless unless name ends with _wings or -wings
      wings = /(_wings|-wings)\.vrm$/i.test(lower);
    }
    list.push({ path: f, preWinged: wings });
  }
  return { generated_at: new Date().toISOString(), models: list };
}

function buildWingsManifest(files){
  const manifest = {};
  for (const f of files){
    if (!f.toLowerCase().startsWith(WING_TEXTURE_DIR)) continue;
    const base = path.basename(f);
    const m = /wing(\d+).*?(_c|_e|_nrm)?\./i.exec(base);
    if (!m) continue;
    const num = m[1];
    const suff = (m[2] || '').toLowerCase();
    const entry = manifest[num] || { id: `wing${num}`, textures: {} };
    const kind = suff === '_e' ? 'emissive' : suff === '_nrm' ? 'normal' : 'albedo';
    entry.textures[kind] = entry.textures[kind] || [];
    entry.textures[kind].push(f);
    manifest[num] = entry;
  }
  return { generated_at: new Date().toISOString(), wings: Object.values(manifest).sort((a,b)=>a.id.localeCompare(b.id)) };
}

function deadEndsFromGit(){
  try{
    const output = child_process.execSync('git log --name-status --pretty=format:"%H|%at"', { encoding: 'utf8' });
    const lines = output.split(/\r?\n/);
    const dead = [];
    let current = null;
    for(const line of lines){
      if(!line) continue;
      if(/^[0-9a-f]{7,40}\|\d+$/i.test(line)){
        current = { commit: line.split('|')[0], ts: Number(line.split('|')[1]) };
        continue;
      }
      // Name-status lines like "D\tpath"
      const m = /^(\w)\t(.+)$/.exec(line);
      if(m && m[1] === 'D'){
        dead.push({ path: m[2], deleted_in: current?.commit, deleted_at: new Date((current?.ts||0)*1000).toISOString() });
      }
    }
    return dead;
  }catch(e){
    return [];
  }
}

(function main(){
  const files = walk(ROOT);
  const index = [];
  for (const rel of files){
    const abs = path.join(ROOT, rel);
    const st = fs.statSync(abs);
    index.push({
      path: rel,
      bytes: st.size,
      sha1: sha1OfFile(abs),
      type: classify(rel),
      purpose: purposeFromPath(rel)
    });
  }
  const summary = {
    count: index.length,
    byType: Object.fromEntries(index.reduce((acc, it)=>{ acc.set(it.type, (acc.get(it.type)||0)+1); return acc; }, new Map())),
    generated_at: new Date().toISOString()
  };

  const wpi = countWallpapers(files);
  const models = buildModels(files);
  const wings = buildWingsManifest(files);
  const dead = deadEndsFromGit();

  ensureDir(OUT_FILE_INDEX);
  fs.writeFileSync(OUT_FILE_INDEX, JSON.stringify({ summary, files: index }, null, 2));

  ensureDir(OUT_PROGRESS);
  let progress = { last_updated: new Date().toISOString(), wallpaper_power_index: wpi };
  try {
    const existing = JSON.parse(fs.readFileSync(OUT_PROGRESS, 'utf8'));
    progress = { ...existing, last_updated: new Date().toISOString(), wallpaper_power_index: wpi };
  } catch {}
  fs.writeFileSync(OUT_PROGRESS, JSON.stringify(progress, null, 2));

  ensureDir(MODELS_JSON);
  fs.writeFileSync(MODELS_JSON, JSON.stringify(models, null, 2));

  ensureDir(WINGS_JSON);
  fs.writeFileSync(WINGS_JSON, JSON.stringify(wings, null, 2));

  ensureDir(DEADENDS_JSON);
  fs.writeFileSync(DEADENDS_JSON, JSON.stringify({ generated_at: new Date().toISOString(), deleted: dead }, null, 2));

  console.log('Repo Sweep complete:', { files: summary.count, wpi, deadEnds: dead.length });
})();
