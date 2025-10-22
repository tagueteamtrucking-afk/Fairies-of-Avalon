// scripts/carol/build-shopping.mjs
import fs from 'fs';

const POINTER_PATH = 'pages/apps/carol/index.json';
const OUT_SHOPPING = 'pages/apps/carol/plans/shopping-quantized.json';
const OUT_COVERAGE = 'pages/apps/carol/plans/coverage.json';
const DEFS_PATH = 'pages/apps/carol/recipes/defs.json';

function readJSON(p){ return JSON.parse(fs.readFileSync(p, 'utf8')); }
function ensureDir(p){ fs.mkdirSync(require('path').dirname(p), { recursive:true }); }
function slugify(s){ return String(s||'').toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,''); }
function nameOf(v){ if (!v) return null; if (typeof v==='string') return v; if (Array.isArray(v)) return v.map(nameOf).filter(Boolean).join(', '); if (typeof v==='object') return v.name||v.title||v.label||v.id||null; return String(v); }

function findDays(plan){
  if (Array.isArray(plan.schedule)) return plan.schedule;
  if (Array.isArray(plan.days)) return plan.days;
  if (Array.isArray(plan.menu)) return plan.menu;
  if (Array.isArray(plan.plan)) return plan.plan;
  for (const [k,v] of Object.entries(plan)){
    if (Array.isArray(v) && v.length>=7 && v.length<=21){
      const hasMeals = v.some(d => typeof d==='object' && (('breakfast'in d)||('lunch'in d)||('dinner'in d)||(d.meals)));
      if (hasMeals) return v;
    }
  }
  return [];
}

function collectNames(plan){
  const days = findDays(plan);
  const out = [];
  for (const d of days){
    const meals = d.meals || d;
    const B = nameOf(meals.breakfast || meals.b); if (B) out.push(B);
    const L = nameOf(meals.lunch     || meals.l); if (L) out.push(L);
    const D = nameOf(meals.dinner    || meals.d); if (D) out.push(D);
    const S = meals.snacks || meals.s || []; const SA = Array.isArray(S) ? S : [S];
    for (const s of SA){ const n = nameOf(s); if (n) out.push(n); }
  }
  return out;
}

function aggregate(items){
  const out = new Map();
  for (const it of items){
    const key = (it.item||'') + '|' + (it.unit||'');
    out.set(key, (out.get(key)||0) + Number(it.qty||0));
  }
  return Array.from(out.entries()).map(([k,qty])=>{
    const [item,unit] = k.split('|');
    return { item, qty: Math.round(qty*100)/100, unit };
  }).sort((a,b)=> a.item.localeCompare(b.item));
}

(function main(){
  const pointer = readJSON(POINTER_PATH);
  const planPath = pointer.plan;
  const plan = readJSON(planPath);
  const people = Number(process.env.PEOPLE || plan?.meta?.people || 2);

  const names = collectNames(plan).map(r => ({ raw:r, key: slugify(r) }));

  const items = [];
  const missing = [];

  // Prefer embedded plan.recipes if present
  const embedded = plan.recipes || plan.recipeBook || null;
  if (embedded){
    for (const {raw,key} of names){
      const r = embedded[raw] || embedded[key];
      if (!r){ missing.push({ recipe: raw, reason: 'not found in plan.recipes' }); continue; }
      for (const ing of r){
        items.push({
          item: ing.item || ing.name,
          unit: ing.unit || 'g',
          qty: Number(ing.qty || 0) * (people / (plan.meta?.people || 2))
        });
      }
    }
  } else {
    // Use defs.json mapping only for exact known patterns (no guessing)
    let defs = null;
    try{ defs = readJSON(DEFS_PATH); }catch{ defs = null; }
    const perServ = Number(defs?.per_servings || 2);
    const scale = people / perServ;
    const recipes = defs?.recipes || {};
    const aliases = defs?.aliases || {};
    for (const {raw,key} of names){
      const mapKey = aliases[key] || key;
      const r = recipes[mapKey];
      if (!r){ missing.push({ recipe: raw, key, reason: 'no mapping in defs.json' }); continue; }
      for (const ing of r){
        items.push({ item: ing.item, unit: ing.unit, qty: Number(ing.qty) * scale });
      }
    }
  }

  const shopping = {
    meta: { people, generated_at: new Date().toISOString(), plan: planPath },
    items: aggregate(items)
  };
  const coverage = {
    total_recipes: names.length,
    matched: names.length - missing.length,
    missing,
    note: missing.length ? "Add missing recipes at pages/apps/carol/recipes/defs.json" : "All recipes covered."
  };

  ensureDir(OUT_SHOPPING);
  fs.writeFileSync(OUT_SHOPPING, JSON.stringify(shopping, null, 2));
  ensureDir(OUT_COVERAGE);
  fs.writeFileSync(OUT_COVERAGE, JSON.stringify(coverage, null, 2));
  console.log('Shopping built for', people, 'people. Missing:', missing.length);
})();
