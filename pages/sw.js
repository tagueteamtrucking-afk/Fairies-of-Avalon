const APP_VERSION = 'v2025.09.13-1';
const SHELL_CACHE = `shell-${APP_VERSION}`;
const RUNTIME_CACHE = `rt-${APP_VERSION}`;
const SHELL_ASSETS = [
  '/', '/index.html',
  '/app.css',
  '/pages/apps/overseers/console.html',
  '/pages/apps/overseers/console.js',
  '/pages/apps/overseers/progress.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(SHELL_CACHE).then(c => c.addAll(SHELL_ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => ![SHELL_CACHE, RUNTIME_CACHE].includes(k)).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Stale-While-Revalidate for heavy assets (VRMs, FBX, textures), network-first for others
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  const heavy = url.pathname.startsWith('/asset/models/')
             || url.pathname.startsWith('/asset/wings/')
             || url.pathname.startsWith('/asset/textures/');
  if (heavy) {
    event.respondWith(swr(event.request));
  } else {
    event.respondWith(networkFirst(event.request));
  }
});

async function swr(req){
  const cache = await caches.open(RUNTIME_CACHE);
  const cached = await cache.match(req);
  const networkPromise = fetch(req).then(res => { if (res && res.ok) cache.put(req, res.clone()); return res; });
  return cached || networkPromise;
}

async function networkFirst(req){
  try {
    const res = await fetch(req);
    if (res && res.ok){
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(req, res.clone());
    }
    return res;
  } catch {
    const cache = await caches.open(RUNTIME_CACHE);
    const cached = await cache.match(req) || await caches.match(req);
    return cached || Response.error();
  }
}
