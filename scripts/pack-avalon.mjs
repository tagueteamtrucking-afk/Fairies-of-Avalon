import { execSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

function sh(s){ execSync(s, { stdio: "inherit" }); }

if(!existsSync("dist")) mkdirSync("dist", { recursive: true });
// Content.zip
sh(`zip -r dist/Avalon-Content.zip . -x ".github/workflows/*"`);
// Workflows.zip (flat root)
if(!existsSync("staging-workflows")) mkdirSync("staging-workflows", { recursive: true });
try { sh(`bash -lc 'shopt -s nullglob; for f in .github/workflows/*.yml .github/workflows/*.yaml; do cp "$f" staging-workflows/$(basename "$f"); done'`); } catch{}
sh(`(cd staging-workflows && zip -r ../dist/Avalon-Workflows.zip .)`);
console.log("Zips are in dist/");
