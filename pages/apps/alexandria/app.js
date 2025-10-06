(function(){
  const grid = document.getElementById('grid');
  const tpl = document.getElementById('world-card');
  async function load() {
    try {
      const res = await fetch('worlds/index.json', { cache: 'no-store' });
      if (!res.ok) throw new Error('Failed to load worlds index.json');
      const data = await res.json();
      const items = Array.isArray(data.items) ? data.items : [];
      if (!items.length) {
        grid.innerHTML = '<p style="color:#9aa4b2">No worlds yet. Run the <em>Avalon: Run-All</em> workflow to generate some.</p>';
        return;
      }
      const frag = document.createDocumentFragment();
      for (const w of items) {
        const node = tpl.content.cloneNode(true);
        node.querySelector('.title').textContent = w.title || w.id || 'Untitled';
        node.querySelector('.summary').textContent = w.summary || '';
        const details = node.querySelector('.code');
        try {
          const worldFile = w.file || (w.slug ? `world-${w.slug}.json` : null);
          if (worldFile) {
            const wr = await fetch(`worlds/${worldFile}`, { cache: 'no-store' });
            if (wr.ok) { const j = await wr.json(); details.textContent = JSON.stringify(j, null, 2); }
            else { details.textContent = JSON.stringify(w, null, 2); }
          } else { details.textContent = JSON.stringify(w, null, 2); }
        } catch (err) { details.textContent = JSON.stringify(w, null, 2); }
        frag.appendChild(node);
      }
      grid.replaceChildren(frag);
    } catch (err) {
      grid.innerHTML = '<p style="color:#ef4444">Error loading worlds. ' + (err && err.message || err) + '</p>';
    }
  }
  load();
}());
