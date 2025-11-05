# Fairies of Avalon Memory Summary

This document consolidates the current state of the Fairies of Avalon project.  It
collects character profiles, building descriptions, and overarching rules from
our repository and prior discussions.  Use this summary as a single source of
truth when designing new features or assets.

## Characters and homes

| Character | Home/Building | Role and key rooms | Notes |
|---|---|---|---|
| **Rey Czar & White Star** | **Palace / Grand Vault** | Administrators of Avalon.  The palace houses the Grand Vault where permissions and telemetry are managed. | These overseers gate releases and enforce style & clarity across the project. |
| **Abbey** | **Grand Vault** | Finance assistant.  Abbey handles the finance desk: she parses receipts and subscriptions, keeps the ledger tidy, and performs monthly roll‑ups.  Her work involves a **Mail Slot**, **Ledger Book** and **Abacus**. | Abbey does **not** manage CSV imports for others; earlier summaries incorrectly attributed those tasks to her. |
| **Alexandria** | **Gothic Library** | Storyteller and lore keeper.  She curates the story shelf and character sheets and will host a timeline explorer for brainstorming.  The library likely features tall bookshelves, stone arches and mythic décor. | Collaborates with Tracy on story illustrations and Stella on audio‑visual projects. |
| **Tracy** | **Cathedral Studio** | Avalon’s artist and skin designer.  The studio contains an **Easel**, **Clay Bust**, **Palette** and **Light Table**.  Tracy produces skins, posters, wallpapers and VRM props and experiments with different art styles. | Responsible for visual continuity across campaigns and quests. |
| **Charlotte** | **Relay Hall** | Combines the former roles of Charlotte and Nina.  She manages translations, message queues, expirations and reminders, and oversees 3‑D fabrication and infrastructure.  The hall includes a **Control Wall**, **Calendarium Shelf** and **Clipboard**. | Nina has merged into Charlotte and is no longer a separate character. |
| **Billie** | **Superstar Mansion** | Monetisation and social‑media manager.  Her mansion features a **Camera Rig**, **Storyboard Wall**, **Analytics Screen**, **Wardrobe Rack** and a secret door. | Oversees grants, campaigns and content creation. |
| **Carol** | **Phoenix Kitchen / Restaurant** | Nutrition assistant.  She plans meals, generates shopping lists and produces nutrition reports based on DASH and reduced‑sodium guidelines.  The kitchen includes a **Menu Board**, **Pantry Shelf**, **Recipe Book** and **Bell**. | Carol’s meal planner follows a two‑week plan with six to eight eating events per day.  Feedback (ratings and notes) influences future plans. |
| **Jem** | **Dojo** | Fitness trainer.  Jem offers a fitness planner, workout calendar and progress tracker.  Week 1 focuses on evaluation and warm‑up, with a **Training Dummy**, **Chalkboard** and **Mat**. | Subsequent weeks emphasise medically proven exercises and gradual progression. |
| **Stella** | **Observatory / Apothecary** | Voice and sound assistant.  She provides text‑to‑speech, a sound library and guided meditation sessions.  Her room combines an **Observatory** (with **Telescope**) and an **Apothecary** (with **Chimes**). | Future enhancements include custom meditation scripts using binaural beats. |

## High‑fantasy palace and town

To support the new Camelot‑inspired visuals requested for Avalon, a **Palace** and
**Town** have been added to the asset pool.  Each new building has `inside`
and `outside` backgrounds.  These backgrounds are currently derived from
generic fantasy art and can be replaced with high‑resolution art later.  The
buildings serve as settings for Rey Czar & White Star (Palace) and for
miscellaneous scenes and gatherings (Town).  When using the `building-skin`
component, specify `data-building="palace"` or `data-building="town"` and
`data-side="inside|outside"` to apply these skins.

## Key rules

* **Truthfulness:** Always tell the truth.  Base statements on verifiable,
  up‑to‑date sources; cite external facts.  If something is unknown, say so
  plainly.
* **Consistency:** Keep names consistent across documents; never invent
  aliases or conflicting labels.
* **Precision over conciseness:** Explain steps clearly in plain English
  before adding technical detail.  Avoid ambiguous instructions.
* **Clarification & verification:** If you are less than 97 % confident about
  intent or constraints, ask targeted clarifying questions.  Verify
  information instead of speculating.
* **Packaging:** On iPad deployments, deliver two ZIPs—one containing the
  website content (without a `.github/` prefix) and another for additional
  assets.  Do not package `.github` inside the content ZIP.
* **Placeholders:** Do not use placeholders.  Provide full implementations
  or go beyond basic scaffolding.
* **Security and secrets:** Use real access control via edge workers or
  server sessions.  Store secrets in platform environment variables or
  GitHub Actions secrets; never embed them in client code.
* **Workflows first:** Prefer server‑side workflows and artifacts over
  running tasks from the root directory, especially for iPad deployments.
* **Whole file replacements:** Provide full file replacements instead of
  ambiguous diffs.  Before restructuring code or plans, analyse the entire
  repository and ask which path to take unless 97 % certain.
* **Continuous improvement:** Always look for inefficiencies or
  inconsistencies across the entire repo and domain.  Update or upgrade
  anything that can be improved.

## Meal‑planning rules

* **Six‑to‑eight events per day:** Each day in the plan includes six to
  eight mini‑meals or snacks.  This equates to roughly seven events per day.
* **Balanced nutrition:** Meals must follow the DASH diet, with reduced
  sodium and added sugars, lactose‑light ingredients and soft/well‑cooked
  foods.  Nutritional information (calories, sodium, added sugars, fibre)
  and portion sizes are specified for each event.
* **Feedback mechanism:** Users can rate each meal (1–5 stars) and record
  notes.  Ratings and notes are stored locally and should influence future
  menu generation without modifying the source plan.
* **Shopping list doubling:** Plans are for two people, so ingredient
  quantities should be doubled when compiling shopping lists.
* **Shopping list sizing:** When compiling the shopping list, double the
  quantities for two servings and use standard grocery store sizes for
  ingredients.  For example, if a recipe calls for one cup of rice for
  a single serving, the shopping list should include two cups of rice,
  or the nearest package size available at a typical supermarket.
* **Do not replace user‑provided art:** Custom artwork stored in
  `assets/img` should not be replaced without explicit permission.  If
  images are missing, restore them from the repository.

### Recent fix – Common CSS and skins

In early November 2025 a bug was discovered where new skins for Carol’s
kitchen and the Camelot‑style palace/town did not appear on the live
pages.  Investigation showed that the pages were still referencing the
legacy `common/style.css` for background images, while our patches only
modified `avalon.css`.  As a result, the old CSS continued to load
backgrounds like `/assets/img/carol-kitchen-outside.jpg`, ignoring the
new files.  To resolve this:

* A new file `pages/apps/common/style.css` was created, mirroring the
  original stylesheet but updating `.carol-inside` and `.carol-outside`
  to point to `carol-kitchen-inside.jpg` and `carol-kitchen-outside.jpg`
  in the repository.  New `.palace-*` and `.town-*` classes were also
  added.
* Carol’s HTML pages (`index.html`, `meal-plan.html` and
  `shopping-list.html`) were updated to load `../common/style.css` before
  the Avalon theme CSS.  Without explicitly loading this updated
  stylesheet, browsers would continue using the old backgrounds.

After applying these changes and clearing browser caches, the new
backgrounds should display correctly on the site.

### Fixing invalid background images

In late November 2025 another issue emerged: even after updating
`common/style.css`, the new backgrounds still did not appear on Carol’s
kitchen pages or the Palace/Town scenes.  Investigation revealed that
several image files in `assets/img` were corrupt – they were actually
patch diffs accidentally saved with `.jpg`/`.png` extensions.  When
browsers attempted to load these files, they displayed snippets of code
rather than imagery, causing a “glitched” appearance.  The affected
files included `carol-kitchen-outside.jpg`, `palace-outside.png`,
`town-outside.png` and `default-outside.png`.

To resolve this, the invalid images were replaced with working art.
Because sourcing new high‑resolution Camelot scenes was not possible at
the time, we reused the fantasy kitchen artwork already present in
`palace-inside.png`.  Using Python’s Pillow library, we created
brightened versions of this image to serve as “outside” views and
saved them as `palace-outside.png`, `town-outside.png` and
`carol-kitchen-outside.jpg`.  The default fallback (`default-outside.png`)
was also regenerated.  Although these backgrounds depict an indoor
scene, the increased brightness evokes an open, sunlit ambience
appropriate for exterior settings until custom art is available.  These
new files are now valid images and prevent the glitch.

Remember that high‑fantasy palace or town artwork can be added later by
replacing the corresponding files in `assets/img/`.  For now, the same
kitchen artwork is used for all inside and outside views to ensure
consistency and reliability.

### Removing outdated on‑site notes

Previous versions of Carol’s Kitchen (`index.html`) included a note
encouraging users to navigate using the links above and describing the
Meal Planner and Shopping List.  The note incorrectly stated that the
shopping list simply “compiles ingredients.”  In reality, the shopping
list doubles the ingredient quantities for two servings per meal and
selects standard grocery store sizes.  To avoid confusion and to keep
explanatory copy out of the user interface, this note has been removed
from the HTML and the accurate information recorded here in
`memory_summary.md`.
