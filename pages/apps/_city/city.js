document.addEventListener('keydown', (e)=>{
  if((e.key==='r' && (e.ctrlKey||e.metaKey)) || e.key==='F5'){
    if(location.pathname.includes('/pages/apps/_city/')){
      sessionStorage.setItem('forceReload', '1');
    }
  }
});
if(sessionStorage.getItem('forceReload')==='1'){
  sessionStorage.removeItem('forceReload');
  if('serviceWorker' in navigator){
    caches && caches.keys && caches.keys().then(keys=>keys.forEach(k=>caches.delete(k)));
    navigator.serviceWorker.getRegistrations().then(list=>list.forEach(r=>r.unregister()));
  }
}
