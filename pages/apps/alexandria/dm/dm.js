(function(){
  // Offline-first DM with local tables and a dice roller.
  // Optional: set window.ALEXANDRIA_API_URL to enable LLM replies via a Cloudflare Worker proxy.
  const API = typeof window.ALEXANDRIA_API_URL === 'string' ? window.ALEXANDRIA_API_URL : null;
  const logEl = document.getElementById('log');
  const outEl = document.getElementById('roll-out');
  const input = document.getElementById('msg');
  const sendBtn = document.getElementById('send');
  const exportBtn = document.getElementById('export');
  const clearBtn = document.getElementById('clear');
  const session = { id: Date.now().toString(36), started: new Date().toISOString(), turns: [] };

  function line(text, who){
    const el = document.createElement('div');
    el.className = 'msg ' + (who||'dm');
    el.textContent = text;
    logEl.appendChild(el);
    logEl.scrollTop = logEl.scrollHeight;
  }
  function roll(n){ return Math.floor(Math.random()*n)+1 }
  function hook(){
    const hooks = [
      "A caravan seeks guards, but its leader hides a cursed artifact.",
      "A storm reveals ruins in the riverbed; the town wants explorers.",
      "A noble hires you to retrieve a family heirloom from a rival."
    ];
    return hooks[Math.floor(Math.random()*hooks.length)];
  }

  // Dice
  [['roll-d20',20],['roll-d12',12],['roll-d10',10],['roll-d8',8],['roll-d6',6],['roll-d4',4]].forEach(([id,n])=>{
    const btn=document.getElementById(id);
    btn.addEventListener('click', ()=>{
      const v=roll(n);
      outEl.textContent = `d${n}: ${v}`;
      session.turns.push({ t: Date.now(), type: 'roll', die: n, value: v });
    });
  });

  // Chat
  async function send(){
    const text = input.value.trim();
    if(!text) return;
    input.value='';
    line(text,'you');
    session.turns.push({ t: Date.now(), who:'you', text });

    if(API){
      try{
        const res = await fetch(API, { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ text, sessionId: session.id }) });
        const j = await res.json();
        const reply = j.reply || '(no reply)';
        line(reply,'dm');
        session.turns.push({ t: Date.now(), who:'dm', text: reply });
      }catch(e){
        line('LLM link failed. Using offline tables...', 'dm');
        const r = `Hook: ${hook()} (try rolling a d20 for outcome)`;
        line(r,'dm');
        session.turns.push({ t: Date.now(), who:'dm', text: r });
      }
    } else {
      const r = `Hook: ${hook()} (roll a d20 and tell me the result)`;
      line(r,'dm');
      session.turns.push({ t: Date.now(), who:'dm', text: r });
    }
  }
  sendBtn.addEventListener('click', send);
  input.addEventListener('keydown', (e)=>{ if(e.key==='Enter') send(); });

  // Export
  exportBtn.addEventListener('click', ()=>{
    const blob = new Blob([JSON.stringify(session, null, 2)], {type:'application/json'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `session-${session.id}.json`;
    a.click();
  });
  clearBtn.addEventListener('click', ()=>{
    logEl.innerHTML='';
    session.turns.push({ t: Date.now(), type:'clear' });
  });

  // Greeting
  line("Welcome to Alexandria's table. Say 'start quest' or roll a die.", 'dm');
})();