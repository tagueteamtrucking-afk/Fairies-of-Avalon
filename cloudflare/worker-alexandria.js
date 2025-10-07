export default {
  async fetch(req, env) {
    const cors={'access-control-allow-origin':'*','access-control-allow-methods':'POST,GET,OPTIONS','access-control-allow-headers':'content-type'};
    if(req.method==='OPTIONS') return new Response(null,{headers:cors});
    if(req.method==='GET') return new Response(JSON.stringify({ok:true,hint:'POST { text, sessionId, tts, voice }'}),{headers:{'content-type':'application/json',...cors}});
    if(req.method!=='POST') return new Response('POST only',{status:405,headers:cors});
    let b; try{ b=await req.json(); }catch{ return new Response(JSON.stringify({error:'bad_json'}),{status:400,headers:{'content-type':'application/json',...cors}}); }
    const {text,sessionId,tts,voice}=b||{}; if(!text) return new Response(JSON.stringify({error:'missing text'}),{status:400,headers:{'content-type':'application/json',...cors}});
    const key=env.OPENAI_API_KEY; const model=env.OPENAI_MODEL||'gpt-4.1-mini'; const ttsModel=env.OPENAI_TTS_MODEL||'gpt-4o-mini-tts';
    if(!key) return new Response(JSON.stringify({error:'missing OPENAI_API_KEY'}),{status:500,headers:{'content-type':'application/json',...cors}});
    const chat = await fetch('https://api.openai.com/v1/chat/completions',{method:'POST',headers:{'authorization':`Bearer ${key}`,'content-type':'application/json'},body:JSON.stringify({model,temperature:0.4,messages:[{role:'system',content:'You are Alexandria, a kind DM for collaborative storytelling. Be concise, suggest next moves, and ask for dice rolls when helpful.'},{role:'user',content:text}]})});
    if(!chat.ok){ const e=await chat.text(); return new Response(JSON.stringify({error:'upstream',detail:e}),{status:502,headers:{'content-type':'application/json',...cors}}); }
    const j=await chat.json(); const reply=j.choices?.[0]?.message?.content||'(no content)';
    let audio=null; if(tts){ const a=await fetch('https://api.openai.com/v1/audio/speech',{method:'POST',headers:{'authorization':`Bearer ${key}`,'content-type':'application/json'},body:JSON.stringify({model:ttsModel,input:reply,voice:voice||'alloy',format:'mp3'})}); if(a.ok){ const buf=await a.arrayBuffer(); const bytes=new Uint8Array(buf); let bin=''; for(let i=0;i<bytes.length;i++) bin+=String.fromCharCode(bytes[i]); audio = 'data:audio/mpeg;base64,'+btoa(bin); } }
    return new Response(JSON.stringify({reply,sessionId,audio}),{headers:{'content-type':'application/json','cache-control':'no-store',...cors}});
  }
}