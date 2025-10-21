// pages/pages/apps/shared/auth-gate.js
// Gate pages via Cloudflare Worker (/auth/*). Shows a PIN modal if unauthenticated.
(async function(){
  const requiredRole = document.documentElement.getAttribute('data-required-role') || null;

  async function whoami() {
    const r = await fetch('/auth/whoami', { credentials: 'include' });
    if (!r.ok) throw new Error('no session');
    return r.json();
  }

  function ensureStyles() {
    if (document.getElementById('avalon-auth-styles')) return;
    const s = document.createElement('style');
    s.id = 'avalon-auth-styles';
    s.textContent = `
      .avalon-auth-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.6); display:flex; align-items:center; justify-content:center; z-index:99999; }
      .avalon-auth-card { background: #121212; color: #eee; width: 90%; max-width: 420px; border-radius: 12px; padding: 18px; box-shadow: 0 12px 30px rgba(0,0,0,.5); }
      .avalon-auth-card h2 { margin: 0 0 8px; font-size: 1.2rem; }
      .avalon-auth-card p { margin: 0 0 12px; opacity: .85; }
      .avalon-auth-input { width: 100%; padding: 12px; font-size: 1.1rem; border-radius: 8px; border: 1px solid #333; background: #1c1c1c; color: #fff; letter-spacing: 0.3em; text-align: center; }
      .avalon-auth-actions { display: flex; gap: 8px; margin-top: 12px; }
      .avalon-btn { flex: 1; padding: 10px 12px; border-radius: 8px; border: 0; background: #2a6df4; color: #fff; font-weight: 600; cursor: pointer; }
      .avalon-btn.secondary { background: #444; }
      .avalon-auth-error { color: #ff7272; margin-top: 8px; min-height: 1.2em; }
    `;
    document.head.appendChild(s);
  }

  function showModal() {
    ensureStyles();
    const overlay = document.createElement('div');
    overlay.className = 'avalon-auth-overlay';
    overlay.innerHTML = `
      <div class="avalon-auth-card" role="dialog" aria-modal="true" aria-labelledby="avalon-auth-title">
        <h2 id="avalon-auth-title">Enter PIN</h2>
        <p>4-digit PIN required to continue.</p>
        <input id="avalon-pin" class="avalon-auth-input" inputmode="numeric" pattern="[0-9]*" maxlength="4" autocomplete="one-time-code" />
        <div class="avalon-auth-actions">
          <button id="avalon-login" class="avalon-btn">Unlock</button>
          <button id="avalon-cancel" class="avalon-btn secondary">Cancel</button>
        </div>
        <div id="avalon-error" class="avalon-auth-error"></div>
      </div>`;
    document.body.appendChild(overlay);
    const input = overlay.querySelector('#avalon-pin');
    const error = overlay.querySelector('#avalon-error');
    overlay.querySelector('#avalon-cancel').onclick = () => overlay.remove();
    overlay.querySelector('#avalon-login').onclick = async () => {
      const pin = (input.value || "").trim();
      if (!/^\d{4}$/.test(pin)) { error.textContent = "PIN must be 4 digits."; return; }
      error.textContent = "";
      const r = await fetch('/auth/login', {
        method: 'POST',
        credentials: 'include',
        headers: { 'content-type':'application/json' },
        body: JSON.stringify({ pin })
      });
      if (!r.ok) {
        const data = await r.json().catch(()=>({}));
        error.textContent = data.error || 'Login failed';
        return;
      }
      location.reload();
    };
    input.focus();
  }

  try {
    const me = await whoami();
    document.documentElement.dataset.avalonRole = me.role || 'user';
    if (requiredRole && me.role !== requiredRole) {
      // Insufficient role → show modal
      showModal();
    }
  } catch {
    showModal();
  }
})();

