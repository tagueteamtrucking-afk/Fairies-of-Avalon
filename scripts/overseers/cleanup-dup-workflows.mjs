// scripts/overseers/cleanup-dup-workflows.mjs
import fs from 'fs';
import path from 'path';

const WF_DIR = '.github/workflows';
const CANON = 'overseers-manifests.yml';
const TARGET_NAME = 'Overseers - Manifests + WPI';

function readName(p){
  try{
    const first = fs.readFileSync(p,'utf8').split(/\r?\n/).find(l=>/^name\s*:/i.test(l));
    return first ? first.split(':',2)[1].trim() : null;
  }catch{ return null; }
}

(function main(){
  if(!fs.existsSync(WF_DIR)) return;
  const files = fs.readdirSync(WF_DIR).filter(f=>f.endsWith('.yml')||f.endsWith('.yaml'));
  const toRemove = [];
  for(const f of files){
    const full = path.join(WF_DIR,f);
    const name = readName(full);
    if(name === TARGET_NAME && f !== CANON){
      toRemove.push(full);
    }
  }
  for(const f of toRemove){
    fs.unlinkSync(f);
    console.log('Removed duplicate workflow:', f);
  }
  console.log('Cleanup complete. Removed:', toRemove.length);
})();
