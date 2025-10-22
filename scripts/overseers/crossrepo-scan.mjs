// scripts/overseers/crossrepo-scan.mjs
import fs from 'fs';
import path from 'path';

const SECOND_DIR = 'second_repo';
const OUT = 'pages/apps/overseers/crossrepo/second_repo_index.json';

function walk(dir){
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  let files = [];
  for (const e of entries){
    const p = path.join(dir, e.name);
    if (e.isDirectory()) files = files.concat(walk(p));
    else files.push(p);
  }
  return files;
}

function main(){
  if (!fs.existsSync(SECOND_DIR)) {
    console.error('second_repo directory not found.');
    process.exit(0);
  }
  const files = walk(SECOND_DIR).map(p=>path.relative(SECOND_DIR, p).replace(/\\/g,'/'));
  fs.mkdirSync(path.dirname(OUT), {recursive:true});
  fs.writeFileSync(OUT, JSON.stringify({ repo: process.env.SECOND_REPO||'', generated_at:new Date().toISOString(), files }, null, 2));
  console.log(`Cross-repo index written to ${OUT} (${files.length} files)`);
}
main();
