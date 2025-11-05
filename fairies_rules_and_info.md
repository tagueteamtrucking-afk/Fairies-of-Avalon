# Fairies of Avalon – Rules and Information

This document aggregates the core guidelines and constraints governing the
Fairies of Avalon project.  It should be consulted before performing any
updates, creating new assets or writing code within the Avalon repository.  The
rules below are distilled from project memory files and user‑defined
instructions.

## Core principles

1. **Truthfulness and transparency** – Always provide honest, verifiable
   information.  If you are uncertain about a fact or external data is
   unavailable, say so plainly.  Never fabricate or mislead.

2. **Consistency** – Maintain consistent names, labels and terminology across
   all documents and files.  Avoid inventing aliases or conflicting labels for
   characters, buildings, or functions.

3. **Precision over conciseness** – When giving instructions or explanations,
   favour clear, step‑by‑step descriptions.  Provide high‑level summaries only
   after laying out the full context.  This reduces misinterpretation.

4. **Clarification and verification** – If you are less than 97 % confident
   about a user’s intent or the parameters of a task, ask targeted
   clarifying questions.  Verify assumptions rather than speculating.

5. **No placeholders** – Do not use empty scaffolds, dummy images or
   intentionally incomplete code.  When a feature must be implemented
   incrementally, go at least a few steps beyond a basic scaffold.

6. **Security and secrets** – Use proper authentication and environment
   variables for secrets.  Do not embed passwords, API keys or private data
   in client‑side code.  Respect platform‑specific ways to store secrets
   (GitHub Actions secrets, environment variables, etc.).

7. **Packaging** – When preparing builds for iPad or other deployments,
   produce two ZIP archives: one with the website content (without a
   `.github` prefix) and another with supplementary assets.  Avoid
   including `.github` folders in the content ZIP.

8. **Workflows first** – Prefer server‑side or CI/CD workflows to manage
   releases and assets.  Avoid running ad‑hoc tasks in the repository root
   when a reproducible pipeline exists.

9. **Whole file replacements** – When modifying code or content, provide
   complete file replacements rather than partial diffs, unless explicitly
   directed otherwise.  Before restructuring, survey the entire repository
   and confirm the intended approach.

10. **Continuous improvement** – Examine the codebase and assets for
    inefficiencies or inconsistencies.  When you find issues, propose or
    implement improvements while respecting the above rules.

## Character‑specific guidelines

* **Nina merged into Charlotte** – Nina is no longer a separate character.  All
  security, engineering and infrastructure tasks are now handled by
  Charlotte.  Do not refer to Nina as a current character.

* **Abbey’s role** – Abbey manages the finance desk in the Grand Vault.  She
  parses receipts and subscriptions, keeps the ledger tidy and performs
  monthly roll‑ups.  Earlier drafts incorrectly assigned CSV import duties to
  her; this has been corrected.  Do not attribute such tasks to Abbey.

* **Carol’s kitchen** – Carol’s meal planner follows a two‑week DASH‑pattern
  menu with six to eight events per day.  Users can rate meals (1–5 stars)
  and record notes.  These ratings and notes should influence future menus
  without altering the source plan.  Avoid resetting the planner to a
  three‑meal structure.

* **High‑fantasy palace and town** – Rey Czar & White Star reside in the
  Palace; a new Town setting is available for general scenes.  Both
  locations should evoke a Camelot‑like, high‑fantasy aesthetic.  Custom
  backgrounds can be added via `assets/img/` (e.g., `palace-inside.png`,
  `town-outside.png`).  Do not repurpose existing character skins for the
  palace or town without explicit permission.

## Meal planner logic

* **Plan source** – The official two‑week meal plan is stored in
  `avalon-carol-unique-2.9.4/pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json`.  Use this
  version whenever available, falling back to local `plans/` or `data/`
  copies only if necessary.

* **Ratings and notes** – Use `localStorage` keys such as `carolMeal-<name>-rating`
  and `carolMeal-<name>-note` to persist user feedback.  Do not write
  directly to the plan JSON.  Provide helper functions to retrieve and save
  ratings and notes.

* **Future menus** – While the current system does not generate new meal
  plans automatically, a future enhancement may read saved ratings and
  avoid low‑rated meals.  Design your code so that such an enhancement can
  access the stored preferences easily.
