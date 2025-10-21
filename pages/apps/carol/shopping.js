
(async () => {
  const $ = s => document.querySelector(s);
  const status = $('#status');
  const container = $('#list');

  const candidates = [
    'plans/shopping-quantized.json',
    'plans/shopping-quantized-unique.json',
    'plans/mealplan-dash-14d-current-shopping.json'
  ];

  let data=null, src=null;
  for (const p of candidates) {
    try { const r = await fetch(p + '?v=' + Date.now(), {cache:'no-store'});
      if (r.ok) { data = await r.json(); src = p; break; }
    } catch(e){}
  }

  if (!data) {
    status.textContent = 'No shopping JSON found. Expected one of: ' + candidates.join(', ');
    container.innerHTML = '<article class="card"><h3>Missing list</h3><p>Run the workflow to generate it.</p></article>';
    return;
  }

  status.textContent = 'Source: ' + src;

  function categoryize(items) {
    // Accepts shapes: { items:[{name,qty,unit,category}] } OR {category:[{...}] } OR array
    let map = {};
    const add = (cat, it) => {
      cat = cat || 'General';
      (map[cat] ||= []).push(it);
    };

    if (Array.isArray(items)) {
      items.forEach(it => add(it.category, it));
    } else if (items?.items && Array.isArray(items.items)) {
      items.items.forEach(it => add(it.category, it));
    } else if (typeof items === 'object') {
      for (const [cat, arr] of Object.entries(items)) {
        if (Array.isArray(arr)) arr.forEach(it => add(cat, it));
      }
    }
    return map;
  }

  const categorized = categoryize(data) || categoryize(data.list) || categoryize(data.shopping);
  const cats = Object.keys(categorized || {}).sort();
  if (!cats.length) {
    container.innerHTML = '<article class="card"><h3>Couldn’t read the list</h3><pre style="white-space: pre-wrap; font-size:12px; color:#ddd;">'+JSON.stringify(data,null,2)+'</pre></article>';
    return;
  }

  container.innerHTML = '';
  cats.forEach(cat => {
    const items = categorized[cat];
    const ul = items.map(it => {
      const name = it.name || it.item || it.title || 'Item';
      const qty = [it.qty ?? it.quantity, it.unit].filter(Boolean).join(' ');
      return `<li>${name}${qty ? ' — <span class="note">'+qty+'</span>':''}</li>`
    }).join('');
    const card = document.createElement('article');
    card.className = 'card';
    card.innerHTML = `<h3>${cat}</h3><ul>${ul}</ul>`;
    container.appendChild(card);
  });
})();
