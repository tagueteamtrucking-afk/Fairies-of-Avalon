(async () => {
  const grid = document.getElementById('menuGrid');
  const debugBox = document.getElementById('debug');
  const log = (...a) => { if (window.CAROL_DEBUG) { debugBox.style.display='block'; debugBox.textContent += a.join(' ') + "\n"; } };

  const pointerUrl = './index.json';
  const fallbackPlans = [
    '/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json',
    '/pages/apps/carol/plans/twoperson-2wk-20251014T234049Z.json',
    '/pages/apps/carol/plans/mealplan-dash-14d-current.json',
    '/pages/apps/carol/plans/plan-14d-seeded.json',
    '/pages/apps/carol/plans/offline-twoperson-2wk-20251010T013559Z.json'
  ];

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

  function pickMealsFrom(obj) {
    // heuristics
    const keys = Object.keys(obj);
    const picks = ['breakfast','lunch','dinner','snacks','snack','brunch'];
    let out = { breakfast:[], lunch:[], dinner:[], snacks:[] };
    for (const k of keys) {
      const lk = k.toLowerCase();
      if (picks.includes(lk)) {
        const v = obj[k];
        const arr = Array.isArray(v) ? v : (v? [v] : []);
        if (lk === 'snack') out.snacks.push(...arr);
        else out[lk].push(...arr);
      }
    }
    // If nothing matched, treat values as lines
    if (!out.breakfast.length && !out.lunch.length && !out.dinner.length && !out.snacks.length) {
      const vals = keys.map(k => obj[k]).filter(x => typeof x === 'string' && x.trim());
      if (vals.length) out.breakfast = vals;
    }
    return out;
  }

  function normalizePlan(raw) {
    // Cases:
    // - { days: [...] } or { plan:{days:[...]} }
    // - [ ... ] already
    // - { "Day 1": {...}, "Day 2": {...}, ... }
    let days = [];
    if (Array.isArray(raw)) {
      days = raw;
    } else if (raw && Array.isArray(raw.days)) {
      days = raw.days;
    } else if (raw && raw.plan && Array.isArray(raw.plan.days)) {
      days = raw.plan.days;
    } else if (raw && typeof raw === 'object') {
      const dayKeys = Object.keys(raw).filter(k => /^day\s*\d+/i.test(k));
      if (dayKeys.length) {
        dayKeys.sort((a,b)=>{
          const na = parseInt(a.replace(/\D+/g,''))||0;
          const nb = parseInt(b.replace(/\D+/g,''))||0;
          return na - nb;
        });
        days = dayKeys.map(k => raw[k]);
      }
    }
    // coerce to 14 items by trimming/padding (repeat last) for display
    if (days.length > 14) days = days.slice(0,14);
    if (days.length < 14 && days.length > 0) {
      const last = days[days.length-1];
      while (days.length < 14) days.push(last);
    }
    return days.map((d,idx) => {
      if (!d || typeof d !== 'object') return { day: idx+1, breakfast:[], lunch:[], dinner:[], snacks:[] };
      const meals = pickMealsFrom(d);
      // Soft substitutions for display
      for (const slot of ['breakfast','lunch','dinner','snacks']) {
        meals[slot] = (meals[slot]||[]).map(line => {
          if (typeof line !== 'string') return JSON.stringify(line);
          let s = line;
          // global dietary display adjustments
          s = s.replace(/\bpeanut butter\b/ig, 'sunflower seed butter');
          s = s.replace(/\bhard[-\s]?taco\b/ig, 'soft taco');
          s = s.replace(/\bgranola bar\b/ig, 'soft oat bar');
          return s;
        });
      }
      return { day: idx+1, ...meals };
    });
  }

  function render(days) {
    const bg = 'style="background-image:url(/asset/textures/wallpapers/carol-menu-bg-gold-crane.jpg)"';
    grid.innerHTML = days.map(d => {
      const L = (arr) => arr && arr.length ? `<ul class="meal">${arr.map(x=>`<li>${x}</li>`).join('')}</ul>` : `<div class="meal" style="color:#b4b8c2">—</div>`;
      return `
        <article class="card">
          <div class="top"><div>Day ${d.day}</div><div class="badge">B/L/D/S</div></div>
          <div class="body" ${bg}>
            <div><strong>Breakfast</strong>${L(d.breakfast)}</div>
            <div><strong>Lunch</strong>${L(d.lunch)}</div>
            <div><strong>Dinner</strong>${L(d.dinner)}</div>
            <div><strong>Snacks</strong>${L(d.snacks)}</div>
          </div>
        </article>
      `;
    }).join('');
  }

  // Load pointer
  let pointer = await fetchJson(pointerUrl);
  if (!pointer) pointer = {};
  if (window.CAROL_DEBUG) debugBox.textContent = "Debug mode ON\n";

  const planCandidates = [];
  if (pointer.activePlan) planCandidates.push(pointer.activePlan);
  planCandidates.push(...fallbackPlans);

  let raw = null, chosen = null;
  for (const url of planCandidates) {
    const data = await fetchJson(url);
    if (data) { raw = data; chosen = url; break; }
  }

  if (!raw) {
    grid.innerHTML = `<div class="notice">Could not load any plan. Check that your plan JSON exists, or edit <code>pages/apps/carol/index.json</code> to point to the correct plan.</div>`;
    log('No plan loaded');
    return;
  }

  log('Using plan:', chosen);
  const days = normalizePlan(raw);
  render(days);
})();