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
    // Try to find a matching image file with various extensions. Many
    // environments store images as .png or .jpg rather than a custom
    // .img extension. We attempt a few common formats and apply the
    // first one that successfully loads.
    const extensions = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp'];
    let applied = false;
    function tryExtension(extIndex) {
      if (extIndex >= extensions.length) return;
      const ext = extensions[extIndex];
      const path = `/assets/img/${character}-${side}.${ext}`;
      const img = new Image();
      img.onload = () => {
        if (!applied) {
          el.style.backgroundImage = `url('${path}')`;
          el.style.backgroundSize = 'cover';
          el.style.backgroundPosition = 'center';
          applied = true;
        }
      };
      img.onerror = () => {
        // try next extension if this one fails
        tryExtension(extIndex + 1);
      };
      img.src = path;
    }
    tryExtension(0);
  });
});