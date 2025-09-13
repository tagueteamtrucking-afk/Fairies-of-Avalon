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
        `<div><span class="badge">${r.status}</span> <b>${r.id}</b> — <i>${r.requester}</i></div>
         <div>Scopes: ${r.scopes.join(', ')}</div>
         <div>Justification: ${r.justification || '—'}</div>
         <div>Requested: ${r.requestedAt}</div>`;
      elList.appendChild(row);
    }
  } catch (err) {
    elSummary.textContent = 'Failed to load state.json. Run the AI Core workflow at least once.';
  }
}

loadState();
