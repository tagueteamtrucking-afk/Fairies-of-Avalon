
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const outDir = 'reports/repo-doctor';
fs.mkdirSync(outDir, { recursive: true });

// Collect all tracked files
const ls = (cmd) => require('child_process').execSync(cmd, {stdio:'pipe'}).toString().trim();
const files = ls("git ls-files").split("\n").filter(Boolean);

// Helpers
const sha256 = (p) => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const isHtml = (p) => /\.html?$/i.test(p);
const isWorkflow = (p) => p.startsWith('.github/workflows/') && /\.ya?ml$/i.test(p);

// 1) Duplicates by content hash
const hashMap = new Map();
for (const f of files) {
  try {
    const h = sha256(f);
    if (!hashMap.has(h)) hashMap.set(h, []);
    hashMap.get(h).push(f);
  } catch { /* ignore unreadable */ }
}
const duplicates = [];
for (const [h, list] of hashMap) if (list.length > 1) duplicates.push({ hash:h, files:list });
fs.writeFileSync(path.join(outDir, 'duplicates.json'), JSON.stringify(duplicates, null, 2));

// 2) Large files (> 5 MB)
const large = [];
for (const f of files) {
  try {
    const sz = fs.statSync(f).size;
    if (sz > 5 * 1024 * 1024) large.push({ path:f, bytes:sz });
  } catch { }
}
large.sort((a,b)=>b.bytes-a.bytes);
fs.writeFileSync(path.join(outDir, 'large-files.json'), JSON.stringify(large, null, 2));

// 3) Orphaned HTML pages (not reachable from index.html or pages/_city/index.html by naive href scan)
const htmlFiles = files.filter(isHtml);
const graph = new Map(htmlFiles.map(f=>[f, new Set()]));
function extractHrefs(content) {
  const hrefs = [];
  const re = /href\s*=\s*["']([^"']+)["']/gi;
  let m; while((m=re.exec(content))) hrefs.push(m[1]);
  return hrefs;
}
for (const f of htmlFiles) {
  try {
    const base = path.dirname(f);
    const hrefs = extractHrefs(fs.readFileSync(f,'utf8'));
    for (const h of hrefs) {
      if (h.startsWith('http')) continue;
      const resolved = path.normalize(path.join(base, h));
      if (graph.has(resolved)) graph.get(f).add(resolved);
    }
  } catch { }
}
const roots = htmlFiles.filter(f => ['index.html', 'pages/_city/index.html'].includes(f));
const visited = new Set();
function dfs(f) { if (visited.has(f)) return; visited.add(f); for (const nxt of (graph.get(f)||[])) dfs(nxt); }
for (const r of roots) if (fs.existsSync(r)) dfs(r);
const orphaned = htmlFiles.filter(f => !visited.has(f));
fs.writeFileSync(path.join(outDir, 'orphaned-pages.json'), JSON.stringify(orphaned, null, 2));

// 4) Dead workflows: present but no runs recorded in last 90d (requires optional input later). For now, flag unused naming patterns.
const workflows = files.filter(isWorkflow);
const dead = workflows.filter(w => /-(hotfix|old|legacy|temp)\.ya?ml$/i.test(w));
fs.writeFileSync(path.join(outDir, 'dead-workflows.json'), JSON.stringify(dead, null, 2));

// 5) Bare specifiers in JS/HTML (imports not in importmap)
let importmap = {imports:{}};
try { importmap = JSON.parse(fs.readFileSync('importmap.json','utf8')); } catch { }
const bare = [];
const jsHtml = files.filter(f => /\.(js|mjs|html)$/i.test(f));
const importsList = new Set(Object.keys(importmap.imports||{}));
const bareRe = /import\s+[^'"]*['"]([^'"]+)['"]/g;
for (const f of jsHtml) {
  try {
    const txt = fs.readFileSync(f,'utf8');
    let m; while((m = bareRe.exec(txt))) {
      const spec = m[1];
      if (!spec.startsWith('./') && !spec.startsWith('../') && !spec.startsWith('/') && !importsList.has(spec) && !spec.includes('://')) {
        bare.push({ file:f, specifier:spec });
      }
    }
  } catch { }
}
fs.writeFileSync(path.join(outDir, 'bare-specifiers.json'), JSON.stringify(bare, null, 2));

// Summary.md
const lines = [];
lines.push(`# Repo Doctor — Cleanup Report`);
lines.push(`Generated: 2025-10-31T04:21:20`);
lines.push('');
lines.push(`- Duplicates (by content hash): **${duplicates.length}**`);
lines.push(`- Large files > 5MB: **${large.length}**`);
lines.push(`- Orphaned HTML pages: **${orphaned.length}**`);
lines.push(`- Dead/legacy-named workflows: **${dead.length}**`);
lines.push(`- Bare ESM specifiers missing from importmap: **${bare.length}**`);
lines.push('');
lines.push('Artifacts contain JSON detail for each category. Use Repo Sweeper to propose deletions based on this report.');
fs.writeFileSync(path.join(outDir, 'summary.md'), lines.join('\n'));
