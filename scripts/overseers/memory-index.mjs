// scripts/overseers/memory-index.mjs
import * as fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

const ROOT = process.cwd();
const OUT_DIR = path.join('pages','apps','overseers','memory');
const OUT_MEM = path.join(OUT_DIR, 'all-file-memory.json');
const OUT_DEL = path.join(OUT_DIR, 'deletion-candidates.json');
const OUT_MD  = path.join(OUT_DIR, 'report.md');

const IGNORE = new Set(['.git','node_modules','.DS_Store','dist','out','_site','.next','.vercel','.cache']);

const KEEP = [
  'asset/models','asset/wings','asset/textures',
  'pages/apps/alexandria/worlds','pages/apps/carol/plans','pages/apps/jem/programs'
];

const IMG = new Set(['.png','.jpg','.jpeg','.webp','.gif','.avif','.svg']);
const TXT = new Set(['.json','.yml','.yaml','.md','.html','.css','.js','.mjs','.ts','.tsx','.txt']);
const VRM = new Set(['.vrm']);

const classify = (rel)=>{
  const p = rel.toLowerCase();
  if(p.startsWith('pages/apps/')) return 'microapp';
  if(p.startsWith('pages/')) return 'page';
  if(p.startsWith('.github/workflows/')) return 'workflow';
  if(p.startsWith('asset/models')) return 'model';
  if(p.startsWith('asset/wings')) return 'wings';
  if(p.startsWith('asset/textures/wallpapers')) return 'wallpaper';
  const ext = path.extname(p);
  if(VRM.has(ext)) return 'model';
  if(IMG.has(ext)) return 'image';
  if(TXT.has(ext)) return 'text';
  return 'other';
};

const purpose = (rel)=>{
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
};

function walk(dir){
  const ents = fs.existsSync(dir) ? fs.readdirSync(dir,{withFileTypes:true}) : [];
  let acc = [];
  for(const e of ents){
    if(IGNORE.has(e.name)) continue;
    const abs = path.join(dir,e.name);
    const rel = path.relative(ROOT,abs).split(path.sep).join('/');
    if(e.isDirectory()) acc = acc.concat(walk(abs));
    else if(e.isFile()) acc.push(rel);
  }
  return acc;
}

function sha1(p){
  try{ return createHash('sha1').update(fs.readFileSync(p)).digest('hex'); }catch{ return null; }
}

function ensure(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function textOf(p){
  try{ return fs.readFileSync(p,'utf8'); }catch{ return ''; }
}

function findUsage(files){
  const textFiles = files.filter(f=> TXT.has(path.extname(f.toLowerCase())));
  const textMap = new Map(textFiles.map(f=> [f, textOf(f)]));
  const refs = {};
  for(const f of files){
    refs[f] = { referencedBy: [] };
    for(const [tf,src] of textMap){
      if(tf===f) continue;
      if(src.includes(f) || src.includes('/'+path.basename(f))){
        refs[f].referencedBy.push(tf);
      }
    }
  }
  return refs;
}

(function main(){
  const files = walk(ROOT);
  const now = new Date().toISOString();
  const index = files.map(rel=>{
    const full = path.join(ROOT,rel);
    const stat = fs.statSync(full);
    return { path:rel, size:stat.size, sha1:sha1(full), type:classify(rel), purpose:purpose(rel), mtime:stat.mtime.toISOString() };
  });

  const refs = findUsage(files);
  const unused = [];
  for(const f of files){
    const keep = KEEP.some(k=> f.startsWith(k));
    if(keep) continue;
    if(f.startsWith('.github/workflows/')) continue;
    if(f.startsWith('pages/apps/carol/plans/')) continue;
    const usage = refs[f]?.referencedBy || [];
    if(usage.length===0) unused.push({ path:f, reason:'No references detected (heuristic)', type: classify(f) });
  }

  ensure(OUT_MEM);
  fs.writeFileSync(OUT_MEM, JSON.stringify({ generated_at:now, files:index }, null, 2));
  fs.writeFileSync(OUT_DEL, JSON.stringify({ generated_at:now, candidates:unused }, null, 2));
  const counts = index.reduce((a,x)=> (a[x.type]=(a[x.type]||0)+1, a),{});
  const md = [
    '# All File Memory','',
    'Generated: '+now,'',
    '## Counts by type','',
    ...Object.keys(counts).sort().map(k=> `- **${k}**: ${counts[k]}`),
    '',
    '## Deletion candidates (heuristic)',
    unused.length? 'Candidates below are not referenced and not in keep paths:' : 'None.',
    ...unused.slice(0,200).map(c=> `- \`${c.path}\` — ${c.type}`),
    '',
    '_Heuristic only; dynamic imports, CSS url() may be missed._'
  ].join('\n');
  ensure(OUT_MD);
  fs.writeFileSync(OUT_MD, md);
  console.log('Memory index written', { total: files.length, candidates: unused.length });
})();
