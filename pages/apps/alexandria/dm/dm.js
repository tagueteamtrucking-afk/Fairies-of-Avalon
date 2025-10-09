(function(){
  const qs = new URLSearchParams(location.search);
  let api = qs.get('api') || localStorage.getItem('ALEXANDRIA_API_URL') || '';
  const ttsEl = document.getElementById('tts');
  const logEl = document.getElementById('log');
  const input = document.getElementById('msg');
  let mediaStream = null, recorder = null, chunks = [], mime = '';

  function line(text, who){ const el = document.createElement('div'); el.className='msg ' + (who||'dm'); el.textContent = text; logEl.appendChild(el); logEl.scrollTop = logEl.scrollHeight; }
  function playAudio(dataUrl){ try{ const a=new Audio(dataUrl); a.play().catch(()=>{});}catch(e){} }
  function roll(n){ return Math.floor(Math.random()*n)+1 }
  [['roll-d20',20],['roll-d12',12],['roll-d10',10],['roll-d8',8],['roll-d6',6],['roll-d4',4]].forEach(([id,n])=>{
    const b=document.getElementById(id); if(b) b.addEventListener('click', ()=>{ const v=roll(n); const o=document.getElementById('roll-out'); if(o) o.textContent = `d${n}: ${v}`; });
  });

  async function sendText(text){
    if (!api) { line('No Worker set. Tap Connect.', 'dm'); return; }
    try{
      const res = await fetch(api, { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ text, sessionId: Date.now().toString(36), tts: !!ttsEl.checked, voice: 'alloy' }) });
      const j = await res.json();
      const reply = j.reply || '(no reply)';
      line(reply,'dm');
      if (ttsEl.checked && j.audio) playAudio(j.audio);
    }catch(e){ line('LLM link failed. Tap Check Worker.', 'dm'); }
  }

  document.getElementById('send').addEventListener('click', async ()=>{
    const text = input.value.trim(); if(!text) return; input.value=''; line(text,'you'); sendText(text);
  });
  document.getElementById('msg').addEventListener('keydown', (e)=>{ if(e.key==='Enter'){ const t=input.value.trim(); if(!t) return; input.value=''; line(t,'you'); sendText(t);} });

  const connectBtn=document.getElementById('connect'); if(connectBtn) connectBtn.addEventListener('click', ()=>{
    const u = prompt('Paste Worker URL (e.g., https://alexandria-dm.example.workers.dev):', api||''); if(!u) return;
    api = u.trim(); localStorage.setItem('ALEXANDRIA_API_URL', api); line('Saved Worker URL.','dm');
  });
  const checkBtn=document.getElementById('check'); if(checkBtn) checkBtn.addEventListener('click', async ()=>{
    if (!api) { line('No Worker URL set.','dm'); return; }
    try{ const r = await fetch(api); line(r.ok?'Worker reachable ✔︎':'Worker error ❌','dm'); }catch(e){ line('Worker not reachable ❌','dm'); }
  });
  const enableBtn=document.getElementById('enable-audio'); if(enableBtn) enableBtn.addEventListener('click', ()=>{ playAudio('data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQAAAAA='); line('Audio enabled.','dm'); });

  const grantBtn=document.getElementById('grant-mic'); if(grantBtn) grantBtn.addEventListener('click', async ()=>{
    try{
      mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const types = ['audio/webm;codecs=opus','audio/webm','audio/mp4'];
      mime = types.find(t=>MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(t)) || '';
      recorder = new MediaRecorder(mediaStream, mime?{mimeType:mime}:{ });
      recorder.ondataavailable = e=>{ if(e.data && e.data.size>0) chunks.push(e.data); };
      recorder.onstop = async ()=>{
        const blob = new Blob(chunks, { type: mime || 'audio/webm' }); chunks=[];
        const b64 = await blobToBase64(blob);
        if (!api) { line('No Worker set. Tap Connect.', 'dm'); return; }
        line('Transcribing…','dm');
        try{
          const res = await fetch(api, { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ audio_b64: b64, mime: blob.type || 'audio/webm', do_chat: true, tts: !!ttsEl.checked, voice: 'alloy' }) });
          const j = await res.json();
          if (j.transcript){ line('You (voice): '+j.transcript, 'you'); }
          if (j.reply){ line(j.reply,'dm'); if (ttsEl.checked && j.audio) playAudio(j.audio); }
        }catch(e){ line('Voice pipeline failed.','dm'); }
      };
      line('Mic ready. Hold-to-talk is active.','dm');
    }catch(e){ line('Mic permission denied.','dm'); }
  });

  const ptt = document.getElementById('ptt');
  if(ptt){
    const startRec = ()=>{ if(!recorder){ line('Grant Mic first.','dm'); return; } if(recorder.state==='recording') return; chunks=[]; recorder.start(); ptt.textContent='🔴 Recording…'; };
    const stopRec  = ()=>{ if(recorder && recorder.state==='recording'){ recorder.stop(); ptt.textContent='🎙 Hold to Talk'; } };
    ptt.addEventListener('mousedown', startRec); ptt.addEventListener('touchstart', startRec);
    ptt.addEventListener('mouseup', stopRec);   ptt.addEventListener('mouseleave', stopRec); ptt.addEventListener('touchend', stopRec);
  }

  function blobToBase64(blob){ return new Promise(res=>{ const fr=new FileReader(); fr.onloadend=()=>res((fr.result||'').toString()); fr.readAsDataURL(blob); }); }
  line("Welcome to the Library. Connect your Worker, Enable Audio, then Grant Mic. Hold-to-talk when ready.", 'dm');
})();