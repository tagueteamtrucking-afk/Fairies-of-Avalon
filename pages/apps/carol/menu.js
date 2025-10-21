async function fetchJSON(url) {
  try {
    const r = await fetch(url, {cache: 'no-store'});
    if (!r.ok) return null;
    return await r.json();
  } catch (e) { return null; }
}

function setHero(url) {
  const hero = document.getElementById('hero');
  hero.style.backgroundImage = `linear-gradient(0deg, rgba(0,0,0,.55), rgba(0,0,0,.0)), url('${url}')`;
}

function setCardBg(url) {
  document.documentElement.style.setProperty('--card-bg', `url('${url}')`);
}

function showNotice(msg) {
  const el = document.getElementById('notice');
  el.style.display = 'block';
  el.textContent = msg;
}

// Normalize various plan shapes into [{day:1..14, meals:[{type,text}]}]
function normalizePlan(raw) {
  const out = [];
  const pushDay = (idx, mealsObj) => {
    const day = idx + 1;
    const meals = [];
    const map = (label, keys) => {
      for (const k of keys) {
        if (mealsObj?.[k]) { meals.push({type: label, text: mealsObj[k]}); return; }
      }
    };
    map('Breakfast', ['breakfast','Breakfast','AM','am']);
    map('Lunch',     ['lunch','Lunch','Midday','midday']);
    map('Dinner',    ['dinner','Dinner','PM','pm','supper']);
    // snacks
    const snackKeys = ['snacks','snack','Snack','Snack1','snack1','Snack2','snack2'];
    for (const k of snackKeys) {
      if (mealsObj?.[k]) {
        const v = mealsObj[k];
        if (Array.isArray(v)) v.forEach(s=> meals.push({type:'Snack', text:s}));
        else meals.push({type:'Snack', text:v});
      }
    }
    // If still empty, try generic keys
    if (meals.length===0) {
      Object.entries(mealsObj||{}).forEach(([k,v])=>{
        if (typeof v === 'string' && v.trim()) meals.push({type:k, text:v});
      });
    }
    out.push({day, meals});
  };

  // 1) Array of days: raw.days[] or raw[]
  if (Array.isArray(raw?.days)) {
    raw.days.slice(0,14).forEach((d,i)=> pushDay(i, d));
    return out;
  }
  if (Array.isArray(raw)) {
    raw.slice(0,14).forEach((d,i)=> pushDay(i, d));
    return out;
  }

  // 2) Object with "Day 1", "Day 2", ...
  const dayKeys = Object.keys(raw||{}).filter(k=>/^day\s*\d+$/i.test(k)).sort((a,b)=>{
    const ai = parseInt(a.match(/\d+/)?.[0]||'0',10);
    const bi = parseInt(b.match(/\d+/)?.[0]||'0',10);
    return ai-bi;
  });
  if (dayKeys.length) {
    dayKeys.slice(0,14).forEach((k,i)=> pushDay(i, raw[k]));
    return out;
  }

  // 3) Nested shapes common in older files
  if (raw?.plan?.days && Array.isArray(raw.plan.days)) {
    raw.plan.days.slice(0,14).forEach((d,i)=> pushDay(i, d));
    return out;
  }

  return null;
}

function applyDietNotes(text) {
  if (!text) return text;
  const lower = text.toLowerCase();
  if (lower.includes('peanut butter') || lower.includes('almond butter') || lower.includes('nut butter')) {
    return text.replace(/butter/gi, 'butter (use sunflower seed butter)');
  }
  if (lower.includes('peanuts')) {
    return text.replace(/peanuts/gi, 'sunflower seeds (or sunflower seed butter)');
  }
  // very hard/crunchy hints: show display note only
  return text;
}

function render(plan) {
  const grid = document.getElementById('grid');
  grid.innerHTML = '';
  plan.forEach(({day, meals})=>{
    const card = document.createElement('div');
    card.className='card';
    const h = document.createElement('header');
    h.innerHTML = `<h3>Day ${day}</h3>`;
    const b = document.createElement('div');
    b.className = 'body';
    const wrap = document.createElement('div');
    wrap.className = 'meals';
    meals.forEach(m=>{
      const row = document.createElement('div'); row.className='meal';
      const tag = document.createElement('div'); tag.className='tag'; tag.textContent = m.type;
      const txt = document.createElement('div'); txt.className='text'; txt.textContent = applyDietNotes(m.text||'');
      row.appendChild(tag); row.appendChild(txt); wrap.appendChild(row);
    });
    b.appendChild(wrap);
    card.appendChild(h); card.appendChild(b);
    grid.appendChild(card);
  });
}

(async function main(){
  const ptr = await fetchJSON('./index.json') || {};
  const img = ptr.images || {};
  if (img.heroMenu) setHero(img.heroMenu);
  if (img.cardBg) setCardBg(img.cardBg);

  const candidates = [];
  if (ptr.activePlan) candidates.push(ptr.activePlan);
  candidates.push(
    '/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json',
    '/pages/apps/carol/plans/twoperson-2wk-20251014T234049Z.json',
    '/pages/apps/carol/plans/mealplan-dash-14d-current.json',
    '/pages/apps/carol/plans/plan-14d-seeded.json',
    '/pages/apps/carol/plans/offline-twoperson-2wk-20251010T013559Z.json'
  );

  let raw=null, used=null;
  for (const p of candidates) {
    raw = await fetchJSON(p);
    if (raw) { used = p; break; }
  }
  if (!raw) {
    showNotice('No meal plan file found. Add one under /pages/apps/carol/plans/ then reload.');
    return;
  }

  const norm = normalizePlan(raw);
  if (!norm) {
    showNotice('Could not understand plan format. The page will be updated to support this schema.');
    return;
  }
  if (used && used!==ptr.activePlan) {
    showNotice(`Showing plan from: ${used}`);
  }
  render(norm);
})();