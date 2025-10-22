import {promises as fs} from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const args = process.argv.slice(2);
function getArg(name, def=''){ const i=args.indexOf(name); return i>=0? args[i+1] : def; }

const MAIN   = getArg('--main','.');
const SECOND = getArg('--second','');
const OUT    = getArg('--out','pages/apps/overseers/all-files.json');

const IGNORE_DIRS = new Set(['.git','node_modules','.DS_Store','dist','out','_site','.next','.vercel','.cache']);

function* walkSync(dir){
  const entries = await fs.readdir(dir, { withFileTypes:true });
  for(const e of entries){
    if (IGNORE_DIRS.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walkSync(p);
    else if (e.isFile()) yield p;
  }
}

function extType(p){
  const e = path.extname(p).toLowerCase();
  if(['.vrm'].includes(e)) return 'model';
  if(['.png','.jpg','.jpeg','.webp','.gif','.avif'].includes(e)) return 'image';
  if(['.css'].includes(e)) return 'style';
  if(['.html','.htm'].includes(e)) return 'html';
  if(['.js','.mjs','.cjs',' .ts'].includes(e)) return 'script';
  if(['.yml','.yaml','.json'].includes(e)) return 'data';
  return 'other';
}

async function fileInfo(root, rel){
  const abspath = path.join(root, rel);
  const b = await fs.readFile(abspath);
  const sha1 = crypto.createHash('sha1').update(b).digest('hex');
  const st = await fs.stat(abspath);
  return { path: rel.replace(/\\/g,'/'), bytes: st.size, sha1, type: extType(rel) };
}

async function gather(root){
  const list = [];
  for await (const p of walkSync(root)){
    const rel = path.relative(root, p);
    list.push(await fileInfo(root, rel));
  }
  return list;
}

const outDir = path.dirname(OUT);
await fs.mkdir(outDir, { recursive:true });

const mainList = await gather(MAIN);
const payload = {
  generated_at: new Date().toISOString(),
  main: { root: MAIN, count: mainList.length, files: mainList }
};

if (SECOND){
  const secondList = await gather(SECOND);
  payload.second = { root: SECOND, count: secondList.length, files: secondList };
}

await fs.writeFile(OUT, JSON.stringify(payload, null, 2));
console.log('Wrote', OUT, 'files:', (payload.main?.count||0) + (payload.second?.count||0));
