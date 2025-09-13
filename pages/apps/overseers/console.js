const capURL = "./capabilities.json";          // relative to /apps/overseers/
const progURL = "./progress.json";             // ditto

const els = {
  aiStatus: document.getElementById("ai-status"),
  aiMode:   document.getElementById("ai-mode"),
  lastRun:  document.getElementById("last-run"),
  barFill:  document.getElementById("bar-fill"),
  done:     document.getElementById("done"),
  total:    document.getElementById("total"),
  success:  document.getElementById("success"),
  pending:  document.getElementById("pending"),
  failed:   document.getElementById("failed"),
  history:  document.getElementById("history"),
};

async function fetchJSON(url) {
  const u = `${url}?t=${Date.now()}`; // cache-buster
  const res = await fetch(u, { cache: "no-store" });
  if (!res.ok) throw new Error(`${url} ${res.status}`);
  return res.json();
}

function setBadge(el, text, ok=true) {
  el.textContent = text;
  el.style.borderColor = ok ? "#2aa198" : "#cb4b16";
  el.style.color = ok ? "#2aa198" : "#cb4b16";
}

function renderCaps(caps) {
  const status = caps?.ai_core?.status || "unknown";
  setBadge(els.aiStatus, `AI Core: ${status}`, /operational|ready/i.test(status));
  const dryDefault = !!caps?.ai_core?.llm_bridge?.dry_run_default;
  setBadge(els.aiMode, dryDefault ? "LLM Mode: DRY-RUN" : "LLM Mode: LIVE", !dryDefault);
}

function renderProgress(p) {
  try {
    els.lastRun.textContent = `last run: ${p.last_run || "—"}`;
    const totals = p.totals || {};
    const pending = Number(p.pending || 0);
    const success = Number(totals.success || 0);
    const failed  = Number(totals.failed || 0);
    const skipped = Number(totals.skipped || 0);
    const total   = success + failed + skipped + pending;
    const done    = success + failed + skipped;

    els.done.textContent = String(done);
    els.total.textContent = String(total);
    els.success.textContent = String(success);
    els.pending.textContent = String(pending);
    els.failed.textContent = String(failed);

    const pct = total > 0 ? Math.round((success / total) * 100) : 0;
    els.barFill.style.width = `${pct}%`;
    els.barFill.style.background = pct === 100 ? "#2aa198" : "#268bd2";

    // history
    const rows = (p.processed || []).slice(-20).reverse().map(r => {
      const tr = document.createElement("tr");
      const when = r.ended || r.started || "";
      const note = [
        r.id ? `id=${r.id}` : "",
        r.actor ? `by ${r.actor}` : "",
        typeof r.dry_run === "boolean" ? (r.dry_run ? "dry-run" : "live") : ""
      ].filter(Boolean).join(" · ");
      tr.innerHTML = `<td>${when.replace("T"," ").replace("Z","Z")}</td>
                      <td>${r.action || ""}</td>
                      <td>${r.status || ""}</td>
                      <td>${note}</td>`;
      return tr;
    });
    els.history.replaceChildren(...rows);
  } catch (e) {
    console.error("renderProgress failed", e);
  }
}

async function tick() {
  try {
    const [caps, prog] = await Promise.all([fetchJSON(capURL), fetchJSON(progURL)]);
    renderCaps(caps);
    renderProgress(prog);
  } catch (e) {
    console.warn("poll error:", e);
  }
}

document.addEventListener("visibilitychange", () => { if (!document.hidden) tick(); });
setInterval(tick, 5000);
tick();
