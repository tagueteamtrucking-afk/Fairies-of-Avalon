// cloudflare/worker-auth.js
// Edge auth worker for Avalon: PIN -> session cookie (HMAC-signed), whoami, logout
// Secrets are provided at deploy time via Cloudflare secrets (set by GitHub Actions):
//   - SESSION_SECRET (random long string)
//   - PIN_RAY (e.g., 1775), PIN_BLANCA (e.g., 4406)
// Route all traffic through this worker at Cloudflare (proxied DNS), with public allowlist if desired.

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/auth/login" && request.method === "POST") {
      const body = await request.json().catch(() => ({}));
      const { pin } = body || {};
      if (!pin) return json({ error: "Missing pin" }, 400);

      let role = null;
      let name = null;

      if (pin === env.PIN_RAY) {
        role = "dev";
        name = "Ray";
      } else if (pin === env.PIN_BLANCA) {
        role = "user";
        name = "Blanca";
      } else {
        return json({ error: "Invalid PIN" }, 401);
      }

      const exp = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30; // 30 days
      const payload = { role, name, exp };
      const token = await sign(payload, env.SESSION_SECRET);

      const headers = new Headers({
        "content-type": "application/json",
        "set-cookie": cookie("avalon_session", token, { httpOnly: true, sameSite: "Lax", path: "/", maxAge: 60 * 60 * 24 * 30, secure: true })
      });
      return new Response(JSON.stringify({ ok: true, role, name, exp }), { status: 200, headers });
    }

    if (path === "/auth/logout") {
      const headers = new Headers({
        "content-type": "application/json",
        "set-cookie": cookie("avalon_session", "", { httpOnly: true, sameSite: "Lax", path: "/", maxAge: 0, secure: true })
      });
      return new Response(JSON.stringify({ ok: true }), { status: 200, headers });
    }

    if (path === "/auth/whoami") {
      const token = getCookie(request.headers.get("cookie") || "", "avalon_session");
      if (!token) return json({ error: "No session" }, 401);
      try {
        const payload = await verify(token, env.SESSION_SECRET);
        if (!payload || !payload.exp || payload.exp * 1000 < Date.now()) {
          return json({ error: "Session expired" }, 401);
        }
        return json({ role: payload.role, name: payload.name, exp: payload.exp }, 200);
      } catch (e) {
        return json({ error: "Invalid session" }, 401);
      }
    }

    // Default: proxy to origin (static site). If you enable full gating, add path checks here.
    return fetch(request);
  }
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" }
  });
}

function cookie(name, value, opts = {}) {
  const parts = [`${name}=${value || ""}`];
  if (opts.maxAge !== undefined) parts.push(`Max-Age=${opts.maxAge}`);
  if (opts.path) parts.push(`Path=${opts.path}`);
  if (opts.sameSite) parts.push(`SameSite=${opts.sameSite}`);
  if (opts.httpOnly) parts.push("HttpOnly");
  if (opts.secure) parts.push("Secure");
  return parts.join("; ");
}

function getCookie(header, name) {
  const cookies = header.split(/;\s*/g);
  for (const c of cookies) {
    const [k, ...rest] = c.split("=");
    if (k === name) return rest.join("=");
  }
  return null;
}

async function sign(payload, secret) {
  const enc = new TextEncoder();
  const header = { alg: "HS256", typ: "JWTlite" };
  const h64 = b64u(JSON.stringify(header));
  const p64 = b64u(JSON.stringify(payload));
  const msg = `${h64}.${p64}`;
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, enc.encode(msg));
  const sig = b64u(String.fromCharCode(...new Uint8Array(mac)));
  return `${msg}.${sig}`;
}

async function verify(token, secret) {
  const enc = new TextEncoder();
  const [h64, p64, sig] = token.split(".");
  if (!h64 || !p64 || !sig) throw new Error("bad token");
  const msg = `${h64}.${p64}`;
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, enc.encode(msg));
  const expected = b64u(String.fromCharCode(...new Uint8Array(mac)));
  if (sig !== expected) throw new Error("bad sig");
  return JSON.parse(atobUrl(p64));
}

function b64u(str) {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
function atobUrl(str) {
  str = str.replace(/-/g, "+").replace(/_/g, "/");
  while (str.length % 4) str += "=";
  return atob(str);
}
