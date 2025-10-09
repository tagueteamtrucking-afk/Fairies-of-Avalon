export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    const url = new URL(request.url);
    if (request.method === 'GET') {
      return json({ ok: true, service: 'alexandria-dm', time: new Date().toISOString() });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }
    const body = await request.json().catch(() => ({}));
    const doTTS = !!body.tts;
    const voice = body.voice || 'alloy';
    let transcript = null;
    if (body.audio_b64) {
      try {
        transcript = await transcribe(body.audio_b64, env);
      } catch (e) {
        return json({ error: 'stt_failed', detail: String(e) }, 500);
      }
    }
    const text = (body.text && String(body.text)) || transcript || '';
    if (!text) return json({ error: 'no_input' }, 400);

    const reply = await chat(text, env).catch(e => ({ error: 'chat_failed', detail: String(e) }));
    if (reply.error) return json(reply, 500);

    let audio = null;
    if (doTTS) {
      try {
        const mp3 = await tts(reply.reply, voice, env);
        audio = 'data:audio/mpeg;base64,' + btoa(String.fromCharCode(...new Uint8Array(mp3)));
      } catch (e) {
        // return text even if audio fails
      }
    }
    return json({ transcript, reply: reply.reply, audio });
  }
};

function corsHeaders() {
  return {
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type',
    'access-control-allow-methods': 'POST,GET,OPTIONS',
  };
}
function json(obj, status=200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json; charset=utf-8', ...corsHeaders() } });
}

async function chat(text, env) {
  const model = env.OPENAI_MODEL || 'gpt-4.1-mini';
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'authorization': `Bearer ${env.OPENAI_API_KEY}`
    },
    body: JSON.stringify({
      model,
      temperature: 0.7,
      messages: [
        { role: 'system', content: 'You are Alexandria, a kind Dungeon Master. Keep responses concise for speech.' },
        { role: 'user', content: text }
      ]
    })
  });
  if (!r.ok) {
    const t = await r.text().catch(()=>'');
    throw new Error('openai_chat_error ' + r.status + ' ' + t);
  }
  const j = await r.json();
  const reply = j.choices?.[0]?.message?.content || '';
  return { reply };
}

async function tts(text, voice, env) {
  const model = env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts';
  const r = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'authorization': `Bearer ${env.OPENAI_API_KEY}`
    },
    body: JSON.stringify({
      model,
      voice,
      input: text,
      format: 'mp3'
    })
  });
  if (!r.ok) {
    const t = await r.text().catch(()=>'');
    throw new Error('openai_tts_error ' + r.status + ' ' + t);
  }
  const arr = new Uint8Array(await r.arrayBuffer());
  return arr;
}

async function transcribe(dataUrl, env) {
  // dataUrl like "data:audio/webm;codecs=opus;base64,AAA..."
  const b64 = dataUrl.split(',')[1] || '';
  const bin = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
  const file = new File([bin], 'audio.webm', { type: 'audio/webm' });
  const form = new FormData();
  form.set('model', env.OPENAI_STT_MODEL || 'whisper-1');
  form.set('file', file);
  const r = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { 'authorization': `Bearer ${env.OPENAI_API_KEY}` },
    body: form
  });
  if (!r.ok) {
    const t = await r.text().catch(()=>'');
    throw new Error('openai_stt_error ' + r.status + ' ' + t);
  }
  const j = await r.json();
  return j.text || '';
}
