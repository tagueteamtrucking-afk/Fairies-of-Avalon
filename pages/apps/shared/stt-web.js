const Rec = window.SpeechRecognition || window.webkitSpeechRecognition || null;

export function sttSupported(){ return !!Rec; }

export class STT{
  constructor({ lang='en-US', interimResults=true, continuous=true } = {}){
    if (!Rec) throw new Error('STT not supported in this browser.');
    const r = this._rec = new Rec();
    r.lang = lang; r.interimResults = interimResults; r.continuous = continuous;
    this.onResult = ()=>{}; // (text, isFinal)
    this.onStatus = ()=>{}; // string
    this._buf = '';
    r.onstart = ()=> this.onStatus('Listening…');
    r.onend   = ()=> this.onStatus('Stopped.');
    r.onerror = (e)=> this.onStatus(`Error: ${e.error||'unknown'}`);
    r.onresult= (ev)=>{
      let finalText=''; let interim='';
      for (let i = ev.resultIndex; i < ev.results.length; i++){
        const res = ev.results[i];
        if (res.isFinal){ finalText += res[0].transcript; }
        else            { interim   += res[0].transcript; }
      }
      if (finalText){ this._buf += (finalText + ' '); this.onResult((this._buf + interim).trim(), true); }
      else { this.onResult((this._buf + interim).trim(), false); }
    };
  }
  start(){ return this._rec.start(); }
  stop(){  try{ this._rec.stop(); }catch{} }
  abort(){ try{ this._rec.abort(); }catch{} }
}
