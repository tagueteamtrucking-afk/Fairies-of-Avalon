// PWA bootstrap: register the service worker and keep the UI minimal.
(async () => {
  if ('serviceWorker' in navigator) {
    try {
      await navigator.serviceWorker.register('/sw.js', { scope: '/' });
    } catch (e) {
      console.warn('SW registration failed:', e);
    }
  }
})();
