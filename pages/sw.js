// Minimal SW with targeted bypass rules for dynamic theme pages.
const BYPASS = [
  /^\/themes\/landing\.generated\.html/,
  /^\/pages\/themes\/landing\.generated\.html/,
  /^\/themes\/landing\.generated\.css/,
  /^\/apps\/overseers\/wallpapers\.json/,
  /^\/asset\/textures\/wallpapers\//,
  /^\/asset\/models\/models\.json/,
  /^\/asset\/wings\/manifest\.json/,
  /^\/importmap\.json/
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(clients.claim());
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (BYPASS.some(rx => rx.test(url.pathname))) {
    event.respondWith(fetch(event.request, { cache: 'no-store' }).catch(() => fetch(event.request)));
    return;
  }
  // Default: let the network handle it (no extra caching here).
});
