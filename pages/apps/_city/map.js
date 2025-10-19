(function(){
  const buildings = [
    {id:'palace', label:'Palace — Ray & Blanca', href:'/pages/apps/_city/index.html', x:600, y:120, w:130, h:70, fill:'#465', icon:'🏰'},
    {id:'stella', label:'Stella — Observatory', href:'/pages/apps/stella/index.html', x:450, y:120, w:90, h:60, fill:'#556', icon:'🔭'},
    {id:'tracy', label:'Tracy — Cathedral Studio', href:'/pages/apps/tracy/index.html', x:750, y:120, w:110, h:60, fill:'#566', icon:'🎨'},
    {id:'abbey', label:'Abbey — Grand Vault', href:'/pages/apps/abbey/index.html', x:320, y:300, w:110, h:60, fill:'#655', icon:'🏦'},
    {id:'billie', label:'Billie — Mansion', href:'/pages/apps/billie/index.html', x:880, y:300, w:110, h:60, fill:'#665', icon:'💰'},
    {id:'odessa', label:'Sorcha — Mansion & Pool', href:'/pages/apps/sorcha/index.html', x:1040, y:300, w:120, h:60, fill:'#676', icon:'🎬'},
    {id:'nina', label:'Nina — Lab', href:'/pages/apps/nina/index.html', x:270, y:480, w:110, h:60, fill:'#466', icon:'🧪'},
    {id:'charlotte', label:'Charlotte — Relay Tower', href:'/pages/apps/charlotte/index.html', x:930, y:480, w:120, h:60, fill:'#474', icon:'📡'},
    {id:'jem', label:'Jem — Dojo', href:'/pages/apps/jem/index.html', x:450, y:560, w:100, h:60, fill:'#575', icon:'🥋'},
    {id:'carol', label:'Carol — Restaurant', href:'/pages/apps/carol/index.html', x:600, y:560, w:120, h:60, fill:'#575', icon:'🍽️'},
    {id:'clarice', label:'Clarice — Courtroom', href:'/pages/apps/clarice/index.html', x:750, y:560, w:120, h:60, fill:'#575', icon:'⚖️'},
    {id:'alexandria', label:'Alexandria — Library', href:'/pages/apps/alexandria/index.html', x:600, y:300, w:140, h:60, fill:'#557', icon:'📚'}
  ];
  const paths = [
    // simple roads connecting key hubs
    {x1:600,y1:155,x2:600,y2:300},{x1:600,y1:300,x2:600,y2:560},
    {x1:320,y1:330,x2:880,y2:330},{x1:270,y1:510,x2:930,y2:510},
    {x1:450,y1:590,x2:750,y2:590}
  ];
  const svg=document.getElementById('map');
  const mk=(n)=>document.createElementNS('http://www.w3.org/2000/svg',n);
  // ground
  const bg=mk('rect'); bg.setAttribute('x',50); bg.setAttribute('y',80); bg.setAttribute('width',1100); bg.setAttribute('height',540);
  bg.setAttribute('fill','rgba(10,20,40,.35)'); bg.setAttribute('rx',28); svg.appendChild(bg);
  // roads
  for(const p of paths){const l=mk('line'); l.setAttribute('x1',p.x1); l.setAttribute('y1',p.y1); l.setAttribute('x2',p.x2); l.setAttribute('y2',p.y2); l.setAttribute('stroke','#2a395a'); l.setAttribute('stroke-width','14'); l.setAttribute('stroke-linecap','round'); svg.appendChild(l);}
  // buildings
  for(const b of buildings){
    const g=mk('g'); g.style.cursor='pointer';
    const r=mk('rect'); r.setAttribute('x',b.x-b.w/2); r.setAttribute('y',b.y-b.h/2); r.setAttribute('width',b.w); r.setAttribute('height',b.h);
    r.setAttribute('rx',12); r.setAttribute('fill',b.fill); r.setAttribute('stroke','#2a3756'); r.setAttribute('stroke-width','2');
    const t=mk('text'); t.setAttribute('x',b.x); t.setAttribute('y',b.y+5); t.setAttribute('fill','#e6e9ff'); t.setAttribute('font-size','14'); t.setAttribute('text-anchor','middle');
    t.textContent=(b.icon||'🏛️')+'  '+b.label;
    g.appendChild(r); g.appendChild(t);
    g.addEventListener('click', ()=>{ location.href=b.href; });
    svg.appendChild(g);
  }
})();