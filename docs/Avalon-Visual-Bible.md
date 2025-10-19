# Avalon — Visual & Lore Bible (City‑Builder Edition)
**Build stamp:** 20251019T224810Z

This document describes the **visual design** of Avalon as a mobile, city‑builder style world. It focuses on how the **buildings**, **rooms**, and **in‑room links** should look and behave. (Core app functionality is handled separately.)

---

## 1) World concept
Avalon is a **living city** that **levels up** visually as its AI assistants grow in capability. The starting state is cozy and simple; over time, buildings gain detail, lighting, and animated life.

- **Map:** A stylized **castle‑town**. The **Palace** is central; specialized buildings surround it.
- **Interaction:** Tap **buildings** to open each assistant’s **room**. Inside rooms, tap **decorative objects** that **look like tools** to open each mini‑app.
- **No placeholders:** Even day‑one visuals use purposeful art (no blank cards).

---

## 2) Characters & buildings (after merges)
**Overseers (Ray & Blanca)** — *Palace (avatars only, no workload)*  
- Visual: Regal **Palace** terrace with banners showing **project progress** and achievements.
- Room links: Progress gallery; photo booth; avatars showcase.

**Alexandria — Gothic Library (DM/Worldbuilding)**  
- Building: Stone **Library** with leaded glass windows, glowing sconces.
- Room: **Desk** (recents), **Bookshelves** (stories & character sheets), **Globe** (worlds & maps), **Corkboard** (campaigns).
- Links: `World Rules`, `Session Log`, `Voice DM` (distinct DM voice).

**Tracy — Cathedral Studio (Art & Wallpapers)**  
- Building: Old **Cathedral studio** with stained glass.
- Room: **Easel** (2D artboards), **Clay bust** (3D/VRM props), **Palette** (wallpapers), **Light table** (exports).

**Nina (merged with Clarice) — Court‑Lab (Security/Code + 3D/VRM)**  
- Building: **Courtroom + Holographic Lab** fusion (Clarice’s structure with Nina’s tech).
- Room: **Server rack** (backups & diagnostics), **VRM hanger** (avatars), **Hologram table** (3D previews).
- Links: `Diagnostics`, `Backups/Snapshots`, `VRM Gallery`.

**Charlotte (absorbed Themis) — Relay‑Hall (Pipelines + Compliance)**  
- Building: **Relay tower** integrated into a **Record Hall** (scrolls, statues).
- Room: **Control wall** (workflow triggers), **Calendarium shelf** (expirations & reminders), **Clipboard** (link registry).
- Links: `Run Workflows`, `Expirations`, `Link Registry`.

**Carol — Restaurant (Nutrition)**  
- Building: Warm **Restaurant** with open kitchen.
- Room: **Menu board** (14‑day plan), **Pantry shelf** (shopping list), **Recipe book** (cookbook), **Bell** (meal alarms).
- Dietary guardrails: **DASH‑style**, **lactose‑light**, **shellfish‑free**, **no cilantro/cumin**, **avoid very hard foods**.  
  *Allowed updates:* tuna, salmon, cod, sushi, eggs, steamed baby carrots, frozen/fresh fruits.

**Jem — Dojo (Coaching/Fitness)**  
- Building: Quiet **Dojo** with tatami and lanterns.
- Room: **Training dummy** (Week‑1 tests), **Chalkboard** (plan), **Mat** (guided sessions), **Belt rack** (progress).
- Links: `Week‑1 Evaluation`, `Program Viewer`, `Progress Log`.

**Stella — Observatory (Meditation/Guided Audio)**  
- Building: **Observatory** dome under stars.
- Room: **Telescope** (focus), **Chime set** (relax), **Cushion** (gateway practices).
- Links: `Guided Audio (Success/Focus/Gratitude/Gateway/Relax)` (distinct voice from Alexandria).

**Abbey — Grand Vault (Finance)**  
- Building: Marble **Vault** with bronze doors.
- Room: **Mail slot** (CSV imports), **Ledger book** (totals), **Abacus** (budget).
- Links: `Import CSV`, `Ledger`, `Budgets`.

**Billie Nair (absorbed Sorcha & Odessa) — Superstar Mansion (Social + Monetization)**  
- Building: Large **Mansion with pool**, cinema light bars. Hidden **basement** via secret passage (for 18+ content).  
- Room: **Camera rig** (video workshop), **Storyboard wall** (campaigns), **Analytics screen** (growth), **Merch rack** (shops), **Secret door** (age‑gated premium).  
- Links: `Video Studio`, `Storyboards`, `Analytics`, `Merch`, `Members (18+)`.
- **Safety & compliance**: host any 18+ materials **off GitHub Pages**, require **age verification**, **explicit consent**, and **no real‑person deepfakes**. This design bible **does not** provide explicit content generation steps.

---

## 3) City map & leveling
- **Level 1 (Foundations):** Buildings appear as **simplified silhouettes** with labels; interiors show a few interactive props.
- **Level 2 (Crafted):** Textures, lighting, animated accents; rooms gain more props; building exteriors reflect progress badges.
- **Level 3 (Alive):** Parallax background, day/night tinting; soft ambient audio by Stella; animated crowds; seasonal themes.

**Map tokens (mobile‑first):**
- Tap targets ≥ 44×44 px.  
- Palette: midnight blues (#0b1220, #111a2a), accents (#a5d6ff), panel strokes (#1c2842).  
- Typography: Inter/Roboto/Segoe UI; display headings with small caps.

---

## 4) Room object → App link mapping
| Assistant | Object (visual) | Opens |
|---|---|---|
| Alexandria | Globe | World rules & maps |
| Alexandria | Bookshelves | Stories & character sheets |
| Alexandria | Corkboard | Campaigns (recents) |
| Tracy | Easel | 2D artboards |
| Tracy | Clay bust | 3D props / VRM |
| Tracy | Palette | Wallpapers tool |
| Nina | Server rack | Diagnostics & backups |
| Nina | Hologram table | 3D previews/VRM |
| Charlotte | Control wall | Workflow triggers |
| Charlotte | Calendarium shelf | Expirations & reminders |
| Charlotte | Clipboard | Link registry |
| Carol | Menu board | 14‑day menu |
| Carol | Pantry shelf | Shopping list (2p sizing) |
| Carol | Recipe book | Cookbook/how‑to |
| Carol | Bell | Meal alarms (.ics) |
| Jem | Training dummy | Week‑1 evaluation |
| Jem | Chalkboard | Plan viewer |
| Jem | Mat | Guided sessions |
| Abbey | Mail slot | CSV importer |
| Abbey | Ledger book | Ledger/Reports |
| Abbey | Abacus | Budgets |
| Stella | Telescope | Focus/Success programs |
| Stella | Chimes | Relax/Gratitude programs |
| Billie | Camera rig | Video studio (faceless/social) |
| Billie | Storyboard wall | Campaign planning |
| Billie | Analytics screen | Growth & revenue |
| Billie | Wardrobe rack | Merch/shops |
| Billie | Secret door | Members (18+) off‑site |

---

## 5) UI Kit (tokens)
Use `var(--*)` tokens. See `ui/ui-kit.css` in this pack.

---

## 6) Art briefs (for illustrators or image models)
Short prompts are included under `prompts/`. Produce **exterior** and **interior** art for each building. Keep PG visuals for Pages. Any 18+ materials must be produced and hosted **off‑site** with strong compliance.

---

## 7) File map added in this pack
- `city/city-map.svg` — lightweight clickable map skeleton.
- `city/city-registry.json` — canonical list of buildings/rooms/links.
- `ui/ui-kit.css` — CSS tokens for dark theme & spacing.
- `prompts/*` — art direction text files.
- `memory/Codys-Memory-visuals.yaml` — memory update (visuals + merges).

---

## 8) Next visual tasks
- Replace city‑grid page with **castle‑town** as default (keep grid as fallback).  
- Add **level badges** to building exteriors based on assistant progress.  
- Animate **soft parallax** wallpaper and **Stella ambient glow** at night.

