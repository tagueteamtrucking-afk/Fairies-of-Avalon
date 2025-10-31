export default {
      async fetch(req, env) {
        const u = new URL(req.url);
        if (u.pathname.startsWith('/api/market/quote')) {
          return new Response(JSON.stringify({ ok: true, quote: 19.99 }), { headers: { 'content-type': 'application/json' } });
        }
        if (u.pathname.startsWith('/api/market/license')) {
          return new Response(JSON.stringify({ ok: true, license: 'AVL-PERSONAL-XXXX' }), { headers: { 'content-type': 'application/json' } });
        }
        if (u.pathname.startsWith('/api/market/download')) {
          return new Response(JSON.stringify({ ok: true, link: '/downloads/sku.zip' }), { headers: { 'content-type': 'application/json' } });
        }
        return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' } });
      }
    }