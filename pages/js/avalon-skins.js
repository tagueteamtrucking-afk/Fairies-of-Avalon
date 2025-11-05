/*
 * Avalon building skins helper
 *
 * This module scans the document for elements with the class
 * `.building-skin` and uses the data attributes `data-character`
 * and `data-side` to determine which image to apply. Images must be
 * stored under `assets/img/<character>-<side>.img`. For example,
 * for character "carol" and side "inside", the script will set
 * the element's background image to `/assets/img/carol-inside.img`.
 */

document.addEventListener('DOMContentLoaded', () => {
  const skins = document.querySelectorAll('.building-skin');
  skins.forEach((el) => {
    const character = el.getAttribute('data-character');
    const side = el.getAttribute('data-side');
    if (!character || !side) return;
    const imgPath = `/assets/img/${character}-${side}.img`;
    el.style.backgroundImage = `url('${imgPath}')`;
    el.style.backgroundSize = 'cover';
    el.style.backgroundPosition = 'center';
  });
});