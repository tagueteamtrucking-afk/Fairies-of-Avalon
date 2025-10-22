// scripts/overseers/repo-doctor.mjs
import fs from 'fs';
import path from 'path';

const CNAME = 'CNAME';
const SKIP_DIRS = new Set(['.git','node_modules','dist','out','_site','.next','.vercel','.cache']);
const TEXT_EXT = new Set(['.html','.htm','.js','.mjs','.ts','.tsx','.css','.json','.md','.yml','.yaml']);

function list(dir){
  const ents = fs.readdirSync(dir, { withFileTypes:true });
  const out = [];
  for (const e of ents){
    if (SKIP_DIRS.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...list(p));
    else out.push(p);
  }
  return out;
}

function isText(p){
  const ext = path.extname(p).toLowerCase();
  return TEXT_EXT.has(ext);
}

(function main(){
  const files = list('.');
  let changed = 0;
  for (const f of files){
    if (!isText(f)) continue;
    let s = fs.readFileSync(f, 'utf8');
    const t = s.replace(/\?v=[^"' )]*/g, '');
    if (t !== s){
      fs.writeFileSync(f, t);
      changed++;
    }
  }
  fs.writeFileSync(CNAME, 'fairiesofavalon.com');
  console.log('Repo Doctor:', { changed });
})();
