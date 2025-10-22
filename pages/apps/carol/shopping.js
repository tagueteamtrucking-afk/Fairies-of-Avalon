(function(){
  const $err = document.getElementById('err');
  const $list = document.getElementById('list');
  const $ass = document.getElementById('assumptions');
  document.getElementById('printBtn').onclick = ()=> window.print();
  document.getElementById('openPrint').onclick = ()=> window.open('./print-shopping.html','_blank');

  const ASSUME = {
    notes: [
      "Chicken cooked→raw equivalence uses 0.75 yield; cooked 6 oz ≈ raw 8 oz.",
      "LF cheese stick ~ 1 oz; counted into mozzarella (LF).",
      "Oats: 1 cup = 2.86 oz; 1 tbsp = 0.17875 oz.",
      "Hummus / cream cheese: 2 tbsp ≈ 1 oz.",
      "Frozen vegetables: 1 cup ≈ 0.33 lb (est). Produce weights vary by size/brand."
    ],
    oats: { cup: 2.86, tbsp: 0.17875 }, // to oz
    hummus_tsp_tbsp_to_oz: 0.5, // per tbsp
    frozenVegCupToLb: 0.33
  };

  function text(el, s){ el.textContent = s; }
  async function loadJSON(p){ const r=await fetch(p,{cache:'no-store'}); if(!r.ok) throw new Error(p+': '+r.status); return r.json(); }
  async function tryLoad(p){ try{ return await loadJSON(p); }catch{ return null; } }
  function normName(n){ return String(n||'').trim().toLowerCase(); }
  function plural(n,u){ return (n===1?`${n} ${u}`:`${n} ${u}${u.endsWith('s')?'':'s'}`); }
  function round(n, p=2){ return Math.round(n*Math.pow(10,p))/Math.pow(10,p); }

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
    ['banana–spinach smoothie (lf)','banana-spinach smoothie (lf)']
  ]);

  const TARGET = new Map([
    ['mixed vegetables, frozen', { unit:'lb' }],
    ['salmon fillet', { unit:'lb' }],
    ['cod fillet', { unit:'lb' }],
    ['chicken breast', { unit:'lb' }],
    ['lean ground turkey', { unit:'lb' }],
    ['canned tuna (in water)', { unit:'can' }],
    ['low-sodium beans (canned)', { unit:'can' }],
    ['low-sodium tomato soup', { unit:'can' }],
    ['greek yogurt, lactose-free', { unit:'oz' }],
    ['cottage cheese, lactose-free', { unit:'oz' }],
    ['mozzarella, lactose-free', { unit:'oz' }],
    ['lactose-free milk', { unit:'qt' }],
    ['rolled oats', { unit:'oz' }],
    ['hummus (no cumin)', { unit:'oz' }],
    ['lf mayo', { unit:'oz' }],
    ['olive oil', { unit:'tbsp' }],
    ['egg', { unit:'piece' }],
    ['egg whites', { unit:'cup' }],
    ['soft whole-wheat tortilla', { unit:'piece' }],
    ['soft whole-grain bread', { unit:'slice' }],
    ['butter lettuce', { unit:'head' }], // aggregated later from leaf count
    ['spinach', { unit:'lb' }],
    ['tomato', { unit:'lb' }],
    ['cucumber', { unit:'lb' }],
    ['grapes', { unit:'lb' }],
    ['banana', { unit:'lb' }],
    ['apple', { unit:'lb' }],
    ['pear', { unit:'lb' }],
    ['lemon', { unit:'lb' }],
    ['baby potatoes', { unit:'lb' }],
    ['avocado', { unit:'lb' }],
    ['pineapple (canned in juice, drained)', { unit:'can' }],
    ['mango (frozen)', { unit:'lb' }],
    ['blueberries', { unit:'lb' }],
    ['kiwi', { unit:'lb' }],
  ]);

  const PIECE_TO_LB = new Map([
    ['banana', 0.26], ['apple', 0.33], ['pear', 0.33], ['lemon', 0.25], ['kiwi', 0.13], ['avocado', 0.3],
    ['tomato', 0.25]
  ]);

  function aliasName(name){
    const k = normName(name);
    return ALIAS.get(k) || name;
  }

  function toTarget(name, qty, unit){
    name = aliasName(name);
    if (normName(name)==='cooked chicken breast'){
      // Convert cooked->raw eq (divide by 0.75), then to lb
      const oz = unit==='oz' ? qty : unit==='lb' ? qty*16 : qty; // assume oz if not specified
      const rawOz = oz / 0.75;
      return { name:'chicken breast', qty: rawOz/16, unit:'lb' };
    }
    if (name==='rolled oats'){
      // cups/tbsp -> oz
      if (unit==='cup') return { name, qty: qty*ASSUME.oats.cup, unit:'oz' };
      if (unit==='tbsp') return { name, qty: qty*ASSUME.oats.tbsp, unit:'oz' };
    }
    if (name==='lactose-free milk'){
      if (unit==='cup') return { name, qty: qty/4, unit:'qt' };
    }
    if (name==='hummus (no cumin)' || name==='lf mayo' || /cream cheese/i.test(name)){
      if (unit==='tbsp') return { name: name.replace(/lf\s+/i,'').replace(/lactose-free\s+/i,''), qty: qty*0.5, unit:'oz' };
    }
    if (name==='mixed vegetables, frozen'){
      if (unit==='cup') return { name, qty: qty*ASSUME.frozenVegCupToLb, unit:'lb' };
    }
    if (TARGET.has(name)){
      const tgt = TARGET.get(name).unit;
      // Simple conversions
      if (unit===tgt) return { name, qty, unit:tgt };
      if ((tgt==='lb') && unit==='oz') return { name, qty: qty/16, unit:'lb' };
      if ((tgt==='oz') && unit==='cup' && /yogurt|cottage/i.test(name)) return { name, qty: qty*8, unit:'oz' };
      if ((tgt==='lb') && unit==='piece'){
        const est = PIECE_TO_LB.get(normName(name)) || 0.3;
        return { name, qty: qty*est, unit:'lb' };
      }
    }
    // default: pass through
    return { name, qty, unit };
  }

  function pushItem(map, name, qty, unit){
    const key = name.toLowerCase();
    const ex = map.get(key);
    if(!ex) map.set(key, { name, qty, unit });
    else{
      if (ex.unit===unit){ ex.qty += qty; }
      else{
        // naive normalize: lb vs oz
        if (ex.unit==='lb' && unit==='oz'){ ex.qty += qty/16; }
        else if (ex.unit==='oz' && unit==='lb'){ ex.qty += qty*16; ex.unit='oz'; }
        else { ex.qty += qty; } // best effort
      }
    }
  }

  function qtyDisplay(q, u){
    if (u==='lb') return `${round(q,2)} lb`;
    if (u==='oz') return `${round(q,1)} oz`;
    if (u==='qt') return `${round(q,2)} qt`;
    if (u==='can') return `${round(q,2)} cans`;
    return `${round(q,2)} ${u}`;
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

  async function loadPlan(){
    // order: prebuilt shopping, else pointer->plan
    const idx = await loadJSON('./index.json').catch(()=>null) || await loadJSON('index.json').catch(()=>null);
    if (!idx) throw new Error('index.json not found');
    const prebuilt = await tryLoad('./shopping-2p.json');
    if (prebuilt) return { prebuilt };
    let rel = idx.plan_latest || idx.plan || null;
    if (!rel) throw new Error('Pointer missing: add plan_latest to pages/apps/carol/index.json');
    rel = rel.replace(/^\/+/, ''); // strip leading slash
    const plan = await loadJSON('/'+rel).catch(()=> loadJSON(rel));
    return { plan };
  }

  function buildFromPlan(plan){
    const map = new Map();
    const persons = 2;
    for (const day of plan.days||[]){
      for (const ev of day.events||[]){
        const mult = (String(ev.for||'').toLowerCase()==='both') ? persons : 1;
        for (const it of ev.items||[]){
          const n = it.ingredient;
          const q = (it.quantity||0) * mult;
          const u = (it.unit||'').toLowerCase();
          const t = toTarget(n, q, u);
          pushItem(map, t.name, t.qty, t.unit);
        }
      }
    }
    // leaf→head: ~12 leaves ≈ 1 head (soft lettuce)
    if (map.has('butter lettuce')){
      const x = map.get('butter lettuce');
      if (x.unit==='leaf'){ x.qty = x.qty/12; x.unit='head'; }
    }
    // remove near-zero noise
    for (const k of [...map.keys()]){
      const it = map.get(k);
      if (it.qty<0.01) map.delete(k);
    }
    // group by category
    const byCat = {};
    for (const it of map.values()){
      const cat = categorize(it.name);
      byCat[cat] = byCat[cat] || [];
      byCat[cat].push({ name: it.name, qty: it.qty, unit: it.unit, qty_display: qtyDisplay(it.qty, it.unit) });
    }
    for (const arr of Object.values(byCat)){
      arr.sort((a,b)=> a.name.localeCompare(b.name));
    }
    return { generated_at: new Date().toISOString(), items_by_cat: byCat, assumptions: ASSUME.notes };
  }

  (async function init(){
    try{
      const loaded = await loadPlan();
      let data = loaded.prebuilt || buildFromPlan(loaded.plan);
      // Render
      const frag = document.createDocumentFragment();
      Object.entries(data.items_by_cat).forEach(([cat,items])=>{
        const det = document.createElement('details');
        det.open = true;
        const sum = document.createElement('summary'); sum.textContent = cat; det.appendChild(sum);
        items.forEach(it=>{
          const row = document.createElement('div'); row.className='row';
          const q = document.createElement('div'); q.className='qty'; q.textContent = it.qty_display;
          const n = document.createElement('div'); n.className='name'; n.textContent = it.name;
          row.appendChild(q); row.appendChild(n); det.appendChild(row);
        });
        frag.appendChild(det);
      });
      $list.innerHTML = ''; $list.appendChild(frag);
      $ass.innerHTML = data.assumptions.map(s=>`• ${s}`).join('<br>');
    }catch(e){
      $err.style.display='block';
      $err.textContent = e.message || String(e);
    }
  })();
})();