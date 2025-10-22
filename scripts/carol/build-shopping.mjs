import fs from 'node:fs';
import path from 'node:path';

const POINTER = 'pages/apps/carol/index.json';
const DEFAULT_OUT = 'pages/apps/carol/plans/shopping-2p.json';

function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }

function readJSON(p){
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

// Basic normalizer mapping
const NAME_ALIASES = new Map([
  ['frozen mixed vegetables','mixed vegetables, frozen'],
  ['mixed vegetables (frozen)','mixed vegetables, frozen'],
  ['frozen veg medley','mixed vegetables, frozen'],
  ['lactose-free greek yogurt','greek yogurt, lactose-free'],
  ['lactose-free cottage cheese','cottage cheese, lactose-free'],
  ['lactose-free milk','milk, lactose-free'],
  ['soft whole-grain bread','whole-grain bread, soft'],
  ['soft whole-wheat tortilla','whole-wheat tortillas, soft'],
  ['lactose-free mozzarella','mozzarella, lactose-free'],
  ['hummus (no cumin)','hummus']
]);

// Unit conversion helpers (approximate for shopping convenience; tweak if needed)
const TBSP_PER_OZ = 2;           // peanut butter, hummus (by volume)
const TSP_PER_FL_OZ = 6;         // oil
const CUP_PER_QUART = 4;
const OZ_PER_CUP_YOGURT = 8;
const OZ_PER_CUP_COTTAGE = 8;
const OZ_PER_CUP_OATS = 3.5;     // rolled oats typical pack weight per cup
const OZ_PER_TBSP_OATS = OZ_PER_CUP_OATS/16;

// Produce per-piece approx weight in lb (tunable)
const PRODUCE_LB = {
  'apple': 0.33,
  'banana': 0.26,
  'pear': 0.33,
  'lemon': 0.25,
  'kiwi': 0.18,
  'tomato': 0.30,
  'cucumber': 0.55,
  'avocado': 0.44,
  'potato': 0.25,
  'grapes(cup)': 0.33 // 1 cup grapes ~ 150g
};

function normName(n){
  const k = String(n||'').trim().toLowerCase();
  return NAME_ALIASES.get(k) || k;
}

function push(map, name, unit, qty){
  const key = name+'__'+(unit||'');
  const prev = map.get(key) || { name, unit, qty:0 };
  prev.qty += qty;
  map.set(key, prev);
}

function aggregate(plan){
  const m = new Map();
  const cookedToRawMultiplier = 4/3; // 0.75 cooked yield

  for(const d of plan.days){
    for(const ev of d.events||[]){
      for(const it of ev.items||[]){
        let name = normName(it.ingredient);
        let unit = (it.unit||'').toLowerCase();
        let qty = Number(it.quantity||0);

        // Dairy conversions
        if(name.includes('greek yogurt')){ // cups -> oz
          if(unit==='cup'||unit==='cups'){ push(m, name, 'oz', qty*OZ_PER_CUP_YOGURT); continue; }
        }
        if(name.includes('cottage cheese')){
          if(unit==='cup'||unit==='cups'){ push(m, name, 'oz', qty*OZ_PER_CUP_COTTAGE); continue; }
        }
        if(name.includes('milk')){ // cups -> quarts
          if(unit==='cup'||unit==='cups'){ push(m, name, 'qt', qty/CUP_PER_QUART); continue; }
        }
        if(name.includes('mozzarella')){ /* keep oz as-is */ }
        if(name==='hummus'){ // tbsp -> oz (2 tbsp = 1 oz)
          if(unit==='tbsp'){ push(m, name, 'oz', qty/TBSP_PER_OZ); continue; }
        }
        if(name==='peanut butter'){
          if(unit==='tbsp'){ push(m, name, 'oz', qty/TBSP_PER_OZ); continue; }
        }

        // Oats
        if(name==='rolled oats'){
          if(unit==='cup'||unit==='cups'){ push(m, name, 'oz', qty*OZ_PER_CUP_OATS); continue; }
          if(unit==='tbsp'){ push(m, name, 'oz', qty*OZ_PER_TBSP_OATS); continue; }
        }

        // Oils
        if(name==='olive oil'){
          if(unit==='tsp'){ push(m, name, 'fl oz', qty/TSP_PER_FL_OZ); continue; }
        }

        // Proteins cooked -> raw pounds
        if(/chicken breast|turkey|salmon|cod|lean turkey|chicken/i.test(name)){
          if(unit==='oz'){ push(m, name, 'lb (raw)', (qty*cookedToRawMultiplier)/16); continue; }
          if(unit==='piece'){ /* ignore; rarely used */ }
        }

        // Produce pieces -> lb
        if(unit==='piece'){
          const base = Object.keys(PRODUCE_LB).find(k=>name.includes(k));
          if(base){ push(m, name, 'lb', qty*PRODUCE_LB[base]); continue; }
        }
        if(unit==='cup' && name.includes('grapes')){
          push(m, name, 'lb', qty*PRODUCE_LB['grapes(cup)']); continue;
        }

        // Default: keep as given
        push(m, name, unit, qty);
      }
    }
  }

  // Merge like items with same unit already handled; now sort into categories
  const categories = [
    { name:'Dairy', test:n=>/yogurt|cottage|milk|mozzarella|cheese/i.test(n) },
    { name:'Proteins', test:n=>/chicken|turkey|tuna|salmon|cod|egg/i.test(n) },
    { name:'Produce', test:n=>/apple|banana|pear|grapes|tomato|cucumber|avocado|spinach|lettuce|potato|kiwi|peach|mango|lemon/i.test(n) },
    { name:'Frozen', test:n=>/mixed vegetables, frozen/i.test(n) },
    { name:'Pantry', test:n=>true }
  ];
  const doc = { generated_at: new Date().toISOString(), categories: categories.map(c=>({name:c.name,items:[]})) };
  for(const v of m.values()){
    const cat = doc.categories.find(c=>c.name!=='Pantry' && categories.find(b=>b.name===c.name).test(v.name)) || doc.categories.find(c=>c.name==='Pantry');
    const qty = Math.round(v.qty*100)/100;
    const unit = v.unit || '';
    cat.items.push({ name:v.name, qty, unit });
  }
  doc.categories.forEach(c=> c.items.sort((a,b)=> a.name.localeCompare(b.name)) );
  return doc;
}

function main(){
  if(!fs.existsSync(POINTER)) throw new Error('index.json missing');
  const ix = readJSON(POINTER);
  if(!ix.plan_latest) throw new Error('index.json missing "plan_latest"');
  const planPath = ix.plan_latest;
  if(!fs.existsSync(planPath)) throw new Error('Plan not found at '+planPath);
  const plan = readJSON(planPath);
  const out = aggregate(plan);
  ensureDir(DEFAULT_OUT);
  fs.writeFileSync(DEFAULT_OUT, JSON.stringify(out, null, 2));
  console.log('Wrote shopping list to', DEFAULT_OUT);
}

main();
