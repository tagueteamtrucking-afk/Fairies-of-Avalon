import { promises as fs } from 'node:fs';
import path from 'node:path';

function norm(s){ return String(s||'').trim().toLowerCase(); }

const POINTER = 'pages/apps/carol/index.json';
const OUT     = 'pages/apps/carol/plans/shopping-2p.json';

function toKey(ingredient){
  let k = norm(ingredient);
  k = k.replace(/\s*\((?:no sodium|no cumin|low-?sodium|canned in juice|drained|frozen|soft|peeled|rinsed|boxed|microwave.*|single burner).*?\)/g,'');
  k = k.replace(/\s+/g,' ').trim();
  return k;
}

function toStdUnit(u){
  const m = norm(u);
  if (['tbsp','tablespoon','tablespoons'].includes(m)) return 'tbsp';
  if (['tsp','teaspoon','teaspoons'].includes(m)) return 'tsp';
  if (['cup','cups'].includes(m)) return 'cup';
  if (['ounce','ounces','oz'].includes(m)) return 'oz';
  if (['pound','pounds','lb','lbs'].includes(m)) return 'lb';
  if (['piece','pieces'].includes(m)) return 'piece';
  if (['spray','sprays'].includes(m)) return 'spray';
  return m || 'unit';
}

function asNumber(n){ const x = Number(n); return Number.isFinite(x)? x : 0; }

function add(map, name, qty, unit){
  const key = toKey(name);
  const u   = toStdUnit(unit);
  const k2  = key + '||' + u;
  map[k2] = (map[k2]||0) + asNumber(qty);
}

function collapse(map){
  const out = [];
  for(const k in map){
    const [name, unit] = k.split('||');
    let qty = map[k];
    // simple oz→lb collapse for > 16oz
    if (unit === 'oz' && qty >= 16){
      const addlb = Math.floor(qty/16);
      const rem   = +(qty % 16).toFixed(2);
      if (addlb>0) out.push({ item: name, qty: addlb, unit: 'lb' });
      if (rem>0) out.push({ item: name, qty: rem, unit: 'oz' });
      continue;
    }
    // tbsp→cup
    if (unit === 'tbsp' && qty >= 16){
      const addcup = Math.floor(qty/16);
      const rem    = +(qty % 16).toFixed(2);
      if (addcup>0) out.push({ item: name, qty: addcup, unit: 'cup' });
      if (rem>0) out.push({ item: name, qty: rem, unit: 'tbsp' });
      continue;
    }
    // tsp→tbsp
    if (unit === 'tsp' && qty >= 3){
      const addtb = Math.floor(qty/3);
      const rem   = +(qty % 3).toFixed(2);
      if (addtb>0) out.push({ item: name, qty: addtb, unit: 'tbsp' });
      if (rem>0) out.push({ item: name, qty: rem, unit: 'tsp' });
      continue;
    }
    out.push({ item: name, qty: +qty.toFixed(2), unit });
  }
  // merge identical again
  const final = {};
  for(const row of out){
    const k = row.item + '||' + row.unit;
    final[k] = (final[k]||0) + row.qty;
  }
  return Object.entries(final).map(([k,q])=>{
    const [item, unit] = k.split('||');
    return { item, qty: +q.toFixed(2), unit };
  }).sort((a,b)=> a.item.localeCompare(b.item));
}

async function main(){
  if (!await fs.stat(POINTER).catch(()=>null)) throw new Error('index.json missing');
  const idx = JSON.parse(await fs.readFile(POINTER,'utf8'));
  const rel = idx.plan_latest;
  if (!rel) throw new Error('index.json missing "plan_latest"');
  if (!await fs.stat(rel).catch(()=>null)) throw new Error('plan file not found: '+rel);
  const plan = JSON.parse(await fs.readFile(rel,'utf8'));
  const map = {};
  for(const d of plan.days||[]){
    for(const e of d.events||[]){
      for(const it of e.items||[]){
        add(map, it.ingredient, it.quantity, it.unit);
      }
    }
  }
  const items = collapse(map);
  await fs.mkdir(path.dirname(OUT), { recursive:true });
  await fs.writeFile(OUT, JSON.stringify({ generated_at:new Date().toISOString(), items }, null, 2));
  console.log('Wrote', OUT, items.length, 'rows');
}

main().catch(e=>{ console.error(e); process.exit(1); });
