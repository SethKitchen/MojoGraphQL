# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The ScorchQL explorer: one web page, with no external resources.

The page reads the schema of the gateway with an introspection query, and
the state of the gateway from `GET /scorchql/state`. It has four views:

- **Explorer**: the documentation of the current type, with a checkbox per
  field that adds the field to the operation; an operation editor with
  highlighting, field completion and tabs; variables and headers; the
  response; and the query plan of the operation.
- **Schema**: every type of the API schema, with its fields, arguments,
  descriptions and the subgraphs that resolve each field.
- **Subgraphs**: the published subgraphs, their SDL, and the forms to
  publish, refresh and remove a subgraph.
- **SDL**: the API schema and the supergraph SDL.

Every 5 seconds the page reads the state again. When the revision has
changed, it reads the schema again.

`explorer_page` puts the title and the GraphQL path into the page. The
page is in `EXPLORER_HTML`, with the text `__SCORCHQL_BOOT__` in place of
a JSON object `{"title": ..., "graphqlPath": ...}`.

Differences from upstream: none; there is no upstream. The layout follows
the public pages of Apollo Sandbox, but no Apollo code is used.
"""

from gql_composition.printer import json_string

comptime BOOT_MARKER = "__SCORCHQL_BOOT__"
"""The text in `EXPLORER_HTML` that `explorer_page` replaces."""
comptime TITLE_MARKER = "__SCORCHQL_TITLE__"
"""The text of the `<title>` in `EXPLORER_HTML`."""


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
    return json_string(text).replace("<", "\\u003c")


def explorer_page(title: StringSlice, graphql_path: StringSlice) -> String:
    """Return the explorer page of a gateway.

    Args:
        title: The name in the header and in the browser tab.
        graphql_path: The GraphQL path, such as `/graphql`.

    Returns:
        The HTML page.
    """
    var boot = (
        '{"title":'
        + script_json(title)
        + ',"graphqlPath":'
        + script_json(graphql_path)
        + "}"
    )
    return (
        String(EXPLORER_HTML)
        .replace(TITLE_MARKER, escape_html(title))
        .replace(BOOT_MARKER, boot)
    )


comptime FAVICON_SVG = r"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs><linearGradient id="f" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#e8202a"/><stop offset=".55" stop-color="#ff6a1a"/><stop offset="1" stop-color="#ffb703"/></linearGradient></defs><path fill="url(#f)" d="M33 3c2 9-3 14-8 20-5 6-10 12-10 21 0 10 8 17 17 17s17-7 17-17c0-7-3-12-7-16 0 5-2 9-6 11 1-9-1-19-3-36zm-1 34c3 4 7 7 7 13 0 4-3 7-7 7s-7-3-7-7c0-4 3-7 7-13z"/></svg>"""
"""The ScorchQL flame, as an SVG image."""

comptime EXPLORER_HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__SCORCHQL_TITLE__</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<style>
:root {
  --bg: #0e0a09; --panel: #161110; --panel-2: #1d1614; --panel-3: #251b18;
  --line: #36261f; --line-2: #4a3329; --text: #f7e9de; --muted: #b59a8b;
  --faint: #7d675b; --ember: #ff6a1a; --flame: #ff3d00; --gold: #ffb703;
  --red: #ff4d5e; --green: #7bd88f; --blue: #79b8ff; --violet: #d6a6ff;
  --fire: linear-gradient(135deg, #ffb703 0%, #ff6a1a 45%, #e8202a 100%);
  --mono: ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
  --sans: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  color-scheme: dark;
}
* { box-sizing: border-box; }
[hidden] { display: none !important; }
html, body { height: 100%; }
body { margin: 0; background: var(--bg); color: var(--text); font: 13px/1.45 var(--sans); overflow: hidden; }
button, input, select, textarea { font: inherit; color: inherit; }
a { color: var(--gold); }
::selection { background: rgba(255, 106, 26, .35); }
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-thumb { background: var(--line-2); border-radius: 6px; border: 2px solid var(--panel); }
::-webkit-scrollbar-track { background: transparent; }

.app { display: grid; grid-template-rows: 52px 1fr; height: 100vh; }
header.top { display: flex; align-items: center; gap: 14px; padding: 0 14px; border-bottom: 1px solid var(--line);
  background: linear-gradient(180deg, #1b1210, #140e0c); position: relative; }
header.top::after { content: ""; position: absolute; left: 0; right: 0; bottom: -1px; height: 1px; background: var(--fire); opacity: .55; }
.brand { display: flex; align-items: center; gap: 8px; font-weight: 800; letter-spacing: .2px; font-size: 17px; }
.brand svg { width: 26px; height: 26px; filter: drop-shadow(0 0 6px rgba(255, 106, 26, .55)); animation: flicker 3.2s infinite ease-in-out; transform-origin: 50% 90%; }
@keyframes flicker { 0%,100% { transform: scale(1) rotate(0); } 30% { transform: scale(1.04, .97) rotate(-1.5deg); } 60% { transform: scale(.98, 1.03) rotate(1deg); } }
.brand .word { background: var(--fire); -webkit-background-clip: text; background-clip: text; color: transparent; }
.brand .title { color: var(--muted); font-weight: 600; font-size: 13px; margin-left: 4px; }
.endpoint { flex: 1; display: flex; align-items: center; gap: 8px; min-width: 0; }
.endpoint .pill { display: flex; align-items: center; gap: 8px; background: var(--panel-2); border: 1px solid var(--line); border-radius: 8px;
  padding: 5px 10px; font-family: var(--mono); font-size: 12px; min-width: 0; max-width: 520px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: var(--faint); flex: none; }
.dot.ok { background: var(--green); box-shadow: 0 0 8px var(--green); }
.dot.warn { background: var(--gold); box-shadow: 0 0 8px var(--gold); }
.dot.bad { background: var(--red); box-shadow: 0 0 8px var(--red); }
.chip { font-size: 11px; color: var(--muted); border: 1px solid var(--line); border-radius: 999px; padding: 2px 8px; white-space: nowrap; }
.btn { background: var(--panel-3); border: 1px solid var(--line-2); border-radius: 7px; padding: 6px 11px; cursor: pointer; white-space: nowrap; }
.btn:hover { border-color: var(--ember); }
.btn.fire { background: var(--fire); border: 0; color: #1a0b05; font-weight: 700; box-shadow: 0 0 14px rgba(255, 106, 26, .35); }
.btn.fire:hover { filter: brightness(1.08); }
.btn.ghost { background: transparent; border-color: transparent; color: var(--muted); }
.btn.ghost:hover { color: var(--text); border-color: var(--line-2); }
.btn.small { padding: 3px 8px; font-size: 12px; }
.btn.danger:hover { border-color: var(--red); color: var(--red); }
.btn:disabled { opacity: .5; cursor: default; }

.main { display: grid; grid-template-columns: 56px minmax(0, 1fr); min-height: 0; }
nav.rail { border-right: 1px solid var(--line); background: var(--panel); display: flex; flex-direction: column; align-items: center; padding-top: 8px; gap: 4px; }
nav.rail button { width: 42px; height: 42px; border-radius: 10px; border: 1px solid transparent; background: transparent; color: var(--muted); cursor: pointer; display: grid; place-items: center; position: relative; }
nav.rail button svg { width: 20px; height: 20px; }
nav.rail button:hover { color: var(--text); background: var(--panel-2); }
nav.rail button.on { color: var(--gold); background: var(--panel-3); border-color: var(--line-2); }
nav.rail button.on::before { content: ""; position: absolute; left: -7px; top: 9px; bottom: 9px; width: 3px; border-radius: 3px; background: var(--fire); }
nav.rail button .tip { position: absolute; left: 50px; background: var(--panel-3); border: 1px solid var(--line-2); padding: 3px 8px; border-radius: 6px; font-size: 12px; white-space: nowrap; color: var(--text); pointer-events: none; opacity: 0; transition: opacity .12s; z-index: 30; }
nav.rail button:hover .tip { opacity: 1; }
.view { min-height: 0; min-width: 0; display: none; }
.view.on { display: grid; }

/* Explorer */
#view-explorer { grid-template-columns: minmax(240px, 22%) minmax(320px, 1fr) minmax(320px, 1fr); }
.pane { min-height: 0; min-width: 0; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--panel); }
.pane:last-child { border-right: 0; }
.pane-head { height: 40px; flex: none; display: flex; align-items: center; gap: 8px; padding: 0 12px; border-bottom: 1px solid var(--line); background: var(--panel-2); }
.pane-head h2 { margin: 0; font-size: 12px; text-transform: uppercase; letter-spacing: .9px; color: var(--muted); font-weight: 700; }
.pane-head .spacer { flex: 1; }
.pane-body { flex: 1; min-height: 0; overflow: auto; }

.docs { padding: 8px 0 20px; }
.crumbs { display: flex; flex-wrap: wrap; gap: 4px; padding: 8px 12px; font-size: 12px; color: var(--muted); border-bottom: 1px solid var(--line); }
.crumbs a { cursor: pointer; color: var(--gold); text-decoration: none; }
.crumbs a:hover { text-decoration: underline; }
.roots { display: flex; gap: 4px; padding: 8px 12px 0; }
.roots button { flex: 1; }
.roots button.on { border-color: var(--ember); color: var(--gold); }
.docs .typehead { padding: 10px 12px 4px; }
.docs .typehead .tname { font-family: var(--mono); font-size: 14px; color: var(--gold); font-weight: 700; }
.docs .desc { color: var(--muted); font-size: 12px; padding: 2px 12px 6px; white-space: pre-wrap; }
.docs .section { padding: 10px 12px 4px; font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: var(--faint); font-weight: 700; }
.frow { display: grid; grid-template-columns: 22px 1fr auto; align-items: center; gap: 4px; padding: 4px 12px; cursor: default; }
.frow:hover { background: var(--panel-2); }
.frow input[type=checkbox] { accent-color: var(--ember); margin: 0; cursor: pointer; }
.frow .fname { font-family: var(--mono); font-size: 12.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.frow .fname .args { color: var(--faint); }
.frow .ftype { font-family: var(--mono); font-size: 12px; color: var(--blue); white-space: nowrap; }
.frow .go { cursor: pointer; color: var(--faint); padding: 0 2px; }
.frow .go:hover { color: var(--gold); }
.frow.dep .fname { text-decoration: line-through; color: var(--faint); }
.frow .fdesc { grid-column: 2 / 4; color: var(--faint); font-size: 11.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.argrow { display: grid; grid-template-columns: 22px 1fr auto; gap: 4px; padding: 2px 12px 2px 34px; font-family: var(--mono); font-size: 12px; color: var(--muted); }
.argrow input { accent-color: var(--gold); margin: 0; }
.argrow .ftype { color: var(--violet); }
.empty { color: var(--faint); padding: 18px 14px; font-size: 12.5px; }

.tabs { display: flex; align-items: stretch; height: 36px; border-bottom: 1px solid var(--line); background: var(--panel); overflow-x: auto; flex: none; }
.tab { display: flex; align-items: center; gap: 6px; padding: 0 10px 0 12px; border-right: 1px solid var(--line); color: var(--muted); cursor: pointer; white-space: nowrap; font-size: 12.5px; max-width: 200px; }
.tab span { overflow: hidden; text-overflow: ellipsis; }
.tab.on { color: var(--text); background: var(--panel-2); box-shadow: inset 0 -2px 0 var(--ember); }
.tab .x { opacity: .5; padding: 0 3px; border-radius: 4px; }
.tab .x:hover { opacity: 1; background: var(--line-2); }
.tab-add { padding: 0 12px; color: var(--muted); cursor: pointer; display: flex; align-items: center; font-size: 16px; }
.tab-add:hover { color: var(--gold); }

.editor-wrap { position: relative; flex: 1; min-height: 120px; display: flex; background: var(--panel); }
.gutter { flex: none; width: 42px; padding: 10px 6px 10px 0; text-align: right; color: var(--faint); font: 12.5px/1.6 var(--mono); user-select: none; overflow: hidden; background: var(--panel); border-right: 1px solid var(--line); white-space: pre; }
.code { position: relative; flex: 1; min-width: 0; }
.code textarea, .code pre { position: absolute; inset: 0; margin: 0; padding: 10px 12px; border: 0; font: 12.5px/1.6 var(--mono); white-space: pre; overflow: auto; tab-size: 2; letter-spacing: 0; word-wrap: normal; }
.code pre { pointer-events: none; color: var(--text); }
.code textarea { background: transparent; color: transparent; caret-color: var(--gold); resize: none; outline: none; }
.code textarea::placeholder { color: var(--faint); }
.code pre.readonly { pointer-events: auto; user-select: text; }
.t-kw { color: #ff7b72; } .t-name { color: var(--text); } .t-field { color: #ffd8a8; } .t-type { color: var(--blue); }
.t-var { color: var(--violet); } .t-str { color: var(--green); } .t-num { color: var(--gold); } .t-com { color: var(--faint); font-style: italic; }
.t-punc { color: var(--muted); } .t-dir { color: #ffa657; } .t-arg { color: #f0b37e; }
.j-key { color: #ffd8a8; } .j-str { color: var(--green); } .j-num { color: var(--gold); } .j-bool { color: #ff7b72; } .j-null { color: var(--faint); }

.toolbar { display: flex; align-items: center; gap: 6px; padding: 6px 10px; border-bottom: 1px solid var(--line); background: var(--panel-2); flex: none; }
.toolbar .spacer { flex: 1; }
.run { display: flex; align-items: center; gap: 6px; }
.run svg { width: 12px; height: 12px; }
.kbd { font-family: var(--mono); font-size: 10.5px; color: var(--muted); border: 1px solid var(--line-2); border-bottom-width: 2px; border-radius: 4px; padding: 0 4px; }
.split { flex: none; height: 6px; cursor: row-resize; background: var(--panel-2); border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); }
.split:hover { background: var(--line-2); }
.sub { display: flex; flex-direction: column; min-height: 80px; }
.subtabs { display: flex; gap: 2px; padding: 0 8px; height: 32px; align-items: stretch; background: var(--panel); border-bottom: 1px solid var(--line); flex: none; }
.subtabs button { background: none; border: 0; padding: 0 10px; color: var(--muted); cursor: pointer; font-size: 12px; text-transform: uppercase; letter-spacing: .7px; font-weight: 700; }
.subtabs button.on { color: var(--gold); box-shadow: inset 0 -2px 0 var(--ember); }
.subtabs .spacer { flex: 1; }
.meta { display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--muted); }
.status-ok { color: var(--green); } .status-bad { color: var(--red); }

.result { flex: 1; min-height: 0; position: relative; }
.result > pre { margin: 0; padding: 12px 14px; font: 12.5px/1.6 var(--mono); white-space: pre-wrap; word-break: break-word; position: absolute; inset: 0; overflow: auto; }
.placeholder { position: absolute; inset: 0; display: grid; place-items: center; text-align: center; color: var(--faint); padding: 20px; }
.placeholder svg { width: 56px; height: 56px; opacity: .55; margin-bottom: 8px; }
.spinner { width: 18px; height: 18px; border-radius: 50%; border: 2px solid var(--line-2); border-top-color: var(--ember); animation: spin .7s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.plan { padding: 12px; overflow: auto; position: absolute; inset: 0; }
.pnode { border: 1px solid var(--line-2); border-radius: 9px; margin: 6px 0; background: var(--panel-2); }
.pnode > .phead { display: flex; align-items: center; gap: 8px; padding: 6px 10px; font-size: 12px; font-weight: 700; letter-spacing: .5px; text-transform: uppercase; color: var(--muted); }
.pnode > .pkids { padding: 2px 10px 8px; }
.pnode.parallel > .pkids { display: flex; gap: 8px; flex-wrap: wrap; }
.pnode.parallel > .pkids > * { flex: 1 1 220px; }
.pnode.fetch { border-color: transparent; background: linear-gradient(var(--panel-3), var(--panel-3)) padding-box, var(--fire) border-box; border: 1px solid transparent; }
.pnode.subscription { border-color: rgba(214, 166, 255, .55); }
.pnode .svc { font-family: var(--mono); text-transform: none; letter-spacing: 0; color: #1a0b05; background: var(--fire); padding: 1px 7px; border-radius: 999px; font-size: 11.5px; }
.pnode .ppath { font-family: var(--mono); text-transform: none; letter-spacing: 0; color: var(--violet); font-weight: 500; }
.pnode pre { margin: 0; padding: 4px 12px 10px; font: 12px/1.55 var(--mono); white-space: pre-wrap; }
.plan-toggle { display: flex; gap: 4px; }
.plan-toggle .btn.on { border-color: var(--ember); color: var(--gold); background: rgba(255, 106, 26, .1); }

/* Schema view */
#view-schema { grid-template-columns: minmax(220px, 280px) 1fr; }
.search { padding: 8px; border-bottom: 1px solid var(--line); }
.search input { width: 100%; background: var(--panel-2); border: 1px solid var(--line-2); border-radius: 7px; padding: 6px 9px; outline: none; }
.search input:focus { border-color: var(--ember); }
.tlist .group { padding: 10px 12px 4px; font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: var(--faint); font-weight: 700; }
.tlist a { display: flex; justify-content: space-between; gap: 6px; padding: 4px 12px; cursor: pointer; font-family: var(--mono); font-size: 12.5px; color: var(--text); text-decoration: none; }
.tlist a:hover { background: var(--panel-2); }
.tlist a.on { background: var(--panel-3); color: var(--gold); box-shadow: inset 2px 0 0 var(--ember); }
.tlist a .k { color: var(--faint); font-size: 11px; font-family: var(--sans); }
.tdetail { padding: 18px 24px 40px; max-width: 980px; }
.tdetail h1 { font: 700 20px var(--mono); margin: 0 0 4px; color: var(--gold); }
.tdetail .kind { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: var(--faint); }
.tdetail p.d { color: var(--muted); white-space: pre-wrap; }
table.fields { width: 100%; border-collapse: collapse; margin-top: 10px; }
table.fields th { text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: var(--faint); padding: 6px 8px; border-bottom: 1px solid var(--line-2); }
table.fields td { padding: 8px; border-bottom: 1px solid var(--line); vertical-align: top; }
table.fields td.n { font-family: var(--mono); white-space: nowrap; }
table.fields td.t { font-family: var(--mono); color: var(--blue); white-space: nowrap; }
table.fields td.t a { color: var(--blue); cursor: pointer; text-decoration: none; }
table.fields td.t a:hover { text-decoration: underline; }
table.fields .argl { color: var(--faint); font-size: 12px; margin-top: 3px; font-family: var(--mono); }
.badge { display: inline-block; font-size: 10.5px; border-radius: 999px; padding: 1px 7px; margin: 1px 2px 1px 0; border: 1px solid var(--line-2); color: var(--muted); font-family: var(--mono); }
.badge.sg { border-color: rgba(255, 106, 26, .55); color: var(--gold); background: rgba(255, 106, 26, .08); }
.badge.dep { border-color: rgba(255, 77, 94, .5); color: var(--red); }

/* Subgraphs view */
#view-subgraphs { grid-template-columns: 1fr; overflow: auto; }
.page { padding: 22px 28px 60px; max-width: 1180px; width: 100%; }
.page h1 { margin: 0 0 4px; font-size: 22px; }
.page .lead { color: var(--muted); margin: 0 0 18px; }
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px; }
.card { border: 1px solid var(--line-2); background: var(--panel); border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; }
.card .ch { display: flex; align-items: center; gap: 10px; padding: 12px 14px; border-bottom: 1px solid var(--line); background: var(--panel-2); }
.card .ch .nm { font: 700 15px var(--mono); }
.card .ch .spacer { flex: 1; }
.card .cb { padding: 10px 14px; display: grid; gap: 6px; font-size: 12.5px; }
.card .cb .row { display: flex; gap: 8px; } .card .cb .row b { width: 92px; color: var(--faint); font-weight: 600; flex: none; }
.card .cb .row span { font-family: var(--mono); word-break: break-all; }
.card details { border-top: 1px solid var(--line); }
.card summary { padding: 8px 14px; cursor: pointer; color: var(--muted); font-size: 12px; }
.card details pre { margin: 0; padding: 10px 14px; max-height: 340px; overflow: auto; font: 12px/1.55 var(--mono); background: var(--bg); border-top: 1px solid var(--line); }
.card .cf { display: flex; gap: 6px; padding: 10px 14px; border-top: 1px solid var(--line); justify-content: flex-end; }
.callout { border: 1px solid var(--line-2); border-radius: 12px; padding: 16px 18px; background: radial-gradient(1200px 200px at 0 0, rgba(255, 106, 26, .12), transparent), var(--panel); margin-bottom: 18px; }
.callout h3 { margin: 0 0 6px; }
.callout pre { background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 10px 12px; overflow: auto; font: 12px/1.55 var(--mono); }

/* SDL view */
#view-sdl { grid-template-columns: 1fr; }
#view-sdl .pane { border-right: 0; }

/* Modal and toast */
.modal-back { position: fixed; inset: 0; background: rgba(5, 3, 2, .7); display: grid; place-items: center; z-index: 50; backdrop-filter: blur(2px); }
.modal { width: min(640px, calc(100vw - 32px)); max-height: calc(100vh - 40px); overflow: auto; background: var(--panel); border: 1px solid var(--line-2); border-radius: 14px; box-shadow: 0 20px 80px rgba(0, 0, 0, .6), 0 0 0 1px rgba(255, 106, 26, .15); }
.modal .mh { padding: 14px 18px; border-bottom: 1px solid var(--line); display: flex; align-items: center; gap: 10px; }
.modal .mh h3 { margin: 0; font-size: 16px; flex: 1; }
.modal .mb { padding: 14px 18px; display: grid; gap: 12px; }
.modal label { display: grid; gap: 5px; font-size: 12px; color: var(--muted); font-weight: 600; }
.modal input, .modal textarea { background: var(--bg); border: 1px solid var(--line-2); border-radius: 8px; padding: 8px 10px; outline: none; font-family: var(--mono); font-size: 12.5px; }
.modal textarea { min-height: 160px; resize: vertical; }
.modal input:focus, .modal textarea:focus { border-color: var(--ember); }
.modal .hint { color: var(--faint); font-weight: 400; }
.modal .mf { padding: 12px 18px; border-top: 1px solid var(--line); display: flex; justify-content: flex-end; gap: 8px; }
.errors { background: rgba(255, 77, 94, .08); border: 1px solid rgba(255, 77, 94, .4); color: #ffc2c8; border-radius: 8px; padding: 8px 10px; white-space: pre-wrap; font: 12px/1.5 var(--mono); }
.toasts { position: fixed; right: 16px; bottom: 16px; display: grid; gap: 8px; z-index: 60; }
.toast { background: var(--panel-3); border: 1px solid var(--line-2); border-left: 3px solid var(--ember); border-radius: 8px; padding: 9px 12px; max-width: 420px; box-shadow: 0 8px 30px rgba(0, 0, 0, .45); animation: rise .2s ease-out; white-space: pre-wrap; }
.toast.bad { border-left-color: var(--red); }
.toast.ok { border-left-color: var(--green); }
@keyframes rise { from { transform: translateY(8px); opacity: 0; } }

.fields-box { flex: 1; min-height: 0; overflow: auto; padding: 8px 10px; display: grid; gap: 6px; align-content: start; background: var(--panel); }
.frm { display: grid; grid-template-columns: minmax(90px, 32%) minmax(0, 1fr) auto; gap: 6px; align-items: center; }
.frm .lab { font-family: var(--mono); font-size: 12.5px; color: var(--violet); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.frm .lab small { color: var(--blue); margin-left: 6px; }
.frm .lab small.warn { color: var(--gold); }
.frm input, .frm select { background: var(--bg); border: 1px solid var(--line-2); border-radius: 6px; padding: 5px 8px; font: 12.5px var(--mono); outline: none; min-width: 0; width: 100%; }
.frm input:focus, .frm select:focus { border-color: var(--ember); }
.frm input.bad { border-color: var(--red); }
.chip.proto { background: transparent; cursor: pointer; font-family: var(--mono); }
.chip.proto:hover { border-color: var(--ember); color: var(--gold); }
.chip.live { border-color: rgba(123, 216, 143, .5); color: var(--green); }
.btn.run.polling { animation: glow 1.4s ease-in-out infinite; }
@keyframes glow { 50% { box-shadow: 0 0 22px rgba(255, 106, 26, .8); } }
.section-title { font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: var(--faint); font-weight: 700; margin-top: 4px; }
.transport { display: grid; gap: 2px; padding: 8px 10px; border: 1px solid var(--line); border-radius: 8px; background: var(--panel-2); }
.transport a { font-family: var(--mono); font-size: 12.5px; }
.hint { color: var(--faint); font-size: 12px; }
.complete { position: absolute; z-index: 40; background: var(--panel-3); border: 1px solid var(--line-2); border-radius: 8px; box-shadow: 0 10px 30px rgba(0, 0, 0, .5); min-width: 240px; max-width: 420px; max-height: 240px; overflow: auto; font: 12.5px var(--mono); padding: 4px; }
.complete div { display: flex; justify-content: space-between; gap: 16px; padding: 4px 8px; border-radius: 5px; cursor: pointer; }
.complete div.on { background: rgba(255, 106, 26, .2); }
.complete div .ty { color: var(--blue); }

@media (max-width: 1000px) {
  #view-explorer { grid-template-columns: minmax(0, 1fr); grid-auto-rows: minmax(440px, auto); overflow: auto; }
  #view-explorer .pane { border-right: 0; border-bottom: 1px solid var(--line); min-height: 440px; }
  #view-schema { grid-template-columns: minmax(0, 1fr); grid-template-rows: 220px minmax(0, 1fr); }
  .endpoint .pill, #copy-url, .brand .title { display: none; }
}
@media (max-width: 640px) {
  #refresh-btn, #summary { display: none; }
  header.top { gap: 8px; }
  .page { padding: 16px 16px 40px; }
  .tdetail { padding: 14px 16px 30px; }
}
</style>
</head>
<body>
<div class="app">
  <header class="top">
    <div class="brand">
      <svg viewBox="0 0 64 64" aria-hidden="true"><defs><linearGradient id="lg" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#e8202a"/><stop offset=".55" stop-color="#ff6a1a"/><stop offset="1" stop-color="#ffb703"/></linearGradient></defs><path fill="url(#lg)" d="M33 3c2 9-3 14-8 20-5 6-10 12-10 21 0 10 8 17 17 17s17-7 17-17c0-7-3-12-7-16 0 5-2 9-6 11 1-9-1-19-3-36zm-1 34c3 4 7 7 7 13 0 4-3 7-7 7s-7-3-7-7c0-4 3-7 7-13z"/></svg>
      <span class="word">ScorchQL</span><span class="title" id="title"></span>
    </div>
    <div class="endpoint">
      <div class="pill" title="The GraphQL endpoint"><span class="dot" id="health"></span><span id="endpoint"></span></div>
      <span class="chip" id="summary">connecting…</span>
      <button class="chip proto" id="proto" title="The HTTP version, and the transports of this gateway">HTTP</button>
    </div>
    <button class="btn ghost" id="copy-url" title="Copy the endpoint URL">Copy URL</button>
    <button class="btn" id="refresh-btn" title="Read the SDL of every subgraph again">Refresh subgraphs</button>
    <button class="btn fire" id="publish-btn">Publish subgraph</button>
  </header>
  <div class="main">
    <nav class="rail">
      <button data-view="explorer" class="on" aria-label="Explorer"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2c1 4-2 6-3.5 8.5S7 15 8 17.5a4.5 4.5 0 0 0 8.5 0c.6-2-.2-3.6-1.4-5 0 1.8-.8 2.8-2 3.2.5-3.4-.1-8.6-1.1-13.7z"/></svg><span class="tip">Explorer</span></button>
      <button data-view="schema" aria-label="Schema"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="8.5" y="14" width="7" height="7" rx="1.5"/><path d="M6.5 10v2h11v-2M12 12v2"/></svg><span class="tip">Schema</span></button>
      <button data-view="subgraphs" aria-label="Subgraphs"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="2.5"/><circle cx="5" cy="18" r="2.5"/><circle cx="19" cy="18" r="2.5"/><path d="M12 7.5v4M12 11.5l-5.5 4.5M12 11.5l5.5 4.5"/></svg><span class="tip">Subgraphs</span></button>
      <button data-view="sdl" aria-label="SDL"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 4H6a2 2 0 0 0-2 2v4l-2 2 2 2v4a2 2 0 0 0 2 2h2M16 4h2a2 2 0 0 1 2 2v4l2 2-2 2v4a2 2 0 0 1-2 2h-2"/></svg><span class="tip">SDL</span></button>
    </nav>

    <section class="view on" id="view-explorer">
      <div class="pane">
        <div class="pane-head"><h2>Documentation</h2><span class="spacer"></span></div>
        <div class="roots" id="roots"></div>
        <div class="crumbs" id="crumbs"></div>
        <div class="pane-body docs" id="docs"></div>
      </div>
      <div class="pane">
        <div class="tabs" id="tabs"></div>
        <div class="toolbar">
          <select class="btn small" id="op-select" title="The operation to run"></select>
          <span class="spacer"></span>
          <button class="btn ghost small" id="prettify" title="Format the operation">Prettify</button>
          <button class="btn ghost small" id="copy-curl" title="Copy the request as a curl command">Copy curl</button>
          <select class="btn small" id="poll" title="Run the operation again at an interval"><option value="0">Poll: off</option><option value="1">Poll: 1 s</option><option value="2">Poll: 2 s</option><option value="5">Poll: 5 s</option><option value="10">Poll: 10 s</option><option value="30">Poll: 30 s</option></select>
          <button class="btn fire run" id="run"><svg viewBox="0 0 12 12"><path d="M2 1l9 5-9 5z" fill="currentColor"/></svg><span id="run-label">Run</span></button>
        </div>
        <div class="editor-wrap" id="op-wrap">
          <div class="gutter" id="op-gutter">1</div>
          <div class="code"><pre id="op-hl" aria-hidden="true"></pre><textarea id="op" spellcheck="false" autocomplete="off" autocapitalize="off" placeholder="# Write an operation, or check the fields in the documentation.&#10;# Ctrl+Enter runs it. Ctrl+Space completes a field."></textarea></div>
        </div>
        <div class="split" id="split-ops"></div>
        <div class="sub" id="vars-box" style="height: 30%">
          <div class="subtabs"><button data-sub="variables" class="on">Variables</button><button data-sub="headers">Headers</button><span class="spacer"></span><div class="plan-toggle" style="align-items:center"><button class="btn small" data-vmode="json">JSON</button><button class="btn small" data-vmode="fields">Fields</button></div></div>
          <div class="fields-box" id="fields" hidden></div>
          <div class="editor-wrap" id="vars-edit">
            <div class="code"><pre id="vars-hl" aria-hidden="true"></pre><textarea id="vars" spellcheck="false" placeholder="{ }"></textarea></div>
          </div>
        </div>
      </div>
      <div class="pane">
        <div class="subtabs" style="height:40px; background: var(--panel-2)">
          <button data-out="response" class="on">Response</button><button data-out="plan">Query plan</button>
          <span class="spacer"></span>
          <span class="meta" id="meta"></span>
        </div>
        <div class="result" id="out-response"><div class="placeholder" id="resp-empty"><div><svg viewBox="0 0 64 64"><path fill="#ff6a1a" d="M33 3c2 9-3 14-8 20-5 6-10 12-10 21 0 10 8 17 17 17s17-7 17-17c0-7-3-12-7-16 0 5-2 9-6 11 1-9-1-19-3-36z"/></svg><div>Run an operation to see its response.</div><div style="margin-top:6px"><span class="kbd">Ctrl</span> + <span class="kbd">Enter</span></div></div></div><pre id="resp" hidden></pre></div>
        <div class="result" id="out-plan" hidden>
          <div class="toolbar"><div class="plan-toggle"><button class="btn small" data-plan="chart">Chart</button><button class="btn small" data-plan="text">Text</button></div><span class="spacer"></span><button class="btn ghost small" id="plan-refresh">Plan again</button></div>
          <div style="position:absolute; inset: 41px 0 0 0"><div class="plan" id="plan"></div></div>
        </div>
      </div>
    </section>

    <section class="view" id="view-schema">
      <div class="pane">
        <div class="search"><input id="type-search" placeholder="Search types and fields" autocomplete="off"></div>
        <div class="pane-body tlist" id="type-list"></div>
      </div>
      <div class="pane"><div class="pane-body" id="type-detail"></div></div>
    </section>

    <section class="view" id="view-subgraphs"><div class="page" id="subgraphs-page"></div></section>

    <section class="view" id="view-sdl">
      <div class="pane">
        <div class="pane-head">
          <div class="plan-toggle"><button class="btn small" data-sdl="api">API schema</button><button class="btn small" data-sdl="supergraph">Supergraph</button></div>
          <span class="spacer"></span>
          <button class="btn ghost small" id="sdl-copy">Copy</button>
        </div>
        <div class="result"><pre id="sdl-text"></pre></div>
      </div>
    </section>
  </div>
</div>
<div class="toasts" id="toasts"></div>
<script>
"use strict";
const BOOT = __SCORCHQL_BOOT__;

// ---------- small helpers ----------
const $ = (s, root) => (root || document).querySelector(s);
const $$ = (s, root) => Array.from((root || document).querySelectorAll(s));
function el(tag, attrs, ...kids) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === "class") node.className = v;
    else if (k === "text") node.textContent = v;
    else if (k === "html") node.innerHTML = v;
    else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, v === true ? "" : v);
  }
  for (const kid of kids.flat(Infinity)) if (kid != null && kid !== false) node.append(kid.nodeType ? kid : String(kid));
  return node;
}
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const store = {
  get(key, fallback) { try { const v = localStorage.getItem("scorchql:" + key); return v == null ? fallback : JSON.parse(v); } catch (e) { return fallback; } },
  set(key, value) { try { localStorage.setItem("scorchql:" + key, JSON.stringify(value)); } catch (e) { } },
};
function toast(text, kind) {
  const t = el("div", { class: "toast " + (kind || ""), text });
  $("#toasts").append(t);
  setTimeout(() => t.remove(), kind === "bad" ? 7000 : 3500);
}
function copy(text, what) {
  const done = () => toast((what || "Text") + " copied.", "ok");
  if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(done, () => fallbackCopy(text, done));
  else fallbackCopy(text, done);
}
function fallbackCopy(text, done) {
  const area = el("textarea", { style: "position:fixed;opacity:0" });
  area.value = text; document.body.append(area); area.select();
  try { document.execCommand("copy"); done(); } catch (e) { toast("Copy failed.", "bad"); }
  area.remove();
}
const endpointUrl = () => location.origin + BOOT.graphqlPath;
const wsEndpointUrl = () => (location.protocol === "https:" ? "wss://" : "ws://") + location.host + BOOT.graphqlPath;
const BLOCK = '"'.repeat(3);

// ---------- GraphQL lexer ----------
const PUNCT = new Set(["!", "$", "&", "(", ")", ":", "=", "@", "[", "]", "{", "|", "}"]);
function lex(src) {
  const out = []; let i = 0; const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === " " || c === "\t" || c === "\n" || c === "\r" || c === "," || c === "﻿") { i++; continue; }
    if (c === "#") { const s = i; while (i < n && src[i] !== "\n") i++; out.push({ k: "com", s, e: i }); continue; }
    if (c === "." && src.startsWith("...", i)) { out.push({ k: "p", v: "...", s: i, e: i + 3 }); i += 3; continue; }
    if (PUNCT.has(c)) { out.push({ k: "p", v: c, s: i, e: i + 1 }); i++; continue; }
    if (c === '"') {
      const s = i;
      if (src.startsWith(BLOCK, i)) {
        i += 3;
        while (i < n && !src.startsWith(BLOCK, i)) i += src[i] === "\\" && src.startsWith(BLOCK, i + 1) ? 4 : 1;
        i = Math.min(n, i + 3);
      } else {
        i++;
        while (i < n && src[i] !== '"' && src[i] !== "\n") i += src[i] === "\\" ? 2 : 1;
        if (src[i] === '"') i++;
      }
      out.push({ k: "str", s, e: i, v: src.slice(s, i) }); continue;
    }
    if (/[0-9-]/.test(c)) { const s = i; i++; while (i < n && /[0-9.eE+-]/.test(src[i])) i++; out.push({ k: "num", s, e: i, v: src.slice(s, i) }); continue; }
    if (/[_A-Za-z]/.test(c)) { const s = i; i++; while (i < n && /[_0-9A-Za-z]/.test(src[i])) i++; out.push({ k: "name", s, e: i, v: src.slice(s, i) }); continue; }
    out.push({ k: "bad", s: i, e: i + 1, v: c }); i++;
  }
  return out;
}

const KEYWORDS = new Set(["query", "mutation", "subscription", "fragment", "on", "type", "interface", "union", "enum", "input", "scalar", "schema", "directive", "extend", "implements", "repeatable", "true", "false", "null"]);
// Highlight an operation as HTML.
function highlight(src) {
  const toks = lex(src); let html = ""; let at = 0; let prev = null; let depth = 0; let paren = 0;
  for (let t = 0; t < toks.length; t++) {
    const tok = toks[t]; const next = toks[t + 1]; const pv = prev ? prev.v : null;
    html += esc(src.slice(at, tok.s));
    let cls = "t-punc";
    if (tok.k === "com") cls = "t-com";
    else if (tok.k === "str") cls = "t-str";
    else if (tok.k === "num") cls = "t-num";
    else if (tok.k === "p") {
      if (tok.v === "{") depth++; else if (tok.v === "}") depth--; else if (tok.v === "(") paren++; else if (tok.v === ")") paren--;
    } else if (tok.k === "name") {
      if (pv === "$") cls = "t-var";
      else if (pv === "@") cls = "t-dir";
      else if (tok.v === "on" && (pv === "..." || (depth === 0 && prev && prev.k === "name"))) cls = "t-kw";
      else if (pv === "on" || (paren > 0 && depth === 0 && (pv === ":" || pv === "["))) cls = "t-type";
      else if (depth === 0 && paren === 0 && ["query", "mutation", "subscription", "fragment"].includes(tok.v)) cls = "t-kw";
      else if (tok.v === "true" || tok.v === "false" || tok.v === "null") cls = "t-kw";
      else if (paren > 0 && next && next.v === ":") cls = "t-arg";
      else if (paren > 0) cls = "t-name";
      else if (depth > 0) cls = next && next.v === ":" ? "t-name" : "t-field";
      else cls = "t-name";
    }
    html += '<span class="' + cls + '">' + esc(src.slice(tok.s, tok.e)) + "</span>";
    at = tok.e; if (tok.k !== "com") prev = tok;
  }
  return html + esc(src.slice(at));
}
const SDL_KEYWORDS = ["type", "interface", "union", "enum", "input", "scalar", "implements", "on", "extend", "schema", "directive", "repeatable"];
// Highlight SDL as HTML.
function highlightSdl(src) {
  const toks = lex(src); let html = ""; let at = 0; let prev = null;
  for (let t = 0; t < toks.length; t++) {
    const tok = toks[t]; const next = toks[t + 1]; const pv = prev ? prev.v : null;
    html += esc(src.slice(at, tok.s));
    let cls = "t-punc";
    if (tok.k === "com") cls = "t-com"; else if (tok.k === "str") cls = "t-str"; else if (tok.k === "num") cls = "t-num";
    else if (tok.k === "name") {
      if (pv === "@") cls = "t-dir";
      else if (pv === "$") cls = "t-var";
      else if ((SDL_KEYWORDS.includes(tok.v) || tok.v === "true" || tok.v === "false" || tok.v === "null") && (!next || (next.v !== ":" && next.v !== "("))) cls = "t-kw";
      else if (pv === ":" || pv === "[" || pv === "|" || pv === "&" || pv === "=" || SDL_KEYWORDS.includes(pv)) cls = "t-type";
      else if (next && (next.v === ":" || next.v === "(")) cls = "t-field";
      else cls = "t-name";
    }
    html += '<span class="' + cls + '">' + esc(src.slice(tok.s, tok.e)) + "</span>";
    at = tok.e; if (tok.k !== "com") prev = tok;
  }
  return html + esc(src.slice(at));
}
function highlightJson(text) {
  return esc(text).replace(/(&quot;(?:[^&\\]|\\.|&(?!quot;))*?&quot;)(\s*:)?|\b(true|false)\b|\bnull\b|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/g, (m, str, colon, bool) => {
    if (str) return colon ? '<span class="j-key">' + str + "</span>" + colon : '<span class="j-str">' + str + "</span>";
    if (bool) return '<span class="j-bool">' + m + "</span>";
    if (m === "null") return '<span class="j-null">null</span>';
    return '<span class="j-num">' + m + "</span>";
  });
}

// ---------- executable document parser and printer ----------
function Parser(src) { this.src = src; this.toks = lex(src).filter((t) => t.k !== "com"); this.i = 0; }
Parser.prototype = {
  peek(o) { return this.toks[this.i + (o || 0)]; },
  is(v) { const t = this.peek(); return t && (t.v === v); },
  next() { const t = this.toks[this.i++]; if (!t) throw new Error("Unexpected end of the document."); return t; },
  expect(v) { const t = this.next(); if (t.v !== v) throw new Error("Expected '" + v + "', found '" + t.v + "'."); return t; },
  name() { const t = this.next(); if (t.k !== "name") throw new Error("Expected a name, found '" + t.v + "'."); return t.v; },
  document() {
    const defs = [];
    while (this.peek()) {
      if (this.is("{")) defs.push({ kind: "op", op: "query", name: null, vars: "", dirs: "", sel: this.selectionSet() });
      else if (this.is("fragment")) {
        this.next(); const name = this.name(); this.expect("on"); const type = this.name();
        defs.push({ kind: "frag", name, type, dirs: this.directives(), sel: this.selectionSet() });
      } else {
        const op = this.name();
        if (!["query", "mutation", "subscription"].includes(op)) throw new Error("Unexpected '" + op + "'.");
        const name = this.peek() && this.peek().k === "name" ? this.name() : null;
        let vars = "";
        if (this.is("(")) { const s = this.peek().s; this.skipGroup("(", ")"); vars = this.src.slice(s, this.toks[this.i - 1].e); }
        defs.push({ kind: "op", op, name, vars, dirs: this.directives(), sel: this.selectionSet() });
      }
    }
    return defs;
  },
  skipGroup(open, close) {
    let depth = 0;
    do { const t = this.next(); if (t.v === open) depth++; else if (t.v === close) depth--; } while (depth > 0);
  },
  value() {
    const t = this.peek();
    if (t.v === "[") { this.skipGroup("[", "]"); return; }
    if (t.v === "{") { this.skipGroup("{", "}"); return; }
    if (t.v === "$") { this.next(); this.name(); return; }
    this.next();
  },
  args() {
    if (!this.is("(")) return [];
    this.next(); const out = [];
    while (!this.is(")")) {
      const name = this.name(); this.expect(":");
      const s = this.peek().s; this.value();
      out.push({ name, value: this.src.slice(s, this.toks[this.i - 1].e) });
    }
    this.next(); return out;
  },
  directives() {
    let text = "";
    while (this.is("@")) {
      const s = this.next().s; this.name();
      if (this.is("(")) this.skipGroup("(", ")");
      text += " " + this.src.slice(s, this.toks[this.i - 1].e);
    }
    return text.trim();
  },
  selectionSet() {
    this.expect("{"); const out = [];
    while (!this.is("}")) {
      if (this.is("...")) {
        this.next();
        if (this.is("on")) { this.next(); const type = this.name(); out.push({ kind: "inline", type, dirs: this.directives(), sel: this.selectionSet() }); }
        else if (this.peek() && this.peek().k === "name") { out.push({ kind: "spread", name: this.name(), dirs: this.directives() }); }
        else out.push({ kind: "inline", type: null, dirs: this.directives(), sel: this.selectionSet() });
        continue;
      }
      let alias = null; let name = this.name();
      if (this.is(":")) { this.next(); alias = name; name = this.name(); }
      const args = this.args(); const dirs = this.directives();
      const sel = this.is("{") ? this.selectionSet() : null;
      out.push({ kind: "field", alias, name, args, dirs, sel });
    }
    this.next(); return out;
  },
};
function parseDocument(src) { return new Parser(src).document(); }
function printSelections(sel, indent) {
  const pad = "  ".repeat(indent); let out = "";
  for (const s of sel) {
    if (s.kind === "field") {
      out += pad + (s.alias ? s.alias + ": " : "") + s.name;
      if (s.args.length) out += "(" + s.args.map((a) => a.name + ": " + a.value).join(", ") + ")";
      if (s.dirs) out += " " + s.dirs;
      if (s.sel && s.sel.length) out += " {\n" + printSelections(s.sel, indent + 1) + pad + "}";
      out += "\n";
    } else if (s.kind === "spread") out += pad + "..." + s.name + (s.dirs ? " " + s.dirs : "") + "\n";
    else out += pad + "..." + (s.type ? " on " + s.type : "") + (s.dirs ? " " + s.dirs : "") + " {\n" + printSelections(s.sel, indent + 1) + pad + "}\n";
  }
  return out;
}
function printDocument(defs) {
  return defs.map((d) => {
    if (d.kind === "frag") return "fragment " + d.name + " on " + d.type + (d.dirs ? " " + d.dirs : "") + " {\n" + printSelections(d.sel, 1) + "}";
    const head = d.op + (d.name ? " " + d.name : "") + (d.vars ? d.vars.replace(/\s+/g, " ").replace(/\(\s+/, "(").replace(/\s+\)/, ")") : "") + (d.dirs ? " " + d.dirs : "");
    return head + " {\n" + printSelections(d.sel, 1) + "}";
  }).join("\n\n") + "\n";
}

// ---------- schema ----------
const INTROSPECTION = "query ScorchIntrospection { __schema { queryType { name } mutationType { name } subscriptionType { name } " +
  "types { kind name description " +
  "fields(includeDeprecated: true) { name description isDeprecated deprecationReason args { name description defaultValue type { ...T } } type { ...T } } " +
  "inputFields { name description defaultValue type { ...T } } interfaces { name } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { name } } " +
  "directives { name description locations args { name description defaultValue type { ...T } } } } } " +
  "fragment T on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }";
const S = { schema: null, types: {}, owners: {}, gateway: null, revision: null, sdl: "", apiSdl: "" };

function typeName(ref) { return ref.kind === "NON_NULL" ? typeName(ref.ofType) + "!" : ref.kind === "LIST" ? "[" + typeName(ref.ofType) + "]" : ref.name; }
function namedType(ref) { while (ref.ofType) ref = ref.ofType; return ref.name; }
function isComposite(name) { const t = S.types[name]; return t && (t.kind === "OBJECT" || t.kind === "INTERFACE" || t.kind === "UNION"); }
function isBuiltin(name) { return name.startsWith("__") || /^(federation|link|join)__/.test(name) || ["String", "Int", "Float", "Boolean", "ID"].includes(name); }
function rootName(op) { const s = S.schema; if (!s) return null; const r = op === "mutation" ? s.mutationType : op === "subscription" ? s.subscriptionType : s.queryType; return r && r.name; }

// Which subgraphs resolve each type and field, read from the supergraph.
function readOwners(sdl) {
  const graphs = {}; const owners = {};
  for (const m of sdl.matchAll(/^\s*([A-Z0-9_]+)\s+@join__graph\(name:\s*"([^"]+)"/gm)) graphs[m[1]] = m[2];
  let current = null; let typeGraphs = [];
  for (const line of sdl.split("\n")) {
    const head = line.match(/^(?:type|interface|input|enum|union|scalar)\s+([_A-Za-z][_0-9A-Za-z]*)/);
    if (head) {
      current = head[1]; typeGraphs = [...line.matchAll(/@join__type\(graph:\s*([A-Z0-9_]+)/g)].map((m) => graphs[m[1]] || m[1]);
      owners[current] = { graphs: typeGraphs, fields: {} };
      if (!line.includes("{")) current = line.includes("=") ? null : current;
      continue;
    }
    if (/^\}/.test(line)) { current = null; continue; }
    if (!current) continue;
    const field = line.match(/^\s+([_A-Za-z][_0-9A-Za-z]*)\s*[(:]/);
    if (!field) continue;
    const fg = [...line.matchAll(/@join__field\((?:[^)]*?)graph:\s*([A-Z0-9_]+)([^)]*)\)/g)].filter((m) => !/external:\s*true/.test(m[2])).map((m) => graphs[m[1]] || m[1]);
    owners[current].fields[field[1]] = fg.length ? fg : typeGraphs;
  }
  return owners;
}

function printApiSchema(schema) {
  const desc = (d, pad) => !d ? "" : !d.includes("\n") && d.length < 70 ? pad + BLOCK + d + BLOCK + "\n" : pad + BLOCK + "\n" + d.split("\n").map((l) => pad + l).join("\n") + "\n" + pad + BLOCK + "\n";
  const args = (list) => !list.length ? "" : "(" + list.map((a) => a.name + ": " + typeName(a.type) + (a.defaultValue != null ? " = " + a.defaultValue : "")).join(", ") + ")";
  const dep = (x) => x.isDeprecated ? " @deprecated" + (x.deprecationReason && x.deprecationReason !== "No longer supported" ? "(reason: " + JSON.stringify(x.deprecationReason) + ")" : "") : "";
  const out = [];
  for (const t of schema.types) {
    if (isBuiltin(t.name)) continue;
    let s = desc(t.description, "");
    if (t.kind === "SCALAR") s += "scalar " + t.name;
    else if (t.kind === "UNION") s += "union " + t.name + " = " + t.possibleTypes.map((p) => p.name).join(" | ");
    else if (t.kind === "ENUM") s += "enum " + t.name + " {\n" + t.enumValues.map((v) => desc(v.description, "  ") + "  " + v.name + dep(v)).join("\n") + "\n}";
    else if (t.kind === "INPUT_OBJECT") s += "input " + t.name + " {\n" + t.inputFields.map((f) => desc(f.description, "  ") + "  " + f.name + ": " + typeName(f.type) + (f.defaultValue != null ? " = " + f.defaultValue : "")).join("\n") + "\n}";
    else {
      const impl = t.interfaces && t.interfaces.length ? " implements " + t.interfaces.map((i) => i.name).join(" & ") : "";
      s += (t.kind === "INTERFACE" ? "interface " : "type ") + t.name + impl + " {\n" + t.fields.map((f) => desc(f.description, "  ") + "  " + f.name + args(f.args) + ": " + typeName(f.type) + dep(f)).join("\n") + "\n}";
    }
    out.push(s);
  }
  return out.join("\n\n") + "\n";
}

async function gql(query, variables, operationName, headers) {
  const res = await fetch(BOOT.graphqlPath, { method: "POST", headers: Object.assign({ "content-type": "application/json", accept: "application/graphql-response+json, application/json" }, headers || {}), body: JSON.stringify({ query, variables, operationName }) });
  const text = await res.text();
  return { status: res.status, text };
}
async function loadSchema() {
  const res = await gql(INTROSPECTION);
  let json; try { json = JSON.parse(res.text); } catch (e) { throw new Error("The introspection response is not JSON (HTTP " + res.status + ")."); }
  if (!json.data || !json.data.__schema) throw new Error((json.errors && json.errors[0] && json.errors[0].message) || "The gateway returned no schema.");
  S.schema = json.data.__schema; S.types = {};
  for (const t of S.schema.types) { t.fields = t.fields || []; t.inputFields = t.inputFields || []; t.enumValues = t.enumValues || []; t.possibleTypes = t.possibleTypes || []; t.interfaces = t.interfaces || []; S.types[t.name] = t; }
  S.apiSdl = printApiSchema(S.schema);
  try { const r = await fetch("/scorchql/supergraph.graphql"); S.sdl = r.ok ? await r.text() : ""; } catch (e) { S.sdl = ""; }
  S.owners = readOwners(S.sdl);
}
function clearSchema() { S.schema = null; S.types = {}; S.owners = {}; S.sdl = ""; S.apiSdl = ""; }

// ---------- tabs and the operation editor ----------
const DEFAULT_OP = "query Example {\n  __typename\n}\n";
let tabs = store.get("tabs", null);
if (!Array.isArray(tabs) || !tabs.length) tabs = [{ id: Date.now(), title: "Example", query: DEFAULT_OP, variables: "{}", headers: "{}" }];
let active = Math.min(store.get("active", 0), tabs.length - 1);
let subTab = "variables";
let outTab = "response";
let planMode = store.get("planMode", "chart");
let docPath = [];
let docRoot = "query";
const tab = () => tabs[active];
function saveTabs() { store.set("tabs", tabs.map((t) => ({ id: t.id, title: t.title, query: t.query, variables: t.variables, headers: t.headers }))); store.set("active", active); }

const op = $("#op"); const opHl = $("#op-hl"); const gutter = $("#op-gutter");
const vars = $("#vars"); const varsHl = $("#vars-hl");
function paintOp() {
  opHl.innerHTML = highlight(op.value) + "\n";
  const lines = op.value.split("\n").length;
  gutter.textContent = Array.from({ length: lines }, (_, i) => i + 1).join("\n");
  syncScroll();
}
function paintVars() { varsHl.innerHTML = highlightJson(vars.value) + "\n"; varsHl.scrollTop = vars.scrollTop; varsHl.scrollLeft = vars.scrollLeft; }
function syncScroll() { opHl.scrollTop = op.scrollTop; opHl.scrollLeft = op.scrollLeft; gutter.scrollTop = op.scrollTop; }
op.addEventListener("scroll", syncScroll);
vars.addEventListener("scroll", paintVars);
op.addEventListener("input", () => { tab().query = op.value; tabTitle(); saveTabs(); paintOp(); renderDocs(); renderOps(); complete.update(false); });
vars.addEventListener("input", () => { tab()[subTab] = vars.value; saveTabs(); paintVars(); });

function insertText(area, text) {
  const s = area.selectionStart, e = area.selectionEnd;
  area.setRangeText(text, s, e, "end");
  area.dispatchEvent(new Event("input"));
}
function editorKeys(area) {
  area.addEventListener("keydown", (ev) => {
    if (area === op && complete.keydown(ev)) return;
    if ((ev.ctrlKey || ev.metaKey) && ev.key === "Enter") { ev.preventDefault(); run(); return; }
    if (area === op && ev.ctrlKey && ev.key === " ") { ev.preventDefault(); complete.update(true); return; }
    if (area === op && ev.shiftKey && ev.altKey && (ev.key === "F" || ev.key === "f")) { ev.preventDefault(); prettify(); return; }
    if (ev.key === "Tab") { ev.preventDefault(); insertText(area, "  "); return; }
    if (ev.key === "Enter") {
      ev.preventDefault();
      const before = area.value.slice(0, area.selectionStart);
      const line = before.slice(before.lastIndexOf("\n") + 1);
      let pad = line.match(/^\s*/)[0];
      const opens = /[{(\[]\s*$/.test(line);
      const after = area.value.slice(area.selectionEnd);
      if (opens) {
        if (/^\s*[})\]]/.test(after)) { const s = area.selectionStart; insertText(area, "\n" + pad + "  \n" + pad); area.selectionStart = area.selectionEnd = s + pad.length + 3; return; }
        pad += "  ";
      }
      insertText(area, "\n" + pad); return;
    }
    const pairs = { "{": "}", "(": ")", "[": "]", '"': '"' };
    if (pairs[ev.key] && area.selectionStart === area.selectionEnd) {
      const next = area.value[area.selectionStart];
      if (ev.key === '"' && next === '"') { ev.preventDefault(); area.selectionStart = area.selectionEnd = area.selectionStart + 1; return; }
      if (!next || /[\s)}\],]/.test(next)) { ev.preventDefault(); const s = area.selectionStart; insertText(area, ev.key + pairs[ev.key]); area.selectionStart = area.selectionEnd = s + 1; return; }
    }
    if ((ev.key === "}" || ev.key === ")" || ev.key === "]") && area.value[area.selectionStart] === ev.key) { ev.preventDefault(); area.selectionStart = area.selectionEnd = area.selectionStart + 1; return; }
    if (ev.key === "}" ) {
      const before = area.value.slice(0, area.selectionStart); const line = before.slice(before.lastIndexOf("\n") + 1);
      if (/^\s+$/.test(line) && line.length >= 2) { ev.preventDefault(); area.setRangeText("", area.selectionStart - 2, area.selectionStart, "end"); insertText(area, "}"); }
    }
  });
}
editorKeys(op); editorKeys(vars);

function operations() {
  try { return parseDocument(op.value).filter((d) => d.kind === "op"); } catch (e) { return null; }
}
function tabTitle() {
  const m = op.value.match(/\b(query|mutation|subscription)\s+([_A-Za-z][_0-9A-Za-z]*)/);
  tab().title = m ? m[2] : (op.value.trim() ? "Untitled" : "New tab");
  renderTabs();
}
function renderTabs() {
  const box = $("#tabs"); box.innerHTML = "";
  tabs.forEach((t, i) => {
    box.append(el("div", { class: "tab" + (i === active ? " on" : ""), onclick: () => selectTab(i), title: t.title },
      el("span", { text: t.title }),
      tabs.length > 1 ? el("span", { class: "x", text: "×", title: "Close", onclick: (ev) => { ev.stopPropagation(); closeTab(i); } }) : null));
  });
  box.append(el("div", { class: "tab-add", text: "+", title: "New tab", onclick: () => newTab() }));
}
function newTab(query) {
  tabs.push({ id: Date.now(), title: "New tab", query: query || "", variables: "{}", headers: "{}" });
  selectTab(tabs.length - 1);
}
function closeTab(i) { if (tabs[i] && tabs[i].stopStream) tabs[i].stopStream(); tabs.splice(i, 1); if (active >= tabs.length) active = tabs.length - 1; else if (i < active) active--; selectTab(active); }
function selectTab(i) {
  active = i; op.value = tab().query; vars.value = tab()[subTab] || ""; saveTabs();
  renderTabs(); paintOp(); paintVars(); renderDocs(); renderOps(); showResponse(); showPlan();
  if (varsMode === "fields") renderFields();
  if (pollTimer) setPoll(0);
}
function selectedOp() {
  const ops = operations() || []; const want = $("#op-select").value;
  return ops.find((o) => (o.name || "") === want) || ops[0] || null;
}
function renderOps() {
  const sel = $("#op-select"); const ops = operations() || []; const prev = sel.value; sel.innerHTML = "";
  ops.forEach((o, i) => sel.append(el("option", { value: o.name || "", text: (o.op + " " + (o.name || "(anonymous)")) })));
  sel.hidden = ops.length < 2;
  if ([...sel.options].some((o) => o.value === prev)) sel.value = prev;
  const t = tab();
  if (t && t.stopStream) {
    $("#run-label").textContent = "Stop";
    $("#run").classList.add("polling");
    return;
  }
  $("#run").classList.toggle("polling", !!pollTimer);
  const cur = selectedOp(); const verb = cur && cur.op === "subscription" ? "Subscribe" : "Run";
  $("#run-label").textContent = ops.length > 1 ? verb + " " + (sel.value || "") : (cur && cur.name ? verb + " " + cur.name : verb);
}
$("#op-select").addEventListener("change", () => { renderOps(); renderDocs(); });
$$("[data-sub]").forEach((b) => b.addEventListener("click", () => {
  subTab = b.dataset.sub; $$("[data-sub]").forEach((x) => x.classList.toggle("on", x === b));
  vars.value = tab()[subTab] || ""; vars.placeholder = subTab === "headers" ? '{ "authorization": "Bearer …" }' : "{ }"; paintVars();
  if (varsMode === "fields") renderFields();
}));

// Resize the variables box.
(function () {
  const bar = $("#split-ops"); const box = $("#vars-box");
  bar.addEventListener("mousedown", (ev) => {
    ev.preventDefault(); const startY = ev.clientY; const startH = box.getBoundingClientRect().height;
    const move = (e) => { box.style.height = Math.max(80, Math.min(window.innerHeight - 220, startH - (e.clientY - startY))) + "px"; };
    const up = () => { window.removeEventListener("mousemove", move); window.removeEventListener("mouseup", up); };
    window.addEventListener("mousemove", move); window.addEventListener("mouseup", up);
  });
})();

// ---------- completion ----------
// The type of the selection set at the end of `text`, or null.
function contextAt(text) {
  const toks = lex(text);
  const last = toks[toks.length - 1];
  if (last && (last.k === "com" || (last.k === "str" && last.e === text.length && !/"$/.test(text)))) return null;
  const stack = []; let paren = 0; let prev = null; let lastField = null; let pendingType = null; let opKind = "query"; let fragType = null;
  for (const t of toks) {
    if (t.k === "com") continue;
    if (t.k === "p") {
      if (t.v === "(") paren++;
      else if (t.v === ")") paren--;
      else if (t.v === "{" && paren === 0) {
        if (!stack.length) stack.push(fragType || rootName(opKind));
        else if (pendingType) stack.push(pendingType);
        else if (prev && prev.v === "...") stack.push(stack[stack.length - 1]);
        else {
          const parent = S.types[stack[stack.length - 1]];
          const f = parent && parent.fields.find((x) => x.name === lastField);
          stack.push(f ? namedType(f.type) : null);
        }
        pendingType = null;
      } else if (t.v === "}" && paren === 0) { stack.pop(); if (!stack.length) { fragType = null; opKind = "query"; } }
    } else if (t.k === "name" && paren === 0) {
      if (!stack.length) {
        if (["query", "mutation", "subscription"].includes(t.v) && !prev) opKind = t.v;
        else if (["query", "mutation", "subscription"].includes(t.v) && prev && prev.v === "}") opKind = t.v;
        if (prev && prev.v === "on") fragType = t.v;
      } else if (prev && prev.v === "on") pendingType = t.v;
      else if (prev && prev.v === "...") { if (t.v !== "on") lastField = null; }
      else if (prev && prev.v === "@") { }
      else lastField = t.v;
    }
    prev = t;
  }
  if (paren > 0 || !stack.length) return null;
  return stack[stack.length - 1];
}
const complete = {
  box: null, items: [], index: 0, start: 0, suppress: false,
  update(force) {
    this.close();
    if (this.suppress) { this.suppress = false; return; }
    if (!S.schema || document.activeElement !== op) return;
    const caret = op.selectionStart; if (caret !== op.selectionEnd) return;
    const before = op.value.slice(0, caret);
    const word = before.match(/[_A-Za-z][_0-9A-Za-z]*$/); const prefix = word ? word[0] : "";
    if (!force && !prefix) return;
    const head = before.slice(0, caret - prefix.length);
    if (/(\.\.\.|@|\$|:\s*)\s*$/.test(head) && !/\{\s*$/.test(head)) return;
    const type = contextAt(head); const t = S.types[type]; if (!t || !t.fields) return;
    const options = t.fields.concat(t.kind !== "INPUT_OBJECT" ? [{ name: "__typename", type: { kind: "NON_NULL", ofType: { kind: "SCALAR", name: "String" } } }] : [])
      .filter((f) => f.name.toLowerCase().startsWith(prefix.toLowerCase()) && f.name !== prefix);
    if (!options.length) return;
    this.items = options.slice(0, 50); this.index = 0; this.start = caret - prefix.length;
    const linesBefore = before.split("\n"); const line = linesBefore.length - 1; const col = linesBefore[line].length - prefix.length;
    const probe = el("span", { text: "M".repeat(40), style: "font: 12.5px var(--mono); position:absolute; visibility:hidden" }); document.body.append(probe);
    const cw = probe.getBoundingClientRect().width / 40; probe.remove();
    const box = el("div", { class: "complete" });
    this.items.forEach((f, i) => box.append(el("div", { class: i === 0 ? "on" : "", onmousedown: (ev) => { ev.preventDefault(); this.index = i; this.accept(); } }, el("span", { text: f.name }), el("span", { class: "ty", text: typeName(f.type) }))));
    const wrap = $("#op-wrap"); const lineH = 12.5 * 1.6;
    box.style.left = (42 + 12 + col * cw - op.scrollLeft) + "px";
    box.style.top = (10 + (line + 1) * lineH - op.scrollTop + 2) + "px";
    wrap.append(box); this.box = box;
  },
  close() { if (this.box) this.box.remove(); this.box = null; },
  move(d) { if (!this.box) return; this.index = (this.index + d + this.items.length) % this.items.length; $$("div", this.box).forEach((x, i) => x.classList.toggle("on", i === this.index)); this.box.children[this.index].scrollIntoView({ block: "nearest" }); },
  accept() {
    const f = this.items[this.index]; this.close(); if (!f) return;
    const lineStart = op.value.lastIndexOf("\n", this.start - 1) + 1;
    const pad = op.value.slice(lineStart, this.start).match(/^\s*/)[0];
    const required = (f.args || []).filter((a) => a.type.kind === "NON_NULL" && a.defaultValue == null);
    let text = f.name; let caret = null;
    if (required.length) { text += "(" + required.map((a) => a.name + ": ").join(", ") + ")"; caret = this.start + f.name.length + 1 + required[0].name.length + 2; }
    if (isComposite(namedType(f.type))) { text += " {\n" + pad + "  \n" + pad + "}"; if (caret == null) caret = this.start + text.length - (pad.length + 2); }
    if (caret == null) caret = this.start + text.length;
    op.setRangeText(text, this.start, op.selectionStart, "end");
    op.selectionStart = op.selectionEnd = caret;
    this.suppress = true; op.dispatchEvent(new Event("input"));
  },
  keydown(ev) {
    if (!this.box) return false;
    if (ev.key === "ArrowDown") { ev.preventDefault(); this.move(1); return true; }
    if (ev.key === "ArrowUp") { ev.preventDefault(); this.move(-1); return true; }
    if (ev.key === "Enter" || ev.key === "Tab") { ev.preventDefault(); this.accept(); return true; }
    if (ev.key === "Escape") { ev.preventDefault(); this.close(); return true; }
    return false;
  },
};
op.addEventListener("blur", () => setTimeout(() => complete.close(), 120));
op.addEventListener("click", () => complete.close());

// ---------- documentation and the field checkboxes ----------
function currentOperation(defs) {
  const ops = defs.filter((d) => d.kind === "op"); if (!ops.length) return null;
  const want = $("#op-select").value;
  return ops.find((o) => (o.name || "") === want) || ops[0];
}
// The selection list at a documentation path, or null.
function selectionAt(sel, path) {
  for (const step of path) {
    if (!sel) return null;
    const node = step.type ? sel.find((s) => s.kind === "inline" && s.type === step.type) : sel.find((s) => s.kind === "field" && s.name === step.name && !s.alias);
    if (!node) return null;
    sel = node.sel;
  }
  return sel;
}
function ensureSelection(sel, path) {
  for (const step of path) {
    let node = step.type ? sel.find((s) => s.kind === "inline" && s.type === step.type) : sel.find((s) => s.kind === "field" && s.name === step.name && !s.alias);
    if (!node) {
      node = step.type ? { kind: "inline", type: step.type, dirs: "", sel: [] } : { kind: "field", alias: null, name: step.name, args: [], dirs: "", sel: [] };
      sel.push(node);
    }
    if (!node.sel) node.sel = [];
    sel = node.sel;
  }
  return sel;
}
function pruneEmpty(sel) {
  for (let i = sel.length - 1; i >= 0; i--) {
    const s = sel[i];
    if (s.sel) { pruneEmpty(s.sel); if (!s.sel.length && s.kind !== "spread") sel.splice(i, 1); }
  }
}
// The variable definitions of an operation, by name: the type, the
// default value and the directives, as text.
function variableDefs(text) {
  const out = {}; if (!text) return out;
  const inner = text.trim().replace(/^\(/, "").replace(/\)$/, "");
  const toks = lex(inner); let i = 0;
  while (i < toks.length) {
    if (toks[i].v === "$" && toks[i + 1] && toks[i + 1].k === "name") {
      const name = toks[i + 1].v; i += 2; if (toks[i] && toks[i].v === ":") i++;
      const s = toks[i] ? toks[i].s : inner.length; let e = s; let depth = 0;
      while (i < toks.length && !(depth === 0 && toks[i].v === "$")) {
        if (["[", "{", "("].includes(toks[i].v)) depth++; else if (["]", "}", ")"].includes(toks[i].v)) depth--;
        e = toks[i].e; i++;
      }
      out[name] = inner.slice(s, e).trim();
    } else i++;
  }
  return out;
}
function setVariableDefs(def, map) {
  const names = Object.keys(map);
  def.vars = names.length ? "(" + names.map((n) => "$" + n + ": " + map[n]).join(", ") + ")" : "";
}
function sampleValue(typeRef) {
  const name = namedType(typeRef); const t = S.types[name];
  if (typeRef.kind === "LIST" || (typeRef.kind === "NON_NULL" && typeRef.ofType.kind === "LIST")) return [];
  if (name === "Int" || name === "Float") return 0;
  if (name === "Boolean") return false;
  if (t && t.kind === "ENUM") return t.enumValues[0] ? t.enumValues[0].name : null;
  if (t && t.kind === "INPUT_OBJECT") return {};
  return "";
}
function editVariables(fn) {
  let obj = {}; try { obj = JSON.parse(tab().variables || "{}") || {}; } catch (e) { obj = {}; }
  fn(obj); tab().variables = JSON.stringify(obj, null, 2);
  if (subTab === "variables") { vars.value = tab().variables; paintVars(); }
  if (subTab === "variables" && varsMode === "fields") renderFields();
}
function mutateOperation(fn) {
  let defs;
  try { defs = op.value.trim() ? parseDocument(op.value) : []; } catch (e) { toast("Fix the syntax error first: " + e.message, "bad"); return; }
  let def = currentOperation(defs);
  if (!def || def.op !== docRoot) {
    const found = defs.find((d) => d.kind === "op" && d.op === docRoot);
    def = found || null;
    if (!def) { def = { kind: "op", op: docRoot, name: docRoot === "query" ? "MyQuery" : docRoot === "mutation" ? "MyMutation" : "MySubscription", vars: "", dirs: "", sel: [] }; defs.push(def); }
  }
  fn(def);
  pruneEmpty(def.sel);
  const keep = defs.filter((d) => d.kind === "frag" || d.sel.length);
  op.value = keep.length ? printDocument(keep) : "";
  tab().query = op.value; tabTitle(); saveTabs(); paintOp(); renderOps();
  const sel = $("#op-select"); if (def.name && [...sel.options].some((o) => o.value === def.name)) sel.value = def.name;
  renderOps(); renderDocs();
}
function uniqueVar(map, name) { let n = name; let i = 2; while (map[n] !== undefined) n = name + i++; return n; }
function toggleField(path, field, on) {
  mutateOperation((def) => {
    const map = variableDefs(def.vars);
    if (on) {
      const sel = ensureSelection(def.sel, path);
      const node = { kind: "field", alias: null, name: field.name, args: [], dirs: "", sel: null };
      for (const a of field.args || []) {
        if (a.type.kind === "NON_NULL" && a.defaultValue == null) {
          const v = uniqueVar(map, a.name); map[v] = typeName(a.type); node.args.push({ name: a.name, value: "$" + v });
          editVariables((o) => { if (!(v in o)) o[v] = sampleValue(a.type); });
        }
      }
      if (isComposite(namedType(field.type))) {
        const sub = S.types[namedType(field.type)];
        const pick = sub.fields && (sub.fields.find((f) => f.name === "id") || sub.fields.find((f) => !isComposite(namedType(f.type)) && !(f.args || []).some((a) => a.type.kind === "NON_NULL")));
        node.sel = [{ kind: "field", alias: null, name: pick ? pick.name : "__typename", args: [], dirs: "", sel: null }];
      }
      sel.push(node);
    } else {
      const sel = selectionAt(def.sel, path); if (!sel) return;
      const i = sel.findIndex((s) => s.kind === "field" && s.name === field.name && !s.alias);
      if (i < 0) return;
      const used = new Set(); const gone = sel[i];
      const collect = (n) => { for (const a of n.args || []) for (const m of a.value.matchAll(/\$([_A-Za-z][_0-9A-Za-z]*)/g)) used.add(m[1]); for (const s of n.sel || []) collect(s); };
      collect(gone); sel.splice(i, 1);
      const still = new Set(); for (const s of def.sel) collect2(s, still);
      for (const v of used) if (!still.has(v)) { delete map[v]; editVariables((o) => { delete o[v]; }); }
    }
    setVariableDefs(def, map);
  });
  function collect2(n, set) { for (const a of n.args || []) for (const m of a.value.matchAll(/\$([_A-Za-z][_0-9A-Za-z]*)/g)) set.add(m[1]); for (const s of n.sel || []) collect2(s, set); }
}
function toggleArgument(path, field, arg, on) {
  mutateOperation((def) => {
    const map = variableDefs(def.vars);
    const sel = on ? ensureSelection(def.sel, path) : selectionAt(def.sel, path); if (!sel) return;
    let node = sel.find((s) => s.kind === "field" && s.name === field.name && !s.alias);
    if (!node && on) { toggleFieldInline(sel, field); node = sel.find((s) => s.kind === "field" && s.name === field.name); }
    if (!node) return;
    if (on) {
      if (node.args.some((a) => a.name === arg.name)) return;
      const v = uniqueVar(map, arg.name); map[v] = typeName(arg.type); node.args.push({ name: arg.name, value: "$" + v });
      editVariables((o) => { if (!(v in o)) o[v] = sampleValue(arg.type); });
    } else {
      const i = node.args.findIndex((a) => a.name === arg.name); if (i < 0) return;
      const m = node.args[i].value.match(/^\$([_A-Za-z][_0-9A-Za-z]*)$/); node.args.splice(i, 1);
      if (m && !JSON.stringify(def.sel).includes('"$' + m[1] + '"')) { delete map[m[1]]; editVariables((o) => { delete o[m[1]]; }); }
    }
    setVariableDefs(def, map);
  });
}
function toggleFieldInline(sel, field) { sel.push({ kind: "field", alias: null, name: field.name, args: [], dirs: "", sel: isComposite(namedType(field.type)) ? [{ kind: "field", alias: null, name: "__typename", args: [], dirs: "", sel: null }] : null }); }

function renderRoots() {
  const box = $("#roots"); box.innerHTML = "";
  if (!S.schema) return;
  for (const kind of ["query", "mutation", "subscription"]) {
    if (!rootName(kind)) continue;
    box.append(el("button", { class: "btn small" + (docRoot === kind ? " on" : ""), text: kind[0].toUpperCase() + kind.slice(1), onclick: () => { docRoot = kind; docPath = []; renderDocs(); } }));
  }
}
function docTypeAt() {
  let type = rootName(docRoot);
  for (const step of docPath) {
    if (step.type) { type = step.type; continue; }
    const t = S.types[type]; const f = t && t.fields.find((x) => x.name === step.name);
    if (!f) return null; type = namedType(f.type);
  }
  return type;
}
function renderDocs() {
  renderRoots();
  const docs = $("#docs"); const crumbs = $("#crumbs"); docs.innerHTML = ""; crumbs.innerHTML = "";
  if (!S.schema) { docs.append(el("div", { class: "empty", text: S.gateway && !S.gateway.subgraphs.length ? "No subgraphs are published yet. Publish one to see its schema here." : "Loading the schema…" })); return; }
  const typeNameNow = docTypeAt(); const type = S.types[typeNameNow];
  if (!type) { docPath = []; return renderDocs(); }
  crumbs.append(el("a", { text: rootName(docRoot), onclick: () => { docPath = []; renderDocs(); } }));
  docPath.forEach((step, i) => { crumbs.append(" › ", el("a", { text: step.type ? "… on " + step.type : step.name, onclick: () => { docPath = docPath.slice(0, i + 1); renderDocs(); } })); });
  let defs = null; try { defs = op.value.trim() ? parseDocument(op.value) : []; } catch (e) { defs = null; }
  const def = defs && currentOperation(defs);
  const sel = def && def.op === docRoot ? selectionAt(def.sel, docPath) : null;
  docs.append(el("div", { class: "typehead" }, el("span", { class: "tname", text: typeNameNow }), " ", el("span", { class: "badge", text: type.kind.toLowerCase().replace("_", " ") })));
  if (type.description) docs.append(el("div", { class: "desc", text: type.description }));
  if (!defs) docs.append(el("div", { class: "desc", style: "color: var(--red)", text: "The operation has a syntax error, so the checkboxes are off." }));
  if (type.kind === "UNION" || type.kind === "INTERFACE") {
    docs.append(el("div", { class: "section", text: "Possible types" }));
    for (const p of type.possibleTypes) docs.append(el("div", { class: "frow" }, el("span"), el("span", { class: "fname" }, el("span", { class: "go", text: "… on " + p.name, onclick: () => { docPath = docPath.concat([{ type: p.name }]); renderDocs(); } })), el("span", { class: "go", text: "›", onclick: () => { docPath = docPath.concat([{ type: p.name }]); renderDocs(); } })));
  }
  if (type.fields.length) docs.append(el("div", { class: "section", text: "Fields" }));
  for (const f of type.fields) {
    const node = sel && sel.find((s) => s.kind === "field" && s.name === f.name && !s.alias);
    const composite = isComposite(namedType(f.type));
    const box = el("input", { type: "checkbox", disabled: !defs, onchange: (ev) => { toggleField(docPath, f, ev.target.checked); if (ev.target.checked && composite) { docPath = docPath.concat([{ name: f.name }]); renderDocs(); } } });
    box.checked = !!node;
    const owners = S.owners[typeNameNow] && S.owners[typeNameNow].fields[f.name];
    docs.append(el("div", { class: "frow" + (f.isDeprecated ? " dep" : ""), title: (f.description || "") + (owners && owners.length ? "\nResolved by: " + owners.join(", ") : "") },
      box,
      el("span", { class: "fname" }, composite ? el("span", { class: "go", style: "color: inherit", text: f.name, onclick: () => { docPath = docPath.concat([{ name: f.name }]); renderDocs(); } }) : f.name, f.args.length ? el("span", { class: "args", text: "(…)" }) : null),
      el("span", {}, el("span", { class: "ftype", text: typeName(f.type) }), composite ? el("span", { class: "go", text: " ›", onclick: () => { docPath = docPath.concat([{ name: f.name }]); renderDocs(); } }) : null),
      f.description ? el("span", { class: "fdesc", text: f.description }) : null));
    if (node || f.args.some((a) => a.type.kind === "NON_NULL")) {
      for (const a of f.args) {
        const ab = el("input", { type: "checkbox", disabled: !defs || !node, onchange: (ev) => toggleArgument(docPath, f, a, ev.target.checked) });
        ab.checked = !!(node && node.args.some((x) => x.name === a.name));
        docs.append(el("div", { class: "argrow", title: a.description || "" }, ab, el("span", { text: a.name }), el("span", { class: "ftype", text: typeName(a.type) })));
      }
    }
  }
  if (type.kind === "OBJECT" || type.kind === "INTERFACE" || type.kind === "UNION") {
    const tn = sel && sel.find((s) => s.kind === "field" && s.name === "__typename");
    const box = el("input", { type: "checkbox", disabled: !defs, onchange: (ev) => toggleField(docPath, { name: "__typename", args: [], type: { kind: "SCALAR", name: "String" } }, ev.target.checked) });
    box.checked = !!tn;
    docs.append(el("div", { class: "frow" }, box, el("span", { class: "fname", style: "color: var(--faint)", text: "__typename" }), el("span", { class: "ftype", text: "String!" })));
  }
}

// ---------- run, response and query plan ----------
let running = false;
function parseJsonBox(text, what) {
  if (!text || !text.trim()) return {};
  try { const v = JSON.parse(text); if (v && typeof v === "object" && !Array.isArray(v)) return v; } catch (e) { }
  throw new Error("The " + what + " must be a JSON object.");
}
function hasHeader(headers, name) {
  const want = name.toLowerCase();
  return Object.keys(headers || {}).some((k) => k.toLowerCase() === want);
}
function mergeIncremental(state, payload) {
  if (payload.data !== undefined && !state.merged) {
    state.merged = { data: payload.data };
    if (payload.errors) state.merged.errors = payload.errors.slice();
  }
  for (const p of payload.pending || []) state.paths[p.id] = p.path || [];
  if (state.merged && payload.incremental) {
    for (const inc of payload.incremental) {
      const path = state.paths[inc.id] || inc.path || [];
      let target = state.merged.data;
      for (const seg of path) if (target != null) target = target[seg];
      if (target && inc.data && typeof inc.data === "object") Object.assign(target, inc.data);
      if (inc.errors && inc.errors.length) state.merged.errors = (state.merged.errors || []).concat(inc.errors);
    }
  }
  if (state.merged && payload.completed) {
    for (const c of payload.completed) {
      if (c.errors && c.errors.length) state.merged.errors = (state.merged.errors || []).concat(c.errors);
    }
  }
}
function formatEvents(events, state) {
  if (state && state.merged) return JSON.stringify(state.merged, null, 2);
  if (events.length === 1) return typeof events[0] === "string" ? events[0] : JSON.stringify(events[0], null, 2);
  return JSON.stringify(events, null, 2);
}
function runWsSubscription(t, query, variables, operationName, headers, started) {
  const events = []; let bytes = 0; let closed = false;
  const ws = new WebSocket(wsEndpointUrl(), "graphql-transport-ws");
  const finish = (live) => {
    if (closed) return; closed = true;
    t.stopStream = null; t.loading = false; running = false; $("#run").disabled = false;
    if (t.response) t.response.live = live ? "stopped · " + events.length + (events.length === 1 ? " event" : " events") : (events.length ? events.length + (events.length === 1 ? " event" : " events") : null);
    try { if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ id: "1", type: "complete" })); ws.close(1000); } catch (e) { }
    renderOps(); showResponse();
  };
  t.stopStream = () => finish(true);
  t.loading = false;
  t.response = { status: 101, ms: 0, bytes: 0, text: "{\n  \"status\": \"waiting for subscription events…\"\n}", protocol: "ws", live: "live · 0 events", at: new Date() };
  renderOps(); showResponse();
  ws.addEventListener("open", () => {
    ws.send(JSON.stringify({ type: "connection_init", payload: headers }));
  });
  ws.addEventListener("message", (ev) => {
    bytes += (ev.data || "").length;
    let msg; try { msg = JSON.parse(ev.data); } catch (e) { return; }
    if (msg.type === "connection_ack") {
      ws.send(JSON.stringify({ id: "1", type: "subscribe", payload: { query, variables, operationName } }));
    } else if (msg.type === "ping") {
      ws.send(JSON.stringify({ type: "pong" }));
    } else if (msg.type === "next") {
      events.push(msg.payload);
      t.response = { status: 200, ms: Math.round(performance.now() - started), bytes, text: formatEvents(events), protocol: "ws", live: "live · " + events.length + (events.length === 1 ? " event" : " events"), at: new Date() };
      showResponse();
    } else if (msg.type === "error") {
      events.push({ errors: msg.payload });
      t.response = { status: 400, ms: Math.round(performance.now() - started), bytes, text: formatEvents(events), protocol: "ws", at: new Date() };
      finish(false);
    } else if (msg.type === "complete") {
      finish(false);
    }
  });
  ws.addEventListener("error", () => {
    if (!events.length && !closed) {
      t.response = { status: 0, ms: Math.round(performance.now() - started), bytes, text: JSON.stringify({ errors: [{ message: "WebSocket connection failed." }] }), protocol: "ws", at: new Date() };
    }
    finish(false);
  });
  ws.addEventListener("close", () => finish(false));
}
async function runHttpStream(t, res, ct, started, ctrl) {
  const isSse = ct.startsWith("text/event-stream");
  const bm = ct.match(/boundary=(?:"([^"]+)"|([^;\s]+))/i);
  const boundary = bm ? (bm[1] || bm[2]) : "-";
  const events = []; const deferState = { merged: null, paths: {} };
  let buf = ""; let bytes = 0; let closed = false;
  const finish = (stopped) => {
    if (closed) return; closed = true;
    t.stopStream = null; t.loading = false; running = false; $("#run").disabled = false;
    try { if (stopped) ctrl.abort(); } catch (e) { }
    if (t.response) {
      const kind = deferState.merged ? "defer · " : (stopped ? "stopped · " : "");
      t.response.live = events.length ? kind + events.length + (events.length === 1 ? " payload" : " payloads") : null;
    }
    renderOps(); showResponse();
  };
  t.stopStream = () => finish(true);
  t.loading = false;
  t.response = { status: res.status, ms: Math.round(performance.now() - started), bytes: 0, text: "{\n  \"status\": \"streaming…\"\n}", protocol: isSse ? "sse" : "multipart", live: "streaming…", at: new Date() };
  renderOps(); showResponse();
  const pushJson = (raw) => {
    let parsed; try { parsed = JSON.parse(raw); } catch (e) { return; }
    const item = parsed && parsed.payload !== undefined && Object.keys(parsed).length === 1 ? parsed.payload : parsed;
    if (item && (item.pending !== undefined || item.incremental !== undefined || item.completed !== undefined)) mergeIncremental(deferState, item);
    events.push(item);
    t.response = { status: res.status, ms: Math.round(performance.now() - started), bytes, text: formatEvents(events, deferState), protocol: isSse ? "sse" : "multipart", live: "live · " + events.length + (events.length === 1 ? " payload" : " payloads"), at: new Date() };
    showResponse();
  };
  const reader = res.body.getReader(); const dec = new TextDecoder();
  try {
    while (!closed) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      buf += dec.decode(value, { stream: true });
      if (isSse) {
        let idx;
        while ((idx = buf.indexOf("\n\n")) >= 0) {
          const block = buf.slice(0, idx); buf = buf.slice(idx + 2);
          let ev = "message"; const data = [];
          for (const line of block.split(/\r?\n/)) {
            if (line.startsWith("event:")) ev = line.slice(6).trim();
            else if (line.startsWith("data:")) data.push(line.slice(5).trimStart());
          }
          if (ev === "complete") { finish(false); return; }
          if (data.length) pushJson(data.join("\n"));
        }
      } else {
        const delim = "--" + boundary;
        let pos;
        while ((pos = buf.indexOf(delim)) >= 0) {
          const rest = buf.slice(pos + delim.length);
          if (rest.startsWith("--")) { finish(false); return; }
          const next = rest.indexOf(delim);
          if (next < 0) break;
          const part = rest.slice(0, next);
          buf = rest.slice(next);
          const sep = part.indexOf("\r\n\r\n");
          const body = (sep >= 0 ? part.slice(sep + 4) : part).trim();
          if (body && body !== "{}") pushJson(body);
        }
      }
    }
  } catch (e) { }
  finish(false);
}
async function run() {
  const t = tab();
  if (t.stopStream) { t.stopStream(); return; }
  if (running) return;
  const ops = operations() || []; const cur = selectedOp();
  const opName = ops.length > 1 ? $("#op-select").value || null : (cur && cur.name) || null;
  let variables, headers;
  try { variables = parseJsonBox(t.variables, "variables"); headers = parseJsonBox(t.headers, "headers"); } catch (e) { toast(e.message, "bad"); return; }
  const started = performance.now();
  if (outTab === "plan") loadPlan(); else t.plan = null;
  if (cur && cur.op === "subscription" && !hasHeader(headers, "accept") && (!S.gateway || S.gateway.subscriptions !== "off")) {
    running = true; runWsSubscription(t, op.value, variables, opName, headers, started); return;
  }
  running = true; $("#run").disabled = true; t.response = null; t.loading = true; showResponse();
  const ctrl = new AbortController();
  try {
    const defAccept = cur && cur.op === "subscription"
      ? "text/event-stream, multipart/mixed;subscriptionSpec=1.0, application/graphql-response+json, application/json"
      : /\b@defer\b/.test(op.value)
        ? "multipart/mixed, text/event-stream, application/graphql-response+json, application/json"
        : "application/graphql-response+json, application/json";
    const res = await fetch(BOOT.graphqlPath, {
      method: "POST",
      headers: Object.assign({ "content-type": "application/json", accept: defAccept }, headers || {}),
      body: JSON.stringify({ query: op.value, variables, operationName: opName }),
      signal: ctrl.signal,
    });
    const ct = (res.headers.get("content-type") || "").toLowerCase();
    if (res.body && (ct.startsWith("text/event-stream") || ct.startsWith("multipart/mixed"))) {
      $("#run").disabled = false;
      await runHttpStream(t, res, ct, started, ctrl);
      return;
    }
    const text = await res.text();
    t.response = { status: res.status, ms: Math.round(performance.now() - started), bytes: new Blob([text]).size, text, protocol: lastProtocol(BOOT.graphqlPath), at: new Date() };
  } catch (e) {
    t.response = { status: 0, ms: Math.round(performance.now() - started), bytes: 0, text: JSON.stringify({ errors: [{ message: "The request failed: " + e.message }] }) };
  }
  t.loading = false; running = false; $("#run").disabled = false;
  renderOps(); showResponse();
}
function showResponse() {
  const t = tab(); const pre = $("#resp"); const empty = $("#resp-empty"); const meta = $("#meta");
  meta.innerHTML = "";
  if (t.loading) { pre.hidden = true; empty.hidden = false; empty.innerHTML = '<div class="spinner"></div>'; return; }
  if (!t.response) { pre.hidden = true; empty.hidden = false; empty.innerHTML = '<div><svg viewBox="0 0 64 64"><path fill="#ff6a1a" d="M33 3c2 9-3 14-8 20-5 6-10 12-10 21 0 10 8 17 17 17s17-7 17-17c0-7-3-12-7-16 0 5-2 9-6 11 1-9-1-19-3-36z"/></svg><div>Run an operation to see its response.</div><div style="margin-top:6px"><span class="kbd">Ctrl</span> + <span class="kbd">Enter</span></div></div>'; return; }
  let text = t.response.text; let ok = t.response.status >= 100 && t.response.status < 300;
  try { const json = JSON.parse(text); text = JSON.stringify(json, null, 2); if (json.errors && json.errors.length) ok = ok && !!json.data; } catch (e) { }
  pre.innerHTML = highlightJson(text); pre.hidden = false; empty.hidden = true;
  renderProtocolChip();
  meta.append(...[el("span", { class: ok ? "status-ok" : "status-bad", text: (t.response.status || "ERR") + "" }), t.response.protocol ? el("span", { class: "chip", title: "The transport of this response", text: protocolName(t.response.protocol) }) : null, t.response.live ? el("span", { class: "chip live", text: t.response.live }) : null, pollTimer ? el("span", { class: "chip live", text: "polling · " + t.response.at.toLocaleTimeString() }) : null, el("span", { text: t.response.ms + " ms" }), el("span", { text: fmtBytes(t.response.bytes) }),
    el("button", { class: "btn ghost small", text: "Copy", onclick: () => copy(text, "Response") })].filter(Boolean));
}
function fmtBytes(n) { return n < 1024 ? n + " B" : (n / 1024).toFixed(1) + " KB"; }
$$("[data-out]").forEach((b) => b.addEventListener("click", () => {
  outTab = b.dataset.out; $$("[data-out]").forEach((x) => x.classList.toggle("on", x === b));
  $("#out-response").hidden = outTab !== "response"; $("#out-plan").hidden = outTab !== "plan";
  if (outTab === "plan") loadPlan();
}));
$$("[data-plan]").forEach((b) => b.addEventListener("click", () => { planMode = b.dataset.plan; store.set("planMode", planMode); showPlan(); }));
$("#plan-refresh").addEventListener("click", () => loadPlan());
async function loadPlan() {
  const t = tab(); const ops = operations() || [];
  const opName = ops.length > 1 ? $("#op-select").value || null : (ops[0] && ops[0].name) || null;
  t.plan = { loading: true }; showPlan();
  try {
    const res = await fetch("/scorchql/plan", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ query: op.value, operationName: opName }) });
    const json = await res.json();
    t.plan = json.ok ? { text: json.plan } : { error: (json.errors || ["The plan failed."]).join("\n") };
  } catch (e) { t.plan = { error: "The plan request failed: " + e.message }; }
  showPlan();
}
// Read the Display text of a query plan into a tree.
function parsePlan(text) {
  const lines = text.split("\n"); let i = 0;
  function node() {
    const line = lines[i].trim(); i++;
    const m = line.match(/^([A-Za-z]+)(\((.*)\))?\s*\{$/);
    if (!m) return { kind: "Text", text: line };
    const n = { kind: m[1], attrs: m[3] || "", kids: [], body: [] };
    if (n.kind === "Fetch" || n.kind === "BatchFetch") {
      let depth = 1; const body = [];
      while (i < lines.length) { const l = lines[i]; i++; const o = (l.match(/\{/g) || []).length; const c = (l.match(/\}/g) || []).length; depth += o - c; if (depth <= 0) break; body.push(l); }
      const pad = Math.min(...body.filter((l) => l.trim()).map((l) => l.match(/^\s*/)[0].length));
      n.body = body.map((l) => l.slice(pad)); return n;
    }
    while (i < lines.length) {
      const l = lines[i].trim();
      if (l === "}" || l === "},") { i++; break; }
      if (!l) { i++; continue; }
      n.kids.push(node());
    }
    return n;
  }
  const out = []; while (i < lines.length) { if (lines[i].trim()) out.push(node()); else i++; }
  return out;
}
function planNode(n) {
  if (n.kind === "Text") return el("pre", { text: n.text });
  const kind = n.kind.toLowerCase();
  const head = el("div", { class: "phead" }, n.kind);
  const svc = n.attrs.match(/service:\s*"([^"]+)"/); if (svc) head.append(el("span", { class: "svc", text: svc[1] }));
  const path = n.attrs.match(/path:\s*"([^"]+)"/); if (path) head.append(el("span", { class: "ppath", text: path[1] }));
  const rest = n.attrs.replace(/service:\s*"[^"]+",?\s*/, "").replace(/path:\s*"[^"]+",?\s*/, "").trim(); if (rest) head.append(el("span", { class: "ppath", text: rest }));
  const box = el("div", { class: "pnode " + kind }, head);
  if (n.body.length) { const pre = el("pre"); pre.innerHTML = highlight(n.body.join("\n")); box.append(pre); }
  if (n.kids.length) { const kids = el("div", { class: "pkids" }); n.kids.forEach((k) => kids.append(planNode(k))); box.append(kids); }
  return box;
}
function showPlan() {
  const box = $("#plan"); const t = tab(); box.innerHTML = "";
  $$("[data-plan]").forEach((b) => b.classList.toggle("on", b.dataset.plan === planMode));
  if (!t.plan) { box.append(el("div", { class: "empty", text: "Open this tab to see how the gateway splits the operation across the subgraphs." })); return; }
  if (t.plan.loading) { box.append(el("div", { class: "spinner" })); return; }
  if (t.plan.error) { box.append(el("div", { class: "errors", text: t.plan.error })); return; }
  if (planMode === "text") { const pre = el("pre", { style: "margin:0; font: 12.5px/1.6 var(--mono); white-space: pre-wrap" }); pre.innerHTML = highlight(t.plan.text); box.append(pre); return; }
  try {
    const tree = parsePlan(t.plan.text);
    const root = tree[0] && tree[0].kind === "QueryPlan" ? tree[0].kids : tree;
    if (!root.length) box.append(el("div", { class: "empty", text: "The gateway answers this operation itself: it sends nothing to a subgraph." }));
    root.forEach((n) => box.append(planNode(n)));
  } catch (e) { const pre = el("pre"); pre.textContent = t.plan.text; box.append(pre); }
}

function prettify() {
  try { const defs = parseDocument(op.value); if (!defs.length) return; op.value = printDocument(defs); op.dispatchEvent(new Event("input")); } catch (e) { toast("Cannot format: " + e.message, "bad"); }
}
$("#prettify").addEventListener("click", prettify);
$("#run").addEventListener("click", run);
$("#copy-curl").addEventListener("click", () => {
  const t = tab(); let variables = {}; let headers = {};
  try { variables = parseJsonBox(t.variables, "variables"); headers = parseJsonBox(t.headers, "headers"); } catch (e) { }
  const ops = operations() || []; const cur = selectedOp();
  const opName = ops.length > 1 ? $("#op-select").value || null : (cur && cur.name) || null;
  const body = JSON.stringify({ query: op.value, variables, operationName: opName });
  const q = (s) => "'" + s.replace(/'/g, "'\\''") + "'";
  const isSub = cur && cur.op === "subscription";
  const isDefer = /\b@defer\b/.test(op.value);
  const extra = (isSub || isDefer) && !hasHeader(headers, "accept")
    ? ["-N", "-H", q("accept: " + (isSub ? "text/event-stream" : "multipart/mixed, application/json"))]
    : [];
  const cmd = ["curl"].concat(extra).concat([q(endpointUrl()), "-H", q("content-type: application/json")]).concat(Object.entries(headers).flatMap(([k, v]) => ["-H", q(k + ": " + v)])).concat(["--data", q(body)]).join(" ");
  copy(cmd, "curl command");
});

// ---------- variables and headers as fields ----------
let varsMode = store.get("varsMode", "json");
function readObject(text) {
  if (!text || !text.trim()) return {};
  try { const v = JSON.parse(text); return v && typeof v === "object" && !Array.isArray(v) ? v : null; } catch (e) { return null; }
}
function declaredVariables() {
  let defs; try { defs = parseDocument(op.value); } catch (e) { return {}; }
  const def = currentOperation(defs); if (!def) return {};
  const out = {};
  for (const [name, text] of Object.entries(variableDefs(def.vars))) out[name] = text.split(/\s*[=@]/)[0].trim();
  return out;
}
function setVarsMode(mode) {
  varsMode = mode; store.set("varsMode", mode);
  $$("[data-vmode]").forEach((b) => b.classList.toggle("on", b.dataset.vmode === mode));
  $("#vars-edit").hidden = mode !== "json"; $("#fields").hidden = mode !== "fields";
  if (mode === "json") { vars.value = tab()[subTab] || ""; paintVars(); } else renderFields();
}
function fieldInput(type, value, onValue) {
  const named = type.replace(/[\[\]!\s]/g, ""); const list = type.trim().startsWith("[");
  const t = S.types[named];
  if (!list && named === "Boolean") {
    const s = el("select", {}, el("option", { value: "", text: "(not set)" }), el("option", { value: "true", text: "true" }), el("option", { value: "false", text: "false" }));
    s.value = value === undefined || value === null ? "" : String(value);
    s.addEventListener("change", () => onValue(s.value === "" ? undefined : s.value === "true")); return s;
  }
  if (!list && t && t.kind === "ENUM") {
    const s = el("select", {}, el("option", { value: "", text: "(not set)" }), t.enumValues.map((v) => el("option", { value: v.name, text: v.name })));
    s.value = value == null ? "" : String(value);
    s.addEventListener("change", () => onValue(s.value === "" ? undefined : s.value)); return s;
  }
  if (!list && (named === "Int" || named === "Float")) {
    const i = el("input", { type: "number", step: named === "Int" ? "1" : "any", value: value == null ? "" : String(value) });
    i.addEventListener("input", () => onValue(i.value === "" ? undefined : Number(i.value))); return i;
  }
  const json = list || (t && t.kind === "INPUT_OBJECT") || (!t && named && !["String", "ID"].includes(named) && typeof value === "object");
  const i = el("input", { type: "text", placeholder: json ? "JSON, such as " + (list ? "[ ]" : "{ }") : "", value: value == null ? "" : json || typeof value !== "string" ? JSON.stringify(value) : value });
  i.addEventListener("input", () => {
    if (i.value === "") { i.classList.remove("bad"); onValue(undefined); return; }
    if (!json) { onValue(i.value); return; }
    try { onValue(JSON.parse(i.value)); i.classList.remove("bad"); } catch (e) { i.classList.add("bad"); }
  });
  return i;
}
function renderFields() {
  const box = $("#fields"); box.innerHTML = "";
  const obj = readObject(tab()[subTab]);
  if (!obj) { box.append(el("div", { class: "errors", text: "The " + subTab + " are not a JSON object, so they cannot be shown as fields. Fix them in JSON mode." })); return; }
  const write = () => { tab()[subTab] = JSON.stringify(obj, null, 2); saveTabs(); };
  if (subTab === "variables") {
    const declared = declaredVariables();
    const names = [...new Set(Object.keys(declared).concat(Object.keys(obj)))];
    if (!names.length) { box.append(el("div", { class: "empty", text: "The operation declares no variables. Declare one, such as query($id: ID!), or check a field with a required argument." })); return; }
    for (const name of names) {
      const type = declared[name];
      const input = fieldInput(type || "", obj[name], (v) => { if (v === undefined) delete obj[name]; else obj[name] = v; write(); });
      box.append(el("div", { class: "frm" },
        el("span", { class: "lab" }, "$" + name, type ? el("small", { text: type }) : el("small", { class: "warn", text: "not declared" })),
        input,
        !type ? el("button", { class: "btn ghost small", text: "Remove", onclick: () => { delete obj[name]; write(); renderFields(); } }) : el("span")));
    }
  } else {
    const entries = Object.entries(obj);
    entries.forEach(([key, value], index) => {
      const k = el("input", { type: "text", value: key, placeholder: "Header name" });
      const v = el("input", { type: "text", value: String(value), placeholder: "Value" });
      const rebuild = () => {
        const next = {}; $$(".frm", box).forEach((row) => { const [a, b] = $$("input", row); if (a.value.trim()) next[a.value.trim()] = b.value; });
        for (const key of Object.keys(obj)) delete obj[key]; Object.assign(obj, next); write();
      };
      k.addEventListener("input", rebuild); v.addEventListener("input", rebuild);
      box.append(el("div", { class: "frm" }, k, v, el("button", { class: "btn ghost small", text: "Remove", onclick: () => { delete obj[key]; write(); renderFields(); } })));
    });
    box.append(el("div", {}, el("button", { class: "btn small", text: "+ Add header", onclick: () => { let n = "x-header"; let i = 2; while (n in obj) n = "x-header-" + i++; obj[n] = ""; write(); renderFields(); } })));
  }
}
$$("[data-vmode]").forEach((b) => b.addEventListener("click", () => setVarsMode(b.dataset.vmode)));

// ---------- HTTP versions ----------
const PROTOCOLS = { "http/1.0": "HTTP/1.0", "http/1.1": "HTTP/1.1", h2: "HTTP/2", h2c: "HTTP/2", h3: "HTTP/3", ws: "WebSocket", sse: "SSE", multipart: "Multipart" };
const protocolName = (p) => PROTOCOLS[p] || (p && p.startsWith("h3") ? "HTTP/3" : p || "unknown");
function lastProtocol(path) {
  const url = new URL(path, location.href).href;
  const list = performance.getEntriesByType("resource").filter((e) => e.name === url);
  const entry = list[list.length - 1];
  if (performance.getEntriesByType("resource").length > 150) performance.clearResourceTimings();
  return entry ? entry.nextHopProtocol : "";
}
function pageProtocol() { const nav = performance.getEntriesByType("navigation")[0]; return nav ? nav.nextHopProtocol : ""; }
function connectionDialog() {
  const g = S.gateway || {}; const host = location.hostname;
  const rows = [["This page", protocolName(pageProtocol()) + " over " + location.protocol.replace(":", "").toUpperCase()]];
  const last = tab().response && tab().response.protocol; if (last) rows.push(["Last response", protocolName(last)]);
  if (g.subscriptions) rows.push(["Subgraph subscriptions", g.subscriptions === "ws" ? "WebSocket (graphql-transport-ws)" : g.subscriptions === "http" ? "HTTP streaming (SSE / multipart)" : "disabled"]);
  const links = [];
  if (g.httpPort) links.push(["HTTP/1.1 and WebSocket", "http://" + host + ":" + g.httpPort + "/", "Plain HTTP/1.1, SSE, multipart/mixed and RFC 6455 WebSocket."]);
  if (g.httpsPort) links.push(["HTTP/2, HTTP/1.1 and WebSocket over TLS", "https://" + host + ":" + g.httpsPort + "/", "ALPN picks HTTP/2, with RFC 8441 WebSockets over HTTP/2."]);
  if (g.h3Port) links.push(["HTTP/3 and WebSocket over QUIC", "https://" + host + ":" + g.h3Port + "/", "UDP port " + g.h3Port + ", announced with Alt-Svc, with RFC 9220 WebSockets over HTTP/3."]);
  dialog("Connection", [
    el("table", { class: "fields" }, rows.map(([a, b]) => el("tr", {}, el("td", { class: "n", text: a }), el("td", { text: b })))),
    el("div", { class: "section-title", text: "This gateway serves" }),
    links.map(([name, url, note]) => el("div", { class: "transport" }, el("b", { text: name }), el("a", { href: url, text: url }), el("div", { class: "hint", text: note }))),
    !g.httpsPort ? el("div", { class: "hint", text: "Start the gateway with --tls-cert and --tls-key to serve HTTP/2 and HTTP/3 too." }) : null,
    el("div", { class: "section-title", text: "Streaming" }),
    el("div", { class: "transport" }, el("b", { text: "WebSocket (graphql-transport-ws)" }), el("span", { style: "font-family:var(--mono);font-size:12px", text: wsEndpointUrl() }), el("div", { class: "hint", text: "The explorer runs subscriptions over WebSocket by default. Set an accept header in Headers to stream over SSE (text/event-stream) or multipart/mixed instead. Operations with @defer stream over multipart/mixed and merge each payload as it arrives." })),
  ], (close) => [el("button", { class: "btn", text: "Close", onclick: close })]);
}
$("#proto").addEventListener("click", connectionDialog);
function renderProtocolChip() { const p = (tab().response && tab().response.protocol) || pageProtocol(); $("#proto").textContent = protocolName(p); }

// ---------- polling ----------
let pollTimer = null;
function setPoll(seconds) {
  if (pollTimer) clearInterval(pollTimer); pollTimer = null;
  $("#poll").value = String(seconds);
  $("#run").classList.toggle("polling", seconds > 0);
  if (seconds > 0) { run(); pollTimer = setInterval(() => { if (!running) run(); }, seconds * 1000); }
}
$("#poll").addEventListener("change", () => setPoll(Number($("#poll").value)));

// ---------- schema reference ----------
let schemaType = null;
function renderTypeList() {
  const box = $("#type-list"); box.innerHTML = "";
  if (!S.schema) { box.append(el("div", { class: "empty", text: "No schema yet." })); $("#type-detail").innerHTML = ""; return; }
  const q = $("#type-search").value.trim().toLowerCase();
  const groups = { "Root types": [], Objects: [], Interfaces: [], Unions: [], Enums: [], Inputs: [], Scalars: [] };
  const roots = [rootName("query"), rootName("mutation"), rootName("subscription")].filter(Boolean);
  for (const t of S.schema.types) {
    if (isBuiltin(t.name) && !roots.includes(t.name)) continue;
    const hit = !q || t.name.toLowerCase().includes(q) || t.fields.some((f) => f.name.toLowerCase().includes(q)) || t.inputFields.some((f) => f.name.toLowerCase().includes(q)) || t.enumValues.some((v) => v.name.toLowerCase().includes(q));
    if (!hit) continue;
    const g = roots.includes(t.name) ? "Root types" : { OBJECT: "Objects", INTERFACE: "Interfaces", UNION: "Unions", ENUM: "Enums", INPUT_OBJECT: "Inputs", SCALAR: "Scalars" }[t.kind];
    groups[g].push(t);
  }
  for (const [g, list] of Object.entries(groups)) {
    if (!list.length) continue;
    box.append(el("div", { class: "group", text: g }));
    for (const t of list) box.append(el("a", { class: t.name === schemaType ? "on" : "", onclick: () => { schemaType = t.name; renderTypeList(); renderTypeDetail(); } }, el("span", { text: t.name }), el("span", { class: "k", text: t.kind === "INPUT_OBJECT" ? "input" : t.kind.toLowerCase() })));
  }
  if (!schemaType || !S.types[schemaType]) { schemaType = rootName("query"); renderTypeList(); }
  renderTypeDetail();
}
function typeLink(ref) {
  const name = namedType(ref); const text = typeName(ref);
  const a = el("a", { text, onclick: () => { schemaType = name; renderTypeList(); } });
  return isBuiltin(name) ? el("span", { text }) : a;
}
function renderTypeDetail() {
  const box = $("#type-detail"); box.innerHTML = ""; const t = S.types[schemaType]; if (!t) return;
  const own = S.owners[t.name];
  const d = el("div", { class: "tdetail" }, el("div", { class: "kind", text: t.kind.replace("_", " ") }), el("h1", { text: t.name }));
  if (own && own.graphs.length) d.append(el("div", {}, el("span", { class: "kind", text: "Subgraphs  " }), own.graphs.map((g) => el("span", { class: "badge sg", text: g }))));
  if (t.description) d.append(el("p", { class: "d", text: t.description }));
  if (t.interfaces.length) d.append(el("p", {}, "Implements ", t.interfaces.map((i) => el("span", { class: "badge", text: i.name }))));
  if (t.possibleTypes.length) d.append(el("p", {}, "Possible types ", t.possibleTypes.map((p) => el("a", { class: "badge", style: "cursor:pointer", text: p.name, onclick: () => { schemaType = p.name; renderTypeList(); } }))));
  const rows = t.kind === "ENUM" ? t.enumValues : t.kind === "INPUT_OBJECT" ? t.inputFields : t.fields;
  if (rows.length) {
    const table = el("table", { class: "fields" }, el("tr", {}, el("th", { text: t.kind === "ENUM" ? "Value" : "Field" }), el("th", { text: t.kind === "ENUM" ? "" : "Type" }), el("th", { text: "Description" }), el("th", { text: t.kind === "OBJECT" || t.kind === "INTERFACE" ? "Subgraphs" : "" })));
    for (const f of rows) {
      const argl = (f.args || []).length ? el("div", { class: "argl" }, f.args.map((a, i) => el("div", {}, a.name + ": ", typeLink(a.type), a.defaultValue != null ? " = " + a.defaultValue : ""))) : null;
      const owners = own && own.fields[f.name];
      table.append(el("tr", {},
        el("td", { class: "n" }, f.name, f.isDeprecated ? el("span", { class: "badge dep", title: f.deprecationReason || "", text: "deprecated" }) : null, argl),
        el("td", { class: "t" }, f.type ? typeLink(f.type) : ""),
        el("td", { text: f.description || "" }),
        el("td", {}, (owners || []).map((g) => el("span", { class: "badge sg", text: g })))));
    }
    d.append(table);
  }
  box.append(d);
}
$("#type-search").addEventListener("input", renderTypeList);

// ---------- subgraphs ----------
function authHeaders() { const token = store.get("token", ""); return token ? { authorization: "Bearer " + token } : {}; }
async function postAdmin(path, body) {
  const res = await fetch(path, { method: "POST", headers: Object.assign({ "content-type": "application/json" }, authHeaders()), body: JSON.stringify(body || {}) });
  let json = null; try { json = await res.json(); } catch (e) { json = { ok: false, errors: ["HTTP " + res.status] }; }
  if (res.status === 401) { store.set("token", ""); }
  return json;
}
function renderSubgraphs() {
  const page = $("#subgraphs-page"); page.innerHTML = "";
  const g = S.gateway;
  page.append(el("h1", { text: "Subgraphs" }), el("p", { class: "lead", text: g ? (g.mode === "registry" ? "The subgraphs published to this gateway. A publish composes the supergraph again; a publish that does not compose is refused." : "This gateway serves a fixed supergraph file. Start it with a registry to publish subgraphs.") : "Loading…" }));
  if (!g) return;
  if (g.loadError) page.append(el("div", { class: "errors", style: "margin-bottom:14px", text: g.loadError }));
  if (g.mode === "registry") {
    const host = endpointUrl().replace(BOOT.graphqlPath, "");
    const seamstress = (g.publishRequiresToken ? "SCORCHQL_TOKEN=<token> " : "") + "seamstress subgraph publish " + host + " --name products --routing-url http://localhost:4001/";
    const curl = "curl " + host + "/scorchql/publish -H 'content-type: application/json' \\\n  " + (g.publishRequiresToken ? "-H 'authorization: Bearer <token>' " : "") + "--data '{\"name\":\"products\",\"url\":\"http://localhost:4001/\"}'";
    page.append(el("div", { class: "callout" }, el("h3", { text: g.subgraphs.length ? "Publish another subgraph" : "Publish your first subgraph" }),
      el("div", { class: "lead", text: "Use the Publish button, or seamstress. Without an SDL, the gateway reads it from the subgraph with { _service { sdl } }." }),
      el("pre", { text: seamstress + "\n\n" + curl }),
      el("button", { class: "btn fire", text: "Publish subgraph", onclick: () => publishDialog() })));
  }
  const cards = el("div", { class: "cards" });
  for (const s of g.subgraphs) {
    const sdl = el("pre"); sdl.innerHTML = highlightSdl(s.sdl || "");
    const owned = Object.entries(S.owners).filter(([, o]) => o.graphs.includes(s.name)).map(([n]) => n).filter((n) => !n.startsWith("join__") && !n.startsWith("link__") && !n.startsWith("federation__"));
    cards.append(el("div", { class: "card" },
      el("div", { class: "ch" }, el("span", { class: "dot ok" }), el("span", { class: "nm", text: s.name }), el("span", { class: "spacer" }), owned.length ? el("span", { class: "chip", text: owned.length + " types" }) : null),
      el("div", { class: "cb" },
        el("div", { class: "row" }, el("b", { text: "Routing URL" }), el("span", { text: s.url })),
        s.publishedAt ? el("div", { class: "row" }, el("b", { text: "Published" }), el("span", { text: new Date(s.publishedAt * 1000).toLocaleString() })) : null,
        owned.length ? el("div", { class: "row" }, el("b", { text: "Types" }), el("span", {}, owned.slice(0, 12).map((n) => el("span", { class: "badge", text: n })), owned.length > 12 ? " …" : "")) : null),
      s.sdl ? el("details", {}, el("summary", { text: "Subgraph SDL" }), sdl) : null,
      g.mode === "registry" ? el("div", { class: "cf" },
        el("button", { class: "btn small", text: "Update", onclick: () => publishDialog(s) }),
        el("button", { class: "btn small danger", text: "Remove", onclick: () => removeDialog(s) })) : null));
  }
  page.append(cards);
}
function dialog(title, body, actions) {
  const back = el("div", { class: "modal-back", onclick: (ev) => { if (ev.target === back) back.remove(); } });
  const close = () => back.remove();
  const m = el("div", { class: "modal" }, el("div", { class: "mh" }, el("h3", { text: title }), el("button", { class: "btn ghost small", text: "Close", onclick: close })), el("div", { class: "mb" }, body), el("div", { class: "mf" }, actions(close)));
  back.append(m); document.body.append(back);
  back.addEventListener("keydown", (ev) => { if (ev.key === "Escape") close(); });
  const first = $("input, textarea", m); if (first) first.focus();
  return close;
}
function tokenField() {
  if (!S.gateway || !S.gateway.publishRequiresToken) return null;
  const input = el("input", { type: "password", placeholder: "The publish token of the gateway", value: store.get("token", "") });
  input.addEventListener("input", () => store.set("token", input.value));
  return el("label", {}, "Publish token", input);
}
function publishDialog(existing) {
  const name = el("input", { placeholder: "products", value: existing ? existing.name : "" });
  const url = el("input", { placeholder: "http://localhost:4001/graphql", value: existing ? existing.url : "" });
  const sdl = el("textarea", { placeholder: "Leave empty: the gateway reads the SDL from the subgraph with { _service { sdl } }." });
  const errors = el("div", { class: "errors", hidden: true });
  dialog(existing ? "Update " + existing.name : "Publish a subgraph", [
    el("label", {}, "Subgraph name", name),
    el("label", {}, "Routing URL ", el("span", { class: "hint", text: "where the gateway sends operations; it must be reachable from the gateway" }), url),
    el("label", {}, "SDL ", el("span", { class: "hint", text: "optional" }), sdl),
    tokenField(), errors,
  ], (close) => [
    el("button", { class: "btn", text: "Cancel", onclick: close }),
    el("button", { class: "btn fire", text: "Publish", onclick: async (ev) => {
      ev.target.disabled = true; errors.hidden = true;
      const body = { name: name.value.trim(), url: url.value.trim() }; if (sdl.value.trim()) body.sdl = sdl.value;
      const res = await postAdmin("/scorchql/publish", body);
      ev.target.disabled = false;
      if (!res.ok) { errors.textContent = (res.errors || []).join("\n\n"); errors.hidden = false; return; }
      close(); toast(res.changed ? "Published " + body.name + ". The supergraph is now revision " + res.revision + "." : body.name + " is unchanged.", "ok");
      await poll(true);
    } }),
  ]);
}
function removeDialog(s) {
  const errors = el("div", { class: "errors", hidden: true });
  dialog("Remove " + s.name, [el("div", { text: "The gateway composes the other subgraphs without " + s.name + ". Operations that need it stop working." }), tokenField(), errors], (close) => [
    el("button", { class: "btn", text: "Cancel", onclick: close }),
    el("button", { class: "btn danger", text: "Remove", onclick: async () => {
      const res = await postAdmin("/scorchql/remove", { name: s.name });
      if (!res.ok) { errors.textContent = (res.errors || []).join("\n\n"); errors.hidden = false; return; }
      close(); toast("Removed " + s.name + ".", "ok"); await poll(true);
    } }),
  ]);
}
$("#publish-btn").addEventListener("click", () => publishDialog());
$("#refresh-btn").addEventListener("click", async () => {
  if (S.gateway && S.gateway.mode !== "registry") { toast("This gateway serves a fixed supergraph.", "bad"); return; }
  if (S.gateway && S.gateway.publishRequiresToken && !store.get("token", "")) {
    dialog("Refresh subgraphs", [tokenField()], (close) => [el("button", { class: "btn fire", text: "Refresh", onclick: () => { close(); $("#refresh-btn").click(); } })]); return;
  }
  const res = await postAdmin("/scorchql/refresh", {});
  if (!res.ok) { toast((res.errors || ["The refresh failed."]).join("\n"), "bad"); return; }
  const lines = res.subgraphs.map((s) => s.name + ": " + s.status + (s.error ? " (" + s.error + ")" : ""));
  toast(lines.length ? lines.join("\n") : "No subgraphs are published.", res.subgraphs.some((s) => s.status === "failed") ? "bad" : "ok");
  await poll(true);
});

// ---------- SDL view ----------
let sdlMode = "api";
function renderSdl() {
  $$("[data-sdl]").forEach((b) => b.classList.toggle("on", b.dataset.sdl === sdlMode));
  const text = sdlMode === "api" ? S.apiSdl : S.sdl;
  $("#sdl-text").innerHTML = text ? highlightSdl(text) : '<span class="t-com"># No schema yet.</span>';
}
$$("[data-sdl]").forEach((b) => b.addEventListener("click", () => { sdlMode = b.dataset.sdl; renderSdl(); }));
$("#sdl-copy").addEventListener("click", () => copy(sdlMode === "api" ? S.apiSdl : S.sdl, "SDL"));

// ---------- views and polling ----------
let view = "explorer";
function showView(name) {
  view = name; location.hash = name === "explorer" ? "" : name;
  $$("nav.rail button").forEach((b) => b.classList.toggle("on", b.dataset.view === name));
  $$(".view").forEach((v) => v.classList.toggle("on", v.id === "view-" + name));
  if (name === "schema") renderTypeList();
  if (name === "subgraphs") renderSubgraphs();
  if (name === "sdl") renderSdl();
}
$$("nav.rail button").forEach((b) => b.addEventListener("click", () => showView(b.dataset.view)));
function renderHeader() {
  const g = S.gateway; const dot = $("#health"); const sum = $("#summary");
  if (!g) { dot.className = "dot bad"; sum.textContent = "gateway unreachable"; return; }
  const n = g.subgraphs.length;
  dot.className = "dot " + (g.loadError ? "bad" : n ? "ok" : "warn");
  sum.textContent = (n ? n + " subgraph" + (n === 1 ? "" : "s") : "no subgraphs") + (g.mode === "registry" ? " · revision " + Math.max(g.revision, 0) : " · fixed supergraph");
  $("#publish-btn").hidden = g.mode !== "registry"; $("#refresh-btn").hidden = g.mode !== "registry";
}
function rerender() { renderHeader(); renderDocs(); if (view === "schema") renderTypeList(); if (view === "subgraphs") renderSubgraphs(); if (view === "sdl") renderSdl(); }
let polling = false;
async function poll(force) {
  if (polling) return; polling = true;
  try {
    const res = await fetch("/scorchql/state", { cache: "no-store" });
    const g = await res.json(); const changed = !S.gateway || g.revision !== S.gateway.revision || force;
    const first = !S.gateway; S.gateway = g;
    if (changed) {
      if (g.subgraphs.length && !g.loadError) {
        try { await loadSchema(); if (!first) toast("The supergraph changed: revision " + g.revision + ".", "ok"); } catch (e) { clearSchema(); toast("Cannot read the schema: " + e.message, "bad"); }
      } else clearSchema();
      rerender();
    } else renderHeader();
  } catch (e) { S.gateway = null; renderHeader(); }
  polling = false;
}

setVarsMode(varsMode);
renderProtocolChip();
$("#title").textContent = BOOT.title !== "ScorchQL" ? BOOT.title : "";
$("#endpoint").textContent = endpointUrl();
$("#copy-url").addEventListener("click", () => copy(endpointUrl(), "Endpoint URL"));
window.addEventListener("keydown", (ev) => { if ((ev.ctrlKey || ev.metaKey) && ev.key === "Enter" && view === "explorer" && document.activeElement !== op && document.activeElement !== vars) { ev.preventDefault(); run(); } });
selectTab(active);
showView(["schema", "subgraphs", "sdl"].includes(location.hash.slice(1)) ? location.hash.slice(1) : "explorer");
poll(true);
setInterval(() => poll(false), 5000);
</script>
</body>
</html>
"""
"""The explorer page, with `__SCORCHQL_TITLE__` and `__SCORCHQL_BOOT__`
in place of the title and the boot object."""
