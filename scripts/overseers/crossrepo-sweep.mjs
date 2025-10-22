import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const PRIMARY_ROOT = process.cwd();
const SECOND_REPO_PATH = process.env.SECOND_REPO_PATH || '__second__';
const OUTPUT_FILE = process.env.OUTPUT_FILE || 'runtime/memory/crossrepo.json';

const IGNORE_DIRS = new Set(['.git','node_modules','.DS_Store','dist','out','.next','.vercel','.cache','vendor','.github']);
const IGNORE_FILES = new Set([]);

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function* walk(dir){
  const entries = fs.readdirSync(dir, { withFileTypes:true });
  for(const e of entries){
    if(IGNORE_DIRS.has(e.name)) continue;
    const abs = path.join(dir, e.name);
    if(e.isDirectory()){
      yield* walk(abs);
    }else if(e.isFile()){
      if(IGNORE_FILES.has(e.name)) continue;
      yield abs;
    }
  }
}

function sha1OfFile(p){
  try{
    const data = fs.readFileSync(p);
    return crypto.createHash('sha1').update(data).digest('hex');
  }catch{ return null; }
}

function relFrom(p, base){ return path.relative(base, p).replaceAll(path.sep, '/'); }

function indexRepo(base){
  const items = [];
  for(const abs of walk(base)){
    const st = fs.statSync(abs);
    items.push({
      path: relFrom(abs, base),
      bytes: st.size,
      sha1: sha1OfFile(abs)
    });
  }
  return items;
}

function main(){
  const primary = indexRepo(PRIMARY_ROOT);
  const secondary = indexRepo(path.resolve(PRIMARY_ROOT, SECOND_REPO_PATH));
  const out = {
    generated_at: new Date().toISOString(),
    primary: { root: '.', files: primary },
    secondary: { root: SECOND_REPO_PATH, files: secondary }
  };
  ensureDir(OUTPUT_FILE);
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(out, null, 2));
  console.log('Crossrepo memory index written:', OUTPUT_FILE);
}

main();
