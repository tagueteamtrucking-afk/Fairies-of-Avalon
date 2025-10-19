async function load(){
  const res = await fetch('/pages/apps/_city/registry.json?cb='+Date.now());
  const reg = res.ok ? await res.json() : {items:[]};
  const grid = document.getElementById('grid'); grid.innerHTML = '';
  if(!reg.items || reg.items.length===0){ grid.innerHTML='<div class="card">No apps registered. Run Charlotte — Link Registry.</div>'; return; }
  for(const it of reg.items){
    const d=document.createElement('div'); d.className='card';
    d.innerHTML=`<div class="icon">${it.icon||'🏛️'}</div><div class="title">${it.name}</div><div class="desc">${it.desc||''}</div><a href="${it.href}">Enter</a>`;
    grid.appendChild(d);
  }
} load();
