
(async () => {
  const $ = sel => document.querySelector(sel);
  const grid = $('#grid');
  const planPathEl = $('#planPath');

  const pointerUrl = './index.json?v=' + Date.now();
  let pointer;
  try {
    const r = await fetch(pointerUrl, {cache: 'no-store'});
    if (r.ok) pointer = await r.json();
  } catch (e) {}

  const candidates = [];
  if (pointer?.active_plan) candidates.push(pointer.active_plan);
  if (Array.isArray(pointer?.fallbacks)) candidates.push(...pointer.fallbacks);
  // Extra fallbacks from historical files
  candidates.push(
    'plans/twoperson-2wk-unique-20251015T022300Z.json',
    'plans/mealplan-dash-14d-current.json',
    'plans/mealplan-balanced-20251019T021457Z.json'
  );

  let plan = null, planUrl = null;
  for (const p of candidates) {
    try {
      const r = await fetch(p + '?v=' + Date.now(), {cache:'no-store'});
      if (r.ok) { plan = await r.json(); planUrl = p; break; }
    } catch(e) {}
  }

  if (!plan) {
    planPathEl.textContent = 'No plan JSON found. Expected one of: ' + candidates.join(', ');
    grid.innerHTML = `<div class="card"><h3>Missing plan</h3>
    <p>Upload your 14‑day plan JSON to <code>pages/apps/carol/plans/</code> and refresh.</p></div>`;
    return;
  }
  planPathEl.textContent = 'Plan: ' + planUrl;

  // Normalize any structure into an array of 14 "days"
  function asArray(x) { return Array.isArray(x) ? x : (x ? [x] : []); }

  function detectDays(obj) {
    if (Array.isArray(obj)) return obj;

    if (obj.days && Array.isArray(obj.days)) return obj.days;

    if (obj.plan?.days && Array.isArray(obj.plan.days)) return obj.plan.days;
    if (obj.menu?.days && Array.isArray(obj.menu.days)) return obj.menu.days;

    // Keys like "Day 1", "day1", etc.
    const dayKeys = Object.keys(obj).filter(k => /^day\s*\d+/i.test(k) || /^d\s*\d+$/i.test(k));
    if (dayKeys.length) {
      dayKeys.sort((a,b) => {
        const na = parseInt(a.match(/\d+/)?.[0] ?? '0', 10);
        const nb = parseInt(b.match(/\d+/)?.[0] ?? '0', 10);
        return na - nb;
      });
      return dayKeys.map(k => obj[k]);
    }
    // Some files nest under weeks
    if (obj.weeks && Array.isArray(obj.weeks)) {
      return obj.weeks.flatMap(w => w.days || []);
    }
    return [];
  }

  function pickStringsFrom(val) {
    if (!val) return [];
    if (typeof val === 'string') return [val];
    if (Array.isArray(val)) return val.flatMap(pickStringsFrom);
    if (typeof val === 'object') {
      // collect likely meal fields
      const fields = ['breakfast','lunch','dinner','snack','snacks','supper','meal','meals','entree','sides','dessert'];
      let out = [];
      for (const key of fields) {
        if (val[key]) out = out.concat(pickStringsFrom(val[key]));
      }
      // Any stringy-ish leaves
      for (const [k,v] of Object.entries(val)) {
        if (['title','name','recipe','item'].includes(k) && typeof v === 'string') out.push(v);
      }
      return out;
    }
    return [];
  }

  function makeMealsList(dayObj) {
    let items = [];
    if (!dayObj) return items;
    if (Array.isArray(dayObj)) items = pickStringsFrom(dayObj);
    else if (typeof dayObj === 'object') {
      items = pickStringsFrom(dayObj);
    } else if (typeof dayObj === 'string') items = [dayObj];
    // swaps: peanut/almond butters -> sunflower seed butter annotation
    items = items.map(x => {
      if (!x) return x;
      const lc = x.toLowerCase();
      if (lc.includes('peanut butter') || lc.includes('almond butter')) {
        return x.replace(/peanut butter|almond butter/ig, 'sunflower seed butter') + ' <span class="badge">swap</span>';
      }
      // "very hard" -> suggest soft alt (note only)
      if (lc.includes('granola') || lc.includes('hard') || lc.includes('crunchy')) {
        return x + ' <span class="badge">soft alt ok</span>';
      }
      return x;
    });
    // de-dupe and trim
    const seen = new Set(); const ok = [];
    for (const it of items) {
      const key = (it||'').toString().toLowerCase().trim();
      if (key && !seen.has(key)) { seen.add(key); ok.push(it); }
    }
    return ok.slice(0, 12); // keep it readable
  }

  const days = detectDays(plan);
  if (!days.length) {
    grid.innerHTML = `<div class="card"><h3>Couldn’t understand the plan file</h3>
      <p>Showing raw JSON for review:</p>
      <pre style="white-space: pre-wrap; font-size:12px; color:#ddd;">${JSON.stringify(plan, null, 2)}</pre></div>`;
    return;
  }

  grid.innerHTML = "";
  days.slice(0,14).forEach((day, i) => {
    const meals = makeMealsList(day);
    const li = meals.map(m => `<li>${m}</li>`).join('') || '<li><em>No items detected for this day.</em></li>';
    const card = document.createElement('article');
    card.className = 'card';
    card.innerHTML = `<h3>Day ${i+1}</h3><ul>${li}</ul>`;
    grid.appendChild(card);
  });
})();
