(async () => {
  const base = location.pathname.replace(/\/[^/]*$/, '');
  async function getJSON(path){
    const res = await fetch(path, {cache:'no-store'});
    if(!res.ok) throw new Error(`Fetch failed ${res.status}: ${path}`);
    return res.json();
  }
  function pick(obj, paths){
    for(const p of paths){
      try{
        const v = p.split('.').reduce((o,k)=>o?.[k], obj);
        if(v !== undefined) return v;
      }catch{}
    }
    return undefined;
  }
  function normalizeMealText(t){
    if(!t) return t;
    const s = String(t);
    // Apply diet swaps (simple presentation swap only)
    return s.replace(/peanut\s*butter/gi, 'sunflower seed butter');
  }
  function normalizeDay(dayLike){
    if(!dayLike) return null;
    // Try common shapes
    let b = pick(dayLike, ['breakfast','meals.breakfast','meal.breakfast']);
    let l = pick(dayLike, ['lunch','meals.lunch','meal.lunch']);
    let d = pick(dayLike, ['dinner','meals.dinner','meal.dinner']);
    let s = pick(dayLike, ['snacks','meals.snacks','meal.snacks','snack']);
    const label = dayLike.day || dayLike.name || dayLike.title;
    // flatten arrays/strings
    const asArr = v => v==null ? [] : Array.isArray(v) ? v : [String(v)];
    return {
      label,
      breakfast: asArr(b).map(normalizeMealText),
      lunch: asArr(l).map(normalizeMealText),
      dinner: asArr(d).map(normalizeMealText),
      snacks: asArr(s).map(normalizeMealText),
      raw: dayLike
    };
  }
  function inferDays(json){
    if(Array.isArray(json)){
      // maybe array of days
      const days = json.map(normalizeDay).filter(Boolean);
      if(days.length) return days;
    }
    if(json && typeof json === 'object'){
      if(Array.isArray(json.days)) {
        const days = json.days.map(normalizeDay).filter(Boolean);
        if(days.length) return days;
      }
      if(json.plan && Array.isArray(json.plan.days)){
        const days = json.plan.days.map(normalizeDay).filter(Boolean);
        if(days.length) return days;
      }
      // object with Day 1..Day 14 keys
      const dayKeys = Object.keys(json).filter(k => /^day\s*\d+/i.test(k));
      if(dayKeys.length){
        const days = dayKeys.sort((a,b)=>{
          const ai = parseInt(a.replace(/\D/g,''))||0;
          const bi = parseInt(b.replace(/\D/g,''))||0;
          return ai-bi;
        }).map(k => normalizeDay(json[k]));
        if(days.length) return days;
      }
    }
    return [];
  }

  const grid = document.getElementById('grid');
  const planNameEl = document.getElementById('planName');
  const noticeEl = document.getElementById('notice');

  let pointer;
  try{
    pointer = await getJSON('./index.json');
  }catch(e){
    noticeEl.style.display='block';
    noticeEl.textContent = 'Pointer file missing (pages/apps/carol/index.json).';
    return;
  }

  const candidates = [pointer.active_plan, pointer.fallback_plan].filter(Boolean);
  let plan, planPath, planJSON;
  for(const rel of candidates){
    if(!rel) continue;
    const path = './' + rel.replace(/^\.?\/?/,''); // ensure relative path
    try{
      planJSON = await getJSON(path);
      planPath = path;
      plan = inferDays(planJSON);
      if(plan.length) break;
    }catch{ /* try next */ }
  }
  if(!planPath){
    noticeEl.style.display='block';
    noticeEl.textContent = 'No plan file could be loaded. Please ensure the pointer has a valid active_plan path.';
    return;
  }
  planNameEl.textContent = planPath.replace(/^\.\//,'');

  if(!plan.length){
    // Show raw and explain
    noticeEl.style.display='block';
    noticeEl.innerHTML = 'Plan file loaded, but I could not infer meals. Showing raw JSON below for inspection.';
    const pre = document.createElement('pre');
    pre.className = 'kv';
    pre.textContent = JSON.stringify(planJSON,null,2);
    noticeEl.appendChild(pre);
    return;
  }

  // Render cards for up to 14 days
  plan.slice(0,14).forEach((day, idx) => {
    const card = document.createElement('section');
    card.className = 'card';
    const head = document.createElement('div');
    head.className = 'head';
    head.innerHTML = `Day ${idx+1} ${day.label? '<span class="badge">'+day.label+'</span>':''}`;
    const ul = document.createElement('ul');
    const add = (label, items) => {
      if(!items || !items.length) return;
      const li = document.createElement('li');
      li.innerHTML = `<strong>${label}:</strong> ${items.map(x=>normalizeMealText(x)).join('; ')}`;
      ul.appendChild(li);
    };
    add('Breakfast', day.breakfast);
    add('Lunch', day.lunch);
    add('Dinner', day.dinner);
    add('Snacks', day.snacks);
    if(!ul.childElementCount){
      const li = document.createElement('li');
      li.textContent = 'No meals found for this day.';
      ul.appendChild(li);
    }
    card.appendChild(head);
    card.appendChild(ul);
    grid.appendChild(card);
  });
})();
