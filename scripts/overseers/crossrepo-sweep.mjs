// scripts/overseers/crossrepo-sweep.mjs
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = process.cwd();
const EXT = process.env.SECOND_REPO_PATH || '_external';
const OUT = path.join(ROOT, 'pages/apps/overseers/crossrepo.json');

function sha1OfFile(abs){
  const h = crypto.createHash('sha1'); h.update(fs.readFileSync(abs)); return h.digest('hex');
}

function walk(dir){
  const out = [];
  const entries = fs.readdirSync(dir, { withFileTypes:true });
  for (const e of entries){
    const abs = path.join(dir, e.name);
    if (e.isDirectory()){
      if (['.git', 'node_modules', '.DS_Store'].includes(e.name)) continue;
      out.push(...walk(abs));
    }else if (e.isFile()){
      out.push(abs);
    }
  }
  return out;
}

function collect(root, prefix){
  const files = walk(root);
  return files.map(abs => ({
    repo: prefix,
    path: abs.replace(root, '').replaceAll('\\','/'),
    sha1: sha1OfFile(abs),
    bytes: fs.statSync(abs).size
  }));
}

async function main(){
  const a = collect(ROOT, 'primary');
  const b = collect(path.join(ROOT, EXT), 'secondary');
  const all = [...a, ...b];
  all.sort((x,y)=> (x.repo+x.path).localeCompare(y.repo+y.path));
  fs.mkdirSync(path.dirname(OUT), { recursive:true });
  await fsp.writeFile(OUT, JSON.stringify({ generated_at: new Date().toISOString(), files: all }, null, 2));
  console.log('Crossrepo report:', OUT, all.length, 'files');
}
main().catch(e=>{ console.error(e); process.exit(1); });
