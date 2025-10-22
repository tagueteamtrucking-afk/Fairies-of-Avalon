// scripts/overseers/memory-index.mjs
// ESM-only (no require). Node 20+.
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';

const ROOT = process.env.GITHUB_WORKSPACE ? path.resolve(process.env.GITHUB_WORKSPACE) : process.cwd();
const OUT_DIR = path.join(ROOT, 'pages/apps/overseers/memory');
const INDEX_PATH = path.join(OUT_DIR, 'file-index.json');
const COVERAGE_PATH = path.join(OUT_DIR, 'coverage.json');

// IMPORTANT: include .github (we used to exclude it). Still skip .git and node_modules.
const IGNORE_DIRS = new Set(['.git', 'node_modules', '.DS_Store', '.vercel', '.cache']);
const IGNORE_FILES = new Set([]);

// Classify by path
function classify(rel){
  const p = rel.toLowerCase();
  if (p.startsWith('.github/workflows/')) return { type:'workflow', purpose:'GitHub Actions' };
  if (p.startsWith('pages/apps/carol/')) return { type:'carol', purpose:'Meals & shopping' };
  if (p.startsWith('pages/apps/jem/')) return { type:'jem', purpose:'Fitness' };
  if (p.startsWith('pages/apps/overseers/')) return { type:'overseers', purpose:'Governance & telemetry' };
  if (p.startsWith('pages/')) return { type:'page', purpose:'Site UI' };
  if (p.startsWith('asset/models/')) return { type:'model', purpose:'VRM' };
  if (p.startsWith('asset/wings/')) return { type:'wings', purpose:'Wings' };
  if (p.endsWith('.html')) return { type:'html', purpose:'' };
  if (p.endsWith('.css')) return { type:'style', purpose:'' };
  if (p.endsWith('.js') || p.endsWith('.mjs')) return { type:'script', purpose:'' };
  if (p.endsWith('.json')) return { type:'data', purpose:'' };
  return { type:'other', purpose:'' };
}

async function sha1OfFile(abs){
  const h = crypto.createHash('sha1');
  await new Promise((resolve, reject)=>{
    const s = fs.createReadStream(abs);
    s.on('error', reject);
    s.on('end', ()=> resolve());
    s.on('data', chunk=> h.update(chunk));
  });
  return h.digest('hex');
}

async function walk(dir){
  const entries = await fsp.readdir(dir, { withFileTypes:true });
  let files = [];
  for (const e of entries){
    const name = e.name;
    if (IGNORE_DIRS.has(name)) continue;
    const abs = path.join(dir, name);
    const rel = path.relative(ROOT, abs).replaceAll('\\','/');
    if (e.isDirectory()){
      files = files.concat(await walk(abs));
    } else if (e.isFile()){
      if (IGNORE_FILES.has(name)) continue;
      files.push(rel);
    }
  }
  return files;
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function getTrackedFiles(){
  try{
    const out = execSync('git ls-files', { cwd: ROOT, encoding:'utf8' });
    return out.split(/\r?\n/).filter(Boolean).map(s=>s.trim());
  }catch{
    return [];
  }
}

(async function main(){
  const scanned = await walk(ROOT);
  const tracked = new Set(getTrackedFiles());

  const rows = [];
  for (const rel of scanned){
    const abs = path.join(ROOT, rel);
    const st = fs.statSync(abs);
    const { type, purpose } = classify(rel);
    const sha1 = await sha1OfFile(abs);
    rows.push({ path: rel, bytes: st.size, sha1, type, purpose });
  }

  // coverage: how many tracked files are represented in our scan
  const scannedSet = new Set(scanned);
  const missing = [...tracked].filter(p => !scannedSet.has(p));
  const cov = Math.round(100 * (tracked.size ? (tracked.size - missing.length) / tracked.size : 1));

  ensureDir(INDEX_PATH);
  await fsp.writeFile(INDEX_PATH, JSON.stringify({ generated_at: new Date().toISOString(), files: rows }, null, 2));
  await fsp.writeFile(COVERAGE_PATH, JSON.stringify({
    generated_at: new Date().toISOString(),
    scanned_count: scanned.length,
    tracked_count: tracked.size,
    coverage_pct: cov,
    ignored_count: 0,
    ignored_paths: [],
    missing_count: missing.length,
    missing_paths_sample: missing.slice(0, 50)
  }, null, 2));

  console.log('Memory index complete:', { scanned: scanned.length, tracked: tracked.size, coverage: cov });
})();