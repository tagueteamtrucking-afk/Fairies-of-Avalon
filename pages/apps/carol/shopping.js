/* pages/apps/carol/shopping.js
   Client-side aggregator: reads pages/apps/carol/index.json → plan_latest (relative or absolute),
   fetches the plan JSON, multiplies items for 2 persons, normalizes names, converts to shopping units,
   and renders grouped table. No top-level await; Safari-friendly.
*/
(function(){
  const Q = (sel, ctx=document)=>ctx.querySelector(sel);
  const QA = (sel, ctx=document)=>Array.from(ctx.querySelectorAll(sel));

  const state = {
    pointerPath: './index.json', // relative to .../pages/apps/carol/
    planPath: null,
    plan: null,
    totals: new Map(), // key -> { aisle, name, unit, total, notes }
  };

  // ---- helpers ----
  function resolvePath(base, child){
    if(!child) return null;
    if(/^https?:\/\//.test(child)) return child;
    if(child.startsWith('/')) return child; // absolute from site root
    // strip filename from base and join
    const baseDir = base.replace(/[^\/]+$/, '');
    const norm = (baseDir + child).replace(/\/+/g,'/').replace(/\/(?:\.\/)+/g,'/');
    return norm;
  }

  const ALIASES = new Map([
    ['lactose-free greek yogurt','Yogurt, lactose-free (Greek)'],
    ['lactose-free cottage cheese','Cottage cheese, lactose-free'],
    ['lactose-free mozzarella','Mozzarella, lactose-free'],
    ['lactose-free cheese stick','Mozzarella, lactose-free'],
    ['lf cheese stick','Mozzarella, lactose-free'],
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

  const AISLE = new Map([
    // produce & frozen produce
    ['Banana','Produce'], ['Apple','Produce'], ['Pear','Produce'], ['Kiwi','Produce'],
    ['Grapes','Produce'], ['Tomato','Produce'], ['Cucumber','Produce'], ['Spinach','Produce'],
    ['Lettuce, butter','Produce'], ['Lemon','Produce'], ['Baby potatoes','Produce'],
    ['Mixed vegetables, frozen','Frozen'], ['Mixed berries, frozen','Frozen'], ['Mango, frozen','Frozen'],
    // dairy
    ['Milk, lactose-free','Dairy'], ['Yogurt, lactose-free (Greek)','Dairy'], ['Cottage cheese, lactose-free','Dairy'],
    ['Mozzarella, lactose-free','Dairy'], ['Cream cheese, lactose-free','Dairy'],
    // proteins & seafood
    ['Chicken breast','Meat/Seafood'], ['Chicken (canned)','Canned'], ['Tuna (canned, in water)','Canned'],
    ['Lean turkey','Meat/Seafood'], ['Cod fillet','Meat/Seafood'], ['Salmon fillet','Meat/Seafood'],
    ['Egg','Dairy'],
    // pantry
    ['Rolled oats','Pantry'], ['Peanut butter','Pantry'], ['Ground flaxseed','Pantry'],
    ['Hummus (no cumin)','Deli'], ['Olive oil','Pantry'], ['Garlic powder','Pantry'],
    ['Panko (light)','Pantry'], ['Low-sugar granola','Pantry'], ['Vanilla extract','Pantry'],
    ['Cinnamon','Pantry'], ['Unsweetened cocoa','Pantry'], ['Lime juice','Pantry'], ['Lemon juice','Pantry'],
    // breads & grains
    ['Tortillas, whole-wheat (soft)','Bakery'], ['Bread, whole-grain (soft)','Bakery'], ['Rice cakes','Pantry'],
    ['Brown rice (pouch)','Pantry'],
    // canned & soups
    ['Low-sodium tomato soup','Canned'], ['Beans, low-sodium (canned)','Canned'],
    ['Black beans, low-sodium (canned)','Canned'],
    ['Tomatoes, diced (no-salt)','Canned'],
    ['Pineapple (canned, drained)','Canned'],
  ]);

  // conversions: return {unit, amount} in shopping unit
  const CNV = {
    // Produce lb (est)
    'Banana':      (q,u)=>({unit:'lb (est)', amount: q * pieceTo( u, { piece:0.25 })}),
    'Apple':       (q,u)=>({unit:'lb (est)', amount: q * pieceTo( u, { piece:0.33 })}),
    'Pear':        (q,u)=>({unit:'lb (est)', amount: q * pieceTo( u, { piece:0.33 })}),
    'Kiwi':        (q,u)=>({unit:'lb (est)', amount: q * pieceTo( u, { piece:0.18 })}),
    'Grapes':      (q,u)=>({unit:'lb (est)', amount: q * cupTo(u, { cup:0.33 })}),
    'Tomato':      (q,u)=>({unit:'lb (est)', amount: q * ( u==='cup' ? 0.5 : pieceTo(u,{piece:0.25}) )}),
    'Cucumber':    (q,u)=>({unit:'lb (est)', amount: q * ( u==='cup' ? 0.25 : pieceTo(u,{piece:0.45}) )}),
    'Spinach':     (q,u)=>({unit:'lb (est)', amount: q * cupTo(u, { cup:0.07 })}),
    'Lettuce, butter': (q,u)=>({unit:'lb (est)', amount: q * pieceTo(u,{ leaf:0.02, piece:0.3 })}),
    'Lemon':       (q,u)=>({unit:'lb (est)', amount: q * pieceTo(u,{ piece:0.26 })}),
    'Baby potatoes':(q,u)=>({unit:'lb (est)', amount: q * pieceTo(u,{ piece:0.10 })}),

    // Frozen produce → lb
    'Mixed vegetables, frozen': (q,u)=>({unit:'lb', amount: q * ( u==='cup' ? 0.3125 : ozToLb(u) )}),
    'Mixed berries, frozen':    (q,u)=>({unit:'lb', amount: q * ( u==='cup' ? 0.31    : ozToLb(u) )}),
    'Mango, frozen':            (q,u)=>({unit:'lb', amount: q * ( u==='cup' ? 0.36    : ozToLb(u) )}),

    // Dairy
    'Milk, lactose-free':       (q,u)=>toQt(q,u),
    'Yogurt, lactose-free (Greek)': (q,u)=>toOz(q,u, { cup:8 }),
    'Cottage cheese, lactose-free': (q,u)=>toOz(q,u, { cup:8 }),
    'Mozzarella, lactose-free':     (q,u)=>toOz(q,u, { oz:1, piece:1 }), // cheese stick ~ 1 oz
    'Cream cheese, lactose-free':   (q,u)=>toOz(q,u, { tbsp:0.5 }),

    // Proteins & seafood
    'Chicken breast':           (q,u)=>toLbOrOz(q,u),
    'Lean turkey':              (q,u)=>toLbOrOz(q,u),
    'Cod fillet':               (q,u)=>toLbOrOz(q,u),
    'Salmon fillet':            (q,u)=>toLbOrOz(q,u),
    'Egg':                      (q,u)=>({unit:'pcs', amount: q * pieceTo(u,{ piece:1 })}),

    // Pantry
    'Rolled oats':              (q,u)=>toOz(q,u, { cup:2.86, tbsp:0.17875 }),
    'Peanut butter':            (q,u)=>toOz(q,u, { tbsp:0.5 }),
    'Ground flaxseed':          (q,u)=>toOz(q,u, { tbsp:0.3 }), // ~8.5g per tbsp → 0.3 oz
    'Hummus (no cumin)':        (q,u)=>toOz(q,u, { tbsp:0.5 }),
    'Olive oil':                (q,u)=>toFloz(q,u, { tsp:(1/6), tbsp:0.5 }),
    'Garlic powder':            (q,u)=>({unit:'tsp', amount: q * tspTo(u, { tsp:1 })}),
    'Panko (light)':            (q,u)=>toOz(q,u, { cup:1.7 }),
    'Low-sugar granola':        (q,u)=>toOz(q,u, { cup:3.5 }), // approx
    'Vanilla extract':          (q,u)=>toTsp(q,u),
    'Cinnamon':                 (q,u)=>toTsp(q,u),
    'Unsweetened cocoa':        (q,u)=>toTsp(q,u),
    'Lime juice':               (q,u)=>toTsp(q,u),
    'Lemon juice':              (q,u)=>toTsp(q,u),

    // Bread & grains
    'Tortillas, whole-wheat (soft)':(q,u)=>({unit:'pcs', amount: q * pieceTo(u,{ piece:1 })}),
    'Bread, whole-grain (soft)':    (q,u)=>({unit:'slices', amount: q * pieceTo(u,{ slice:1 })}), // approx 20 slices/loaf (see format)
    'Rice cakes':                    (q,u)=>({unit:'pcs', amount: q * pieceTo(u,{ piece:1 })}),
    'Brown rice (pouch)':            (q,u)=>({unit:'pouch', amount: q * ( u==='cup' ? 1 : pieceTo(u,{ pouch:1 }) )}),

    // Canned
    'Low-sodium tomato soup':       (q,u)=>({unit:'cans', amount: q * ( u==='cup' ? (1/1.25) : pieceTo(u,{ can:1 }) )}),
    'Beans, low-sodium (canned)':   (q,u)=>({unit:'cans', amount: q * ( u==='cup' ? (1/1.5)  : pieceTo(u,{ can:1 }) )}),
    'Black beans, low-sodium (canned)':(q,u)=>({unit:'cans', amount: q * ( u==='cup' ? (1/1.5)  : pieceTo(u,{ can:1 }) )}),
    'Tomatoes, diced (no-salt)':    (q,u)=>({unit:'cups', amount: q * cupTo(u,{ cup:1 })}), // leave as cups (choose can sizes later)
    'Pineapple (canned, drained)':  (q,u)=>toOz(q,u, { cup:5.8 }), // drained cup → oz
  };

  function ozToLb(u){ return (u==='oz'||u==='ounce'||u==='ounces') ? (1/16) : 0; }
  function toLbOrOz(q,u){
    if(u==='oz') return {unit:'lb', amount: q/16};
    if(u==='lb') return {unit:'lb', amount: q};
    if(u==='g')  return {unit:'lb', amount: q/453.592};
    if(u==='cup') return {unit:'lb', amount: (q*8)/16}; // cooked meat ~8 oz per cup (approx)
    return {unit:'oz', amount: q}; // fallback
  }
  function toOz(q,u, map){ const f = (map&&map[u])|| (u==='oz'?1:0); return {unit:'oz', amount: q * f}; }
  function toFloz(q,u, map){ const f = (map&&map[u])|| (u==='fl oz'?1:0); return {unit:'fl oz', amount: q * f}; }
  function toTsp(q,u){ return {unit:'tsp', amount: q * tspTo(u,{ tsp:1 })}; }
  function toQt(q,u){
    if(u==='cup') return {unit:'qt', amount: q/4};
    if(u==='qt')  return {unit:'qt', amount: q};
    if(u==='oz')  return {unit:'qt', amount: q/32};
    return {unit:'qt', amount: 0};
  }
  function pieceTo(u, map){ if(u in map) return map[u]; return 0; }
  function cupTo(u, map){ if(u in map) return map[u]; return 0; }
  function tspTo(u, map){ if(u in map) return map[u]; return 0; }

  function aliasName(raw){
    const key = String(raw||'').trim().toLowerCase();
    return ALIASES.get(key) || capitalize(raw||'');
  }
  function capitalize(s){ return s.replace(/^(.)/, (m)=>m.toUpperCase()); }

  function keyOf(aisle,name){
    return aisle + '::' + name;
  }

  function addTotal(aisle,name,unit,amount, note=''){
    if(!amount || !isFinite(amount)) return;
    const k = keyOf(aisle,name);
    if(!state.totals.has(k)){
      state.totals.set(k, { aisle, name, unit, total: 0, notes: new Set() });
    }
    const t = state.totals.get(k);
    t.total += amount;
    if(note) t.notes.add(note);
  }

  function roundSmart(num, unit){
    if(unit==='lb' || unit==='lb (est)' || unit==='qt') return Math.round(num*100)/100;
    if(unit==='oz' || unit==='fl oz') return Math.round(num*10)/10;
    if(unit==='tsp') return Math.round(num*10)/10;
    if(unit==='pcs' || unit==='slices' || unit==='pouch' || unit==='cans' || unit==='cups') return Math.ceil(num*100)/100;
    return Math.round(num*100)/100;
  }

  function formatWithHints(row){
    // special formatting hints
    if(row.name==='Bread, whole-grain (soft)' && row.unit==='slices'){
      const loaves = Math.ceil(row.total / 20);
      return `${row.total} slices (≈ ${loaves} loaf${loaves>1?'s':''})`;
    }
    if(row.name==='Milk, lactose-free' && row.unit==='qt'){
      const q = row.total;
      const gal = Math.floor(q/4);
      const rem = Math.round((q - gal*4)*100)/100;
      return (gal?`${gal} gal `:'') + (rem?`${rem} qt`:'') || '0';
    }
    if((row.name==='Mozzarella, lactose-free') && row.unit==='oz'){
      // if mostly sticks, add hint
      return `${row.total} oz (cheese sticks are ~1 oz each)`;
    }
    return `${row.total} ${row.unit}`;
  }

  async function loadJSON(path){
    const res = await fetch(path, { cache: 'no-store' });
    if(!res.ok) throw new Error(`HTTP ${res.status} for ${path}`);
    return res.json();
  }

  function normalizeUnit(u){
    if(!u) return '';
    u = u.toLowerCase().trim();
    if(u==='piece') return 'piece';
    if(u==='pieces') return 'piece';
    if(u==='leaf') return 'leaf';
    if(u==='slice' || u==='slices') return 'slice';
    if(u==='tsp' || u==='teaspoon' || u==='teaspoons') return 'tsp';
    if(u==='tbsp' || u==='tablespoon' || u==='tablespoons') return 'tbsp';
    if(u==='cup' || u==='cups') return 'cup';
    if(u==='oz' || u==='ounce' || u==='ounces') return 'oz';
    if(u==='fl oz' || u==='fluid ounce' || u==='fluid ounces') return 'fl oz';
    if(u==='can' || u==='cans') return 'can';
    if(u==='spray' || u==='sprays') return 'spray';
    if(u==='leaf' || u==='leaves') return 'leaf';
    if(u==='pouch' || u==='pouches') return 'pouch';
    return u;
  }

  function peopleMultiplier(forField){
    if(!forField) return 1;
    const f = String(forField).toLowerCase();
    if(f==='both') return 2; // multiply for shopping
    if(f.includes('ray') || f==='a') return 1;
    if(f.includes('blanca') || f==='b') return 1;
    return 1;
  }

  function computeTotals(plan){
    const errors = [];
    for(const day of (plan.days||[])){
      for(const ev of (day.events||[])){
        const mult = peopleMultiplier(ev.for);
        for(const it of (ev.items||[])){
          const name = aliasName(it.ingredient);
          const aisle = AISLE.get(name) || 'Other';
          const unitIn = normalizeUnit(it.unit);
          const qty = Number(it.quantity||0) * mult;
          try{
            const conv = CNV[name];
            if(conv){
              const out = conv(qty, unitIn);
              addTotal(aisle, name, out.unit, out.amount, ev.name);
            }else{
              // If we don't know how to convert, aggregate raw units conservatively by unit
              addTotal(aisle, name, unitIn||'', qty, ev.name);
            }
          }catch(e){
            errors.push(`${name}: ${e.message}`);
          }
        }
      }
    }
    return errors;
  }

  function render(){
    // table rows sorted by aisle then name
    const rows = Array.from(state.totals.values())
      .map(r=>({ ...r, total: roundSmart(r.total, r.unit), notes: Array.from(r.notes).slice(0,3).join('; ') }))
      .filter(r=>r.total>0)
      .sort((a,b)=> (a.aisle.localeCompare(b.aisle) || a.name.localeCompare(b.name)) );

    const tb = Q('#listBody');
    tb.innerHTML = '';
    for(const r of rows){
      const tr = document.createElement('tr');
      tr.innerHTML = `<td>${r.aisle}</td><td>${r.name}</td><td>${formatWithHints(r)}</td><td class="screen-only"><small class="dim">${r.notes}</small></td>`;
      tb.appendChild(tr);
    }
  }

  async function main(){
    try{
      // Locate pointer under current directory
      const here = location.pathname.replace(/[^\/]+$/, '');
      const pointerUrl = resolvePath(here, state.pointerPath);
      const pointer = await loadJSON(pointerUrl);
      const planPath = pointer && pointer.plan_latest;
      if(!planPath){
        Q('#error').classList.remove('hidden');
        Q('#error').innerHTML = `Pointer missing <code>plan_latest</code>. <a href="./index.json">Add File</a>`;
        return;
      }
      state.planPath = resolvePath(here, planPath);
      Q('#planPath').textContent = state.planPath;
      const plan = await loadJSON(state.planPath);
      state.plan = plan;
      if(Q('#pattern')) Q('#pattern').textContent = plan.pattern || '—';

      // compute
      const errs = computeTotals(plan);
      render();
      if(errs.length){
        const e = Q('#error'); e.classList.remove('hidden');
        e.innerHTML = 'Some items used conservative units (no conversion rule found). You can refine rules in <code>shopping.js</code>.';
      }
    }catch(err){
      const e = Q('#error');
      e.classList.remove('hidden');
      e.textContent = err.message;
    }
  }

  document.addEventListener('DOMContentLoaded', ()=>{
    const printBtn = Q('#printNow');
    const openBtn = Q('#openPrintPage');
    if(printBtn) printBtn.addEventListener('click', ()=>window.print());
    if(openBtn) openBtn.addEventListener('click', ()=>{
      const url = new URL('./print-shopping.html', location.href);
      window.open(url.toString(), '_blank');
    });
    main();
  });
})();
