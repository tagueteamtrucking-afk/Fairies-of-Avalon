(async function(){
  const qs = new URLSearchParams(location.search);
  let api = qs.get('api') || localStorage.getItem('ALEXANDRIA_API_URL') || '';
  const tts = { enabled: true, voice: 'alloy' };

  const logEl = document.getElementById('log'), outEl=document.getElementById('roll-out'), input=document.getElementById('msg');
  function line(t,who){ const d=document.createElement('div'); d.className='msg '+(who||'dm'); d.textContent=t; logEl.appendChild(d); logEl.scrollTop=logEl.scrollHeight; }
  function playAudio(s){ try{ new Audio(s).play().catch(()=>{});}catch(e){} }
  function roll(n){ return Math.floor(Math.random()*n)+1 }
  [['roll-d20',20],['roll-d12',12],['roll-d10',10],['roll-d8',8],['roll-d6',6],['roll-d4',4]].forEach(([id,n])=>{
    document.getElementById(id).addEventListener('click', ()=>{ const v=roll(n); outEl.textContent=`d${n}: ${v}`; });
  });

  async function send(){
    const text=input.value.trim(); if(!text) return; input.value=''; line(text,'you');
    if(!api){ line('Offline: tap “Connect Worker”.', 'dm'); return; }
    try{
      const r=await fetch(api,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({text,sessionId:Date.now().toString(36),tts:true,voice:tts.voice})});
      const j=await r.json(); const reply=j.reply||'(no reply)'; line(reply,'dm'); if(j.audio) playAudio(j.audio);
    }catch(e){ line('LLM link failed. Tap “Check Worker”.','dm'); }
  }
  document.getElementById('send').addEventListener('click', send);
  document.getElementById('msg').addEventListener('keydown', e=>{ if(e.key==='Enter') send(); });
  document.getElementById('export').addEventListener('click', ()=>{ const a=document.createElement('a'); a.href=URL.createObjectURL(new Blob([logEl.innerText],{type:'text/plain'})); a.download='session.txt'; a.click(); });
  document.getElementById('clear').addEventListener('click', ()=>{ logEl.innerHTML=''; });
  document.getElementById('connect').addEventListener('click', ()=>{ const u=prompt('Paste your Worker URL (e.g., https://alexandria-dm.tagueteamtrucking.workers.dev):', api||''); if(!u) return; api=u.trim(); localStorage.setItem('ALEXANDRIA_API_URL', api); line('Saved Worker URL.','dm'); });
  document.getElementById('check').addEventListener('click', async ()=>{ if(!api){ line('No Worker URL set.','dm'); return; } try{ const r=await fetch(api); line(r.ok?'Worker reachable ✔︎':'Worker error ❌','dm'); }catch(e){ line('Worker not reachable ❌','dm'); }});
  line('Welcome. Paste your Worker URL via “Connect Worker”.','dm');
})();