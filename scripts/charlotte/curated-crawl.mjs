// scripts/charlotte/curated-crawl.mjs
// ESM-safe: no require. Keep to simple HTTP fetches from public repos/APIs if needed.
// For now, we produce a curated seed list (no network dependency) to avoid flakiness.
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';

const ROOT = process.cwd();
const OUT = path.join(ROOT, 'pages/apps/charlotte/finds.json');

async function main(){
  const items = [
    { group: "Open-source creative app starters", links: [
      { title: "Stable Studio (web UI)", url: "https://github.com/Stability-AI/StableStudio", note: "OSS image app foundation" },
      { title: "InvokeAI", url: "https://github.com/invoke-ai/InvokeAI", note: "Local image gen workflow app" }
    ]},
    { group: "3D / Mesh tools (for Nina & Tracy)", links: [
      { title: "Open Source 3D Editor (three.js based)", url: "https://github.com/mrdoob/three.js/tree/dev/editor", note: "Three.js editor" }
    ]},
    { group: "Video (faceless / automated)", links: [
      { title: "OpenShot Video Editor", url: "https://github.com/OpenShot/openshot-qt", note: "Video editor; pipeline base" }
    ]}
  ];

  fs.mkdirSync(path.dirname(OUT), { recursive:true });
  await fsp.writeFile(OUT, JSON.stringify({ generated_at: new Date().toISOString(), items }, null, 2));
  console.log('Charlotte finds written:', OUT);
}

main().catch(e=>{ console.error(e); process.exit(1); });
