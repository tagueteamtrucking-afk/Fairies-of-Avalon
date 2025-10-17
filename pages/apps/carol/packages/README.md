# Carol Package Map (US) — Seed v0.5.0
Updated: 2025-10-17T22:46:58Z

This seed file maps common ingredients to **package sizes** sold at major US retailers. Carol's aggregator uses it to convert the **total required amount** into **buyable packages**.

## Files
- `pages/apps/carol/packages/us.json` — the package map
- `scripts/Carol-Package-Map-Report.ps1` — lists **unmapped** ingredients in your current plan and writes `pages/apps/carol/plans/packages-missing.json`
- Workflow: `carol-package-map-report.yml` — run from Actions to generate the report and commit it.

## How to use
1. Upload `us.json` to `pages/apps/carol/packages/`.
2. Run **Actions → Carol — Package Map Coverage Report**.  
   - Open `pages/apps/carol/plans/packages-missing.json` to see any ingredient names Carol doesn't recognize.
3. Edit `us.json`:
   - Add an entry to `ingredient_map` for each missing name, pointing it to an existing **sku** (or add a new sku).
   - If the SKU needs a new package size, add it under that sku's `packages_oz` / `packages_fl_oz`.
4. Re-run your **shopping aggregator** (the one you already have) with `-Persons 2`, then **Deploy Pages**.

## Notes
- Two-person multiplier: ensure your aggregator is called with `-Persons 2`. If you want, I can ship a flat workflow that **always** runs Carol's aggregator with `-Persons 2` and commits `shopping-quantized.json`.
- Conversions: this map includes density helpers to convert **tbsp** peanut butter/hummus to **ounces**, and **cups** of rolled oats to **grams/ounces**, so Carol can pick jars/tubs/canisters.
- Region: this is a US map. If you frequently shop in the EU, I can ship `eu.json` with liter and gram defaults.

