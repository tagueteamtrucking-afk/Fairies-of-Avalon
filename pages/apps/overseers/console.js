async function setWallpaper() {
  try {
    const res = await fetch('../../wallpapers/index.json', { cache: 'no-store' });
    if (res.ok) {
      const list = await res.json();
      if (Array.isArray(list) && list.length) {
        const pic = list[Math.floor(Math.random() * list.length)];
        document.body.style.backgroundImage = `url('../../wallpapers/${encodeURIComponent(pic)}')`;
        document.body.classList.add('has-image');
      }
    }
  } catch {}
}

async function loadProgress() {
  const bar = document.getElementById('pi-bar');
  const scoreEl = document.getElementById('pi-score');
  const noteEl = document.getElementById('pi-note');
  const kpis = document.getElementById('pi-kpis');
  const details = document.getElementById('pi-details');

  try {
    const res = await fetch('./progress.json', { cache: 'no-store' });
    if (!res.ok) throw new Error(res.statusText);
    const data = await res.json();

    const pct = Math.max(0, Math.min(100, Number(data.overall || 0)));
    bar.style.width = pct + '%';
    scoreEl.textContent = pct + '%';
    noteEl.textContent = `Last updated: ${data.lastUpdated}`;

    kpis.innerHTML = '';
    (data.categories || []).forEach(c => {
      const el = document.createElement('div');
      el.className = 'kpi';
      el.innerHTML = `<div class="label">${c.label}</div><div class="value">${c.score}%</div>`;
      kpis.appendChild(el);
    });

    const m = data.metrics || {};
    details.innerHTML = `
      <div>VRMs: <b>${m.vrm_present || 0}</b> / <b>${m.vrm_expected || '?'}</b> &nbsp;•&nbsp;
           Wings meshes: <b>${m.wings_meshes || 0}</b> &nbsp;•&nbsp;
           Wallpapers: <b>${m.wallpapers || 0}</b></div>
      <div>Requests: <b>${m.requests || 0}</b> &nbsp;•&nbsp; Grants: <b>${m.grants || 0}</b></div>
      <div>Import map pinned: <b>${m.importmap_pinned ? 'Yes' : 'No'}</b></div>
    `;
  } catch (e) {
    bar.style.width = '0%';
    scoreEl.textContent = '0%';
    noteEl.textContent = 'Run “Overseers — AI Core” once to generate progress.';
  }
}

async function loadState() {
  const url = './permissions/state.json';
  const elSummary = document.getElementById('perm-summary');
  const elList = document.getElementById('perm-list');

  try {
    const res = await fetch(url, { cache: 'no-store' });
    if (!res.ok) throw new Error(res.statusText);
    const data = await res.json();

    elSummary.textContent = `Last updated: ${data.lastUpdated} • Requests: ${data.requests.length} • Grants: ${data.grants.length}`;

    elList.innerHTML = '';
    for (const r of data.requests) {
      const row = document.createElement('div');
      row.className = 'status';
      row.innerHTML =
        `<div><span class="badge">${r.status || 'requested'}</span> <b>${r.id}</b> — <i>${r.requester}</i></div>
         <div>Scopes: ${(r.scopes || []).join(', ') || '—'}</div>
         <div>Justification: ${r.justification || '—'}</div>
         <div>Requested: ${r.requestedAt || '—'}</div>`;
      elList.appendChild(row);
    }
  } catch (err) {
    elSummary.textContent = 'Failed to load state.json. Run the AI Core workflow at least once.';
  }
}

setWallpaper();
loadProgress();
loadState();
