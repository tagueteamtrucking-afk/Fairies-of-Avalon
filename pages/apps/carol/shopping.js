async function fetchJSON(url) {
  try {
    const r = await fetch(url, {cache:'no-store'});
    if (!r.ok) return null;
    return await r.json();
  } catch (e) { return null; }
}
function setHero(url) {
  const hero = document.getElementById('hero');
  hero.style.backgroundImage = `linear-gradient(0deg, rgba(0,0,0,.55), rgba(0,0,0,.0)), url('${url}')`;
}
function renderShopping(data) {
  const root = document.getElementById('shopping');
  root.innerHTML = '';
  if (!data) {
    const div = document.createElement('div');
    div.className = 'notice';
    div.textContent = 'No shopping list found yet. Run the “Carol — Refresh Shopping (direct commit)” workflow to generate shopping-quantized.json.';
    root.appendChild(div);
    return;
  }
  // Accept either {category:[items]} or flat list
  if (Array.isArray(data)) {
    const g = document.createElement('div'); g.className='group';
    g.innerHTML = `<header><strong>All Items</strong><span>${data.length}</span></header>`;
    const ul = document.createElement('ul');
    data.forEach(x=>{
      const li = document.createElement('li');
      li.textContent = typeof x === 'string' ? x : (x?.name || JSON.stringify(x));
      ul.appendChild(li);
    });
    g.appendChild(ul); root.appendChild(g); return;
  }
  // Grouped
  Object.keys(data).sort().forEach(cat=>{
    const items = data[cat];
    const g = document.createElement('div'); g.className='group';
    g.innerHTML = `<header><strong>${cat}</strong><span>${Array.isArray(items)?items.length:0}</span></header>`;
    const ul = document.createElement('ul');
    (Array.isArray(items)?items:[]).forEach(it=>{
      const li = document.createElement('li');
      if (typeof it === 'string') li.textContent = it;
      else {
        const qty = it.qty || it.quantity || it.amount || '';
        const unit = it.unit || '';
        const name = it.name || it.item || JSON.stringify(it);
        li.textContent = [qty, unit, name].filter(Boolean).join(' ').replace(/\s+/g,' ').trim();
      }
      ul.appendChild(li);
    });
    g.appendChild(ul); root.appendChild(g);
  });
}
(async function main(){
  const ptr = await fetchJSON('./index.json') || {};
  const img = ptr.images || {};
  if (img.heroShopping) setHero(img.heroShopping);
  const candidates = [];
  if (ptr.activeShopping) candidates.push(ptr.activeShopping);
  candidates.push(
    '/pages/apps/carol/plans/shopping-quantized.json',
    '/pages/apps/carol/plans/mealplan-dash-14d-current-shopping.json',
    '/pages/apps/carol/plans/shopping-extracted.json'
  );
  let data=null, used=null;
  for (const p of candidates) {
    data = await fetchJSON(p);
    if (data) { used = p; break; }
  }
  renderShopping(data);
})();