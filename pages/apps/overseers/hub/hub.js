import { fetchJSON } from './hub_util.js';

const PROGRESS_URL = '/pages/apps/overseers/progress.json';
const FILES_URL = '/memory/file-index.json';

const FAIRIES = [
  { id:'clarice', name:'Clarice', path:'/pages/apps/clarice/' },
  { id:'charlotte', name:'Charlotte', path:'/pages/apps/charlotte/' },
  { id:'nina', name:'Nina', path:'/pages/apps/nina/' },
  { id:'alexandria', name:'Alexandria', path:'/pages/apps/alexandria/' },
  { id:'tracy', name:'Tracy', path:'/pages/apps/tracy/' },
  { id:'carol', name:'Carol', path:'/pages/apps/carol/' },
  { id:'jem', name:'Jem', path:'/pages/apps/jem/' },
  { id:'stella', name:'Stella', path:'/pages/apps/stella/' },
  { id:'sorcha', name:'Sorcha', path:'/pages/apps/sorcha/' },
  { id:'odessa', name:'Odessa', path:'/pages/apps/odessa/' },
  { id:'billie', name:'Billie', path:'/pages/apps/billie/' },
  { id:'themis', name:'Themis', path:'/pages/apps/themis/' },
  { id:'abbey', name:'Abbey', path:'/pages/apps/abbey/' },
];

function setLink(id, url, label) {
  const el = document.getElementById(id);
  if (!el) return;
  if (url) {
    el.href = url; 
    if (label) el.textContent = label;
  } else {
    el.href = '#';
    if (label) el.textContent = label;
  }
}

function getRepoBase(){
  return localStorage.getItem('avalon_repo_actions_base') || null;
}
function promptRepoBase(){
  const prev = getRepoBase() || 'https://github.com/OWNER/REPO/actions/workflows/';
  const url = prompt('Paste your repo Actions base URL (ends with ".../actions/workflows/"):', prev);
  if (url && /^https:\/\/github\.com\/[^\s]+\/actions\/workflows\/$/.test(url)) {
    localStorage.setItem('avalon_repo_actions_base', url);
    return url;
  }
  alert('Not saved. Example: https://github.com/<owner>/<repo>/actions/workflows/');
  return null;
}

(async () => {
  const prog = await fetchJSON(PROGRESS_URL).catch(() => null);
  const files = await fetchJSON(FILES_URL).catch(() => null);

  const wpi = prog?.wallpaper_power_index ?? 0;
  const totalFiles = files?.summary?.count ?? '…';

  document.getElementById('wpi-badge').textContent = `WPI: ${wpi}`;
  document.getElementById('files-badge').textContent = `Files: ${totalFiles}`;
  document.getElementById('telemetry').textContent = JSON.stringify(prog ?? { note:'Run Repo Sweep to generate telemetry.' }, null, 2);

  let ghBase = getRepoBase();
  if (!ghBase) {
    setLink('run-memory-sweep', '#', 'Connect Actions');
    document.getElementById('run-memory-sweep').onclick = (e)=>{
      e.preventDefault();
      ghBase = promptRepoBase();
      if (ghBase){ 
        setLink('run-memory-sweep', ghBase + 'overseers-memory-sweep.yml', 'Run: Repo Sweep');
        setLink('run-deploy', ghBase + 'deploy-pages.yml', 'Run: Deploy Pages');
      }
    };
  } else {
    setLink('run-memory-sweep', ghBase + 'overseers-memory-sweep.yml', 'Run: Repo Sweep');
    setLink('run-deploy', ghBase + 'deploy-pages.yml', 'Run: Deploy Pages');
  }
  setLink('open-permissions', '/pages/apps/overseers/permissions/state.json', 'Permissions State');

  const grid = document.getElementById('fairies');
  FAIRIES.forEach(f => {
    const a = document.createElement('a');
    a.className = 'tile';
    a.href = f.path;
    a.innerHTML = `<div class="name">${f.name}</div><div class="sub">${f.path}</div>`;
    grid.appendChild(a);
  });
})();
