// Carol two‑week meal plan script
// This script fetches the two‑week plan and renders approximately seven mini meals
// per day. Users can select a day from a dropdown. Each event (snack or mini‑meal)
// appears as a card; clicking a card opens a modal with portion sizes, nutrition
// facts and instructions.

(function () {
  const daySelect = document.getElementById('day-select');
  const mealsGrid = document.getElementById('meals-grid');
  const modal = document.getElementById('meal-modal');
  const modalTitle = document.getElementById('modal-title');
  const modalBody = document.getElementById('modal-body');
  const modalClose = document.getElementById('modal-close');

  /**
   * Fetch the meal plan JSON from possible paths. Returns the parsed JSON or null.
   */
  async function loadPlan() {
    /*
     * Attempt to fetch Carol’s two‑week plan from multiple locations.  The official
     * plan lives under a versioned folder (avalon‑carol‑unique‑2.9.4) and
     * contains all fourteen days.  However, some deployments still host a
     * truncated plan under the local data/ directory with only two days.  We
     * iterate through a list of potential paths and return the first plan
     * that loads successfully.  If none of the sources respond, we return
     * null so the UI can show an error.
     */
    const candidatePaths = [
      // Preferred: full two‑week plan in the versioned folder.  Use a
      // relative path from meal-plan.html (pages/apps/carol/) to the root.
      '../../../avalon-carol-unique-2.9.4/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json',
      // Fallback: a local copy in a plans folder (if added to the repo)
      'plans/twoperson-2wk-unique-20251015T022300Z.json',
      '../plans/twoperson-2wk-unique-20251015T022300Z.json',
      // Legacy: truncated plan in data directory
      'data/twoperson-2wk-unique-20251015T022300Z.json',
      '../data/twoperson-2wk-unique-20251015T022300Z.json'
    ];
    for (const path of candidatePaths) {
      try {
        const resp = await fetch(path);
        if (resp.ok) {
          const json = await resp.json();
          // Ensure we have a days array with more than two days; otherwise keep looking
          if (Array.isArray(json.days) && json.days.length >= 2) {
            return json;
          }
        }
      } catch (e) {
        // ignore fetch errors and try next path
      }
    }
    return null;
  }

  /**
   * Populate the day dropdown using the `days` array from the plan.
   */
  function populateDaySelect(plan) {
    daySelect.innerHTML = '';
    plan.days.forEach((day, idx) => {
      const option = document.createElement('option');
      option.value = day.index;
      option.textContent = day.day_label || `Day ${idx + 1}`;
      if (idx === 0) option.selected = true;
      daySelect.appendChild(option);
    });
  }

  /**
   * Create a meal card for an event.
   */
  function createMealCard(event) {
    const card = document.createElement('div');
    card.className = 'meal-card';
    // Each meal card shows only the meal name; we intentionally omit a photo
    // because the plan does not provide specific images for each dish.  Using a
    // generic placeholder for every meal proved confusing in earlier versions.
    const nameDiv = document.createElement('div');
    nameDiv.className = 'meal-name';
    nameDiv.textContent = event.name;
    card.appendChild(nameDiv);
    card.addEventListener('click', () => showMealDetails(event));
    return card;
  }

  /**
   * Render the events for a specific day index.
   */
  function renderMealsForDay(dayIndex, plan) {
    const day = plan.days.find((d) => String(d.index) === String(dayIndex));
    mealsGrid.innerHTML = '';
    if (!day || !day.events || day.events.length === 0) {
      const msg = document.createElement('p');
      msg.textContent = 'No meals found for this day.';
      mealsGrid.appendChild(msg);
      return;
    }
    day.events.forEach((event) => {
      mealsGrid.appendChild(createMealCard(event));
    });
  }

  /**
   * Show event details in the modal.
   */
  function showMealDetails(event) {
    modalTitle.textContent = event.name;
    modalBody.innerHTML = '';
    const fragments = [];

    // Helper functions for localStorage persistence
    function storageKey(base) {
      // Normalize event name to create a safe key
      const safeName = event.name.replace(/[^a-zA-Z0-9]/g, '');
      return `carolMeal-${safeName}-${base}`;
    }
    function getSavedRating() {
      const val = localStorage.getItem(storageKey('rating'));
      return val ? parseInt(val, 10) : 0;
    }
    function setSavedRating(r) {
      localStorage.setItem(storageKey('rating'), String(r));
    }
    function getSavedNote() {
      return localStorage.getItem(storageKey('note')) || '';
    }
    function setSavedNote(note) {
      localStorage.setItem(storageKey('note'), note);
    }

    // Rating UI
    const ratingDiv = document.createElement('div');
    ratingDiv.className = 'rating-container';
    let currentRating = getSavedRating();
    function renderStars() {
      ratingDiv.innerHTML = '';
      for (let i = 1; i <= 5; i++) {
        const star = document.createElement('span');
        star.className = 'rating-star' + (i <= currentRating ? ' selected' : '');
        star.textContent = '★';
        star.addEventListener('click', () => {
          currentRating = i;
          setSavedRating(i);
          renderStars();
        });
        ratingDiv.appendChild(star);
      }
    }
    renderStars();
    fragments.push(ratingDiv);

    // Notes UI
    const noteSection = document.createElement('div');
    noteSection.className = 'note-section';
    const noteLabel = document.createElement('strong');
    noteLabel.textContent = 'Notes:';
    const textarea = document.createElement('textarea');
    textarea.value = getSavedNote();
    textarea.addEventListener('input', (e) => {
      setSavedNote(e.target.value);
    });
    noteSection.appendChild(noteLabel);
    noteSection.appendChild(document.createElement('br'));
    noteSection.appendChild(textarea);
    fragments.push(noteSection);
    // Portion sizes / ingredients
    if (event.items && event.items.length > 0) {
      const itemsList = document.createElement('ul');
      event.items.forEach((item) => {
        const li = document.createElement('li');
        const quantity = item.quantity !== undefined ? item.quantity : '';
        const unit = item.unit || '';
        const notes = item.notes ? ` (${item.notes})` : '';
        li.textContent = `${quantity} ${unit} ${item.ingredient}${notes}`.trim();
        itemsList.appendChild(li);
      });
      const section = document.createElement('div');
      const header = document.createElement('strong');
      header.textContent = 'Portion sizes:';
      section.appendChild(header);
      section.appendChild(itemsList);
      fragments.push(section);
    }
    // Nutrition info
    const nutritionFields = ['kcal', 'sodium_mg', 'added_sugars_g', 'fiber_g'];
    const nutritionLabels = {
      kcal: 'Calories',
      sodium_mg: 'Sodium (mg)',
      added_sugars_g: 'Added sugars (g)',
      fiber_g: 'Fiber (g)'
    };
    const nutrition = document.createElement('p');
    const parts = [];
    nutritionFields.forEach((key) => {
      if (event[key] !== undefined) {
        parts.push(`${nutritionLabels[key]}: ${event[key]}`);
      }
    });
    if (parts.length > 0) {
      nutrition.innerHTML = '<strong>Nutrition:</strong> ' + parts.join(' | ');
      fragments.push(nutrition);
    }
    // Instructions
    if (event.instructions && event.instructions.length > 0) {
      const instrSection = document.createElement('div');
      const header = document.createElement('strong');
      header.textContent = 'Instructions:';
      instrSection.appendChild(header);
      const ul = document.createElement('ul');
      event.instructions.forEach((step) => {
        const li = document.createElement('li');
        li.textContent = step;
        ul.appendChild(li);
      });
      instrSection.appendChild(ul);
      fragments.push(instrSection);
    }
    // Append all fragments to modal body
    fragments.forEach((el) => modalBody.appendChild(el));
    modal.classList.remove('hidden');
  }

  /**
   * Hide modal when clicking close or outside.
   */
  function hideModal() {
    modal.classList.add('hidden');
  }
  modalClose.addEventListener('click', hideModal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) hideModal();
  });
  daySelect.addEventListener('change', (e) => {
    renderMealsForDay(e.target.value, window.carolPlanData);
  });

  // Initialize
  (async function init() {
    const plan = await loadPlan();
    if (!plan) {
      mealsGrid.innerHTML = '<p class="error">Unable to load meal plan. Please ensure the JSON file exists.</p>';
      return;
    }
    window.carolPlanData = plan;
    populateDaySelect(plan);
    // Render first day
    const firstDay = daySelect.value;
    renderMealsForDay(firstDay, plan);
  })();
})();