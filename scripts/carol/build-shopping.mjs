// scripts/carol/build-shopping.mjs (ESM)
import fs from 'fs';
import path from 'path';

const ROOT = process.env.GITHUB_WORKSPACE || process.cwd();
const POINTER = path.join(ROOT, 'pages/apps/carol/index.json');
const OUT = path.join(ROOT, 'pages/apps/carol/plans/shopping-2p.json');

function readJSON(p){
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function normalizeUnit(u){
  if(!u) return '';
  u = u.toLowerCase().trim();
  if(u==='pieces') u='piece';
  if(u==='slices') u='slice';
  if(u==='teaspoons') u='tsp';
  if(u==='tablespoons') u='tbsp';
  if(u==='cups') u='cup';
  if(u==='ounces') u='oz';
  if(u==='cans') u='can';
  return u;
}

function aliasName(raw){
  const key = String(raw||'').trim().toLowerCase();
  const map = new Map([
    ['lactose-free greek yogurt','Yogurt, lactose-free (Greek)'],
    ['lactose-free cottage cheese','Cottage cheese, lactose-free'],
    ['lactose-free mozzarella','Mozzarella, lactose-free'],
    ['lactose-free cheese stick','Mozzarella, lactose-free'],
    ['lf cream cheese','Cream cheese, lactose-free'],
    ['hummus (no cumin)','Hummus (no cumin)'],
    ['frozen mixed vegetables','Mixed vegetables, frozen'],
    ['mixed vegetables (frozen)','Mixed vegetables, frozen'],
    ['frozen veg medley','Mixed vegetables, frozen'],
    ['mango (frozen)','Mango, frozen'],
    ['frozen mixed berries','Mixed berries, frozen'],
    ['frozen berries','Mixed berries, frozen'],
    ['soft whole-wheat tortilla','Tortillas, whole-wheat (soft)'],
    ['soft whole-grain bread','Bread, whole-grain (soft)'],
    ['butter lettuce','Lettuce, butter'],
    ['canned tuna (in water)','Tuna (canned, in water)'],
    ['canned chicken','Chicken (canned)'],
    ['brown rice (microwave pouch)','Brown rice (pouch)'],
    ['low-sodium black beans (rinsed)','Black beans, low-sodium (canned)'],
    ['low-sodium beans (canned)','Beans, low-sodium (canned)'],
    ['diced tomatoes (no salt added)','Tomatoes, diced (no-salt)'],
    ['pineapple (canned in juice, drained)','Pineapple (canned, drained)'],
    ['lactose-free milk','Milk, lactose-free'],
    ['olive oil spray','Olive oil spray'],
  ]);
  return map.get(key) || (raw? (raw[0].toUpperCase()+raw.slice(1)) : '');
}

function peopleMultiplier(forField){
  if(!forField) return 1;
  const f = String(forField).toLowerCase();
  if(f==='both') return 2;
  if(f.includes('ray') || f==='a') return 1;
  if(f.includes('blanca') || f==='b') return 1;
  return 1;
}

function aggregate(plan){
  const totals = new Map(); // key: aisle::name::unit
  const aisleOf = (name)=>{
    const aisles = new Map([
      ['Produce',['Banana','Apple','Pear','Kiwi','Grapes','Tomato','Cucumber','Spinach','Lettuce, butter','Lemon','Baby potatoes']],
      ['Frozen',['Mixed vegetables, frozen','Mixed berries, frozen','Mango, frozen']],
      ['Dairy',['Milk, lactose-free','Yogurt, lactose-free (Greek)','Cottage cheese, lactose-free','Mozzarella, lactose-free','Cream cheese, lactose-free','Egg']],
      ['Meat/Seafood',['Chicken breast','Lean turkey','Cod fillet','Salmon fillet']],
      ['Pantry',['Rolled oats','Peanut butter','Ground flaxseed','Hummus (no cumin)','Olive oil','Garlic powder','Panko (light)','Low-sugar granola','Vanilla extract','Cinnamon','Unsweetened cocoa','Lime juice','Lemon juice','Rice cakes','Brown rice (pouch)']],
      ['Bakery',['Tortillas, whole-wheat (soft)','Bread, whole-grain (soft)']],
      ['Canned',['Low-sodium tomato soup','Beans, low-sodium (canned)','Black beans, low-sodium (canned)','Tomatoes, diced (no-salt)','Pineapple (canned, drained)','Chicken (canned)','Tuna (canned, in water)']],
      ['Other',[]]
    ]);
    for(const [aisle, list] of aisles.entries()) if(list.includes(name)) return aisle;
    return 'Other';
  };
  const cnv = {
    // These match the browser script logic; here we only produce "base" totals without fancy hints.
    toOz: (q,u,m)=> q * (m[u] ?? (u==='oz'?1:0)),
    toFloz: (q,u,m)=> q * (m[u] ?? (u==='fl oz'?1:0)),
    toQt: (q,u)=> u==='cup' ? q/4 : u==='qt' ? q : u==='oz' ? q/32 : 0,
    piece: (u, m)=> (m[u] ?? 0),
    cup: (u, m)=> (m[u] ?? 0),
    ozToLb: (u)=> (u==='oz'? 1/16 : 0),
  };
  const add = (aisle,name,unit,amount)=>{
    if(!amount || !isFinite(amount)) return;
    const k = `${aisle}::${name}::${unit}`;
    totals.set(k, (totals.get(k)||0) + amount);
  };

  const conv = {
    'Banana': (q,u)=> add('Produce','Banana','lb (est)', q * cnv.piece(u,{piece:0.25})),
    'Apple':  (q,u)=> add('Produce','Apple','lb (est)',  q * cnv.piece(u,{piece:0.33})),
    'Pear':   (q,u)=> add('Produce','Pear','lb (est)',   q * cnv.piece(u,{piece:0.33})),
    'Kiwi':   (q,u)=> add('Produce','Kiwi','lb (est)',   q * cnv.piece(u,{piece:0.18})),
    'Grapes': (q,u)=> add('Produce','Grapes','lb (est)', q * cnv.cup(u,{cup:0.33})),
    'Tomato': (q,u)=> add('Produce','Tomato','lb (est)', q * (u==='cup' ? 0.5 : cnv.piece(u,{piece:0.25}))),
    'Cucumber': (q,u)=> add('Produce','Cucumber','lb (est)', q * (u==='cup' ? 0.25 : cnv.piece(u,{piece:0.45}))),
    'Spinach': (q,u)=> add('Produce','Spinach','lb (est)', q * cnv.cup(u,{cup:0.07})),
    'Lettuce, butter': (q,u)=> add('Produce','Lettuce, butter','lb (est)', q * cnv.piece(u,{leaf:0.02, piece:0.3})),
    'Lemon': (q,u)=> add('Produce','Lemon','lb (est)', q * cnv.piece(u,{piece:0.26})),
    'Baby potatoes': (q,u)=> add('Produce','Baby potatoes','lb (est)', q * cnv.piece(u,{piece:0.10})),

    'Mixed vegetables, frozen': (q,u)=> add('Frozen','Mixed vegetables, frozen','lb', q * (u==='cup'?0.3125: cnv.ozToLb(u))),
    'Mixed berries, frozen': (q,u)=> add('Frozen','Mixed berries, frozen','lb', q * (u==='cup'?0.31: cnv.ozToLb(u))),
    'Mango, frozen': (q,u)=> add('Frozen','Mango, frozen','lb', q * (u==='cup'?0.36: cnv.ozToLb(u))),

    'Milk, lactose-free': (q,u)=> add('Dairy','Milk, lactose-free','qt', cnv.toQt(q,u)),
    'Yogurt, lactose-free (Greek)': (q,u)=> add('Dairy','Yogurt, lactose-free (Greek)','oz', cnv.toOz(q,u,{cup:8})),
    'Cottage cheese, lactose-free': (q,u)=> add('Dairy','Cottage cheese, lactose-free','oz', cnv.toOz(q,u,{cup:8})),
    'Mozzarella, lactose-free': (q,u)=> add('Dairy','Mozzarella, lactose-free','oz', cnv.toOz(q,u,{oz:1, piece:1})),
    'Cream cheese, lactose-free': (q,u)=> add('Dairy','Cream cheese, lactose-free','oz', cnv.toOz(q,u,{tbsp:0.5})),

    'Chicken breast': (q,u)=> add('Meat/Seafood','Chicken breast','lb', u==='oz'? q/16 : q),
    'Lean turkey': (q,u)=> add('Meat/Seafood','Lean turkey','lb', u==='oz'? q/16 : q),
    'Cod fillet': (q,u)=> add('Meat/Seafood','Cod fillet','lb', u==='oz'? q/16 : q),
    'Salmon fillet': (q,u)=> add('Meat/Seafood','Salmon fillet','lb', u==='oz'? q/16 : q),
    'Egg': (q,u)=> add('Dairy','Egg','pcs', q * (u==='piece'?1:0)),

    'Rolled oats': (q,u)=> add('Pantry','Rolled oats','oz', cnv.toOz(q,u,{cup:2.86, tbsp:0.17875})),
    'Peanut butter': (q,u)=> add('Pantry','Peanut butter','oz', cnv.toOz(q,u,{tbsp:0.5})),
    'Ground flaxseed': (q,u)=> add('Pantry','Ground flaxseed','oz', cnv.toOz(q,u,{tbsp:0.3})),
    'Hummus (no cumin)': (q,u)=> add('Deli','Hummus (no cumin)','oz', cnv.toOz(q,u,{tbsp:0.5})),
    'Olive oil': (q,u)=> add('Pantry','Olive oil','fl oz', cnv.toFloz(q,u,{tsp:(1/6), tbsp:0.5})),
    'Garlic powder': (q,u)=> add('Pantry','Garlic powder','tsp', q * (u==='tsp'?1:0)),
    'Panko (light)': (q,u)=> add('Pantry','Panko (light)','oz', cnv.toOz(q,u,{cup:1.7})),
    'Low-sugar granola': (q,u)=> add('Pantry','Low-sugar granola','oz', cnv.toOz(q,u,{cup:3.5})),
    'Vanilla extract': (q,u)=> add('Pantry','Vanilla extract','tsp', q * (u==='tsp'?1:0)),
    'Cinnamon': (q,u)=> add('Pantry','Cinnamon','tsp', q * (u==='tsp'?1:0)),
    'Unsweetened cocoa': (q,u)=> add('Pantry','Unsweetened cocoa','tsp', q * (u==='tsp'?1:0)),
    'Lime juice': (q,u)=> add('Pantry','Lime juice','tsp', q * (u==='tsp'?1:0)),
    'Lemon juice': (q,u)=> add('Pantry','Lemon juice','tsp', q * (u==='tsp'?1:0)),

    'Tortillas, whole-wheat (soft)': (q,u)=> add('Bakery','Tortillas, whole-wheat (soft)','pcs', q * (u==='piece'?1:0)),
    'Bread, whole-grain (soft)': (q,u)=> add('Bakery','Bread, whole-grain (soft)','slices', q * (u==='slice'?1:0)),
    'Rice cakes': (q,u)=> add('Pantry','Rice cakes','pcs', q * (u==='piece'?1:0)),
    'Brown rice (pouch)': (q,u)=> add('Pantry','Brown rice (pouch)','pouch', q * (u==='cup'?1: (u==='pouch'?1:0))),

    'Low-sodium tomato soup': (q,u)=> add('Canned','Low-sodium tomato soup','cans', q * (u==='cup'? (1/1.25) : (u==='can'?1:0))),
    'Beans, low-sodium (canned)': (q,u)=> add('Canned','Beans, low-sodium (canned)','cans', q * (u==='cup'? (1/1.5) : (u==='can'?1:0))),
    'Black beans, low-sodium (canned)': (q,u)=> add('Canned','Black beans, low-sodium (canned)','cans', q * (u==='cup'? (1/1.5) : (u==='can'?1:0))),
    'Tomatoes, diced (no-salt)': (q,u)=> add('Canned','Tomatoes, diced (no-salt)','cups', q * (u==='cup'?1:0)),
    'Pineapple (canned, drained)': (q,u)=> add('Canned','Pineapple (canned, drained)','oz', q * (u==='cup'?5.8: (u==='oz'?1:0))),
  };

  for(const day of (plan.days||[])){
    for(const ev of (day.events||[])){
      const mult = peopleMultiplier(ev.for);
      for(const it of (ev.items||[])){
        const name = aliasName(it.ingredient);
        const u = normalizeUnit(it.unit);
        const qty = Number(it.quantity||0) * mult;
        const fn = conv[name];
        if(fn) fn(qty, u);
      }
    }
  }
  // produce output structure
  const out = {};
  for(const [k,val] of totals.entries()){
    const [aisle,name,unit] = k.split('::');
    out[aisle] ||= {};
    out[aisle][name] ||= { unit, total: 0 };
    out[aisle][name].total += Math.round(val*100)/100;
  }
  return out;
}

function safeJoin(...parts){
  const p = path.join(...parts).replace(/\\/g,'/');
  if(p.startsWith('/')) return p.slice(1); // avoid leading slash for GH Pages
  return p;
}

function main(){
  const pointer = readJSON(POINTER);
  const rel = pointer.plan_latest;
  if(!rel) throw new Error('index.json missing "plan_latest"');
  const planPath = safeJoin('pages/apps/carol', rel);
  const plan = readJSON(path.join(ROOT, planPath));

  const out = aggregate(plan);
  fs.mkdirSync(path.dirname(OUT), { recursive:true });
  fs.writeFileSync(OUT, JSON.stringify({ generated_at: new Date().toISOString(), source_plan: rel, for_persons: 2, totals: out }, null, 2));
  console.log('Built', path.relative(ROOT, OUT));
}

main();
