// scripts/carol/build-shopping.mjs
// Generates shopping-quantized.json for the plan pointed by pages/apps/carol/index.json
// Strategy: if plan contains full ingredients, use them; otherwise use defs.json mapping per 2 servings.
// Missing recipes will be listed in pages/apps/carol/plans/coverage.json

import fs from 'fs';
import path from 'path';

const POINTER_PATH = 'pages/apps/carol/index.json';
const DEFAULT_PLAN = '/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json';
const OUT_SHOPPING = 'pages/apps/carol/plans/shopping-quantized.json';
const OUT_COVERAGE = 'pages/apps/carol/plans/coverage.json';
const DEFS_PATH = 'pages/apps/carol/recipes/defs.json';

function readJSON(p){
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}
function ensureDir(p){ fs.mkdirSync(path.dirname(p), { recursive:true }); }
function slugify(s){
  return s.toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,'');
}

function collectFromPlan(plan){
  const names = [];
  const sched = plan.schedule || [];
  for (const d of sched){
    if (d.breakfast) names.push(d.breakfast);
    if (d.lunch) names.push(d.lunch);
    if (d.dinner) names.push(d.dinner);
    if (Array.isArray(d.snacks)) names.push(...d.snacks);
  }
  return names;
}

function aggregate(items){
  const out = {};
  for (const it of items){
    const key = it.item + '|' + it.unit;
    out[key] = (out[key] || 0) + Number(it.qty || 0);
  }
  return Object.entries(out).map(([k,qty])=>{
    const [item,unit] = k.split('|');
    return { item, qty: Math.round(qty*100)/100, unit };
  }).sort((a,b)=> a.item.localeCompare(b.item));
}

(function main(){
  const pointer = fs.existsSync(POINTER_PATH) ? readJSON(POINTER_PATH) : { plan: DEFAULT_PLAN };
  const planPath = pointer.plan || DEFAULT_PLAN;
  const plan = readJSON(planPath);
  const people = Number(process.env.PEOPLE || plan?.meta?.people || 2);

  const names = collectFromPlan(plan);
  const normalized = names.map(n => ({ raw: n, key: slugify(n) }));

  let items = [];
  const missing = [];

  // Case A: plan.recipes contains ingredients
  const recipesInPlan = plan.recipes || plan.RECIPES || null;
  if (recipesInPlan){
    for (const {raw, key} of normalized){
      const r = recipesInPlan[raw] || recipesInPlan[key] || null;
      if (!r){ missing.push({ recipe: raw, reason: 'not found in plan.recipes' }); continue; }
      for (const ing of r){
        const unit = ing.unit || ing.u || 'g';
        const qty = Number(ing.qty || ing.q || 0) * (people / (plan.meta?.people || 2));
        items.push({ item: ing.item || ing.name, unit, qty });
      }
    }
  } else {
    // Case B: use defs.json (per_servings=2)
    let defs = null;
    try{ defs = readJSON(DEFS_PATH); }catch{ defs = null; }
    const perServ = Number(defs?.per_servings || 2);
    const scale = people / perServ;

    const recipes = defs?.recipes || {};
    const aliases = defs?.aliases || {};

    for (const {raw, key} of normalized){
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
    total_recipes: normalized.length,
    matched: normalized.length - missing.length,
    missing,
    note: missing.length ? "Add missing recipes at pages/apps/carol/recipes/defs.json" : "All recipes covered."
  };

  ensureDir(OUT_SHOPPING);
  fs.writeFileSync(OUT_SHOPPING, JSON.stringify(shopping, null, 2));
  ensureDir(OUT_COVERAGE);
  fs.writeFileSync(OUT_COVERAGE, JSON.stringify(coverage, null, 2));
  console.log('Shopping built for', people, 'people. Missing:', missing.length);
})();