(async () => {
  const host = document.getElementById('list');
  const debugBox = document.getElementById('debug');
  const log = (...a) => { if (window.CAROL_DEBUG) { debugBox.style.display='block'; debugBox.textContent += a.join(' ') + "\n"; } };

  async function fetchJson(url) {
    try {
      const r = await fetch(url, { cache: 'no-store' });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return await r.json();
    } catch (e) {
      log('fetch fail', url, String(e));
      return null;
    }
  }

  const pointer = await fetchJson('./index.json') || {};
  const fallbackList = [
    pointer.activeShopping,
    '/pages/apps/carol/plans/shopping-quantized.json',
    '/pages/apps/carol/plans/mealplan-dash-14d-current-shopping.json',
    '/pages/apps/carol/plans/shopping-extracted.json'
  ].filter(Boolean);

  let data = null, chosen = null;
  for (const url of fallbackList) {
    const j = await fetchJson(url);
    if (j) { data = j; chosen = url; break; }
  }
  log('shopping source:', chosen || 'none');

  if (!data) {
    host.innerHTML = `<div class="notice">
      No shopping file found yet. Run <strong>Actions → Carol — Refresh Shopping (direct commit)</strong> to generate
      <code>shopping-quantized.json</code>. Then reload this page.
    </div>`;
    return;
  }

  // Data can be either grouped { "Produce":[...], "Dairy":[...], ... } or a flat array
  function renderGrouped(obj) {
    const keys = Object.keys(obj);
    return keys.map(k => {
      const arr = Array.isArray(obj[k]) ? obj[k] : [];
      return `<div class="group">
        <h3>${k}</h3>
        <ul>${arr.map(x => `<li>${typeof x === 'string' ? x : JSON.stringify(x) }</li>`).join('')}</ul>
      </div>`;
    }).join('');
  }

  function renderFlat(arr) {
    return `<div class="group">
      <ul>${arr.map(x => `<li>${typeof x === 'string' ? x : JSON.stringify(x)}</li>`).join('')}</ul>
    </div>`;
  }

  if (Array.isArray(data)) {
    host.innerHTML = renderFlat(data);
  } else if (data && typeof data === 'object') {
    host.innerHTML = renderGrouped(data);
  } else {
    host.innerHTML = `<div class="notice">Unrecognized shopping format.</div>`;
  }
})();