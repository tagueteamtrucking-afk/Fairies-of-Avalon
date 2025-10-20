const SCHEDULE = [
  { block: "Morning · Pre‑drive warm‑up (~8 min)", items: [
    "Neck circles × 5 each",
    "Shoulder rolls × 10",
    "Cat‑camel (standing against dash) × 8",
    "Hip hinges hands‑on‑thighs × 10",
    "Calf raises × 12",
    "Wall push‑ups × 8–12 (knees if inside sleeper)"
  ]},
  { block: "Mid‑shift · Micro‑break (~5 min)", items: [
    "Brisk in‑place march × 60 s",
    "Seated knee extension × 10 / side",
    "Glute squeeze (seated) × 10",
    "Thoracic openers (hands behind head) × 8"
  ]},
  { block: "Evening · Mobility & Core (~10–12 min)", items: [
    "Hamstring stretch (towel) × 30 s / side",
    "Figure‑4 (seated) × 30 s / side",
    "Side‑lying clamshells × 10 / side",
    "Dead bug (slow) × 6 / side",
    "Front plank (knees OK) × 15–30 s"
  ]}
];

function renderToday(){
  const host = document.getElementById('today');
  host.innerHTML = "";
  SCHEDULE.forEach(b => {
    const div = document.createElement('div');
    div.className = 'block';
    const h = document.createElement('h3'); h.textContent = b.block; div.appendChild(h);
    const row = document.createElement('div'); row.className = 'row';
    b.items.forEach(t => {
      const span = document.createElement('span'); span.className = 'badge'; span.textContent = t;
      row.appendChild(span);
    });
    div.appendChild(row);
    host.appendChild(div);
  });
}

document.getElementById('loadPlan').addEventListener('click', renderToday);
document.getElementById('saveLog').addEventListener('click', () => {
  const who = document.getElementById('who').value || "Unknown";
  const log = {
    ts: new Date().toISOString(),
    who,
    sit_to_stand_reps: parseInt(document.getElementById('sts_reps').value||"0",10),
    plank_seconds: parseInt(document.getElementById('plank_sec').value||"0",10),
    push_style: document.getElementById('push_style').value||"Wall",
    push_reps: parseInt(document.getElementById('push_reps').value||"0",10)
  };
  const key = 'jem_week1_log_' + who;
  const arr = JSON.parse(localStorage.getItem(key) || "[]");
  arr.push(log);
  localStorage.setItem(key, JSON.stringify(arr));
  alert("Saved locally. (The GitHub write‑back happens via the workflow you run.)");
});
