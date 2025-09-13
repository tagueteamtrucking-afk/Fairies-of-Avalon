async function getJSON(path){
  try{
    const r = await fetch(path, {cache:'no-store'});
    if(!r.ok) throw new Error(r.statusText);
    return await r.json();
  }catch{ return null; }
}

function el(tag, html){ const e=document.createElement(tag); e.innerHTML=html; return e; }

(async () => {
  const queueEl = document.getElementById('queue-status');
  const permEl  = document.getElementById('perm-status');

  const queue = await getJSON('/apps/overseers/out/rey-czar.queue.json')
            || await getJSON('/apps/overseers/out/ray-czar.queue.json');

  if(queue){
    const items = (queue.items||[]).map(n=>`<li>${n}</li>`).join('');
    queueEl.replaceChildren(el('div', `<p><strong>Items:</strong> ${queue.count||0}</p><ul>${items}</ul>`));
  }else{
    queueEl.textContent = 'No queue status yet.';
  }

  const profiles = await getJSON('/apps/overseers/permissions/profiles.json');
  const state    = await getJSON('/apps/overseers/permissions/state.json');

  if(!profiles && !state){
    permEl.textContent = 'No permissions data yet. Run “Seed — Permissions”, then “Runner — Process Overseers Queue”.';
    return;
  }

  const grants = (state && state.grants) ? state.grants : [];
  const rows = grants.map(g => `
    <tr>
      <td>${g.assignee}</td>
      <td>${g.profile}</td>
      <td><span class="badge">${g.status}</span></td>
      <td><small>${g.requested_ts || ''}</small></td>
      <td><small>${g.approved_by || ''}</small></td>
    </tr>`).join('');

  permEl.replaceChildren(el('div', `
    <p><strong>Profiles loaded:</strong> ${profiles ? Object.keys(profiles.profiles||{}).length : 0}</p>
    <div style="overflow-x:auto">
      <table style="width:100%; border-collapse:collapse">
        <thead>
          <tr><th align="left">Assignee</th><th align="left">Profile</th><th align="left">Status</th><th align="left">Requested</th><th align="left">Approved By</th></tr>
        </thead>
        <tbody>${rows || '<tr><td colspan="5">No grants yet.</td></tr>'}</tbody>
      </table>
    </div>
  `));
})();
