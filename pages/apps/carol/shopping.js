
(async () => {
  const table = document.getElementById('shopTable');
  const sourceEl = document.getElementById('source');

  function swapDiet(text) {
    if (!text) return text;
    let t = String(text);
    t = t.replace(/\bpeanut butter\b/gi, 'sunflower seed butter');
    t = t.replace(/\bpeanuts\b/gi, 'sunflower seeds');
    return t;
  }

  function rowsFromData(data) {
    const rows = [];
    if (Array.isArray(data)) {
      for (const it of data) {
        if (it && typeof it === 'object') {
          rows.push([it.category || it.cat || '', swapDiet(it.name || it.item || ''), it.qty || it.quantity || it.count || '', it.notes || it.note || '']);
        } else {
          rows.push(['', swapDiet(String(it)), '', '']);
        }
      }
      return rows;
    }
    // category arrays
    if (Array.isArray(data.categories)) {
      for (const cat of data.categories) {
        const cname = cat.name || cat.category || '';
        const items = cat.items || cat.list || [];
        for (const it of items) {
          if (it && typeof it === 'object') {
            rows.push([cname, swapDiet(it.name || it.item || ''), it.qty || it.quantity || '', it.notes || '']);
          } else {
            rows.push([cname, swapDiet(String(it)), '', '']);
          }
        }
      }
      return rows;
    }
    // map object
    const keys = Object.keys(data || {});
    if (keys.length) {
      for (const k of keys) {
        const v = data[k];
        if (Array.isArray(v)) {
          for (const it of v) {
            if (it && typeof it === 'object') {
              rows.push([k, swapDiet(it.name || it.item || ''), it.qty || it.quantity || '', it.notes || '']);
            } else {
              rows.push([k, swapDiet(String(it)), '', '']);
            }
          }
        } else {
          rows.push([k, swapDiet(typeof v==='string'?v:JSON.stringify(v)), '', '']);
        }
      }
      return rows;
    }
    return rows;
  }

  async function loadJSON(path) {
    const res = await fetch(path, {cache: 'no-store'});
    if (!res.ok) throw new Error(`Failed to load ${path}: ${res.status}`);
    return res.json();
  }

  let pointer;
  try {
    pointer = await loadJSON('./index.json');
  } catch (e) {
    sourceEl.textContent = 'Pointer missing: ./index.json';
    return;
  }
  if (pointer.heroImages?.shopping) {
    document.querySelector('.hero').style.backgroundImage = `url('${pointer.heroImages.shopping}')`;
  }

  const candidates = [
    pointer.activeShopping,
    'pages/apps/carol/plans/shopping-quantized.json',
    'pages/apps/carol/plans/mealplan-dash-14d-current-shopping.json'
  ].filter(Boolean);

  let used = null, data = null, err = null;
  for (const c of candidates) {
    try {
      const path = '/' + c.replace(/^\/?/, '');
      data = await loadJSON(path);
      used = c; break;
    } catch (e) { err = e; }
  }
  if (!data) {
    table.innerHTML = `<tr><td>Could not load shopping JSON</td><td>${err?err.message:''}</td></tr>`;
    return;
  }
  sourceEl.textContent = `Shopping: ${used}`;

  const rows = rowsFromData(data);
  table.innerHTML = `<thead><tr><th>Category</th><th>Item</th><th>Qty</th><th>Notes</th></tr></thead>`
    + `<tbody>` + rows.map(r=>`<tr><td>${r[0]||''}</td><td>${r[1]||''}</td><td>${r[2]||''}</td><td>${r[3]||''}</td></tr>`).join('') + `</tbody>`;
})();
