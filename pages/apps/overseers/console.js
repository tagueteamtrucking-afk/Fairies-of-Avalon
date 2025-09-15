(function(){
  const pillAI  = document.getElementById('ai');
  const pillWPI = document.getElementById('wpi');
  const grid    = document.getElementById('fairies');

  function setWPI(v){
    if (Number.isFinite(v)) {
      pillWPI.textContent = 'WPI: ' + v + '%';
    } else {
      pillWPI.textContent = 'WPI: —';
    }
  }

  async function j(url){
    try{
      const r = await fetch(url + (url.includes('?') ? '' : '?t=') + Date.now(), { cache: 'no-store' });
      if (!r.ok) return null;
      return await r.json();
    }catch{ return null; }
  }

  (async ()=>{
    const progress = await j('/apps/overseers/progress.json');
    const wpi = progress?.telemetry?.wallpaper_power_index;
    setWPI(Number.isFinite(wpi) ? wpi : null);

    const assistants = await j('/apps/overseers/assistants.json') || [];
    grid.innerHTML = assistants.map(a => `
      <div class="card">
        <h3>${a.name}</h3>
        <div><a class="pill" href="${a.path}">Open microapp</a>
             <a class="pill" href="/apps/overseers/console.html#${a.id}">View in Console</a></div>
        <div><small>ID: ${a.id}</small></div>
      </div>`).join('');
  })();
})();
