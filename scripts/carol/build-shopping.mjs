// scripts/carol/build-shopping.mjs
import fs from 'fs';
import path from 'path';

const POINTER = 'pages/apps/carol/index.json';
const OUT_SHOPPING = 'pages/apps/carol/plans/shopping-quantized.json';

function readJSON(p){ return JSON.parse(fs.readFileSync(p,'utf8')); }
function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function eventServings(e, people){
  if(!e || !e.for) return 1;
  const f = String(e.for).toLowerCase();
  if (f.includes('both')) return people;
  // allow listing by person id or name fragments
  const hits = ['a','ray','b','blanca'].filter(k => f.includes(k)).length;
  return Math.max(1, Math.min(people, hits || 1));
}

function aggregateFromPlan(plan, people){
  const bag = new Map(); // key: item|unit -> qty
  let eventsCount = 0;
  for (const d of (plan.days||[])){
    for (const e of (d.events||[])){
      eventsCount++;
      const factor = eventServings(e, people);
      for (const it of (e.items||[])){
        const item = (it.ingredient||it.item||'').trim();
        const unit = (it.unit||'').trim();
        const qty = Number(it.quantity ?? it.qty ?? 0) * factor;
        const key = item+'|'+unit;
        bag.set(key, (bag.get(key)||0) + qty);
      }
    }
  }
  const items = Array.from(bag.entries()).map(([k,qty])=>{
    const [item,unit] = k.split('|');
    // round to 2 decimals
    return { item, qty: Math.round(qty*100)/100, unit: unit || '' };
  }).sort((a,b)=> a.item.localeCompare(b.item));
  return { items, eventsCount };
}

(function main(){
  const ptr = readJSON(POINTER);
  const plan = readJSON(ptr.plan);
  const people = (plan.persons && plan.persons.length) || 2;
  const { items, eventsCount } = aggregateFromPlan(plan, people);
  const out = {
    meta: { people, source_plan: ptr.plan, generated_at: new Date().toISOString(), events_count: eventsCount },
    items
  };
  ensureDir(OUT_SHOPPING);
  fs.writeFileSync(OUT_SHOPPING, JSON.stringify(out, null, 2));
  console.log('Shopping list built:', items.length, 'lines from', eventsCount, 'events for', people, 'people');
})();
