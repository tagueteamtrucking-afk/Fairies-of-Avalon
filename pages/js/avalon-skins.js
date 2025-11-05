// Apply building skins for elements with the `.building-skin` class.

document.addEventListener('DOMContentLoaded', () => {
  const skins = document.querySelectorAll('.building-skin');
  skins.forEach((el) => {
    const dataset = el.dataset;
    // Determine building/character and side/room from data attributes.  Fallbacks
    // cascade: building-room, building-side, character-side, default-side.
    const building = dataset.building;
    const room = dataset.room;
    const character = dataset.character || dataset.char || dataset.charactername;
    const side = dataset.side || 'outside';
    // Build an ordered list of candidate filenames (without extension).
    const names = [];
    if (building && room) names.push(`${building}-${room}`);
    if (building) names.push(`${building}-${side}`);
    if (character) names.push(`${character}-${side}`);
    // Always provide a default fallback
    names.push(`default-${side}`);
    // Try a set of common image extensions for each candidate name until one
    // succeeds.
    const extensions = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp'];
    let applied = false;
    function tryNextName(nameIndex, extIndex) {
      if (nameIndex >= names.length) return;
      if (extIndex >= extensions.length) {
        // move to next base name
        tryNextName(nameIndex + 1, 0);
        return;
      }
      const ext = extensions[extIndex];
      const base = names[nameIndex];
      const path = `/assets/img/${base}.${ext}`;
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
        // try next extension for the same base name
        tryNextName(nameIndex, extIndex + 1);
      };
      img.src = path;
    }
    tryNextName(0, 0);
  });
});