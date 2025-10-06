(function(){
  const grid = document.getElementById('grid');
  const tpl = document.getElementById('component-card');
  async function load() {
    try {
      const res = await fetch('components/index.json', { cache: 'no-store' });
      if (!res.ok) throw new Error('Failed to load components index.json');
      const data = await res.json();
      const items = Array.isArray(data.items) ? data.items : [];
      if (!items.length) {
        grid.innerHTML = '<p style="color:#9aa4b2">No components yet. Run the <em>Stella: LLM Components</em> workflow.</p>';
        return;
      }
      const frag = document.createDocumentFragment();
      for (const c of items) {
        const node = tpl.content.cloneNode(true);
        node.querySelector('.title').textContent = c.title || c.id || 'Untitled';
        node.querySelector('.summary').textContent = c.summary || '';
        const details = node.querySelector('.code');
        try {
          const file = c.file || (c.slug ? `component-${c.slug}.json` : null);
          if (file) {
            const wr = await fetch(`components/${file}`, { cache: 'no-store' });
            if (wr.ok) { const j = await wr.json(); details.textContent = JSON.stringify(j, null, 2); }
            else { details.textContent = JSON.stringify(c, null, 2); }
          } else { details.textContent = JSON.stringify(c, null, 2); }
        } catch (err) { details.textContent = JSON.stringify(c, null, 2); }
        frag.appendChild(node);
      }
      grid.replaceChildren(frag);
    } catch (err) {
      grid.innerHTML = '<p style="color:#ef4444">Error loading components. ' + (err && err.message || err) + '</p>';
    }
  }
  load();
}());
