export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      return new Response(JSON.stringify({ ok: true, ts: new Date().toISOString() }), {
        headers: { "content-type": "application/json", "cache-control": "no-store" }
      });
    }
    if (url.pathname === "/tts" && request.method === "POST") {
      const body = await request.json();
      const text = (body && body.text) || "Hello from Stella.";
      const voice = body.voice || "alloy";
      const model = body.model || "tts-1";
      const resp = await fetch("https://api.openai.com/v1/audio/speech", {
        method: "POST",
        headers: { "authorization": `Bearer ${env.OPENAI_API_KEY}`, "content-type": "application/json" },
        body: JSON.stringify({ model, voice, input: text, format: "mp3" })
      });
      if (!resp.ok) {
        const err = await resp.text();
        return new Response(JSON.stringify({ error: err }), { status: 500, headers: { "content-type": "application/json" } });
      }
      return new Response(resp.body, { headers: { "content-type": "audio/mpeg", "cache-control": "no-store", "access-control-allow-origin": "*" } });
    }
    if (url.pathname === "/stt" && request.method === "POST") {
      const form = await request.formData();
      const file = form.get("file");
      if (!file) return new Response(JSON.stringify({ error: "file is required" }), { status: 400 });
      const fd = new FormData();
      fd.append("file", new Blob([await file.arrayBuffer()], { type: file.type || "audio/webm" }), file.name || "audio.webm");
      fd.append("model", "whisper-1");
      const resp = await fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: { "authorization": `Bearer ${env.OPENAI_API_KEY}` },
        body: fd
      });
      if (!resp.ok) {
        const err = await resp.text();
        return new Response(JSON.stringify({ error: err }), { status: 500, headers: { "content-type": "application/json" } });
      }
      const data = await resp.json();
      return new Response(JSON.stringify(data), { headers: { "content-type": "application/json", "access-control-allow-origin": "*" } });
    }
    if (url.pathname === "/chat" && request.method === "POST") {
      const body = await request.json();
      const messages = body.messages || [{ role: "user", content: "Hello Stella" }];
      const model = body.model || "gpt-4o-mini";
      const resp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "authorization": `Bearer ${env.OPENAI_API_KEY}`, "content-type": "application/json" },
        body: JSON.stringify({ model, messages })
      });
      if (!resp.ok) {
        const err = await resp.text();
        return new Response(JSON.stringify({ error: err }), { status: 500, headers: { "content-type": "application/json" } });
      }
      const data = await resp.json();
      return new Response(JSON.stringify(data), { headers: { "content-type": "application/json", "cache-control": "no-store", "access-control-allow-origin": "*" } });
    }
    if (request.method === "OPTIONS") {
      return new Response("", { headers: { "access-control-allow-origin": "*", "access-control-allow-methods": "POST, GET, OPTIONS", "access-control-allow-headers": "content-type, authorization" } });
    }
    return new Response("Stella Voice Worker", { headers: { "content-type": "text/plain" } });
  }
}