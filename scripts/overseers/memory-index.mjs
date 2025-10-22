// scripts/overseers/memory-index.mjs (ESM, Node 20)
// Scans the repo and writes:
//  - pages/apps/overseers/memory/all-file-memory.json  (detailed index)
//  - pages/apps/overseers/memory/deletion-candidates.json (unused / low-signal)
//  - pages/apps/overseers/memory/report.md (human summary)
import * as fs from 'node:fs';
import * as fsp from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';

const ROOT = process.cwd();
const OUT_DIR = path.join('pages','apps','overseers','memory');
const OUT_MEM = path.join(OUT_DIR, 'all-file-memory.json');
const OUT_DEL = path.join(OUT_DIR, 'deletion-candidates.json');
const OUT_MD  = path.join(OUT_DIR, 'report.md');

const IGNORE_DIRS = new Set(['.git','node_modules','.DS_Store','dist','out','_site','.next','.vercel','.cache']);
const IMAGE_EXT = new Set(['.png','.jpg','.jpeg','.webp','.gif','.avif']);
const VRM_EXT   = new Set(['.vrm']);
const TEXT_EXT  = new Set(['.json','.yml','.yaml','.md','.html','.css','.js','.mjs','.ts','.tsx','.svg','.txt']);
const KEEP_PATHS= [
  'asset/models','asset/wings','asset/textures',
  'pages/apps/alexandria/worlds','pages/apps/carol/plans','pages/apps/jem/programs'
];

function walk(dir){
  const entries = fs.existsSync(dir) ? fs.readdirSync(dir, { withFileTypes:true }) : [];
  let files = [];
  for(const e of entries){
    if(IGNORE_DIRS.has(e.name)) continue;
    const abs = path.join(dir, e.name);
    const rel = path.relative(ROOT, abs).split(path.sep).join('/');
    if(e.isDirectory()){
      files = files.concat(walk(abs));
    } else if(e.isFile()){
      files.push(rel);
    }
  }
  return files;
}

function sha1OfFile(p){
  try {
    const data = fs.readFileSync(p);
    return createHash('sha1').update(data).digest('hex');
  } catch { return null; }
}

function classify(rel){
  const p = rel.toLowerCase();
  if(p.startsWith('pages/apps/')) return 'microapp';
  if(p.startsWith('pages/')) return 'page';
  if(p.startsWith('.github/workflows/')) return 'workflow';
  if(p.startsWith('asset/models')) return 'model';
  if(p.startsWith('asset/wings')) return 'wings';
  if(p.startsWith('asset/textures/wallpapers')) return 'wallpaper';
  const ext = path.extname(p);
  if(VRM_EXT.has(ext)) return 'model';
  if(IMAGE_EXT.has(ext)) return 'image';
  if(TEXT_EXT.has(ext)) return 'text';
  return 'other';
}

function purposeFromPath(rel){
  const p = rel.toLowerCase();
  if(p.includes('/overseers/hub/')) return 'Overseers Hub UI';
  if(p.endsWith('/index.json')) return 'Pointer file';
  if(p.includes('/carol/')){
    if(p.endsWith('menu.html')) return 'Carol menu UI';
    if(p.endsWith('shopping.html')) return 'Carol shopping UI';
    if(p.endsWith('print-menu.html')) return 'Print menu (one day per page)';
    if(p.endsWith('print-shopping.html')) return 'Print shopping list';
    if(p.endsWith('print.css')) return 'Print styles';
    if(p.includes('/plans/')) return 'Meal plan data (JSON)';
  }
  if(p.startsWith('.github/workflows/')) return 'CI workflow';
  return '';
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function loadText(p){ try{ return fs.readFileSync(p, 'utf8'); } catch { return ''; } }

function findUsage(files){
  // Very light reference finder: look for exact relative names inside text files
  const textFiles = files.filter(f=>TEXT_EXT.has(path.extname(f.toLowerCase())));
  const textMap = new Map();
  for(const f of textFiles){
    const full = path.join(ROOT,f);
    textMap.set(f, loadText(full));
  }
  const refs = {};
  for(const f of files){
    refs[f] = { referencedBy: [] };
    for(const [tf,src] of textMap){
      if(tf===f) continue;
      if(src.includes(f) || src.includes('./'+path.basename(f)) || src.includes('/'+path.basename(f))){
        refs[f].referencedBy.push(tf);
      }
    }
  }
  return refs;
}

async function main(){
  const files = walk(ROOT);
  const nowISO = new Date().toISOString();
  const index = [];

  for(const rel of files){
    const full = path.join(ROOT, rel);
    const stat = fs.statSync(full);
    index.push({
      path: rel,
      size: stat.size,
      sha1: sha1OfFile(full),
      type: classify(rel),
      purpose: purposeFromPath(rel),
      mtime: stat.mtime.toISOString()
    });
  }

  // Build usage references
  const refs = findUsage(files);
  const indexByPath = new Map(index.map(x=>[x.path,x]));
  const unused = [];
  for(const f of files){
    const isKeep = KEEP_PATHS.some(prefix => f.startsWith(prefix));
    const isWorkflow = f.startsWith('.github/workflows/');
    const isPlan = f.startsWith('pages/apps/carol/plans/');
    const usage = refs[f]?.referencedBy || [];
    const type = indexByPath.get(f)?.type || '';
    if(usage.length===0 && !isKeep && !isWorkflow && !isPlan){
      // Candidate if not in obvious keep paths
      unused.push({ path:f, type, reason:'No references found (heuristic)' });
    }
  }

  // Write outputs
  ensureDir(OUT_MEM);
  fs.writeFileSync(OUT_MEM, JSON.stringify({ generated_at: nowISO, files: index }, null, 2), 'utf8');
  fs.writeFileSync(OUT_DEL, JSON.stringify({ generated_at: nowISO, candidates: unused }, null, 2), 'utf8');

  // Summary MD
  const counts = index.reduce((acc,x)=>{ acc[x.type]=(acc[x.type]||0)+1; return acc; }, {});
  const md = [
    '# All File Memory',
    '',
    `Generated: ${nowISO}`,
    '',
    '## Counts by type',
    '',
    ...Object.keys(counts).sort().map(k=>`- **${k}**: ${counts[k]}`),
    '',
    '## Deletion candidates (heuristic)',
    '',
    unused.length? 'Candidates below are not referenced by any text file and not in keep paths. Review before deletion.' : 'None.',
    '',
    ...unused.slice(0,200).map(c=>`- \`${c.path}\` — ${c.reason}`),
    '',
    '_Note: usage detection is heuristic; JS dynamic imports, CSS url() etc. may not be detected._'
  ].join('\n');
  ensureDir(OUT_MD);
  fs.writeFileSync(OUT_MD, md, 'utf8');

  console.log('Memory index written:', { files:index.length, unused:unused.length, OUT_MEM, OUT_DEL, OUT_MD });
}

main().catch(err=>{ console.error(err); process.exit(1); });
