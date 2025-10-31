import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';

const outDir = path.join('reports','clarity');
fs.mkdirSync(outDir, { recursive: true });

const sha = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const files = execSync('git ls-files').toString().trim().split('\n').filter(Boolean);

const index = [];
const pages = [];
const workflows = [];
const workers = [];

const firstLines = (txt, n=80) => txt.split(/\r?\n/).slice(0, n).join('\n');
const isHtml = (p) => /\.html?$/i.test(p);
const isWorkflow = (p) => p.startsWith('.github/workflows/') && /\.ya?ml$/i.test(p);

function purposeOf(p){
  if (isWorkflow(p)) return 'workflow';
  if (p.startsWith('cloudflare/') && p.endsWith('.js')) return 'worker';
  if (p.startsWith('pages/apps/')) return 'app-page';
  if (p.startsWith('pages/_city/')) return 'city-page';
  if (isHtml(p)) return 'page';
  if (/\.(mjs|js)$/i.test(p)) return 'automation';
  if (/\.css$/i.test(p)) return 'style';
  if (/\.(vrm|fbx|glb|gltf)$/i.test(p)) return '3d-asset';
  if (/memory\.ya?ml/i.test(p)) return 'memory';
  return 'other';
}
function extractImports(txt){ return Array.from(new Set([...txt.matchAll(/import\s+[^'"]*['"]([^'"]+)['"]/g)].map(m=>m[1]))); }
function extractLinks(txt){ return Array.from(new Set([...txt.matchAll(/href\s*=\s*["']([^"']+)["']/gi)].map(m=>m[1]))); }
function referencedPaths(txt){
  const out = [];
  const re = /(src|href)=["']([^"']+)["']/gi;
  let m; while((m=re.exec(txt))) out.push(m[2]);
  return Array.from(new Set(out));
}

for (const p of files){
  try{
    const buf = fs.readFileSync(p);
    const bytes = buf.length;
    const hash = sha(buf);
    const texty = bytes < 200_000 ? buf.toString('utf8') : '';
    const purpose = purposeOf(p);
    const imports = texty ? extractImports(texty) : [];
    const links = texty && isHtml(p) ? extractLinks(texty) : [];
    const refs = texty ? referencedPaths(texty) : [];
    const preview = texty ? firstLines(texty, 60) : '';
    index.push({ path: p, sha256: hash, bytes, purpose, imports, links, refs, preview });

    if (purpose === 'workflow'){
      const name = (texty.match(/^name:\s*(.*)$/m) || [])[1] || path.basename(p);
      const onBlock = (texty.match(/^\s*on:\s*([\s\S]*?)^\S/m) || [])[1] || '';
      const triggers = Array.from(new Set((onBlock.match(/[a-zA-Z_]+/g) || []).filter(x=>x!=='on')));
      workflows.push({ path: p, name: name.trim(), triggers });
    }
    if (purpose === 'worker'){ workers.push({ path: p }); }
    if (purpose === 'page' || purpose === 'app-page' || purpose === 'city-page'){ pages.push({ path: p, links }); }
  }catch{}
}

fs.writeFileSync(path.join(outDir,'files-index.json'), JSON.stringify(index,null,2));
fs.writeFileSync(path.join(outDir,'pages-map.json'), JSON.stringify(pages,null,2));
fs.writeFileSync(path.join(outDir,'workflows-map.json'), JSON.stringify(workflows,null,2));
fs.writeFileSync(path.join(outDir,'workers-map.json'), JSON.stringify(workers,null,2));
console.log('Crown of Clarity: analysis written to reports/clarity/*.json');
