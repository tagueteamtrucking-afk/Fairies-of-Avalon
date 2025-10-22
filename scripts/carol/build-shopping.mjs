// scripts/carol/build-shopping.mjs
// Node 20, ESM. No 'param', no PowerShell. Pure JS.
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';

const ROOT = process.cwd();
const IDX = path.join(ROOT, 'pages/apps/carol/index.json');

function loadJSON(p){ return JSON.parse(fs.readFileSync(p, 'utf8')); }

function normName(n){ return String(n||'').trim().toLowerCase(); }

const ALIAS = new Map([
  ['mixed vegetables (frozen)','mixed vegetables, frozen'],
  ['frozen mixed vegetables','mixed vegetables, frozen'],
  ['frozen veg medley','mixed vegetables, frozen'],
  ['lactose-free mozzarella','mozzarella, lactose-free'],
  ['lactose-free cheese stick','mozzarella, lactose-free'],
  ['lf cheese stick','mozzarella, lactose-free'],
  ['lf greek yogurt','greek yogurt, lactose-free'],
  ['lactose-free greek yogurt','greek yogurt, lactose-free'],
  ['lf cottage cheese','cottage cheese, lactose-free'],
  ['lactose-free cottage cheese','cottage cheese, lactose-free'],
]);

const OATS = { cup: 2.86, tbsp: 0.17875 };
const FROZEN_CUP_TO_LB = 0.33;

function alias(n){ const k=normName(n); return ALIAS.get(k) || n; }

function toTarget(name, qty, unit){
  name = alias(name);
  if (normName(name)==='cooked chicken breast'){
    const oz = unit==='oz' ? qty : unit==='lb' ? qty*16 : qty;
    const rawOz = oz / 0.75; // cooked->raw eq
    return { name:'chicken breast', qty: rawOz/16, unit:'lb' };
  }
  if (name==='rolled oats'){
    if (unit==='cup') return { name, qty: qty*OATS.cup, unit:'oz' };
    if (unit==='tbsp') return { name, qty: qty*OATS.tbsp, unit:'oz' };
  }
  if (name==='mixed vegetables, frozen' && unit==='cup'){
    return { name, qty: qty*FROZEN_CUP_TO_LB, unit:'lb' };
  }
  if (/yogurt|cottage/i.test(name) && unit==='cup'){
    return { name, qty: qty*8, unit:'oz' };
  }
  if (/hummus|cream cheese|mayo/i.test(name) && unit==='tbsp'){
    return { name, qty: qty*0.5, unit:'oz' };
  }
  if (unit==='oz' && ['salmon fillet','cod fillet','chicken breast','lean ground turkey'].includes(name)){
    return { name, qty: qty/16, unit:'lb' };
  }
  return { name, qty, unit };
}

function push(map, name, qty, unit){
  const k = normName(name);
  const ex = map.get(k);
  if (!ex) map.set(k, { name, qty, unit });
  else{
    if (ex.unit===unit) ex.qty += qty;
    else if (ex.unit==='lb' && unit==='oz') ex.qty += qty/16;
    else if (ex.unit==='oz' && unit==='lb'){ ex.qty = ex.qty*16 + qty*16; ex.unit = 'oz'; }
    else ex.qty += qty;
  }
}

function qtyDisplay(q, u){
  const r = (n,p=2)=> Math.round(n*10**p)/10**p;
  if (u==='lb') return `${r(q,2)} lb`;
  if (u==='oz') return `${r(q,1)} oz`;
  if (u==='qt') return `${r(q,2)} qt`;
  if (u==='can') return `${r(q,2)} cans`;
  return `${r(q,2)} ${u}`;
}

function categorize(name){
  const n = normName(name);
  if (/yogurt|cottage|milk|mozzarella/.test(n)) return 'Dairy (LF)';
  if (/chicken|turkey|salmon|cod|tuna|beans/.test(n)) return 'Proteins';
  if (/tomato|cucumber|grapes|banana|apple|pear|lemon|potatoes|spinach|avocado|kiwi|blueberries|mango/.test(n)) return 'Produce';
  if (/mixed vegetables/.test(n)) return 'Frozen';
  if (/oats|hummus|mayo|olive oil|tortilla|bread|rice|panko|cinnamon|cocoa|chia|flax|crackers|granola/.test(n)) return 'Pantry';
  return 'Other';
}

async function main(){
  const idx = loadJSON(IDX);
  let rel = idx.plan_latest || idx.plan;
  if (!rel) throw new Error('index.json missing "plan_latest"');
  rel = rel.replace(/^\/+/, '');
  const PLAN = path.join(ROOT, rel);
  const plan = loadJSON(PLAN);

  const persons = 2;
  const map = new Map();
  for (const day of plan.days||[]){
    for (const ev of day.events||[]){
      const mult = (String(ev.for||'').toLowerCase()==='both') ? persons : 1;
      for (const it of ev.items||[]){
        const t = toTarget(it.ingredient, (it.quantity||0)*mult, (it.unit||'').toLowerCase());
        push(map, t.name, t.qty, t.unit);
      }
    }
  }

  // Butter lettuce leaves -> heads (~12 leaves/head)
  const bl = map.get('butter lettuce');
  if (bl && bl.unit==='leaf'){ bl.qty = bl.qty/12; bl.unit='head'; }

  // prune tiny noise
  for (const [k,v] of map){
    if (v.qty < 0.01) map.delete(k);
  }

  const byCat = {};
  for (const v of map.values()){
    const cat = categorize(v.name);
    byCat[cat] = byCat[cat] || [];
    byCat[cat].push({ name: v.name, qty: v.qty, unit: v.unit, qty_display: qtyDisplay(v.qty, v.unit) });
  }
  for (const arr of Object.values(byCat)) arr.sort((a,b)=> a.name.localeCompare(b.name));

  const out = {
    generated_at: new Date().toISOString(),
    assumptions: [
      "Chicken cooked→raw equivalence uses 0.75 yield; cooked 6 oz ≈ raw 8 oz.",
      "LF cheese stick ~ 1 oz; merged under mozzarella (LF).",
      "Oats: 1 cup = 2.86 oz; 1 tbsp = 0.17875 oz.",
      "Hummus / cream cheese: 2 tbsp ≈ 1 oz.",
      "Frozen vegetables: 1 cup ≈ 0.33 lb (estimate)."
    ],
    items_by_cat: byCat
  };

  const OUT = path.join(ROOT, 'pages/apps/carol/plans/shopping-2p.json');
  fs.mkdirSync(path.dirname(OUT), { recursive:true });
  await fsp.writeFile(OUT, JSON.stringify(out, null, 2));
  console.log('Built', OUT);
}

main().catch(e=>{ console.error(e); process.exit(1); });
