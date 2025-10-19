(async()=>{
  try{
    const r = await fetch('./registry.json?cb='+Date.now());
    if(!r.ok) return; const reg = await r.json();
    const grid = document.getElementById('grid'); if(!grid) return;
    grid.innerHTML='';
    for(const it of reg.items||[]){
      const a=document.createElement('a'); a.className='card'; a.href=it.href;
      a.innerHTML=`<span class="icon">🏛️</span><div><b>${it.title||it.name}</b><div class="small">${it.desc||''}</div></div>`;
      grid.appendChild(a);
    }
  }catch(e){ /* ignore, static fallback stays */ }
})();