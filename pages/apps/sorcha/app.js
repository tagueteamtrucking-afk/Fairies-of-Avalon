(async ()=>{
  async function fetchJSON(u){ const r=await fetch(u+'?t='+Date.now(),{cache:'no-store'}); if(!r.ok) throw new Error(u+': '+r.status); return r.json(); }
  try{
    const prog = await fetchJSON('/apps/overseers/progress.json');
    const caps = await fetchJSON('/apps/overseers/capabilities.json');
    const el = document.getElementById('status');
    const done = (prog?.totals?.success||0)+(prog?.totals?.failed||0)+(prog?.totals?.skipped||0);
    const total = done + (prog?.pending||0);
    el.textContent = Queue: / processed · last run  · AI Core ;
  }catch(e){
    document.getElementById('status').textContent = 'Status unavailable';
    console.warn(e);
  }
})();
