import fs from 'fs';
import path from 'path';

const PTR_PATH = 'pages/apps/carol/index.json';
function readJSON(p){ return JSON.parse(fs.readFileSync(p,'utf8')); }

const NORMALIZE = new Map([
  ['frozen mixed vegetables','mixed vegetables, frozen'],
  ['mixed vegetables (frozen)','mixed vegetables, frozen'],
  ['lactose-free mozzarella','mozzarella, lactose-free'],
  ['lactose-free cheese stick','mozzarella, lactose-free'],
  ['lf cream cheese','cream cheese, lactose-free'],
  ['lf greek yogurt','greek yogurt, lactose-free'],
  ['lactose-free greek yogurt','greek yogurt, lactose-free'],
  ['lactose-free milk','milk, lactose-free'],
  ['hummus (no cumin)','hummus'],
  ['olive oil spray','olive oil'],
]);

const TBSP_PER_FL_OZ = 2;
const TSP_PER_TBSP = 3;
const TSP_PER_FL_OZ = TBSP_PER_FL_OZ * TSP_PER_TBSP;
const CUP_OATS_OZ = 3.5;
const CUP_RICE_COOKED_OZ = 5.0;
const CUP_FRUIT_OZ = 5.0;
const SLICE_BREAD_OZ = 1.0;
const PIECE_FRUIT_LB = { apple:0.33, banana:0.25, pear:0.33, kiwi:0.2, lemon:0.2, tomato:0.33 };
const PIECE_MISC_LB = { 'baby potatoes':0.1 };
function normName(n){ n=String(n||'').trim().toLowerCase(); return NORMALIZE.get(n)||n; }
function add(map,key,val){ map.set(key,(map.get(key)||0)+val); }
function toShopping(ing, qty, unit){
  const k = normName(ing);
  if(unit==='tbsp') return [k, qty / TBSP_PER_FL_OZ, 'fl oz'];
  if(unit==='tsp')  return [k, qty / TSP_PER_FL_OZ, 'fl oz'];
  if(unit==='cup'){
    if(/oats/.test(k)) return [k, qty * CUP_OATS_OZ, 'oz'];
    if(/rice/.test(k)) return [k, qty * CUP_RICE_COOKED_OZ, 'oz'];
    if(/berries|pineapple|mango|fruit|grapes|peach|peaches/.test(k)) return [k, qty * CUP_FRUIT_OZ, 'oz'];
    if(/yogurt|cottage/.test(k)) return [k, qty * 8, 'oz'];
    if(/vegetables/.test(k)) return [k, qty * 5, 'oz'];
    return [k, qty * 8, 'fl oz'];
  }
  if(unit==='slice' && /bread/.test(k)) return [k, qty * SLICE_BREAD_OZ, 'oz'];
  if(unit==='leaf') return [k, qty, 'ea'];
  if(unit==='spray') return [k, qty/10, 'fl oz'];
  if(unit==='oz') return [k, qty, 'oz'];
  if(unit==='can') return [k, qty*15, 'oz'];
  if(unit==='piece'){
    const base = ing.toLowerCase();
    if(PIECE_FRUIT_LB[base]) return [k, qty*PIECE_FRUIT_LB[base], 'lb'];
    if(PIECE_FRUIT_LB[k]) return [k, qty*PIECE_FRUIT_LB[k], 'lb'];
    if(PIECE_MISC_LB[base]) return [k, qty*PIECE_MISC_LB[base], 'lb'];
    return [k, qty, 'ea'];
  }
  if(unit==='egg' || (unit==='piece' && /egg/.test(k))) return ['eggs', qty, 'ea'];
  return [k, qty, unit];
}

function buildFromPlan(plan){
  const map = new Map();
  const persons = (plan.persons && plan.persons.length) ? plan.persons.length : 2;
  for(const d of plan.days){
    for(const ev of d.events||[]){
      const mult = (String(ev.for||'Both').toLowerCase()==='both') ? persons : 1;
      for(const it of ev.items||[]){
        const [name,val,u] = toShopping(it.ingredient, it.quantity*mult, it.unit);
        const key = name+'__'+u;
        add(map, key, val);
      }
    }
  }
  const items = [];
  for(const [key,val] of map){
    const [name,u] = key.split('__');
    const qty = Math.round(val*100)/100;
    items.push({name, qty, unit:u});
  }
  const groups = {};
  for(const it of items){
    let g = 'pantry';
    if(/(apple|banana|pear|grapes|kiwi|mango|tomato|cucumber|lemon|potatoes?)/.test(it.name)) g='produce';
    if(/(salmon|cod|chicken|turkey|tuna)/.test(it.name)) g='protein';
    if(/(yogurt|cottage|mozzarella|milk|cream cheese|cheese)/.test(it.name)) g='dairy';
    if(/(oats|rice|tortilla|bread|panko)/.test(it.name)) g='grains';
    if(/(vegetables)/.test(it.name)) g='frozen';
    (groups[g]=groups[g]||[]).push(it);
  }
  return { generated_at:new Date().toISOString(), persons, groups };
}

function main(){
  const ptr = readJSON(PTR_PATH);
  const rel = (ptr.plan_latest||'').trim();
  if(!rel) throw new Error('index.json missing "plan_latest"');
  const planPath = 'pages/apps/carol/plans/'+rel.split('/').pop();
  const plan = readJSON(planPath);
  const out = buildFromPlan(plan);
  const outPath = 'pages/apps/carol/plans/shopping-2p.json';
  fs.mkdirSync(path.dirname(outPath), {recursive:true});
  fs.writeFileSync(outPath, JSON.stringify(out,null,2));
  console.log('Wrote', outPath);
}
main();
