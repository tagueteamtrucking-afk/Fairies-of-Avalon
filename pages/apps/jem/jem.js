// pages/pages/apps/jem/jem.js
(function(){
  const todayKey = new Date().toISOString().slice(0,10);
  const storeKey = k => `jem:log:${k}`;
  const $ = s => document.querySelector(s);
  const $$ = s => Array.from(document.querySelectorAll(s));

  function saveLog() {
    const data = {
      date: todayKey,
      pushups: {
        style: $('input[name="pushup_style"]:checked')?.value || "none",
        difficulty: $('input[name="pushup_diff"]:checked')?.value || "unknown",
        reps_done: parseInt($('#pushup_reps').value || "0", 10)
      },
      warmup_done: $('#warmup_done').checked,
      break_done: $('#break_done').checked,
      unwind_done: $('#unwind_done').checked,
      notes: ($('#notes').value || "").trim()
    };
    localStorage.setItem(storeKey(todayKey), JSON.stringify(data));
    toast("Saved");
    renderStatus();
  }

  function loadLog(dateKey=todayKey) {
    const raw = localStorage.getItem(storeKey(dateKey));
    return raw ? JSON.parse(raw) : null;
  }

  function renderStatus() {
    const data = loadLog();
    $('#status').textContent = data ? "Logged today ✓" : "Not logged yet";
  }

  function exportAll() {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('jem:log:'));
    const items = keys.map(k => JSON.parse(localStorage.getItem(k)));
    const blob = new Blob([JSON.stringify(items, null, 2)], {type:'application/json'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'jem-logs.json';
    a.click();
  }

  function toast(msg) {
    let t = document.createElement('div');
    t.textContent = msg;
    t.style.position='fixed'; t.style.bottom='16px'; t.style.left='50%'; t.style.transform='translateX(-50%)';
    t.style.background='#222'; t.style.color='#fff'; t.style.padding='8px 12px'; t.style.borderRadius='8px';
    t.style.boxShadow='0 6px 14px rgba(0,0,0,.3)'; t.style.zIndex='9999';
    document.body.appendChild(t);
    setTimeout(()=>t.remove(),1200);
  }

  window.jem = { saveLog, exportAll };
  document.addEventListener('DOMContentLoaded', renderStatus);
})();

