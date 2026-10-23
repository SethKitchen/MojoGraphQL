# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Forge web site: one page, with no external resources.

The page is the control plane for graphs that customers already host. It
has seven views: Overview, Schema, Compare, Insights, Operations,
Analyst and Connect. It loads nothing from the network besides the Forge
API on the same origin.

`forge_page` puts the title into the page. The page is in `PAGE_HTML`,
with the text `__FORGE_BOOT__` in place of a JSON object
`{"title": ...}`.

Differences from upstream: none; there is no upstream. The layout is
original. It does not use Apollo Studio code.
"""

from gql_json.writer import JsonWriter

comptime BOOT_MARKER = "__FORGE_BOOT__"
"""The text in `PAGE_HTML` that `forge_page` replaces."""
comptime TITLE_MARKER = "__FORGE_TITLE__"
"""The text of the `<title>` in `PAGE_HTML`."""


def escape_html(text: StringSlice) -> String:
    """Escape text for an HTML text node or a quoted attribute.

    Args:
        text: The text.

    Returns:
        The text with `&`, `<`, `>`, `"` and `'` escaped.
    """
    var out = String(capacity_bytes=text.byte_length())
    for char in text.codepoint_slices():
        if char == "&":
            out += "&amp;"
        elif char == "<":
            out += "&lt;"
        elif char == ">":
            out += "&gt;"
        elif char == '"':
            out += "&quot;"
        elif char == "'":
            out += "&#39;"
        else:
            out += char
    return out^


def script_json(text: StringSlice) -> String:
    """Write a string as JSON that is safe inside a `<script>` element.

    Args:
        text: The string.

    Returns:
        A JSON string literal; each `<` is written as `\\u003c`.
    """
    var writer = JsonWriter()
    writer.string(text)
    return writer^.take_string().replace("<", "\\u003c")


def forge_page(title: StringSlice) -> String:
    """Return the Forge page.

    Args:
        title: The name in the header and in the browser tab.

    Returns:
        The HTML page.
    """
    var boot = '{"title":' + script_json(title) + "}"
    return (
        String(PAGE_HTML)
        .replace(TITLE_MARKER, escape_html(title))
        .replace(BOOT_MARKER, boot)
    )


comptime FAVICON_SVG = r"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#12151c"/><path fill="#d9822b" d="M14 42h36l-6 8H20z"/><path fill="#e8edf5" d="M20 14h24v4H20z"/><path fill="#8aa0b8" d="M24 20h16v18H24z"/><path fill="#d9822b" d="M28 24h8v10h-8z"/></svg>"""
"""The Forge mark, as an SVG image."""

comptime PAGE_HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__FORGE_TITLE__</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<style>
:root {
  --bg: #0b0d11; --panel: #12151c; --panel-2: #171b24; --line: #242a36;
  --text: #e8edf5; --muted: #8b95a8; --faint: #5d6678;
  --accent: #d9822b; --steel: #7aa2f7; --ok: #6fbf8a; --bad: #e06c75;
  --warn: #e0b44b; --chip: #1c2230;
  --sans: "Segoe UI", system-ui, sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
  color-scheme: dark;
}
* { box-sizing: border-box; }
[hidden] { display: none !important; }
html, body { height: 100%; }
body { margin: 0; background: var(--bg); color: var(--text); font: 13px/1.45 var(--sans); }
button, input, select, textarea { font: inherit; color: inherit; }
button { cursor: pointer; }
a { color: var(--steel); }
.app { display: grid; grid-template-columns: 220px 1fr; height: 100vh; }
.nav { background: var(--panel); border-right: 1px solid var(--line); padding: 18px 12px; display: flex; flex-direction: column; gap: 18px; }
.brand { display: flex; align-items: center; gap: 10px; padding: 0 8px; }
.brand svg { width: 28px; height: 28px; }
.brand strong { font-size: 16px; letter-spacing: .04em; }
.brand span { display: block; color: var(--muted); font-size: 11px; font-weight: 400; }
.nav button.item { width: 100%; text-align: left; background: transparent; border: 0; border-radius: 8px; padding: 8px 10px; color: var(--muted); }
.nav button.item.active, .nav button.item:hover { background: var(--panel-2); color: var(--text); }
.main { display: grid; grid-template-rows: 56px 1fr; min-width: 0; }
.top { display: flex; align-items: center; gap: 12px; padding: 0 20px; border-bottom: 1px solid var(--line); background: #0e1117; }
.sel { display: flex; gap: 8px; min-width: 0; }
.sel select, .top input, .card input, .card select, .card textarea {
  background: var(--panel-2); border: 1px solid var(--line); border-radius: 8px; padding: 6px 8px;
}
.grow { margin-left: auto; display: flex; gap: 8px; align-items: center; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: var(--faint); }
.dot.ok { background: var(--ok); }
.dot.bad { background: var(--bad); }
.content { overflow: auto; padding: 22px 24px 40px; }
h1 { font-size: 22px; font-weight: 650; margin: 0 0 6px; }
.lead { color: var(--muted); margin: 0 0 18px; max-width: 68ch; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 16px; }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 14px; }
.card h2 { margin: 0 0 8px; font-size: 13px; color: var(--muted); font-weight: 600; }
.kpi { font-size: 28px; font-weight: 650; }
.row { display: flex; justify-content: space-between; gap: 12px; padding: 8px 0; border-bottom: 1px solid var(--line); }
.row:last-child { border-bottom: 0; }
.chip { font-size: 11px; border-radius: 999px; padding: 2px 8px; background: var(--chip); color: var(--muted); }
.chip.breaking { color: var(--bad); }
.chip.dangerous { color: var(--warn); }
.chip.additive { color: var(--ok); }
.btn { background: var(--accent); color: #1a1006; border: 0; border-radius: 8px; padding: 7px 12px; font-weight: 650; }
.btn.ghost { background: var(--panel-2); color: var(--text); border: 1px solid var(--line); }
.schema { display: grid; grid-template-columns: 240px 1fr; gap: 14px; min-height: 60vh; }
.list { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; overflow: auto; }
.list button { display: block; width: 100%; text-align: left; background: transparent; border: 0; padding: 8px 12px; border-bottom: 1px solid var(--line); color: var(--muted); }
.list button.active { background: var(--panel-2); color: var(--text); }
pre { background: #0e1117; border: 1px solid var(--line); border-radius: 10px; padding: 12px; overflow: auto; font: 12px/1.5 var(--mono); }
.bar { height: 8px; background: #1b2130; border-radius: 99px; overflow: hidden; }
.bar > i { display: block; height: 100%; background: var(--steel); }
.form { display: grid; gap: 10px; max-width: 560px; }
label { display: grid; gap: 4px; color: var(--muted); }
.banner { background: #1a140c; border: 1px solid #3d2a14; color: #f0d2a8; border-radius: 10px; padding: 10px 12px; margin-bottom: 16px; }
.empty { color: var(--muted); padding: 28px; text-align: center; }
.finding { padding: 8px 0; border-bottom: 1px solid var(--line); }
</style>
</head>
<body>
<div class="app">
  <aside class="nav">
    <div class="brand">
      <svg viewBox="0 0 64 64" aria-hidden="true"><rect width="64" height="64" rx="14" fill="#12151c"/><path fill="#d9822b" d="M14 42h36l-6 8H20z"/><path fill="#e8edf5" d="M20 14h24v4H20z"/><path fill="#8aa0b8" d="M24 20h16v18H24z"/><path fill="#d9822b" d="M28 24h8v10h-8z"/></svg>
      <div><strong>Forge</strong><span>Watch graphs you run</span></div>
    </div>
    <div>
      <button class="item active" data-view="overview">Overview</button>
      <button class="item" data-view="schema">Schema</button>
      <button class="item" data-view="compare">Compare</button>
      <button class="item" data-view="insights">Insights</button>
      <button class="item" data-view="operations">Operations</button>
      <button class="item" data-view="analyst">Analyst</button>
      <button class="item" data-view="connect">Connect</button>
    </div>
  </aside>
  <section class="main">
    <header class="top">
      <div class="sel">
        <select id="org"></select>
        <select id="graph"></select>
        <select id="variant"></select>
      </div>
      <div class="grow">
        <span class="dot" id="dot"></span>
        <input id="token" placeholder="Admin token" size="18">
        <button class="btn ghost" id="reload">Reload</button>
      </div>
    </header>
    <div class="content" id="content"></div>
  </section>
</div>
<script>
const BOOT = __FORGE_BOOT__;
const state = { data: { organizations: [] }, view: "overview", org: "", graph: "", variant: "", type: "" };

function token() { return document.getElementById("token").value.trim(); }
function auth() {
  const t = token();
  return t ? { "Authorization": "Bearer " + t, "Content-Type": "application/json" } : { "Content-Type": "application/json" };
}
function qs(extra) {
  const p = new URLSearchParams({ org: state.org, graph: state.graph, variant: state.variant, ...extra });
  return p.toString();
}
async function api(path, opt) {
  const res = await fetch(path, opt);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (e) { json = { raw: text }; }
  if (!res.ok) throw new Error((json && json.error) || text || res.status);
  return json;
}
function orgs() { return state.data.organizations || []; }
function graphs() {
  const org = orgs().find(o => o.slug === state.org);
  return org ? org.graphs || [] : [];
}
function variants() {
  const g = graphs().find(g => g.ref === state.graph);
  return g ? g.variants || [] : [];
}
function currentVariant() { return variants().find(v => v.name === state.variant); }
function fillSelect(id, items, value, label) {
  const el = document.getElementById(id);
  el.innerHTML = items.map(it => `<option value="${esc(it.value)}">${esc(it.label)}</option>`).join("");
  if (items.some(it => it.value === value)) el.value = value;
  else if (items[0]) el.value = items[0].value;
  return el.value;
}
function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;" }[c])); }
function setSelectors() {
  state.org = fillSelect("org", orgs().map(o => ({ value: o.slug, label: o.name || o.slug })), state.org);
  state.graph = fillSelect("graph", graphs().map(g => ({ value: g.ref, label: g.name || g.ref })), state.graph);
  state.variant = fillSelect("variant", variants().map(v => ({ value: v.name, label: v.name })), state.variant);
  const v = currentVariant();
  const dot = document.getElementById("dot");
  dot.className = "dot" + (v && v.lastPullOk ? " ok" : v && v.lastPullError ? " bad" : "");
}
async function loadState() {
  state.data = await api("/forge/state", { headers: auth() });
  setSelectors();
}
function banner() {
  const ip = state.data.advertiseIp || "";
  if (!ip) return `<div class="banner">Forge does not host graphs. Start with --advertise-ip so customers can allowlist you, or upload SDL.</div>`;
  return `<div class="banner">Customers must allowlist <strong>${esc(ip)}</strong> so Forge can pull schemas. They keep the infrastructure.</div>`;
}
function renderOverview() {
  const v = currentVariant();
  const cards = variants().map(x => `<div class="card"><h2>${esc(x.name)}</h2><div class="kpi">${x.schemaRevision || 0}</div><div class="row"><span>Endpoint</span><span>${esc(x.endpointUrl)}</span></div><div class="row"><span>Last pull</span><span>${x.lastPullOk ? "ok" : (x.lastPullError || "never")}</span></div></div>`).join("");
  document.getElementById("content").innerHTML = `
    ${banner()}
    <h1>${esc(state.graph || "No graph")}</h1>
    <p class="lead">Forge watches this supergraph. It does not serve traffic. Compare environments, read telemetry, and inspect schema changes.</p>
    <div class="grid">${cards || `<div class="card empty">Connect a variant to begin.</div>`}</div>
    <div class="card"><h2>Current endpoint</h2><pre>${esc(v ? v.endpointUrl : "")}</pre></div>`;
}
async function renderSchema() {
  document.getElementById("content").innerHTML = `<h1>Schema</h1><p class="lead">The last snapshot Forge stored for ${esc(state.variant)}.</p><div class="empty">Loading</div>`;
  try {
    const data = await api("/forge/schema-index?" + qs());
    const types = data.types || [];
    state.type = state.type || (data.queryType || (types[0] && types[0].name) || "");
    const selected = types.find(t => t.name === state.type) || types[0];
    const fields = ((selected && (selected.fields.length ? selected.fields : selected.inputFields.length ? selected.inputFields : selected.enumValues)) || []);
    document.getElementById("content").innerHTML = `
      <h1>Schema</h1>
      <p class="lead">${esc(data.queryType || "")} query · ${types.length} types in ${esc(state.variant)}</p>
      <div class="schema">
        <div class="list">${types.map(t => `<button data-type="${esc(t.name)}" class="${t.name===state.type?"active":""}">${esc(t.name)} <span class="chip">${esc(t.kind)}</span></button>`).join("")}</div>
        <div class="card">
          <h2>${esc(selected ? selected.name : "")}</h2>
          <p class="lead">${esc(selected && selected.description || "")}</p>
          ${fields.map(f => `<div class="row"><span>${esc(f.name)}</span><span class="chip">${esc(f.type || "")}</span></div>`).join("") || "<div class='empty'>No fields</div>"}
        </div>
      </div>`;
    document.querySelectorAll("[data-type]").forEach(btn => btn.onclick = () => { state.type = btn.getAttribute("data-type"); renderSchema(); });
  } catch (e) {
    document.getElementById("content").innerHTML = `<h1>Schema</h1><div class="empty">${esc(e.message)}. Pull or upload SDL on Connect.</div>`;
  }
}
async function renderCompare() {
  const names = variants().map(v => v.name);
  const from = names[0] || "";
  const to = names[1] || names[0] || "";
  document.getElementById("content").innerHTML = `
    <h1>Compare environments</h1>
    <p class="lead">Breaking, dangerous and additive changes between two variants you already run.</p>
    <div class="form"><label>From<select id="from">${names.map(n=>`<option>${esc(n)}</option>`).join("")}</select></label>
    <label>To<select id="to">${names.map(n=>`<option>${esc(n)}</option>`).join("")}</select></label>
    <button class="btn" id="go">Compare</button></div>
    <div id="diff"></div>`;
  if (document.getElementById("from")) document.getElementById("from").value = from;
  if (document.getElementById("to")) document.getElementById("to").value = to;
  document.getElementById("go").onclick = runCompare;
  if (from && to && from !== to) runCompare();
}
async function runCompare() {
  const from = document.getElementById("from").value;
  const to = document.getElementById("to").value;
  try {
    const data = await api("/forge/compare?" + qs({ from, to }));
    document.getElementById("diff").innerHTML = `
      <div class="grid">
        <div class="card"><h2>Breaking</h2><div class="kpi">${data.breaking}</div></div>
        <div class="card"><h2>Dangerous</h2><div class="kpi">${data.dangerous}</div></div>
        <div class="card"><h2>Additive</h2><div class="kpi">${data.additive}</div></div>
      </div>
      <div class="card">${(data.changes||[]).map(c => `<div class="row"><span class="chip ${esc(c.severity)}">${esc(c.severity)}</span><span>${esc(c.description)}</span></div>`).join("") || "<div class='empty'>No changes</div>"}</div>`;
  } catch (e) {
    document.getElementById("diff").innerHTML = `<div class="empty">${esc(e.message)}</div>`;
  }
}
async function renderInsights() {
  document.getElementById("content").innerHTML = `<h1>Insights</h1><div class="empty">Loading</div>`;
  try {
    const data = await api("/forge/insights?" + qs());
    const max = Math.max(1, ...(data.operations||[]).map(o => o.count));
    document.getElementById("content").innerHTML = `
      <h1>Insights</h1>
      <p class="lead">Telemetry the customer router sent. Forge did not execute these operations.</p>
      <div class="grid">
        <div class="card"><h2>Requests</h2><div class="kpi">${data.requests}</div></div>
        <div class="card"><h2>Errors</h2><div class="kpi">${data.errors}</div></div>
        <div class="card"><h2>p95</h2><div class="kpi">${data.p95}<span style="font-size:14px"> ms</span></div></div>
        <div class="card"><h2>p99</h2><div class="kpi">${data.p99}<span style="font-size:14px"> ms</span></div></div>
      </div>
      <div class="card">${(data.operations||[]).map(o => `<div class="row"><span>${esc(o.name)}</span><span>${o.count} · p95 ${o.p95} ms</span></div><div class="bar"><i style="width:${Math.round(o.count*100/max)}%"></i></div>`).join("") || "<div class='empty'>No events yet</div>"}</div>`;
  } catch (e) {
    document.getElementById("content").innerHTML = `<h1>Insights</h1><div class="empty">${esc(e.message)}</div>`;
  }
}
async function renderOperations() {
  try {
    const data = await api("/forge/operations?" + qs());
    document.getElementById("content").innerHTML = `
      <h1>Operations</h1>
      <p class="lead">Recent events ingested from ${esc(state.variant)}.</p>
      <div class="card">${(data.recent||[]).slice().reverse().map(e => `<div class="row"><span>${esc(e.name)}</span><span>${e.ok ? "ok" : "error"} · ${e.durationMs} ms</span></div>`).join("") || "<div class='empty'>No events yet</div>"}</div>`;
  } catch (e) {
    document.getElementById("content").innerHTML = `<h1>Operations</h1><div class="empty">${esc(e.message)}</div>`;
  }
}
async function renderAnalyst() {
  document.getElementById("content").innerHTML = `
    <h1>Analyst</h1>
    <p class="lead">Ask about latency, errors, schema types, or the diff between environments. Answers come from stored evidence.</p>
    <div class="form"><textarea id="q" rows="3" placeholder="What broke between staging and prod?"></textarea><button class="btn" id="ask">Ask</button></div>
    <div id="ans"></div>`;
  document.getElementById("ask").onclick = async () => {
    try {
      const data = await api("/forge/analyze", { method: "POST", headers: auth(), body: JSON.stringify({ org: state.org, graph: state.graph, question: document.getElementById("q").value, from: state.variant }) });
      document.getElementById("ans").innerHTML = `<div class="card"><h2>${esc(data.title)}</h2><p class="lead">${esc(data.summary)}</p>${(data.findings||[]).map(f=>`<div class="finding">${esc(f)}</div>`).join("")}</div>`;
    } catch (e) {
      document.getElementById("ans").innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  };
}
function renderConnect() {
  const v = currentVariant();
  document.getElementById("content").innerHTML = `
    ${banner()}
    <h1>Connect</h1>
    <p class="lead">Point Forge at a ScorchQL gateway or router you already run. Forge does not start that process. It stores telemetry, schemas and diffs.</p>
    <div class="card form">
      <label>Organization slug<input id="c-org" value="${esc(state.org)}"></label>
      <label>Organization name<input id="c-org-name" placeholder="Acme"></label>
      <button class="btn ghost" id="mk-org">Create organization</button>
      <label>Graph ref<input id="c-graph" value="${esc(state.graph)}"></label>
      <label>Graph name<input id="c-graph-name" placeholder="Shop"></label>
      <button class="btn ghost" id="mk-graph">Create graph</button>
      <label>Variant<input id="c-var" value="${esc(state.variant || "prod")}"></label>
      <label>Endpoint URL<input id="c-url" placeholder="http://10.0.0.5:4000/graphql" value="${esc(v ? v.endpointUrl : "")}"></label>
      <button class="btn" id="mk-var">Create variant</button>
      <label>Schema SDL<textarea id="c-sdl" rows="8" placeholder="type Query { health: String }"></textarea></label>
      <div><button class="btn ghost" id="up">Upload SDL</button> <button class="btn ghost" id="pull">Pull schema</button></div>
      <pre>${v ? "Ingest token\\n" + esc(v.ingestToken) : "Create a variant to get an ingest token."}</pre>
      <p class="lead">Send one event after each operation. Use the ingest token, not the admin token:</p>
      <pre>curl /forge/telemetry -H 'content-type: application/json' \\
  -H 'authorization: Bearer &lt;INGEST_TOKEN&gt;' --data '{"org":"acme","graph":"shop","variant":"prod","name":"Hero","durationMs":12}'</pre>
    </div>`;
  const post = (path, body) => api(path, { method: "POST", headers: auth(), body: JSON.stringify(body) });
  document.getElementById("mk-org").onclick = async () => { await post("/forge/orgs", { slug: val("c-org"), name: val("c-org-name") }); await reload(); };
  document.getElementById("mk-graph").onclick = async () => { await post("/forge/graphs", { org: val("c-org"), ref: val("c-graph"), name: val("c-graph-name") }); await reload(); };
  document.getElementById("mk-var").onclick = async () => { await post("/forge/variants", { org: val("c-org"), graph: val("c-graph"), name: val("c-var"), endpointUrl: val("c-url") }); await reload(); };
  document.getElementById("up").onclick = async () => { await post("/forge/schema", { org: state.org, graph: state.graph, name: state.variant, sdl: val("c-sdl") }); await reload(); };
  document.getElementById("pull").onclick = async () => { await post("/forge/pull", { org: state.org, graph: state.graph, name: state.variant }); await reload(); };
}
function val(id) { return document.getElementById(id).value.trim(); }
async function render() {
  const views = { overview: renderOverview, schema: renderSchema, compare: renderCompare, insights: renderInsights, operations: renderOperations, analyst: renderAnalyst, connect: renderConnect };
  document.querySelectorAll(".item").forEach(b => b.classList.toggle("active", b.getAttribute("data-view") === state.view));
  await (views[state.view] || renderOverview)();
}
async function reload() { await loadState(); await render(); }
document.querySelectorAll(".item").forEach(b => b.onclick = () => { state.view = b.getAttribute("data-view"); render(); });
["org","graph","variant"].forEach(id => document.getElementById(id).onchange = () => {
  state[id] = document.getElementById(id).value;
  if (id === "org") { state.graph = ""; state.variant = ""; }
  if (id === "graph") state.variant = "";
  setSelectors(); render();
});
document.getElementById("reload").onclick = reload;
document.getElementById("token").value = sessionStorage.getItem("forgeToken") || "";
document.getElementById("token").onchange = () => sessionStorage.setItem("forgeToken", token());
loadState().then(render).catch(err => {
  document.getElementById("content").innerHTML = `<div class="empty">${esc(err.message)}</div>`;
});
</script>
</body>
</html>
"""
"""The Forge site, as one HTML document."""
