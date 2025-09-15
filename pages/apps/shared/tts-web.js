export function ttsSupported(){ return 'speechSynthesis' in window; }

export function listVoices(){
  return new Promise((resolve)=>{
    if (!ttsSupported()) return resolve([]);
    const v = speechSynthesis.getVoices();
    if (v && v.length) return resolve(v);
    speechSynthesis.addEventListener('voiceschanged', () => resolve(speechSynthesis.getVoices()), { once: true });
    // Safari sometimes needs a nudge
    setTimeout(() => resolve(speechSynthesis.getVoices()), 1200);
  });
}

export function cancelSpeak(){ if (ttsSupported()) speechSynthesis.cancel(); }

export async function speak(text, { voiceName, rate=1, pitch=1, volume=1 } = {}){
  if (!ttsSupported()) throw new Error('TTS not supported in this browser.');
  if (!text || !text.trim()) return;
  const voices = await listVoices();
  const u = new SpeechSynthesisUtterance(text);
  if (voiceName){
    const v = voices.find(v => v.name === voiceName);
    if (v) u.voice = v;
  }
  u.rate = Math.max(0.5, Math.min(1.5, rate));
  u.pitch= Math.max(0.5, Math.min(1.5, pitch));
  u.volume = Math.max(0, Math.min(1, volume));
  return new Promise((resolve,reject)=>{
    u.onend = () => resolve();
    u.onerror = (e) => reject(e.error || 'tts_error');
    speechSynthesis.speak(u);
  });
}
