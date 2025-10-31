import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';

const outDir = path.join('reports', 'clarity');
fs.mkdirSync(outDir, { recursive: true });

const shasum = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const files = execSync('git ls-files').toString().trim().split('\n').filter(Boolean);

const index = [];
const pages = [];
const workflows = [];
const workers = [];

function firstLines(txt, n=80){ return txt.split(/\r?\n/).slice(0,n).join('\n'); }
function guessPurpose(p){
  if (p.startsWith('.github/workflows/') && /\.ya?ml$/i.test(p)) return 'workflow';
  if (p.startsWith('cloudflare/') && p.endsWith('.js')) return 'worker';
  if (p.startsWith('pages/apps/')) return 'app-page';
  if (p.startsWith('pages/_city/')) return 'city-page';
  if (/\.html?$/i.test(p)) return 'page';
  if (/\.(mjs|js)$/i.test(p)) return 'automation';
  if (/\.css$/i.test(p)) return 'style';
  if (/\.(vrm|fbx|glb|gltf)$/i.test(p)) return '3d-asset';
  if (/memory\.ya?ml/i.test(p)) return 'memory';
  return 'other';
}
function extractImports(txt){ return Array.from(new Set([...txt.matchAll(/import\s+[^'"]*['"]([^'"]+)['"]/g)].map(m=>m[1]))); }
function extractLinks(txt){ return Array.from(new Set([...txt.matchAll(/href\s*=\s*["']([^"']+)["']/gi)].map(m=>m[1]))); }

for (const p of files){
  try{
    const b = fs.readFileSync(p);
    const s = b.length;
    const h = shasum(b);
    const isText = s < 200_000;
    const txt = isText ? b.toString('utf8') : '';
    const purpose = guessPurpose(p);
    const imports = isText ? extractImports(txt) : [];
    const links = isText && /\.html?$/i.test(p) ? extractLinks(txt) : [];
    const preview = isText ? firstLines(txt, 80) : '';
    index.push({ path: p, sha256: h, bytes: s, purpose, imports, links, preview });

    if (purpose === 'workflow'){
      const name = (txt.match(/^name:\s*(.*)$/m) || [])[1] || path.basename(p);
      const onBlock = (txt.match(/^\s*on:\s*([\s\S]*?)^\S/m) || [])[1] || '';
      const triggers = Array.from(new Set((onBlock.match(/[a-zA-Z_]+/g) || []).filter(x=>x!=='on')));
      workflows.push({ path: p, name: name.trim(), triggers });
    }
    if (purpose === 'worker'){
      workers.push({ path: p });
    }
    if (purpose === 'page' || purpose === 'app-page' || purpose === 'city-page'){
      pages.push({ path: p, links });
    }
  }catch{}
}

fs.writeFileSync(path.join(outDir,'files-index.json'), JSON.stringify(index,null,2));
fs.writeFileSync(path.join(outDir,'pages-map.json'), JSON.stringify(pages,null,2));
fs.writeFileSync(path.join(outDir,'workflows-map.json'), JSON.stringify(workflows,null,2));
fs.writeFileSync(path.join(outDir,'workers-map.json'), JSON.stringify(workers,null,2));
console.log('Crown of Clarity: wrote reports/clarity/*.json');
