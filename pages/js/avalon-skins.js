
// avalon-skins.js — apply inside/outside building skins from assets/img/<character>-<side>.img
// Usage: element with class "building-skin", data-character="carol", data-side="inside|outside"
window.AvalonSkins = (function(){
  const IMG_BASE = "/assets/img";
  function pathFor(character, side){
    return `${IMG_BASE}/${character}-${side}.img`; // do not replace user's art; just reference
  }
  function apply(el){
    if(!el) return;
    const character = el.getAttribute('data-character') || 'tracy';
    const side = el.getAttribute('data-side') || 'inside';
    el.style.backgroundImage = `url("${pathFor(character, side)}")`;
  }
  function toggle(el){
    if(!el) return;
    const side = el.getAttribute('data-side') === 'inside' ? 'outside' : 'inside';
    el.setAttribute('data-side', side);
    apply(el);
  }
  return { apply, toggle, pathFor };
})();
