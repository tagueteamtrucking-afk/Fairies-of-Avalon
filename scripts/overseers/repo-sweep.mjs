// scripts/overseers/repo-sweep.mjs
import fs from 'fs';
import path from 'path';

const MODELS_DIRS = ['asset/models/with-wings','asset/winged-models','asset/models/wingless','asset/models'];
const WINGS_DIR = 'asset/wings';
const WP_DIR = 'asset/textures/wallpapers';
const PROGRESS = 'pages/apps/overseers/progress.json';
const MODELS_MANIFEST = 'asset/models/models.json';
const WINGS_MANIFEST = 'asset/wings/manifest.json';

function ensureDir(p){ fs.mkdirSync(path.dirname(p),{recursive:true}); }
function list(dir){ try{ return fs.readdirSync(dir, { withFileTypes:true }).map(d=>({name:d.name,dirent:d})); } catch{ return []; } }

function scanModels(){
  const out = [];
  for (const d of MODELS_DIRS){
    for (const ent of list(d)){
      if (ent.dirent.isFile() && ent.name.toLowerCase().endsWith('.vrm')){
        const p = path.posix.join(d, ent.name);
        const preWinged = /with-wings|winged-models/i.test(d) || /(_wings|-wings)\.vrm$/i.test(ent.name);
        out.push({ path:p, preWinged });
      }
    }
  }
  return out.sort((a,b)=>a.path.localeCompare(b.path));
}

function scanWings(){
  const tex = [];
  const sub = list(WINGS_DIR);
  for (const ent of sub){
    const p = path.posix.join(WINGS_DIR, ent.name);
    if (ent.dirent.isFile()){
      const low = ent.name.toLowerCase();
      if (low.endsWith('.png')||low.endsWith('.jpg')||low.endsWith('.jpeg')||low.endsWith('.webp')){
        tex.push({ id: path.basename(ent.name, path.extname(ent.name)), file: p });
      }
    } else if (ent.dirent.isDirectory()){
      for (const file of list(p)){
        const low = file.name.toLowerCase();
        if (file.dirent.isFile() && (low.endsWith('.png')||low.endsWith('.jpg')||low.endsWith('.jpeg')||low.endsWith('.webp'))){
          tex.push({ id: path.basename(file.name, path.extname(file.name)), file: path.posix.join(p, file.name) });
        }
      }
    }
  }
  return tex.sort((a,b)=>a.file.localeCompare(b.file));
}

function scanWallpapers(){
  let count = 0;
  for (const ent of list(WP_DIR)){
    if (ent.dirent.isFile()){
      const low = ent.name.toLowerCase();
      if (low.endsWith('.png')||low.endsWith('.jpg')||low.endsWith('.jpeg')||low.endsWith('.webp')) count++;
    }
  }
  return count;
}

(function main(){
  const models = scanModels();
  const wings = scanWings();
  const wpi = scanWallpapers();
  ensureDir(MODELS_MANIFEST);
  fs.writeFileSync(MODELS_MANIFEST, JSON.stringify({ generated_at:new Date().toISOString(), models }, null, 2));
  ensureDir(WINGS_MANIFEST);
  fs.writeFileSync(WINGS_MANIFEST, JSON.stringify({ generated_at:new Date().toISOString(), textures:wings }, null, 2));
  ensureDir(PROGRESS);
  const progress = { last_updated: new Date().toISOString(), wallpaper_power_index: wpi, models_count: models.length, wings_textures: wings.length };
  fs.writeFileSync(PROGRESS, JSON.stringify(progress, null, 2));
  console.log('Repo sweep complete:', progress);
})();
