/* Client-side PIN gate (soft access control).
 * Truth: This is not secure against a determined user on a static site.
 * Goal: lightweight personalization for <=10 users and a dev role.
 * Storage:
 *   - localStorage['avalon:pin-hashes'] = JSON.stringify([{hash, role}...])  // SHA-256 hex
 *   - localStorage['avalon:pin-session'] = JSON.stringify({hash, role, ts})
 * Configure hashes via /pages/pin-config.html
 */
(async()=>{
  const scope = (document.currentScript && document.currentScript.dataset.scope) || "site";
  const toHex = (buffer)=>[...new Uint8Array(buffer)].map(b=>b.toString(16).padStart(2,"0")).join("");
  async function sha256(str){const enc=new TextEncoder();return toHex(await crypto.subtle.digest("SHA-256", enc.encode(str)));}
  function getHashes(){
    try{ return JSON.parse(localStorage.getItem("avalon:pin-hashes")||"[]"); }
    catch{ return []; }
  }
  function getSession(){
    try{ return JSON.parse(localStorage.getItem("avalon:pin-session")||"null"); }
    catch{ return null; }
  }
  function setSession(rec){ localStorage.setItem("avalon:pin-session", JSON.stringify(rec)); }
  function overlay(html){
    const el = document.createElement("div");
    el.id = "avalon-pin-overlay";
    el.innerHTML = html;
    Object.assign(el.style, {
      position:"fixed", inset:"0", backdropFilter:"blur(6px)",
      background:"rgba(5,8,13,0.8)", color:"#e9eef5", zIndex:"9999",
      display:"flex", alignItems:"center", justifyContent:"center", padding:"20px"
    });
    document.body.appendChild(el);
    return el;
  }

  const hashes = getHashes();
  const session = getSession();

  if(!hashes.length){
    const el = overlay(`<div style="max-width:420px;background:#12161d;border:1px solid #2a3240;border-radius:12px;padding:18px;">
      <h2 style="margin-top:0">PINs not configured</h2>
      <p>To enable personalized access, set up 4‑digit PINs (up to 10) and roles using the configuration page.</p>
      <p><a href="/pages/pin-config.html" style="color:#8ab4ff">Configure PINs</a></p>
    </div>`);
    return;
  }

  // If a session exists and matches an allowed hash, continue without prompting
  if(session && hashes.some(h=>h.hash===session.hash)){
    document.documentElement.dataset.avalonRole = session.role;
    return;
  }

  // Prompt for PIN
  const el = overlay(`<form id="pinForm" style="max-width:360px;background:#12161d;border:1px solid #2a3240;border-radius:12px;padding:18px;">
    <h2 style="margin-top:0">Enter 4‑digit PIN</h2>
    <input type="password" inputmode="numeric" pattern="\d{4}" maxlength="4" minlength="4" required aria-label="PIN"
      style="width:100%;font-size:20px;padding:10px;border-radius:8px;border:1px solid #2a3240;background:#0b0e13;color:#e9eef5;" />
    <div style="display:flex;gap:10px;margin-top:12px;">
      <button type="submit" style="flex:1;padding:10px;border-radius:8px;border:1px solid #2a3240;background:#1b2230;color:#cfe3ff;">Continue</button>
      <a href="/pages/pin-config.html" style="padding:10px 12px;border-radius:8px;border:1px solid #2a3240;background:#0b0e13;color:#8ab4ff;text-decoration:none;">Configure</a>
    </div>
    <p id="pinMsg" style="color:#ff8a80;min-height:1.2em;margin:8px 0 0 0;"></p>
  </form>`);

  const form = el.querySelector("#pinForm");
  const pinMsg = el.querySelector("#pinMsg");
  form.addEventListener("submit", async (ev)=>{
    ev.preventDefault();
    const pin = form.querySelector("input").value.trim();
    if(!/^\d{4}$/.test(pin)){ pinMsg.textContent="PIN must be 4 digits."; return; }
    const hash = await sha256(pin);
    const rec = hashes.find(h=>h.hash===hash);
    if(!rec){ pinMsg.textContent="Invalid PIN."; return; }
    setSession({hash, role:rec.role||"user", ts: Date.now()});
    document.documentElement.dataset.avalonRole = rec.role||"user";
    el.remove();
  });
})();
