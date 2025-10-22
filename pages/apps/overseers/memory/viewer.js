(function(){
  const byId = id => document.getElementById(id);
  const $summary = byId('summary');
  const $list = byId('list');
  const $q = byId('q');
  const $showIgnored = byId('showIgnored');
  const $genAt = byId('genAt');

  const fmtBytes = n => {
    if (n==null) return '—';
    const units=['B','KB','MB','GB']; let i=0; let x=n;
    while(x>=1024 && i<units.length-1){ x/=1024; i++; }
    return `${x.toFixed(x>=10?0:1)} ${units[i]}`;
  };

  async function loadJSON(p){
    const r = await fetch(p, {cache:'no-store'});
    if(!r.ok) throw new Error(p+': '+r.status+' '+r.statusText);
    return r.json();
  }

  function renderSummary(cov){
    const ignored = cov.ignored_count ?? 0;
    const missing = cov.missing_count ?? 0;
    $summary.innerHTML = [
      `<div><strong>Total scanned:</strong> ${cov.scanned_count} files`,
      `<strong>Tracked (git ls-files):</strong> ${cov.tracked_count}`,
      `<strong>COVERAGE:</strong> ${cov.coverage_pct}%`,
      ignored ? `<span class="badge">ignored: ${ignored}</span>` : '',
      missing ? `<span class="badge" title="Listed by git but not in scan">missing: ${missing}</span>` : ''
    ].join(' &nbsp; ');
    $genAt.textContent = cov.generated_at || '—';
  }

  function renderList(index, cov){
    const ignoredSet = new Set(cov.ignored_paths||[]);
    const all = index.files;
    const state = { q:'', showIgnored:false };
    const apply = () => {
      const q = state.q.trim().toLowerCase();
      const showIgnored = state.showIgnored;
      const rows = all.filter(f => {
        const isIgnored = ignoredSet.has(f.path);
        if (!showIgnored && isIgnored) return false;
        if (!q) return true;
        const hay = [f.path, f.type||'', (f.purpose||'')].join(' ').toLowerCase();
        return hay.includes(q);
      }).map(f => {
        const badges = [f.type?`<span class="badge">${f.type}</span>`:'', f.purpose?`<span class="badge">${f.purpose}</span>`:''].join('');
        return `<div class="item"><div class="path">${f.path} ${badges}</div><div class="meta">${fmtBytes(f.bytes)} &nbsp; <span title="sha1">${(f.sha1||'').slice(0,8)}</span></div></div>`;
      });
      $list.innerHTML = rows.join('') || '<div class="item">No files match.</div>';
    };
    $q.addEventListener('input', e=>{ state.q = e.target.value; apply(); });
    $showIgnored.addEventListener('change', e=>{ state.showIgnored = !!e.target.checked; apply(); });
    apply();
  }

  (async function init(){
    try{
      const [index, cov] = await Promise.all([
        loadJSON('./file-index.json'),
        loadJSON('./coverage.json')
      ]);
      renderSummary(cov);
      renderList(index, cov);
    }catch(err){
      $summary.innerHTML = '<strong>Memory data missing.</strong> <a href="../../overseers/">Back</a>';
      console.error(err);
    }
  })();
})();