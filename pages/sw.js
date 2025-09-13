// Simple offline cache for the shell; no dynamic caching.
const NAME = "avalon-shell-v1";
const PRECACHE = [ "/", "/index.html", "/app.css" ];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(NAME).then(c => c.addAll(PRECACHE)));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== NAME).map(k => caches.delete(k))))
  );
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request))
  );
});
