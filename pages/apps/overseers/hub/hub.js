async function j(url){const r=await fetch(url+'?t='+Date.now(),{cache:'no-store'});if(!r.ok)throw new Error(url+': '+r.status);return r.json();}

function pill(el, ok){ el.classList.remove('ok','warn'); el.classList.add(ok?'ok':'warn'); }

async function tick(){
  try{
    const [caps, prog, asst] = await Promise.all([
      j('/apps/overseers/capabilities.json'),
      j('/apps/overseers/progress.json'),
      j('/apps/overseers/assistants.json')
    ]);

    const ai = document.getElementById('ai');
    const wpi = document.getElementById('wpi');
    const last = document.getElementById('last');

    const aiStatus = caps?.ai_core?.status || 'unknown';
    ai.textContent = `AI: ${aiStatus}`;
    pill(ai, /operational|ready/i.test(aiStatus));

    const WPI = prog?.telemetry?.wallpaper_power_index ?? null;
    wpi.textContent = `WPI: ${WPI ?? '—'}`;
    pill(wpi, (WPI ?? 0) > 0);

    last.textContent = `Last run: ${prog?.last_run || '—'}`;

    const fairies = document.getElementById('fairies');
    fairies.innerHTML = '';
    (asst||[]).forEach(a=>{
      const d = document.createElement('div');
      d.className = 'card';
      const ok = !!a.microapp_exists;
      d.innerHTML = `
        <h4>${a.name}</h4>
        <div style="margin:6px 0">
          <a class="pill ${ok?'ok':'warn'}" href="${a.path}">${ok?'Open microapp':'Coming soon'}</a>
          <a class="pill" href="/apps/overseers/console.html">View in Console</a>
        </div>
        <small>ID: ${a.id}</small>
      `;
      fairies.appendChild(d);
    });
  }catch(e){ console.warn(e); }
}
document.addEventListener('visibilitychange',()=>{ if(!document.hidden) tick(); });
setInterval(tick, 5000);
tick();
