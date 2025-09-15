import { createVRMViewer } from '/apps/shared/vrm-viewer.js';
import { applyWallpaperTheme } from '/apps/shared/theme.js';

await applyWallpaperTheme({ strategy: 'first', overlay: 'dark' }).catch(()=>{});

const selAvatar = document.getElementById('avatar');
const selWing   = document.getElementById('wing');
const note      = document.getElementById('note');
const viewerDiv = document.getElementById('viewer');

const state = { viewer: null };

function addOpt(sel, value, text){ const o=document.createElement('option'); o.value=value; o.textContent=text; sel.appendChild(o); }
function clear(sel){ while(sel.firstChild) sel.removeChild(sel.firstChild); }

async function loadJSON(url){
  try {
    const r = await fetch(url + (url.includes('?') ? '' : '?t=') + Date.now(), { cache: 'no-store' });
    if (!r.ok) throw new Error(r.status + ' ' + r.statusText);
    return await r.json();
  } catch { return null; }
}

const models = await loadJSON('/asset/models/models.json');
const wings  = await loadJSON('/asset/wings/manifest.json');

const byAvatar = models?.byAvatar || {};
const wingMap  = wings?.wings || {};

if (Object.keys(byAvatar).length === 0) {
  // Fallback to assistants.json so at least names appear
  const assistants = (await loadJSON('/apps/overseers/assistants.json')) || [];
  assistants.forEach(a => addOpt(selAvatar, '', a.name));
  note.innerHTML = '<small>models.json missing or empty — dropdown shows names only. Run <b>Overseers — Manifests & WPI</b> to regenerate mapping.</small>';
} else {
  Object.keys(byAvatar).sort().forEach(name => addOpt(selAvatar, byAvatar[name], name));
  note.innerHTML = '<small>Tip: Use touch/mouse drag to orbit. Wings and blink are animated.</small>';
}

const wingIds = Object.keys(wingMap).sort((a,b)=>Number(a)-Number(b));
if (wingIds.length === 0) {
  addOpt(selWing, '', 'none');
} else {
  wingIds.forEach(id => addOpt(selWing, id, 'wing' + id));
}

async function mount(){
  const path = selAvatar.value;
  if (!path) {
    viewerDiv.innerHTML = '<p class="card"><small>Select an avatar that has a VRM path in models.json.</small></p>';
    return;
  }
  if (state.viewer) { state.viewer.dispose(); state.viewer = null; }
  state.viewer = await createVRMViewer({
    container: '#viewer',
    vrmPath: '/' + String(path).replace(/^\/+/,''),
    wingId: selWing.value || null,
    enableOrbitControls: true
  });
}

selAvatar.addEventListener('change', mount);
selWing.addEventListener('change', async () => { if (state.viewer) await state.viewer.setWing(selWing.value || null); });

if (selAvatar.options.length) { selAvatar.selectedIndex = 0; await mount(); }
