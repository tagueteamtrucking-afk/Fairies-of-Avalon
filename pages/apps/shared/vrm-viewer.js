// VRM Viewer — Avalon shared module
// Loads a VRM, attaches a wing FBX (via manifest), and animates (blink, idle sway, wing flaps).
// Requires: import map for `three`, `three/addons/`, `@pixiv/three-vrm`

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { VRMLoaderPlugin, VRMUtils } from '@pixiv/three-vrm';

export async function createVRMViewer({
  container,
  vrmPath,
  wingsManifestUrl = '/asset/wings/manifest.json',
  wingId = null,                 // e.g., "1420" or "wing1420"
  modelScale = 1.0,
  wingsScale = 1.0,
  wingsOffset = { x: 0, y: 0.12, z: -0.06 },
  enableOrbitControls = true,
  animate = { wingsFlap: true, blink: true, idleSway: true },
  exposure = 0.9
} = {}) {
  const mount = typeof container === 'string' ? document.querySelector(container) : container;
  if (!mount) throw new Error('vrm-viewer: container not found');

  // --- three boilerplate ---
  const scene = new THREE.Scene();
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = exposure;
  mount.innerHTML = '';
  mount.appendChild(renderer.domElement);

  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 1.45, 2.2);

  // lights
  const hemi = new THREE.HemisphereLight(0xffffff, 0x444444, 1.0);
  hemi.position.set(0, 1.5, 0);
  scene.add(hemi);
  const dir = new THREE.DirectionalLight(0xffffff, 1.2);
  dir.position.set(0.5, 1.5, 1.2);
  scene.add(dir);

  // controls
  const controls = enableOrbitControls ? new OrbitControls(camera, renderer.domElement) : null;
  if (controls) {
    controls.target.set(0, 1.35, 0);
    controls.enableDamping = true;
    controls.minDistance = 0.8;
    controls.maxDistance = 4.0;
    controls.minPolarAngle = Math.PI * 0.25;
    controls.maxPolarAngle = Math.PI * 0.85;
  }

  // resize
  function resize() {
    const w = mount.clientWidth || 800;
    const h = mount.clientHeight || 450;
    renderer.setSize(w, h, false);
    camera.aspect = w / Math.max(1, h);
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(mount);
  resize();

  // loaders
  const gltfLoader = new GLTFLoader();
  gltfLoader.register(parser => new VRMLoaderPlugin(parser));
  const fbxLoader = new FBXLoader();
  const texLoader = new THREE.TextureLoader();

  // state
  const clock = new THREE.Clock();
  let vrm = null;
  let wingGroup = null;
  let t = 0;

  function applyWingTextures(mat, texDef = {}) {
    if (texDef.color) {
      const t = texLoader.load('/' + texDef.color.replace(/^\//, ''));
      t.colorSpace = THREE.SRGBColorSpace;
      mat.map = t;
    }
    if (texDef.emissive) {
      const t = texLoader.load('/' + texDef.emissive.replace(/^\//, ''));
      t.colorSpace = THREE.SRGBColorSpace;
      mat.emissiveMap = t;
      mat.emissive = new THREE.Color(0xffffff);
      mat.emissiveIntensity = 0.8;
    }
    if (texDef.normal) {
      const t = texLoader.load('/' + texDef.normal.replace(/^\//, ''));
      mat.normalMap = t;
    }
    mat.needsUpdate = true;
  }

  async function loadVRM(path) {
    const gltf = await gltfLoader.loadAsync(path);
    VRMUtils.removeUnnecessaryJoints(gltf.scene);
    VRMUtils.removeUnnecessaryVertices(gltf.scene);
    vrm = gltf.userData.vrm;
    vrm.scene.traverse(o => o.frustumCulled = false);
    vrm.scene.scale.setScalar(modelScale);
    vrm.scene.rotation.y = Math.PI;
    scene.add(vrm.scene);
  }

  async function loadWingById(id) {
    if (!id) return null;
    const key = String(id).toLowerCase().replace(/^wing/, '');
    const manifest = await (await fetch(wingsManifestUrl, { cache: 'no-store' })).json();
    const wing = manifest?.wings?.[key];
    if (!wing?.mesh) throw new Error(`Wing '${id}' not found in manifest`);
    const group = await fbxLoader.loadAsync('/' + wing.mesh);
    const mat = new THREE.MeshStandardMaterial({ metalness: 0.1, roughness: 0.8 });
    const tdef = {
      color: wing.textures?.color || wing.textures?.base,
      emissive: wing.textures?.emissive,
      normal: wing.textures?.normal
    };
    group.traverse(o => { if (o.isMesh) { o.material = mat; o.castShadow = true; o.receiveShadow = true; } });
    if (tdef.color || tdef.emissive || tdef.normal) applyWingTextures(mat, tdef);

    group.scale.setScalar(wingsScale);
    group.position.set(wingsOffset.x, wingsOffset.y, wingsOffset.z);
    group.rotation.set(0, Math.PI, 0);

    const chest = vrm?.humanoid?.getBoneNode?.('Chest') || vrm?.humanoid?.getBoneNode?.('Spine') || vrm?.scene;
    chest.add(group);
    return group;
  }

  await loadVRM(vrmPath);
  if (wingId) wingGroup = await loadWingById(wingId);

  function update(delta) {
    t += delta;

    if (vrm) {
      if (animate?.blink && vrm.expressionManager) {
        // Occasional blink
        const blink = (Math.sin(t * 2.7) + 1) * 0.5 > 0.96 ? 1 : 0;
        vrm.expressionManager.setValue('blink', blink);
      }
      if (animate?.idleSway) {
        vrm.scene.rotation.z = Math.sin(t * 0.5) * 0.02;
      }
      vrm.update(delta);
    }

    if (wingGroup && animate?.wingsFlap) {
      wingGroup.rotation.z = Math.sin(t * 2.0) * 0.25; // flap a bit
    }

    controls && controls.update();
    renderer.render(scene, camera);
  }

  renderer.setAnimationLoop(() => update(clock.getDelta()));

  return {
    /** Swap wings on the fly (pass null to remove). */
    setWing: async (id) => {
      if (wingGroup) {
        wingGroup.parent && wingGroup.parent.remove(wingGroup);
        wingGroup.traverse(o => {
          if (o.geometry) o.geometry.dispose();
          if (o.material) o.material.dispose();
        });
        wingGroup = null;
      }
      if (id) wingGroup = await loadWingById(id);
    },
    dispose: () => {
      renderer.setAnimationLoop(null);
      controls && controls.dispose();
      if (wingGroup) { wingGroup.parent && wingGroup.parent.remove(wingGroup); }
      if (vrm) { scene.remove(vrm.scene); }
      renderer.dispose();
      mount.innerHTML = '';
    }
  };
}
