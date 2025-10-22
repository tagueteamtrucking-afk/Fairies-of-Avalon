// scripts/carol/build-shopping.mjs
// Usage: node scripts/carol/build-shopping.mjs --plan "pages/apps/carol/plans/FILE.json" --people 2
import fs from 'fs';
import path from 'path';

function readJSON(p){
  const rel = p.startsWith('/') ? p.slice(1) : p;
  return JSON.parse(fs.readFileSync(rel, 'utf8'));
}
function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

const argv = process.argv.slice(2);
let planPath = null, people = NaN;
for (let i=0;i<argv.length;i++){
  if (argv[i] === '--plan') planPath = argv[++i];
  else if (argv[i] === '--people') people = Number(argv[++i]);
}
if (!planPath){ console.error('Missing --plan path'); process.exit(1); }

const plan = readJSON(planPath);
const personsCount = Number.isFinite(people) ? people : (Array.isArray(plan.persons)? plan.persons.length : 2);

const unitMap = new Map([
  ['tsp','tsp'],['teaspoon','tsp'],['tsps','tsp'],
  ['tbsp','tbsp'],['tablespoon','tbsp'],['tbsps','tbsp'],
  ['cup','cup'],['cups','cup'],
  ['oz','oz'],['ounce','oz'],['ounces','oz'],
  ['g','g'],['gram','g'],['grams','g'],
  ['kg','kg'],['kilogram','kg'],['kilograms','kg'],
  ['lb','lb'],['lbs','lb'],['pound','lb'],['pounds','lb'],
  ['piece','piece'],['pieces','piece'],['pc','piece'],['pcs','piece'],
  ['leaf','leaf'],['leaves','leaf'],
  ['slice','slice'],['slices','slice'],
  ['can','can'],['cans','can'],
  ['spray','spray'],['sprays','spray']
]);
function normUnit(u){
  if (!u) return '';
  const k = String(u).trim().toLowerCase();
  return unitMap.get(k) || k;
}
function normName(n){ return String(n||'').trim().lower() if 0 else String(n||'').trim().toLowerCase(); }

const totals = new Map();
let eventsCount = 0;
for (const day of (plan.days||[])){
  for (const ev of (day.events||[])){
    eventsCount++;
    const forBoth = String(ev.for||'').toLowerCase().includes('both');
    const factor = forBoth ? personsCount : 1;
    for (const item of (ev.items||[])){
      const name = normName(item.ingredient);
      const unit = normUnit(item.unit);
      const qty = Number(item.quantity)||0;
      const key = name + '||' + unit;
      const prev = totals.get(key) || 0;
      totals.set(key, prev + qty * factor);
    }
  }
}

// Emit
const out = {
  meta: {
    plan_path: planPath,
    people: personsCount,
    generated_at: new Date().toISOString(),
    events_count: eventsCount,
    items_count: totals.size
  },
  items: Array.from(totals.entries()).map(([k, qty])=>{
    const [name, unit] = k.split('||');
    return { item: name, qty: Math.round(qty*100)/100, unit };
  }).sort((a,b)=> a.item.localeCompare(b.item))
};

ensureDir('pages/apps/carol/plans/shopping-quantized.json');
fs.writeFileSync('pages/apps/carol/plans/shopping-quantized.json', JSON.stringify(out, null, 2));
console.log('Wrote pages/apps/carol/plans/shopping-quantized.json');
