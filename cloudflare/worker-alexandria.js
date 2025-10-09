export default {
  async fetch(req, env) {
    const cors={'access-control-allow-origin':'*','access-control-allow-methods':'POST,GET,OPTIONS','access-control-allow-headers':'content-type'};
    if(req.method==='OPTIONS') return new Response(null,{headers:cors});
    if(req.method==='GET') return new Response(JSON.stringify({ok:true,hint:'POST JSON: { text, sessionId, tts, voice } or { audio_b64, mime, do_chat }'}),{headers:{'content-type':'application/json',...cors}});
    if(req.method!=='POST') return new Response('POST only',{status:405,headers:cors});
    let b; try{ b=await req.json(); }catch{ return new Response(JSON.stringify({error:'bad_json'}),{status:400,headers:{'content-type':'application/json',...cors}}); }

    const key=env.OPENAI_API_KEY; if(!key) return new Response(JSON.stringify({error:'missing OPENAI_API_KEY'}),{status:500,headers:{'content-type':'application/json',...cors}});
    const model=env.OPENAI_MODEL||'gpt-4.1-mini';
    const ttsModel=env.OPENAI_TTS_MODEL||'gpt-4o-mini-tts';

    // If voice payload provided: transcribe first
    if(b.audio_b64){
      const { text, transcript, reply, audio } = await handleVoicePipeline(b, key, model, ttsModel);
      return new Response(JSON.stringify({ transcript, reply, audio }),{headers:{'content-type':'application/json',...cors}});
    }

    // Otherwise normal text chat
    const text = b.text;
    const tts = !!b.tts; const voice=b.voice||'alloy';
    if(!text) return new Response(JSON.stringify({error:'missing text'}),{status:400,headers:{'content-type':'application/json',...cors}});
    const reply = await chat(text, key, model);
    let audio=null; if(tts){ audio = await speak(reply, key, ttsModel, voice); }
    return new Response(JSON.stringify({ reply, audio }),{headers:{'content-type':'application/json',...cors}});

    async function chat(text, key, model){
      const r = await fetch('https://api.openai.com/v1/chat/completions',{
        method:'POST',headers:{'authorization':`Bearer ${key}`,'content-type':'application/json'},
        body:JSON.stringify({model,temperature:0.4,messages:[{role:'system',content:'You are Alexandria, a kind DM for collaborative storytelling. Be concise, suggest next moves, and ask for dice rolls when helpful.'},{role:'user',content:text}]})
      }); if(!r.ok) throw new Error('chat '+await r.text());
      const j = await r.json(); return j.choices?.[0]?.message?.content || '(no content)';
    }
    async function speak(text, key, ttsModel, voice){
      const r = await fetch('https://api.openai.com/v1/audio/speech',{method:'POST',headers:{'authorization':`Bearer ${key}`,'content-type':'application/json'},body:JSON.stringify({model:ttsModel,input:text,voice,format:'mp3'})});
      if(!r.ok) return null; const buf=await r.arrayBuffer(); const bytes=new Uint8Array(buf); let bin=''; for(let i=0;i<bytes.length;i++) bin+=String.fromCharCode(bytes[i]); return 'data:audio/mpeg;base64,'+btoa(bin);
    }
    async function handleVoicePipeline(b, key, model, ttsModel){
      const { audio_b64, mime, do_chat, tts, voice } = b;
      const { data, type } = parseDataUrl(audio_b64, mime);
      // Build multipart for Whisper
      const fd = new FormData();
      const file = new File([data], 'input'+extFromMime(type), { type });
      fd.append('file', file);
      fd.append('model', 'whisper-1');
      const tr = await fetch('https://api.openai.com/v1/audio/transcriptions',{ method:'POST', headers:{'authorization':`Bearer ${key}`}, body: fd });
      if(!tr.ok) throw new Error('stt '+await tr.text());
      const tj = await tr.json(); const transcript = tj.text || '';
      if(!do_chat) return { text: null, transcript, reply: null, audio: null };
      const reply = await chat(transcript, key, model);
      let audio = null; if(tts){ audio = await speak(reply, key, ttsModel, voice||'alloy'); }
      return { text: null, transcript, reply, audio };
    }
    function parseDataUrl(dataUrl, fallbackMime){
      try{
        const i=dataUrl.indexOf(',');
        const header=dataUrl.substring(0,i); const b64=dataUrl.substring(i+1);
        const m = /data:(.*?);base64/.exec(header); const type=(m && m[1]) || fallbackMime || 'audio/webm';
        const bin = atob(b64); const bytes = new Uint8Array(bin.length); for(let i=0;i<bin.length;i++) bytes[i]=bin.charCodeAt(i);
        return { data: bytes, type };
      }catch(e){ return { data: new Uint8Array(0), type: fallbackMime||'application/octet-stream' }; }
    }
    function extFromMime(m){ if(m.includes('webm')) return '.webm'; if(m.includes('mp4')) return '.mp4'; if(m.includes('mpeg')) return '.mp3'; return ''; }
  }
}