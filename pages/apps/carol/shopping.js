(async () => {
  async function getJSON(path){
    const res = await fetch(path, {cache:'no-store'});
    if(!res.ok) throw new Error(`Fetch failed ${res.status}: ${path}`);
    return res.json();
  }
  const pointer = await getJSON('./index.json');
  const candidates = (pointer.shopping_files||[]).map(p => './'+p.replace(/^\.?\/?/,''));
  const shopSrc = document.getElementById('shopSrc');
  const noticeEl = document.getElementById('notice');
  const tbody = document.getElementById('tbody');

  let data, src;
  for(const c of candidates){
    try{ data = await getJSON(c); src = c; break; }catch{}
  }
  if(!data){
    noticeEl.style.display='block';
    noticeEl.innerHTML = 'No shopping file found yet. Please run the workflow “Carol — Refresh Menu + Shopping” to generate <code>plans/shopping-quantized.json</code>.';
    shopSrc.textContent = 'not found';
    return;
  }
  shopSrc.textContent = src.replace(/^\.\//,'');

  // Accept various shapes:
  //  - { categories:[{name:'Produce', items:[{name,qty,unit,notes}]}] }
  //  - { items:[{category,name,qty,unit,note}] }
  //  - flat object map: { "Produce":[{...}], "Dairy":[{...}] }
  let rows = [];
  if(Array.isArray(data.categories)){
    data.categories.forEach(cat => {
      (cat.items||[]).forEach(it => rows.push({
        category: cat.name||'Other',
        name: it.name||it.item||'',
        qty: it.qty||it.quantity||'',
        unit: it.unit||'',
        notes: it.notes||it.note||''
      }));
    });
  } else if(Array.isArray(data.items)){
    data.items.forEach(it => rows.push({
      category: it.category||'Other',
      name: it.name||it.item||'',
      qty: it.qty||it.quantity||'',
      unit: it.unit||'',
      notes: it.notes||it.note||''
    }));
  } else if (data && typeof data === 'object'){
    Object.keys(data).forEach(cat => {
      const list = Array.isArray(data[cat]) ? data[cat] : [];
      list.forEach(it => rows.push({
        category: cat,
        name: it.name||it.item||'',
        qty: it.qty||it.quantity||'',
        unit: it.unit||'',
        notes: it.notes||it.note||''
      }));
    });
  }
  if(!rows.length){
    noticeEl.style.display='block';
    noticeEl.textContent = 'Shopping JSON loaded but I could not parse any rows.';
    return;
  }
  // Apply diet swap for display
  rows.forEach(r => {
    if(r.name) r.name = String(r.name).replace(/peanut\s*butter/gi, 'sunflower seed butter');
    if(r.notes) r.notes = String(r.notes).replace(/peanut\s*butter/gi, 'sunflower seed butter');
  });
  // render
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    const td = (t)=>{const d=document.createElement('td'); d.textContent=t||''; return d;};
    tr.appendChild(td(r.category));
    tr.appendChild(td(r.name));
    tr.appendChild(td([r.qty,r.unit].filter(Boolean).join(' ')));
    tr.appendChild(td(r.notes||''));
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);
})();
