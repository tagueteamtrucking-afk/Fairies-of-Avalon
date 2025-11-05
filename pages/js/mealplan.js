/*
 * Meal plan rendering script
 *
 * This script fetches a two‑week meal plan and dynamically renders
 * approximately seven mini‑meals for each day. Users can select
 * a specific day from a dropdown list; the script will populate
 * the grid with that day's meals. Each meal card includes the dish
 * image (if provided) and a label; clicking the card opens a modal
 * with detailed portion sizes, ingredients and nutrition notes.
 *
 * The plan is pulled from a JSON file relative to the project. To
 * accommodate both local builds and environment‑specific paths,
 * the script checks two possible locations. If neither is found,
 * it gracefully displays an error message on the page.
 */

(function () {
  const daySelect = document.getElementById('day-select');
  const mealsGrid = document.getElementById('meals-grid');
  const modal = document.getElementById('meal-modal');
  const modalTitle = document.getElementById('modal-title');
  const modalBody = document.getElementById('modal-body');
  const modalClose = document.getElementById('modal-close');

  /**
   * Attempt to fetch the meal plan JSON from multiple known paths.
   * Returns the parsed JSON or null if both attempts fail.
   */
  async function loadMealPlan() {
    const endpoints = [
      '/avalon-carol-unique-2.9.4/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json',
      '/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json'
    ];
    for (const url of endpoints) {
      try {
        const res = await fetch(url);
        if (res.ok) {
          return await res.json();
        }
      } catch (e) {
        // continue to next
      }
    }
    return null;
  }

  /**
   * Populate the day dropdown based on the keys in the meal plan.
   */
  function populateDaySelect(plan) {
    const days = Object.keys(plan);
    days.sort();
    daySelect.innerHTML = '';
    days.forEach((day, idx) => {
      const option = document.createElement('option');
      option.value = day;
      option.textContent = day;
      // select first day by default
      if (idx === 0) option.selected = true;
      daySelect.appendChild(option);
    });
  }

  /**
   * Create an individual meal card element.
   */
  function createMealCard(meal) {
    const card = document.createElement('div');
    card.className = 'meal-card';
    const img = document.createElement('img');
    img.className = 'meal-image';
    // fallback to placeholder if missing
    img.src = meal.image || '/assets/img/tracy-sample.png';
    img.alt = meal.name;
    const name = document.createElement('div');
    name.className = 'meal-name';
    name.textContent = meal.name;
    card.appendChild(img);
    card.appendChild(name);
    card.addEventListener('click', () => showMealDetails(meal));
    return card;
  }

  /**
   * Render the meals for a given day.
   */
  function renderMealsForDay(day, plan) {
    const meals = plan[day] || [];
    mealsGrid.innerHTML = '';
    if (meals.length === 0) {
      const msg = document.createElement('p');
      msg.textContent = 'No meals found for this day.';
      mealsGrid.appendChild(msg);
      return;
    }
    meals.forEach((meal) => {
      mealsGrid.appendChild(createMealCard(meal));
    });
  }

  /**
   * Show meal details in a modal dialog.
   */
  function showMealDetails(meal) {
    modalTitle.textContent = meal.name;
    modalBody.innerHTML = '';
    const ul = document.createElement('ul');
    if (meal.portions) {
      meal.portions.forEach((p) => {
        const li = document.createElement('li');
        li.textContent = `${p.item}: ${p.amount}`;
        ul.appendChild(li);
      });
    }
    if (meal.ingredients) {
      const li = document.createElement('li');
      li.textContent = `Ingredients: ${meal.ingredients.join(', ')}`;
      ul.appendChild(li);
    }
    if (meal.notes) {
      const li = document.createElement('li');
      li.textContent = `Notes: ${meal.notes}`;
      ul.appendChild(li);
    }
    if (meal.nutrition) {
      const li = document.createElement('li');
      li.textContent = `Nutrition: ${meal.nutrition}`;
      ul.appendChild(li);
    }
    modalBody.appendChild(ul);
    modal.classList.remove('hidden');
  }

  /**
   * Hide the modal when closed.
   */
  function hideModal() {
    modal.classList.add('hidden');
  }

  // Event listeners
  modalClose.addEventListener('click', hideModal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) hideModal();
  });
  daySelect.addEventListener('change', (e) => {
    const selectedDay = e.target.value;
    renderMealsForDay(selectedDay, window.mealPlanData);
  });

  // Initialize: load plan and render
  (async function init() {
    const plan = await loadMealPlan();
    if (!plan) {
      mealsGrid.innerHTML = '<p class="error">Unable to load meal plan. Please ensure the JSON file exists in the correct directory.</p>';
      return;
    }
    window.mealPlanData = plan;
    populateDaySelect(plan);
    // Render the first day by default
    const firstDay = daySelect.value;
    renderMealsForDay(firstDay, plan);
  })();
})();