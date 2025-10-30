// scripts/overseers/jem-program-plan.mjs
// Node-only Samsung Health parser → weekly plans in pages/apps/jem/programs/*.json
import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const base = path.join(repoRoot, 'pages', 'apps', 'jem');
const outDir = path.join(base, 'programs');
function ensureDir(p) { if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true }); }

// tiny CSV reader
function readCSV(file) {
  const txt = fs.readFileSync(file, 'utf8').replace(/\r/g,'');
  const lines = txt.split('\n').filter(Boolean);
  if (!lines.length) return [];
  const hdr = lines[0].split(',').map(s=>s.trim());
  return lines.slice(1).map(line => {
    const parts = []; let cur = '', inQ = false;
    for (let i=0;i<line.length;i++){
      const ch = line[i];
      if (ch === '"' && line[i+1] === '"'){ cur+='"'; i++; continue; }
      if (ch === '"'){ inQ = !inQ; continue; }
      if (!inQ && ch === ','){ parts.push(cur); cur=''; continue; }
      cur += ch;
    }
    parts.push(cur);
    const rec = {}; hdr.forEach((h,ix)=> rec[h] = (parts[ix]??'').trim());
    return rec;
  });
}
const sum = a => a.reduce((x,y)=> x+(Number(y)||0), 0);
const mean = a => a.length? sum(a)/a.length : 0;

function findCsvFiles(dir){
  const found = [];
  function walk(d){
    for (const name of fs.readdirSync(d)){
      const p = path.join(d, name);
      const s = fs.statSync(p);
      if (s.isDirectory()) walk(p);
      else if (name.toLowerCase().endsWith('.csv')) found.push(p);
    }
  }
  if (fs.existsSync(dir)) walk(dir);
  return found;
}

function analyze(files){
  const m = { stepsTotal: 0, stepsAvg: 0, workouts: 0, workoutMins: 0, sleepHoursAvg: 0 };
  let steps=[], mins=0, workouts=0, sleep=[];
  for (const f of files){
    const name = path.basename(f).toLowerCase();
    const rows = readCSV(f); if (!rows.length) continue;
    if (name.includes('step') || name.includes('steps')){
      for (const r of rows){ const s = Number(r['count']||r['steps']||r['Step count']||r['step_count']||0); if (!isNaN(s)) steps.push(s); }
    }
    if (name.includes('exercise') || name.includes('workout')){
      for (const r of rows){ const d = Number(r['duration(min)']||r['Duration (min)']||r['duration']||0); if (!isNaN(d) && d>0){ mins += d; workouts++; } }
    }
    if (name.includes('sleep')){
      for (const r of rows){ const h = Number(r['hours']||r['Hours']||r['sleep_hours']||0); if (!isNaN(h) && h>0) sleep.push(h); }
    }
  }
  m.stepsTotal = sum(steps);
  m.stepsAvg = Math.round(mean(steps));
  m.workouts = workouts;
  m.workoutMins = Math.round(mins);
  m.sleepHoursAvg = Math.round(mean(sleep)*10)/10;
  return m;
}

function buildPlan(name, m){
  const today = new Date().toISOString().slice(0,10);
  const intensity = m.workoutMins >= 90 ? 'moderate' : 'light';
  return {
    name: `week1-${name}`,
    generated: today,
    metrics: m,
    days: Array.from({length:7}, (_,i)=>{
      const d=i+1;
      const baseSteps = Math.max(3000, Math.min(12000, Math.round(m.stepsAvg || 5000)));
      const targetSteps = baseSteps + (i%2===0? 500: 0);
      const w = (i%2===1) ? { type: (i%3===0?'strength':'cardio'), minutes: intensity==='moderate' ? 30: 20 } : null;
      const notes = w ? 'Warm-up 5; cool-down 5; form over speed.' : 'Easy day: posture & breathing.';
      return { day:d, targetSteps, workout:w, notes };
    })
  };
}
function writeJSON(p, obj){ fs.writeFileSync(p, JSON.stringify(obj, null, 2)); }

async function main(){
  ensureDir(outDir);
  // CSVs are expected at EXTRACTED_DIR (set by workflow unzip step)
  const extracted = process.env.EXTRACTED_DIR || '';
  const files = extracted && fs.existsSync(extracted) ? findCsvFiles(extracted) : [];
  const whoList = (process.env.WHO || 'Ray,Blanca').split(',').map(s=>s.trim()).filter(Boolean);
  const created = [];
  if (files.length){
    for (const who of whoList){
      const m = analyze(files);
      const plan = buildPlan(who, m);
      const out = path.join(outDir, `week1-${who}.json`);
      writeJSON(out, plan);
      created.push(path.basename(out));
    }
  }
  const filesOut = fs.readdirSync(outDir).filter(f=>f.endsWith('.json'));
  const index = filesOut.map(f => ({ file:f, title:f.replace('.json','') }));
  writeJSON(path.join(outDir, 'index.json'), index);
  console.log('Created/updated programs:', created);
}
main().catch(e=>{ console.error(e); process.exit(1); });
