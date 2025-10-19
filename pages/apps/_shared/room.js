export function mountRoom(el, items){
  el.innerHTML = '';
  for(const it of items){
    const a = document.createElement('a'); a.href = it.href; a.className='obj'; a.innerHTML = `<h3>${it.icon||'🔗'} ${it.title}</h3><p>${it.desc||''}</p>`;
    el.appendChild(a);
  }
}