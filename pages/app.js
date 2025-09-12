if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(console.error));
}
console.log('Avalon app-shell ready at fairiesofavalon.com');
