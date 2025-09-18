// Alexandria World Builder (client-only; no secrets)
const MAGIC = ["Mana currents","Leylines","Blood rites","Soul contracts","Runic logic","Dream‑weaving","Quantum psionics","Divine boons","Alchemy","Wild chaos"];
const MAGIC_RULES = ["Conservation of energy","Equivalent exchange","Personal cost","Ritual time","Catalyst required","Backlash risk","Corruption","Focus medium"];
const PANTHEON = ["The Twelve","Elemental Courts","Ancestor Spirits","Celestial Bureaucracy","Great Old Ones","Twin Suns & the Abyss","World‑Tree & Roots","Dragon Lords","The Nameless","Seasonal Regents"];
const BIOMES = ["plains","forest","taiga","tundra","desert","savanna","jungle","swamp","highlands","volcanic","coastal","archipelago","steppe","underworld","floating isles"];
const GOVTS = ["tribal council","city‑state senate","merchant republic","sacral monarchy","mage theocracy","warring clans","feudal houses","imperial prefectures","guild compact","nomad confederacy"];
const MONSTERS = ["dragon","hydra","phoenix","kraken","griffin","cerberus","basilisk","sphinx","kitsune","oni","yokai","tengu","naga","rakshasa","djinn","ghoul","vampire","werewolf","lich","goblin","orc","troll","giant","fae","dryad","centaur","minotaur","medusa","cyclops","harpy","wendigo","banshee","kelpie","lamia","manticore","salamander","ifrit","roc","golem","ooze"];

const $ = sel => document.querySelector(sel);
const $$ = sel => Array.from(document.querySelectorAll(sel));

function rnd(arr){ return arr[Math.floor(Math.random()*arr.length)] }
function create(el, props={}, ...children){
  const e = Object.assign(document.createElement(el), props);
  for(const c of children){ if(typeof c==="string") e.appendChild(document.createTextNode(c)); else if(c) e.appendChild(c); }
  return e;
}

function fillSelect(sel, items){
  const s = $(sel); s.innerHTML = ""; items.forEach(v=> s.appendChild(create("option",{value:v, textContent:v})));
}

function chipBox(id, items){
  const box = $(id); box.innerHTML="";
  items.forEach(v=> box.appendChild(create("button",{type:"button", textContent:v, onclick:()=>{}})));
}

function buildRegions(n){
  const wrap = $("#regions"); wrap.innerHTML="";
  for(let i=0;i<Math.max(1,Number(n||5));i++){
    const r = create("div",{className:"region"});
    const biomeSel = create("select"); BIOMES.forEach(v=> biomeSel.appendChild(create("option",{value:v,textContent:v})));
    const govSel = create("select"); GOVTS.forEach(v=> govSel.appendChild(create("option",{value:v,textContent=v})));
    const monSel = create("select"); MONSTERS.forEach(v=> monSel.appendChild(create("option",{value:v,textContent=v})));

    const biomeCus = create("input",{placeholder:"Custom biome"});
    const govCus = create("input",{placeholder:"Custom government"});
    const monCus = create("input",{placeholder:"Custom monster"});

    const biomeRoll = create("button",{type:"button",textContent:"Roll",onclick:()=> biomeSel.value=rnd(BIOMES)});
    const govRoll   = create("button",{type:"button",textContent:"Roll",onclick:()=> govSel.value=rnd(GOVTS)});
    const monRoll   = create("button",{type:"button",textContent:"Roll",onclick:()=> monSel.value=rnd(MONSTERS)});

    const row1 = create("div",{className:"row"},
      create("div",{}, create("small",{}, "Biome"), create("div",{className:"tri"}, biomeSel, biomeRoll, biomeCus)),
      create("div",{}, create("small",{}, "Government"), create("div",{className:"tri"}, govSel, govRoll, govCus)),
      create("div",{}, create("small",{}, "Signature monster"), create("div",{className:"tri"}, monSel, monRoll, monCus)),
    );
    r.appendChild(row1);
    wrap.appendChild(r);

    r._fields = { biomeSel, biomeCus, govSel, govCus, monSel, monCus };
  }
}

function currentModel(){
  const regions = $$("#regions .region").map((r,idx)=>{
    const f = r._fields;
    const biome = f.biomeCus.value.trim() || f.biomeSel.value;
    const govt  = f.govCus.value.trim()   || f.govSel.value;
    const mons  = f.monCus.value.trim()   || f.monSel.value;
    return { id:`region-${idx+1}`, name:`Region ${idx+1}`, biomes:[biome], government:govt, monsters:[mons], settlements:["Town A","Village B"] };
  });
  const rules = Array.from($("#magic-rules").querySelectorAll("button")).map(b=>b.textContent);
  const magic = $("#magic-custom").value.trim() || $("#magic-choose").value;
  const pantheon = $("#pantheon-custom").value.trim() || $("#pantheon-choose").value;

  return {
    id: `draft-${Date.now()}`,
    title: $("#w-title").value.trim(),
    prompt: $("#w-hook").value.trim(),
    timeline_events: Number($("#w-events").value)||7,
    npc_target: Number($("#w-npcs").value)||12,
    regions_count: Number($("#w-regions").value)||5,
    magic_system: { source: magic, rules },
    pantheon,
    regions
  };
}

function download(filename, dataStr){
  const a = create("a",{href:URL.createObjectURL(new Blob([dataStr],{type:"application/json"})), download:filename});
  document.body.appendChild(a); a.click(); setTimeout(()=>{URL.revokeObjectURL(a.href); a.remove()}, 0);
}

function init(){
  fillSelect("#magic-choose", MAGIC);
  fillSelect("#pantheon-choose", PANTHEON);
  chipBox("#magic-rules", MAGIC_RULES);
  buildRegions($("#w-regions").value);

  $("[data-roll='magic']").onclick = ()=> $("#magic-choose").value = rnd(MAGIC);
  $("[data-roll='pantheon']").onclick = ()=> $("#pantheon-choose").value = rnd(PANTHEON);
  $("#regen-regions").onclick = ()=> buildRegions($("#w-regions").value);

  $("#export-json").onclick = ()=> {
    const model = currentModel();
    const name = (model.title || "avalon-world").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,"");
    download(`world-draft-${name||"untitled"}.json`, JSON.stringify(model, null, 2));
  };

  $("#reset").onclick = ()=> { localStorage.removeItem("alex-world-draft"); location.reload() };
}

document.addEventListener("DOMContentLoaded", init);
