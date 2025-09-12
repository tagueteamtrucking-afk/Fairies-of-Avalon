import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { VRM, VRMUtils } from '@pixiv/three-vrm';

const root = document.getElementById('viewport');
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(root.clientWidth, root.clientHeight);
root.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x101010);
const camera = new THREE.PerspectiveCamera(35, root.clientWidth / root.clientHeight, 0.1, 1000);
camera.position.set(0, 1.4, 2.8);

const light = new THREE.DirectionalLight(0xffffff, 2);
light.position.set(1, 1, 2);
scene.add(light);
scene.add(new THREE.AmbientLight(0xffffff, 0.6));

const grid = new THREE.GridHelper(6, 12);
scene.add(grid);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;

let currentVRM = null;
let currentWings = null;

function animate() {
  requestAnimationFrame(animate);
  controls.update();
  renderer.render(scene, camera);
}
animate();

function resize() {
  const w = root.clientWidth;
  const h = Math.max(root.clientHeight, 520);
  renderer.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);

const gltfLoader = new GLTFLoader();
const fbxLoader  = new FBXLoader();

async function loadVRMFromFile(file) {
  const url = URL.createObjectURL(file);
  const gltf = await gltfLoader.loadAsync(url);
  VRMUtils.removeUnnecessaryJoints(gltf.scene);
  const vrm = await VRM.from(gltf);
  URL.revokeObjectURL(url);

  if (currentVRM) {
    scene.remove(currentVRM.scene);
    currentVRM = null;
  }
  currentVRM = vrm;
  currentVRM.scene.rotation.y = Math.PI; // face camera
  scene.add(currentVRM.scene);
}

async function loadWingsFromFile(file) {
  const url = URL.createObjectURL(file);
  let obj;
  if (file.name.toLowerCase().endsWith('.fbx')) {
    obj = await fbxLoader.loadAsync(url);
  } else {
    const gltf = await gltfLoader.loadAsync(url);
    obj = gltf.scene;
  }
  URL.revokeObjectURL(url);

  obj.traverse((n)=>{ if(n.isMesh){ n.castShadow = true; n.receiveShadow = true; }});
  obj.scale.setScalar(1.0);

  if (currentWings) {
    currentWings.removeFromParent();
    currentWings = null;
  }
  currentWings = obj;
  attachWings(document.getElementById('bone').value);
}

function findBone(name) {
  if (!currentVRM) return null;
  const humanoid = currentVRM.humanoid;
  if (!humanoid) return null;
  try {
    return humanoid.getBoneNode( name );
  } catch(e) {
    return null;
  }
}

function attachWings(boneName) {
  if (!currentVRM || !currentWings) return;
  const bone = findBone(boneName);
  if (!bone) return;
  bone.add(currentWings);
  currentWings.position.set(0, 0.15, -0.05);
}

document.getElementById('vrmFile').addEventListener('change', async (e) => {
  const f = e.target.files?.[0];
  if (f) await loadVRMFromFile(f);
});

document.getElementById('wingsFile').addEventListener('change', async (e) => {
  const f = e.target.files?.[0];
  if (f) await loadWingsFromFile(f);
});

document.getElementById('bone').addEventListener('change', (e) => {
  if (currentWings) attachWings(e.target.value);
});

resize();
