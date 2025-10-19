async function load(){
  const fall = {items:[
    {name:'alexandria',title:'Alexandria — Gothic Library',desc:'DM & Worldbuilding',href:'/pages/apps/alexandria/index.html'},
    {name:'charlotte',title:'Charlotte — Relay Tower',desc:'Design & Pipelines',href:'/pages/apps/charlotte/index.html'},
    {name:'nina',title:'Nina — Futuristic Lab',desc:'3D & VRM',href:'/pages/apps/nina/index.html'},
    {name:'tracy',title:'Tracy — Cathedral Studio',desc:'Artboards & Wallpapers',href:'/pages/apps/tracy/index.html'},
    {name:'carol',title:'Carol — Restaurant',desc:'Meal Plans & Shopping',href:'/pages/apps/carol/index.html'},
    {name:'jem',title:'Jem — Dojo',desc:'Coaching & Biometrics',href:'/pages/apps/jem/index.html'},
    {name:'stella',title:'Stella — Observatory',desc:'Meditations & Gateway',href:'/pages/apps/stella/index.html'},
    {name:'abbey',title:'Abbey — Grand Vault',desc:'Finance & Reports',href:'/pages/apps/abbey/index.html'},
    {name:'themis',title:'Themis — Record Hall',desc:'Compliance & Reminders',href:'/pages/apps/themis/index.html'},
    {name:'billie',title:'Billie — Gold Mansion',desc:'Monetization & Shops',href:'/pages/apps/billie/index.html'},
    {name:'sorcha',title:'Sorcha — Mansion & Pool',desc:'Social Video',href:'/pages/apps/sorcha/index.html'},
    {name:'clarice',title:'Clarice — Courtroom & Palace',desc:'Security & Backups',href:'/pages/apps/clarice/index.html'}
  ]};
  let reg = fall;
  try{
    const r = await fetch('/pages/apps/_city/registry.json?cb='+Date.now());
    if(r.ok){ reg = await r.json(); }
  }catch(e){}
  const grid = document.getElementById('grid'); grid.innerHTML='';
  for(const it of reg.items){
    const d = document.createElement('div'); d.className='card';
    const icon='🏛️';
    d.innerHTML=`<div class="icon">${icon}</div><div class="title">${it.title||it.name}</div><div class="small">${it.desc||''}</div><a href="${it.href}">Enter</a>`;
    grid.appendChild(d);
  }
} load();