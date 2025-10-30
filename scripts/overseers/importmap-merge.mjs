import fs from 'node:fs'; import path from 'node:path';
const repo=process.cwd(), mapPath=path.join(repo,'importmap.json'), addPath=path.join(repo,'pages','apps','overseers','importmap-additions.json');
function die(m){ console.error(m); process.exit(1); }
function readJSON(p){ if(!fs.existsSync(p)) die('Add File: '+p); try{return JSON.parse(fs.readFileSync(p,'utf8'));}catch(e){ die('Invalid JSON: '+p);} }
const base=readJSON(mapPath), add=readJSON(addPath); const baseImp=base.imports||{}, addImp=add.imports||{};
for(const [k,v] of Object.entries(addImp)) baseImp[k]=v;
const sorted=Object.fromEntries(Object.entries(baseImp).sort((a,b)=>a[0].localeCompare(b[0])));
fs.writeFileSync(mapPath, JSON.stringify({...base, imports:sorted}, null, 2)); console.log('importmap merged');