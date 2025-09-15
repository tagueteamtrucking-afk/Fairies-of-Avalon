// Wallpaper theme — picks a wallpaper from wallpapers.json and skins the page.
export async function applyWallpaperTheme({
  targetSelector = 'body',
  wallpapersUrl = '/apps/overseers/wallpapers.json',
  strategy = 'first',   // 'first' | 'random'
  overlay = 'dark'      // 'dark' | 'light' | 'none'
} = {}) {
  const el = document.querySelector(targetSelector);
  if (!el) throw new Error('theme: target not found');

  let list = [];
  try {
    const res = await fetch(wallpapersUrl + '?t=' + Date.now(), { cache: 'no-store' });
    list = await res.json();
  } catch { /* ignore */ }

  if (!Array.isArray(list) || list.length === 0) return null;

  const chosen = strategy === 'random' ? list[Math.floor(Math.random() * list.length)] : list[0];
  const url = '/' + chosen.path.replace(/^\//, '');

  el.style.backgroundImage = `url('${url}')`;
  el.style.backgroundSize = 'cover';
  el.style.backgroundPosition = 'center';
  el.style.backgroundAttachment = 'fixed';

  if (overlay !== 'none') {
    const ov = document.createElement('div');
    ov.style.position = 'fixed';
    ov.style.inset = '0';
    ov.style.pointerEvents = 'none';
    ov.style.background = overlay === 'dark'
      ? 'linear-gradient(180deg, rgba(0,0,0,.35), rgba(0,0,0,.55))'
      : 'linear-gradient(180deg, rgba(255,255,255,.35), rgba(255,255,255,.55))';
    document.body.appendChild(ov);
  }

  return chosen; // { path, size, name }
}
