// Alexandria Dice & Tables (no external deps)
export function roll(notation='1d20+0'){
  const m = /^\s*(\d+)d(\d+)([+\-]\d+)?\s*$/i.exec(notation);
  if(!m) return { total:0, rolls:[], mod:0 };
  const n = parseInt(m[1],10), sides=parseInt(m[2],10), mod = m[3]?parseInt(m[3],10):0;
  const rolls = Array.from({length:n},()=> 1+Math.floor(Math.random()*sides));
  const total = rolls.reduce((a,b)=>a+b,0)+mod;
  return { total, rolls, mod };
}
export function pick(arr, n=1){
  if(!Array.isArray(arr)||arr.length===0) return [];
  const pool=[...arr]; const out=[];
  for(let i=0;i<Math.min(n, pool.length);i++){ out.push(pool.splice(Math.floor(Math.random()*pool.length),1)[0]); }
  return out;
}
export async function loadChoices(){
  try{ const r = await fetch('/apps/alexandria/knowledge/choices.json?t='+Date.now(),{cache:'no-store'}); if(!r.ok) throw 0; return r.json(); }
  catch{ return {}; }
}
