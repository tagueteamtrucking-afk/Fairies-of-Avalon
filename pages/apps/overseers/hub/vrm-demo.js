import { createVRMViewer } from '/apps/shared/vrm-viewer.js';
import { applyWallpaperTheme } from '/apps/shared/theme.js';

await applyWallpaperTheme({ strategy: 'first', overlay: 'dark' }).catch(()=>{});

const models = await (await fetch('/asset/models/models.json?t=' + Date.now(), { cache: 'no-store' })).json();
const wings  = await (await fetch('/asset/wings/manifest.json?t=' + Date.now(), { cache: 'no-store' })).json();

const byAvatar = models?.byAvatar || {};
const wingIds = Object.keys(wings?.wings || {}).sort((a,b)=>Number(a)-Number(b));

const selAvatar = document.getElementById('avatar');
const selWing   = document.getElementById('wing');

Object.keys(byAvatar).sort().forEach(name => {
  const opt = document.createElement('option');
  opt.value = byAvatar[name];
  opt.textContent = name;
  selAvatar.appendChild(opt);
});
wingIds.forEach(id => {
  const opt = document.createElement('option');
  opt.value = id;
  opt.textContent = 'wing' + id;
  selWing.appendChild(opt);
});

// pick defaults
if (selAvatar.options.length > 0) selAvatar.selectedIndex = 0;
if (selWing.options.length > 0)   selWing.selectedIndex   = Math.max(0, wingIds.indexOf('1420'));

const viewer = await createVRMViewer({
  container: '#viewer',
  vrmPath: selAvatar.value ? ('/' + selAvatar.value.replace(/^\//,'')) : null,
  wingId: selWing.value || null,
  modelScale: 1.0,
  wingsScale: 1.0,
  enableOrbitControls: true
});

selAvatar.addEventListener('change', async () => {
  // easy reload: dispose and recreate to switch VRM
  viewer.dispose();
  await createVRMViewer({
    container: '#viewer',
    vrmPath: selAvatar.value ? ('/' + selAvatar.value.replace(/^\//,'')) : null,
    wingId: selWing.value || null,
    modelScale: 1.0,
    wingsScale: 1.0
  });
});

selWing.addEventListener('change', async () => {
  await viewer.setWing(selWing.value || null);
});
