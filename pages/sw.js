/* Avalon SW — v2.1.0 (2025-09-13) */
const PRECACHE = "avalon-precache-v2.1.0";
const RUNTIME  = "avalon-runtime-v2.1.0";

// Minimal shell: keep this light; heavy assets use runtime SWR
const PRECACHE_URLS = [
  "/",
  "/index.html",
  "/app.css",
  "/apps/overseers/console.html",
  "/apps/overseers/console.js",
  "/apps/overseers/capabilities.json",
  "/manifest.webmanifest"
];

// Do NOT precache progress.json — always network-first
const LIVE_JSON = [
  "/apps/overseers/progress.json",
  "/apps/overseers/capabilities.json" // can be cached but keep fresh
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(PRECACHE).then(cache => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.map(k => {
        if (k !== PRECACHE && k !== RUNTIME) return caches.delete(k);
      }))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Network-first for Overseers live JSON
  if (LIVE_JSON.some(p => url.pathname === p)) {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(request, { cache: "no-store" });
          const cache = await caches.open(RUNTIME);
          cache.put(request, fresh.clone()).catch(() => {});
          return fresh;
        } catch {
          const cached = await caches.match(request);
          return cached || new Response("{}", { headers: { "Content-Type": "application/json" }});
        }
      })()
    );
    return;
  }

  // Stale-while-revalidate for most static assets
  event.respondWith(
    (async () => {
      const cache = await caches.open(RUNTIME);
      const cached = await cache.match(request);
      const fetchPromise = fetch(request).then(response => {
        cache.put(request, response.clone()).catch(() => {});
        return response;
      }).catch(() => cached);

      return cached || fetchPromise;
    })()
  );
});
