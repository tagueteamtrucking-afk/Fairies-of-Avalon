(()=>{
  const log = s => { const el=document.getElementById('log'); el.textContent += s + "\n"; el.scrollTop=el.scrollHeight; };
  let ctx, master, nodes=[], timer=null, current=null;

  function ac(){ if(!ctx){ ctx=new (window.AudioContext||window.webkitAudioContext)(); master=ctx.createGain(); master.gain.value=parseFloat(document.getElementById('vol').value||0.35); master.connect(ctx.destination); } }

  function whiteNoise(){
    const buffer = ctx.createBuffer(2, ctx.sampleRate*2, ctx.sampleRate);
    for(let ch=0; ch<2; ch++){
      const data = buffer.getChannelData(ch);
      for(let i=0; i<data.length; i++) data[i] = (Math.random()*2-1)*0.6;
    }
    const src = ctx.createBufferSource(); src.buffer=buffer; src.loop=true;
    const g = ctx.createGain(); g.gain.value = 0.3;
    src.connect(g).connect(master);
    src.start(); return [src,g];
  }
  function filteredNoise(type='pink'){
    // start with white then gentle shelves for character; approximation only
    const [src,g] = whiteNoise();
    const biq1 = ctx.createBiquadFilter(); biq1.type='lowshelf'; biq1.frequency.value=200; biq1.gain.value=(type==='brown'?10:5);
    const biq2 = ctx.createBiquadFilter(); biq2.type='highshelf'; biq2.frequency.value=4000; biq2.gain.value=(type==='brown'?-12:(type==='pink'?-6:-2));
    g.disconnect();
    src.connect(biq1).connect(biq2).connect(master);
    return [src,biq1,biq2];
  }
  function binaural(base=220, diff=8){
    const l = ctx.createOscillator(); const r = ctx.createOscillator();
    const g = ctx.createGain(); g.gain.value=0.15;
    const split = ctx.createChannelMerger(2);
    const panL = new StereoPannerNode(ctx,{pan:-1});
    const panR = new StereoPannerNode(ctx,{pan: 1});
    l.frequency.value=base; r.frequency.value=base+diff;
    l.connect(panL).connect(split,0,0);
    r.connect(panR).connect(split,0,1);
    split.connect(g).connect(master);
    l.start(); r.start(); return [l,r,g,split,panL,panR];
  }
  function tone(freq=432){
    const o=ctx.createOscillator(), g=ctx.createGain(); o.type='sine'; o.frequency.value=freq; g.gain.value=0.12; o.connect(g).connect(master); o.start(); return [o,g];
  }

  function stopAll(){
    nodes.forEach(n=>{ try{ (n.stop?n.stop():0); if(n.disconnect) n.disconnect(); }catch(e){} });
    nodes=[]; if(timer){ clearTimeout(timer); timer=null; }
    document.querySelectorAll('.tile').forEach(b=>b.classList.remove('active'));
    current=null; log('Stopped.');
  }

  function setVol(v){ if(master){ master.gain.value=parseFloat(v)||0.35; } }

  function play(mode){
    ac(); stopAll(); const mins = Math.max(1, Math.min(120, parseInt(document.getElementById('mins').value||'20',10)));
    let config='';
    switch(mode){
      case 'focus':
        nodes.push(...filteredNoise('pink')); nodes.push(...binaural(220, 10)); config='pink noise + binaural ~10Hz (focus)';
        break;
      case 'calm':
        nodes.push(...filteredNoise('brown')); nodes.push(...tone(432)); config='brown noise + 432Hz tone (calm)';
        break;
      case 'relax':
        nodes.push(...filteredNoise('pink')); nodes.push(...binaural(200, 6)); config='soft pink noise + binaural ~6Hz (relax)';
        break;
      case 'energize':
        nodes.push(...whiteNoise()); nodes.push(...tone(528)); config='white noise + 528Hz tone (energize)';
        break;
      case 'winddown':
        nodes.push(...filteredNoise('brown')); nodes.push(...binaural(180, 3)); config='brown noise + binaural ~3Hz (wind‑down)';
        break;
      case 'silence':
        config='silence / stop'; break;
    }
    document.querySelector(`[data-mode="${mode}"]`)?.classList.add('active');
    current=mode; log(`Mode: ${mode} — ${config} for ${mins} min`);
    timer = setTimeout(()=> stopAll(), mins*60*1000);
  }

  // Wire UI
  document.querySelectorAll('.tile').forEach(btn=>{
    btn.addEventListener('click', ()=>{
      const m=btn.dataset.mode;
      if(current===m){ stopAll(); } else { play(m); }
    });
  });
  document.getElementById('stop').addEventListener('click', stopAll);
  document.getElementById('vol').addEventListener('input', e=> setVol(e.target.value));

  log('Ready. Choose a mood.');
})();