import fs from 'node:fs'; import path from 'node:path';
const base = path.join(process.cwd(),'pages','apps','carol'); const plans=path.join(base,'plans'); const idx=path.join(base,'index.json');
function die(m){ console.error(m); process.exit(1); }
function readJSON(p){ if(!fs.existsSync(p)) die('Add File: '+p); try{return JSON.parse(fs.readFileSync(p,'utf8'));}catch(e){ die('Invalid JSON: '+p); } }
const meta = readJSON(idx);
if(!meta.plan_latest) die('Error: index.json missing "plan_latest"');
const plan = readJSON(path.join(base, meta.plan_latest));
const counts = {}; (plan.days||[]).forEach(d=> (d.meals||[]).forEach(m=> counts[m]=(counts[m]||0)+1 ));
const rules = { oatmeal:['lb',0.25], salad:['bag',1], 'stir-fry':['lb',0.5] };
const items = Object.entries(counts).map(([name,count])=>{ const r=rules[name]||['ea',1]; return {name, qty:(count*r[1]).toFixed(2)+' '+r[0]}; });
fs.writeFileSync(path.join(plans,'shopping-quantized.json'), JSON.stringify({plan:plan.plan,items},null,2));
fs.writeFileSync(path.join(plans,'plan-report.json'), JSON.stringify({counts},null,2));
console.log('Carol: built shopping-quantized.json from', meta.plan_latest);