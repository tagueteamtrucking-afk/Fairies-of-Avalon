import { listVoices, speak, cancelSpeak, ttsSupported } from '/apps/shared/tts-web.js';
import { STT, sttSupported } from '/apps/shared/stt-web.js';

function randPick(arr){ return arr[Math.floor(Math.random()*arr.length)] }
function slugify(s){ return String(s||'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'').slice(0,80) }

// Local, deterministic world-seed generator (no LLM required)
function generateSeedLocal(prompt, { isekai=false, dnd=false } = {}){
  const genres   = ['fantasy','science-fantasy','solarpunk','dieselpunk','cyber-fantasy','mythic','weird'];
  const tones    = ['hopeful','grimbright','noblebright','nobledark','cozy','epic','mysterious'];
  const magic    = ['ritual','runes','spirit contracts','songcraft','weave','divine','artifice','alchemy','bloodline','psionics','forbidden'];
  const tech     = ['stone','medieval','clockwork','renaissance','industrial','diesel','atomic','digital','biotech','post-scarcity'];
  const travel   = ['portals','skyships','leylines','dreamways','undersea gates','astral currents','wyrm tunnels','rail','caravans','orbital lifts'];
  const conflicts= ['invasion','succession','apocalypse averted','heist','holy war','colonization','rebellion','first contact','cataclysm aftermath'];
  const arche    = ['reluctant hero','archivist','witch‑engineer','paladin out of time','ranger‑navigator','bard‑spy','alchemist‑medic','cartographer'];
  const alignment= ['LG','NG','CG','LN','N','CN','LE','NE','CE']; // D&D shorthand

  const g = {
    id: 'seed-' + Date.now().toString(36),
    title: (isekai? 'Isekai: ' : '') + (prompt?.slice(0,60) || randPick(genres)+' saga'),
    tags: [randPick(genres), randPick(tones)],
    isekai,
    dnd_compatible: dnd,
    pillars: {
      magic_system: randPick(magic),
      tech_level: randPick(tech),
      travel: randPick(travel)
    },
    conflict: randPick(conflicts),
    protagonist_archetype: randPick(arche),
    starter_hook: 'A catalyst forces action: '+(prompt || 'an omen tied to the world’s core mystery.'),
    factions: [
      { name: 'The Aegis', motif: 'protective order', goal: 'preserve balance' },
      { name: 'The Crucible', motif: 'radical progress', goal: 'reshape the world' }
    ],
    cosmology: {
      planar_topology: randPick(['world‑tree','archipelago','ringworld','stacked planes','floating continents','nested bubbles']),
      portals: randPick(['rare & costly','seasonal','unstable','omnipresent'])
    },
    language_notes: ['conlangs optional; bind runes to phonemes for magic resonance'],
    safety: { content_maturity: 'pg-13' },
    references: { prompt },
    suggested_alignment_bias: dnd ? randPick(alignment) : 'n/a',
    format_version: '1.0.0'
  };

  // Derive outline
  const outline =
`Act I — Setup:
• Introduce ${g.protagonist_archetype}, show ${g.pillars.magic_system} and ${g.pillars.travel}.
• Inciting incident tied to ${g.starter_hook}.

Act II — Trials:
• Faction clash: ${g.factions[0].name} vs ${g.factions[1].name}.
• Conflict escalates (${g.conflict}); secrets of ${g.cosmology.planar_topology} surface.

Act III — Resolution:
• Choice tests values (tone: ${g.tags[1]}). Gate via ${g.cosmology.portals}.`

  return { seed: g, outline };
}

// Simple file download helper
function downloadJson(obj, filename='seed.json'){
  const blob = new Blob([JSON.stringify(obj, null, 2)], {type:'application/json'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(a.href);
}

async function init(){
  const el = (id)=>document.getElementById(id);

  const prompt = el('prompt');
  const optIsekai = el('optIsekai');
  const optDnd    = el('optDnd');
  const seedOut   = el('seed');
  const outline   = el('outline');

  // TTS controls
  const voiceSel  = el('voice');
  const rate      = el('rate');
  const pitch     = el('pitch');
  const speakBtn  = el('speak');
  const stopSpeak = el('stopSpeak');

  // STT controls
  const sttStatus = el('sttStatus');
  const startRec  = el('startRec');
  const stopRec   = el('stopRec');
  const transcript= el('transcript');
  const appendBtn = el('appendToPrompt');

  // Actions
  const genLocal  = el('genLocal');
  const exportBtn = el('exportSeed');
  const genLLM    = el('genLLM');

  // Populate voices
  if (ttsSupported()){
    const voices = await listVoices();
    voices.forEach(v => {
      const opt = document.createElement('option');
      opt.value = v.name; opt.textContent = `${v.name} (${v.lang})`;
      voiceSel.appendChild(opt);
    });
  } else {
    voiceSel.innerHTML = '<option>— TTS not supported —</option>';
  }

  // Init STT (if available)
  let stt = null;
  if (sttSupported()){
    stt = new STT({ lang: navigator.language || 'en-US', interimResults: true, continuous: true });
    stt.onStatus = (s)=>{ sttStatus.textContent = s; sttStatus.className = 'fine muted'; };
    stt.onResult = (text, isFinal)=>{
      transcript.value = text;
      if (isFinal) sttStatus.textContent = 'Finalized.';
    };
  } else {
    sttStatus.textContent = 'Speech‑to‑Text not supported in this browser (try Chrome).';
    sttStatus.className = 'fine warn';
  }

  // Wire STT buttons
  startRec.onclick = async ()=>{ if (stt){ try{ await stt.start(); }catch(e){ sttStatus.textContent = e.message; sttStatus.className='fine bad'; } } };
  stopRec.onclick  = async ()=>{ if (stt){ stt.stop(); } };
  appendBtn.onclick= ()=>{ prompt.value = (prompt.value+'\n'+transcript.value).trim(); };

  // Local seed generation
  genLocal.onclick = ()=>{
    const { seed, outline:ol } = generateSeedLocal(prompt.value, { isekai: optIsekai.checked, dnd: optDnd.checked });
    seedOut.value = JSON.stringify(seed, null, 2);
    outline.value = ol;
  };

  exportBtn.onclick = ()=>{
    let obj;
    try { obj = JSON.parse(seedOut.value); } catch { obj = null; }
    if (!obj){ alert('Seed JSON is invalid. Generate again or fix JSON.'); return; }
    const name = slugify(obj.title || obj.id || 'seed');
    downloadJson(obj, `${name}.seed.json`);
  };

  // LLM seed via workflow (open prefilled dispatch URL)
  genLLM.onclick = ()=>{
    window.open('/.github/workflows/alexandria-worldseed.yml', '_blank');
    alert('Open GitHub → Actions → “Alexandria — Generate World Seed”, fill Prompt/Isekai/DnD, and run. The seed JSON will commit to /apps/alexandria/worlds/.');
  };

  // TTS
  speakBtn.onclick = ()=>{
    const text = outline.value.trim() || prompt.value.trim();
    if (!text){ alert('Nothing to speak. Type an outline or generate a seed first.'); return; }
    const opts = { voiceName: voiceSel.value, rate: parseFloat(rate.value), pitch: parseFloat(pitch.value), volume: 1 };
    speak(text, opts).catch(()=>{ /* ignore */ });
  };
  stopSpeak.onclick = ()=> cancelSpeak();
}

init().catch(console.error);
