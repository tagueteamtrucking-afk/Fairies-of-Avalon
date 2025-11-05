
// mealplan.js — renders ~7 mini‑meals per selected day; click a dish to view portions
window.CarolMealPlan = (function(){
  // Primary plan path from memory; fallback to a simpler path if repo root differs
  const PLAN_CANDIDATES = [
    "/avalon-carol-unique-2.9.4/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json",
    "/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json"
  ];

  const state = { plan: null, dayIndex: 0 };

  async function fetchFirstAvailable(urls){
    for(const url of urls){
      try {
        const res = await fetch(url, { cache: "no-store" });
        if(res.ok) return await res.json();
      } catch(_){ /* continue */ }
    }
    throw new Error("Meal plan JSON not found at expected locations.");
  }

  function buildDayOptions(plan, select){
    select.innerHTML = "";
    const days = plan.days || plan.Days || [];
    days.forEach((d, i) => {
      const opt = document.createElement("option");
      opt.value = String(i);
      const name = d.name || d.day || `Day ${i+1}`;
      opt.textContent = name;
      select.appendChild(opt);
    });
  }

  function kcal(n){ return typeof n==="number" ? `${Math.round(n)} kcal` : ""; }

  function normalizeEvents(day){
    // Support "events" or "meals" or similar; target ~7 mini‑meals
    const arr = day.events || day.meals || day.snacks || [];
    return arr;
  }

  function thumbFor(entry){
    // Use provided image if present; otherwise fall back to Tracy sample card
    return entry.image || "/assets/img/tracy-sample.png";
  }

  function renderDay(plan, index){
    const day = (plan.days || plan.Days || [])[index] || {};
    const events = normalizeEvents(day);
    const cards = document.getElementById("cards");
    const summary = document.getElementById("summary");
    cards.innerHTML = "";

    const totalKcal = (events || []).reduce((sum, e) => sum + (e.calories||e.kcal||0), 0);
    const approx = `${events.length} mini‑meals • ${Math.round(totalKcal||0)} kcal (approx)`;
    summary.textContent = approx;

    (events || []).forEach((e, idx) => {
      const card = document.createElement("article");
      card.className = "card";
      card.innerHTML = `
        <div class="thumb" style="background-image:url('${thumbFor(e)}')"></div>
        <div class="body">
          <div class="title">${e.title || e.name || "Untitled dish"}</div>
          <div class="meta">
            ${kcal(e.calories || e.kcal)} ${e.time ? " • " + e.time : ""}
          </div>
          <div class="actions">
            <button class="button" data-idx="${idx}">Portions & Details</button>
            ${Array.isArray(e.tags) ? e.tags.map(t=>`<span class="chip">${t}</span>`).join("") : ""}
          </div>
        </div>
      `;
      // clicking either the button or the image opens details
      card.querySelector(".button").addEventListener("click", () => openDetails(day, e));
      card.querySelector(".thumb").addEventListener("click", () => openDetails(day, e));
      cards.appendChild(card);
    });
  }

  function openDetails(day, entry){
    const modal = document.getElementById("modalBackdrop");
    const title = document.getElementById("modalTitle");
    const body = document.getElementById("modalBody");
    title.textContent = entry.title || entry.name || "Dish";
    const portions = entry.portions || entry.portion || entry.serving || entry.servings || {};
    const ing = entry.ingredients || entry.ings || [];
    const sodium = entry.sodium != null ? `${entry.sodium} mg sodium` : "";
    const sugar = entry.addedSugars != null ? `${entry.addedSugars} g added sugars` : "";
    const fiber = entry.fiber != null ? `${entry.fiber} g fiber` : "";
    const notes = entry.notes || "";

    function kv(key, val){
      return val ? `<div><strong>${key}:</strong> ${val}</div>` : "";
    }

    const portionList = Array.isArray(portions) ? portions.map(p=>`<li>${p}</li>`).join("") :
      Object.keys(portions).length ? Object.entries(portions).map(([k,v])=>`<li>${k}: ${v}</li>`).join("") :
      "<li>See ingredients and instructions for suggested serving sizes.</li>";

    const ingList = Array.isArray(ing) ? ing.map(i=>`<li>${i.qty ? i.qty + " " : ""}${i.item || i.name || i}</li>`).join("") : "";

    body.innerHTML = `
      <div class="meta">${kv("Time", entry.time||"")} ${kv("Calories", entry.calories||entry.kcal||"")} ${kv("Sodium", sodium)} ${kv("Added Sugars", sugar)} ${kv("Fiber", fiber)}</div>
      <h3>Portion Sizes</h3>
      <ul>${portionList}</ul>
      ${ingList ? "<h3>Ingredients</h3><ul>"+ingList+"</ul>" : ""}
      ${entry.instructions ? "<h3>Instructions</h3><p>"+entry.instructions+"</p>" : ""}
      ${notes ? "<h3>Notes</h3><p>"+notes+"</p>" : ""}
    `;
    modal.style.display = "flex";
    modal.setAttribute("aria-hidden", "false");
  }

  function wireModal(){
    const modal = document.getElementById("modalBackdrop");
    document.getElementById("modalClose").addEventListener("click", () => {
      modal.style.display = "none";
      modal.setAttribute("aria-hidden", "true");
    });
    modal.addEventListener("click", (e) => {
      if(e.target === modal){
        modal.style.display = "none";
        modal.setAttribute("aria-hidden", "true");
      }
    });
  }

  async function init(){
    wireModal();
    // side toggle for building skin
    const skinEl = document.getElementById("phoenixSkin");
    document.getElementById("toggleSide").addEventListener("click", () => window.AvalonSkins.toggle(skinEl));

    const plan = await fetchFirstAvailable(PLAN_CANDIDATES);
    state.plan = plan;

    const select = document.getElementById("daySelect");
    buildDayOptions(plan, select);
    select.addEventListener("change", (e) => {
      state.dayIndex = parseInt(e.target.value,10)||0;
      renderDay(state.plan, state.dayIndex);
    });

    // default to day 1
    select.value = "0";
    renderDay(plan, 0);
  }

  return { init };
})();
