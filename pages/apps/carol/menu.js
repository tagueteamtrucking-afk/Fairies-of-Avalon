
(async () => {
  const daysEl = document.getElementById('days');
  const sourceEl = document.getElementById('source');

  function swapDiet(text) {
    if (!text) return text;
    // sunflower seed butter swap and softer alternatives wording
    let t = String(text);
    t = t.replace(/\bpeanut butter\b/gi, 'sunflower seed butter');
    t = t.replace(/\bpeanuts\b/gi, 'sunflower seeds');
    return t;
  }
  function normalizeMealValue(v) {
    if (!v) return [];
    if (Array.isArray(v)) return v.map(x => swapDiet(typeof x === 'string' ? x : JSON.stringify(x)));
    if (typeof v === 'string') return [swapDiet(v)];
    if (typeof v === 'object') {
      // Try common shapes
      if (Array.isArray(v.items)) return v.items.map(x=>swapDiet(typeof x==='string'?x:(x.name||JSON.stringify(x))));
      if (Array.isArray(v.menu)) return v.menu.map(x=>swapDiet(typeof x==='string'?x:(x.name||JSON.stringify(x))));
      if (Array.isArray(v.list)) return v.list.map(x=>swapDiet(typeof x==='string'?x:(x.name||JSON.stringify(x))));
      return [swapDiet(JSON.stringify(v))];
    }
    return [swapDiet(String(v))];
  }
  function extractDayMeals(day) {
    const keys = Object.keys(day || {});
    const find = (names) => {
      for (const n of names) {
        const k = keys.find(k => k.toLowerCase() === n.toLowerCase());
        if (k) return day[k];
      }
      return undefined;
    };
    const sections = [
      ['Breakfast','breakfast','bk','am'],
      ['Lunch','lunch','midday','noon'],
      ['Dinner','dinner','supper','pm'],
      ['Snacks','snacks','snack','extras']
    ].map(([label, ...alts]) => ({ label, value: find([label, ...alts]) }));
    // If totally custom, try a generic "meals" list
    if (sections.every(s => !s.value) && Array.isArray(day.meals)) {
      return day.meals.map(m => ({
        label: m.name || m.title || 'Meal',
        items: normalizeMealValue(m.items || m.menu || m.list || m)
      }));
    }
    // Map to items
    return sections.filter(s => s.value !== undefined).map(s => ({
      label: s.label,
      items: normalizeMealValue(s.value)
    }));
  }
  function extractDays(plan) {
    if (!plan) return [];
    if (Array.isArray(plan.days)) return plan.days;
    if (plan.plan && Array.isArray(plan.plan.days)) return plan.plan.days;
    const dayKeys = Array.from({length: 14}, (_,i)=>`Day ${i+1}`);
    const hasDayKeys = dayKeys.some(k => k in plan);
    if (hasDayKeys) return dayKeys.map(k => plan[k]).filter(Boolean);
    if (Array.isArray(plan.itinerary)) return plan.itinerary;
    if (Array.isArray(plan.menuDays)) return plan.menuDays;
    // single-week shape + 7-day
    const dayKeys7 = Array.from({length: 7}, (_,i)=>`Day ${i+1}`);
    if (dayKeys7.some(k => k in plan)) return dayKeys7.map(k => plan[k]).filter(Boolean);
    return [];
  }

  async function loadJSON(path) {
    const res = await fetch(path, {cache: 'no-store'});
    if (!res.ok) throw new Error(`Failed to load ${path}: ${res.status}`);
    return res.json();
  }

  // Load pointer
  let pointerPath = './index.json';
  let pointer;
  try {
    pointer = await loadJSON(pointerPath);
  } catch (e) {
    sourceEl.textContent = `Pointer missing: ${pointerPath}`;
    return;
  }
  const planPath = pointer.activePlan || 'plans/mealplan-dash-14d-current.json';
  sourceEl.textContent = `Plan: ${planPath}`;
  // swap hero if pointer has images
  if (pointer.heroImages?.menu) {
    document.querySelector('.hero').style.backgroundImage = `url('${pointer.heroImages.menu}')`;
  }

  // Load and render
  try {
    const plan = await loadJSON('/' + planPath.replace(/^\/?/, ''));
    const days = extractDays(plan);
    if (!days.length) {
      daysEl.innerHTML = `<div class="card day"><h3>No days found in plan</h3><div class="kv">Check JSON shape</div></div>`;
      return;
    }
    days.forEach((day, idx) => {
      const meals = extractDayMeals(day);
      const div = document.createElement('div');
      div.className = 'card day';
      const title = `Day ${idx+1}`;
      const inner = [`<h3>${title}</h3>`]
      if (!meals.length) {
        // Fallback: pretty-print the object (compact)
        inner.push(`<div class="kv">`+swapDiet(JSON.stringify(day)).replaceAll('"','&quot;')+`</div>`);
      } else {
        for (const m of meals) {
          inner.push(`<div class="meal"><h4>${m.label}</h4><div>${m.items.map(x=>`• ${x}`).join('<br/>')}</div></div>`);
        }
      }
      div.innerHTML = inner.join("");
      daysEl.appendChild(div);
    });
  } catch (err) {
    daysEl.innerHTML = `<div class="card day"><h3>Could not load plan</h3><div class="kv">${err.message}</div></div>`;
  }
})();
