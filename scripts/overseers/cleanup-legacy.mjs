// scripts/overseers/cleanup-legacy.mjs
// Deletes old Castle-Town duplicates & zero-byte wings in Avalon repo only.
// Also thins memory-history to earliest + latest (milestones can be preserved by name filters).

import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
function rmSafe(p){ if (fs.existsSync(p)) { const s = fs.statSync(p); if (s.isFile()) fs.unlinkSync(p); } }
function rmDirSafe(p){ if (fs.existsSync(p)) { fs.rmSync(p, {recursive:true, force:true}); } }

const deletions = [
  // Duplicate city root (canonical lives at /pages/_city)
  'city/city-map.svg',
  'city/city-registry.json',
  // Duplicate index case
  'pages/apps/Index.html',
  // Zero-byte/bad wing FBX
  'asset/wings/Wing1423.fbx',
  'asset/wings/wing1424.fbx',
  'asset/wings/wing1425.fbx',
  'asset/wings/wing1426.fbx',
  'asset/wings/wing1428.fbx',
  'asset/wings/wing1430.fbx',
  'asset/wings/Wing1436.fbx',
  'asset/wings/Wing1437.fbx',
  'asset/wings/Wing1438.fbx'
];

for (const rel of deletions){
  const p = path.join(repoRoot, rel);
  rmSafe(p);
}

// Memory thinning: keep earliest + latest only (future: add milestone tag detection)
const memDir = path.join(repoRoot, 'home/runner/work/Fairies-of-Avalon/Fairies-of-Avalon/memory-history');
if (fs.existsSync(memDir)){
  const files = fs.readdirSync(memDir).filter(f=>f.endsWith('.yaml')).sort();
  if (files.length > 2){
    const keep = new Set([files[0], files[files.length-1]]);
    for (const f of files){
      if (!keep.has(f)) rmSafe(path.join(memDir, f));
    }
  }
}

console.log('Cleanup complete.');
