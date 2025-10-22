(function(){
  const req = (document.currentScript && document.currentScript.dataset.required) || '';
  const role = localStorage.getItem('avalon.role') || 'user';
  if(req && role !== req){
    document.body.innerHTML = '<main style="font-family:system-ui;padding:24px;color:#333"><h1>Restricted</h1><p>This page requires role <b>'+req+'</b>. Use the Access page to set your role.</p></main>';
    document.title = 'Restricted';
  }
})();