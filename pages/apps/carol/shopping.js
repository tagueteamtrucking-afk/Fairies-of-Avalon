/* Carol shopping list loader (prefers prebuilt JSON; can build in browser) */
(async function(){
  const status = document.getElementById('status');
  const root = document.getElementById('root');
  const buildBtn = document.getElementById('build');

  async function fetchJSON(rel){
    const tried=[];
    async function tryFetch(p){
      try{ const r = await fetch(p); tried.push(p); if(r.ok) return await r.json(); }catch{}
      return null;
    }
    return await tryFetch(rel) || await tryFetch('./'+rel) || null;
  }

  function renderList(doc){
    root.innerHTML = '';
    for(const cat of doc.categories){
      const sec = document.createElement('section'); sec.className='group';
      sec.innerHTML = `<h2>${cat.name}</h2><ul></ul>`;
      const ul = sec.querySelector('ul');
      for(const it of cat.items){
        const unit = it.unit ? ` ${it.unit}` : '';
        const notes = it.notes ? ` — <span class="mut">${it.notes}</span>`:'';
        ul.innerHTML += `<li>${it.qty}${unit} ${it.name}${notes}</li>`;
      }
      root.appendChild(sec);
    }
    status.textContent = 'Loaded';
  }

  // Prefer prebuilt JSON
  const ix = await fetchJSON('index.json');
  if(ix && ix.shopping_latest){
    const doc = await fetchJSON(ix.shopping_latest);
    if(doc && doc.categories){
      renderList(doc);
    }else{
      status.textContent = 'Prebuilt list missing; use Build in Browser.';
    }
  }else{
    status.textContent = 'Pointer missing; use Build in Browser.';
  }

  // Fallback build in browser (simple sum by exact name/unit)
  buildBtn.onclick = async ()=>{
    status.textContent = 'Building…';
    const ix2 = await fetchJSON('index.json');
    if(!ix2 || !ix2.plan_latest){ status.textContent='Pointer missing plan_latest'; return; }
    const plan = await fetchJSON(ix2.plan_latest);
    if(!plan){ status.textContent='Plan not found'; return; }
    const bucket = new Map();
    function key(n,u){ return (n||'').trim().toLowerCase()+'__'+(u||'').trim().toLowerCase(); }
    for(const d of plan.days){
      for(const ev of d.events||[]){
        for(const it of ev.items||[]){
          const n = (it.ingredient||'').trim();
          const u = (it.unit||'').trim();
          const k = key(n,u);
          const prev = bucket.get(k) || { name:n, unit:u, qty:0 };
          prev.qty += Number(it.quantity||0);
          bucket.set(k, prev);
        }
      }
    }
    const byCat = [
      {name:'Dairy', test:n=>/yogurt|cottage|milk|mozzarella|cheese/i.test(n)},
      {name:'Proteins', test:n=>/chicken|turkey|tuna|salmon|cod|egg/i.test(n)},
      {name:'Produce', test:n=>/apple|banana|pear|grape|tomato|cucumber|avocado|spinach|lettuce|potato|kiwi|peach|mango|lemon/i.test(n)},
      {name:'Frozen', test:n=>/frozen|mixed vegetables/i.test(n)},
      {name:'Pantry', test:n=>true}
    ];
    const doc = { categories: byCat.map(c=>({name:c.name, items:[]})) };
    for(const v of bucket.values()){
      const cat = doc.categories.find(c=>c.name!=='Pantry' && byCat.find(b=>b.name===c.name).test(v.name)) || doc.categories.find(c=>c.name==='Pantry');
      cat.items.push({ name:v.name, qty:Math.round((v.qty+Number.EPSILON)*100)/100, unit:v.unit });
    }
    doc.categories.forEach(c=>c.items.sort((a,b)=>a.name.localeCompare(b.name)));
    renderList(doc);
  };
})();