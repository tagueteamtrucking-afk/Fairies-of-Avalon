(async function () {
  const elBadges = document.getElementById('badges');
  const elCards  = document.getElementById('cards');
  const diagLink = document.getElementById('downloadDiag');

  async function safeJson(url){
    try{
      const r = await fetch(url, {cache:'no-store'});
      if(!r.ok) return null;
      return await r.json();
    }catch{ return null; }
  }

  const progress = await safeJson('./progress.json');
  const perms    = await safeJson('./permissions/state.json');
  const caps     = await safeJson('./capabilities.json');

  if (progress) {
    // Budgets & badges
    const b = progress.budgets || {};
    const assets = progress.assets || {};
    const coverage = assets.coverage || {};
    function badge(label, state, detail=''){
      const cls = state === 'ok' ? 'ok' : state === 'warn' ? 'warn' : 'fail';
      return `<span class="badge ${cls}" title="${detail}">${label}</span>`;
    }
    const badges = [];

    // We can only check what we know: wallpapers count vs budget
    const wallCount = (assets.wallpapers && assets.wallpapers.count) || 0;
    if (b.wallpapers_total){
      const st = wallCount <= b.wallpapers_total ? 'ok' : 'warn';
      badges.push(badge(`Wallpapers: ${wallCount}/${b.wallpapers_total}`, st));
    }
    // VRM per-file budget is advisory; we show count
    badges.push(badge(`VRMs (wingless): ${assets.vrm_wingless?.count ?? 0}`, 'ok'));
    badges.push(badge(`VRMs (with-wings): ${assets.vrm_with_wings?.count ?? 0}`, 'ok'));
    // Coverage
    badges.push(badge(`Wing sets covered: ${coverage.groups_with_mesh_and_textures ?? 0}/${coverage.groups_total ?? 0}`, 
      (coverage.groups_total === coverage.groups_with_mesh_and_textures) ? 'ok' : 'warn'));

    elBadges.innerHTML = badges.join(' ');

    // Cards
    const cards = [];
    cards.push(`
      <section class="card">
        <h3>Assets</h3>
        <ul>
          <li>Wingless VRMs: <strong>${assets.vrm_wingless?.count ?? 0}</strong> (${assets.vrm_wingless?.size_mb ?? '—'} MB)</li>
          <li>Pre-winged VRMs: <strong>${assets.vrm_with_wings?.count ?? 0}</strong> (${assets.vrm_with_wings?.size_mb ?? '—'} MB)</li>
          <li>Wing meshes: <strong>${assets.wings_meshes?.count ?? 0}</strong> (${assets.wings_meshes?.size_mb ?? '—'} MB)</li>
          <li>Wing textures: <strong>${assets.wings_textures?.count ?? 0}</strong> (${assets.wings_textures?.size_mb ?? '—'} MB)</li>
          <li>Wallpapers: <strong>${assets.wallpapers?.count ?? 0}</strong> (${assets.wallpapers?.size_mb ?? '—'} MB)</li>
        </ul>
        <p class="muted">Paths: <code>${Object.values(progress.paths||{}).join('</code> · <code>')}</code></p>
      </section>
    `);

    // Mismatch card
    const missM = coverage.groups_missing_mesh || [];
    const missT = coverage.groups_missing_textures || [];
    cards.push(`
      <section class="card">
        <h3>Wing Coverage</h3>
        <p><strong>${coverage.groups_with_mesh_and_textures ?? 0}</strong> complete of <strong>${coverage.groups_total ?? 0}</strong>.</p>
        ${missM.length? `<p>Missing mesh for: <code>${missM.join(', ')}</code></p>` : `<p>All texture groups have meshes.</p>`}
        ${missT.length? `<p>Missing textures for: <code>${missT.join(', ')}</code></p>` : `<p>All mesh groups have textures.</p>`}
      </section>
    `);

    // Budgets card
    cards.push(`
      <section class="card">
        <h3>Budgets</h3>
        <ul>
          <li>Initial shell ≤ <strong>${b.initial_shell_kb ?? '—'}</strong> KB (gz)</li>
          <li>Initial requests ≤ <strong>${b.initial_requests ?? '—'}</strong></li>
          <li>VRM per file ≤ <strong>${b.vrm_per_file_mb ?? '—'}</strong> MB (advisory)</li>
          <li>Wallpapers on home ≤ <strong>${b.wallpapers_total ?? '—'}</strong></li>
        </ul>
      </section>
    `);

    elCards.innerHTML = cards.join('\n');

    // Diagnostics download
    try{
      const blob = new Blob([JSON.stringify(progress, null, 2)], {type:'application/json'});
      const url = URL.createObjectURL(blob);
      diagLink.href = url;
    }catch{}
  } else {
    elCards.innerHTML = `<section class="card"><h3>No diagnostics</h3><p class="muted">progress.json not found.</p></section>`;
  }

  // Permissions & capabilities (read-only)
  if (perms || caps){
    const capList = (caps && caps.capabilities) ? caps.capabilities.map(c=>`<code>${c.id}</code> — ${c.description}`).join('<br>') : '<em>None</em>';
    const reqs = (perms && perms.requests) ? perms.requests.length : 0;
    const grants = (perms && perms.grants) ? perms.grants.length : 0;
    const sec = document.createElement('section');
    sec.className = 'card';
    sec.innerHTML = `
      <h3>Permissions</h3>
      <p>Requests: <strong>${reqs}</strong> · Grants: <strong>${grants}</strong></p>
      <details><summary>Capabilities Registry</summary><p>${capList}</p></details>
    `;
    elCards.appendChild(sec);
  }
})();
