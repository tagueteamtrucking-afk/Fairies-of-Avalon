async function load(){
  let reg;
  try{ reg = await fetch('/pages/apps/_city/registry.json?cb='+Date.now()).then(r=>r.json()); }catch(e){}
  const items = reg?.items || [];
  const grid = document.getElementById('grid');
  grid.innerHTML = '';
  if(items.length===0){
    grid.innerHTML = '<div class="card">No apps registered. Run Charlotte — Link Registry.</div>';
    return;
  }
  for(const it of items){
    const d = document.createElement('div'); d.className='card';
    d.innerHTML = `<div class="icon">${it.icon||'🏛️'}</div><div class="title">${it.name}</div><div class="desc">${it.desc||''}</div><a href="${it.href}">Enter</a>`;
    grid.appendChild(d);
  }
}
load();
