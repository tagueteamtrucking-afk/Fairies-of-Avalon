async function load(){
  let reg;
  try{ reg = await fetch('/pages/apps/_city/registry.json?cb='+Date.now()).then(r=>r.json()); }catch(e){}
  const items = reg?.items || [
    {id:'alexandria',name:'Alexandria — Library',icon:'📚',href:'/pages/apps/alexandria/index.html',desc:'Worldbuilding & DM'},
    {id:'tracy',name:'Tracy — Atelier',icon:'🎨',href:'/pages/apps/tracy/index.html',desc:'Skins, 2D, 3D'},
    {id:'nina',name:'Nina — Lab',icon:'🧪',href:'/pages/apps/nina/index.html',desc:'3D scenes & buttons'},
    {id:'charlotte',name:'Charlotte — Relay',icon:'📡',href:'/pages/apps/charlotte/index.html',desc:'Pipelines, UI polish'},
    {id:'stella',name:'Stella — Observatory',icon:'🌌',href:'/pages/apps/stella/index.html',desc:'Meditation & sound'},
    {id:'jem',name:'Jem — Dojo',icon:'🐉',href:'/pages/apps/jem/index.html',desc:'Fitness & coaching'},
    {id:'carol',name:'Carol — Bistro',icon:'🔥',href:'/pages/apps/carol/index.html',desc:'Menu & shopping'}
  ];
  const grid = document.getElementById('grid');
  grid.innerHTML = '';
  for(const it of items){
    const d = document.createElement('div'); d.className='card';
    d.innerHTML = `<div class="icon">${it.icon||'🏛️'}</div><div class="title">${it.name}</div><div class="desc">${it.desc||''}</div><a href="${it.href}">Enter</a>`;
    grid.appendChild(d);
  }
}
load();
