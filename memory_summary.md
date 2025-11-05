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
* **Do not replace user‑provided art:** Custom artwork stored in
  `assets/img` should not be replaced without explicit permission.  If
  images are missing, restore them from the repository.
