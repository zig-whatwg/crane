// Crane WPT results: renders the record from data/*.json.
// No framework and no build step; every figure comes from the generator's shards.
"use strict";

(() => {
  const NARROW = window.matchMedia("(max-width: 52rem)");
  const RESERVED = new Set(["status", "history", "toc", "main", "suites", "chart", "gens"]);
  const SUB_PAGE = 200; // subtests drawn before "show all"
  const nf = new Intl.NumberFormat("en-US");
  const n = (x) => nf.format(x || 0);
  const $ = (sel, root = document) => root.querySelector(sel);

  const state = { suiteNo: new Map(), meta: null, suites: null, rows: new Map(), sections: new Map(), dirCache: new Map(), fileCache: new Map() };

  // ---------------------------------------------------------------- helpers
  function el(tag, attrs, ...kids) {
    const e = document.createElement(tag);
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === "class") e.className = v;
      else if (k === "text") e.textContent = v;
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v === true ? "" : v);
    }
    for (const k of kids.flat()) if (k != null && k !== false) e.append(k.nodeType ? k : document.createTextNode(String(k)));
    return e;
  }
  const svgNS = "http://www.w3.org/2000/svg";
  function svg(tag, attrs) {
    const e = document.createElementNS(svgNS, tag);
    for (const [k, v] of Object.entries(attrs || {})) e.setAttribute(k, v);
    return e;
  }
  // A path or file name with break opportunities after its separators, so a
  // narrow column wraps it at "_", "-", "." or "/" rather than mid-word.
  function breakable(text) {
    const code = document.createElement("code");
    const parts = String(text).split(/(?<=[_\-./])/);
    parts.forEach((p, i) => { if (i) code.append(document.createElement("wbr")); code.append(p); });
    return code;
  }
  function plural(x, one, many) { return `${n(x)} ${x === 1 ? one : (many || one + "s")}`; }
  const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  function parseAt(s) { // "2026-09-30T11:21:23" or "...Z"
    const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?/.exec(s || "");
    return m ? { y: +m[1], mo: +m[2], d: +m[3], key: `${m[1]}-${m[2]}-${m[3]}` } : null;
  }
  function longDate(s) { const p = parseAt(s); return p ? `${p.d} ${MONTHS[p.mo - 1]} ${p.y}` : "an unrecorded date"; }
  function shortDate(s) { const p = parseAt(s); return p ? `${p.d} ${MONTHS[p.mo - 1].slice(0, 3)}` : "?"; }
  function shortDateY(s) { const p = parseAt(s); return p ? `${p.d} ${MONTHS[p.mo - 1].slice(0, 3)} ${p.y}` : "an unrecorded date"; }
  function commitLink(sha) {
    if (!sha || sha === "?") return el("span", { class: "runs-more", text: "commit not recorded" });
    return el("a", { href: `${state.meta.links.crane}/commit/${sha}` }, el("code", { text: sha }));
  }
  function sourceUrl(path) {
    const w = state.meta.wpt;
    if (w.kind === "upstream") return `${state.meta.links.wpt_upstream}/blob/${w.revision}/${path}`;
    if (w.kind === "fork") return `${state.meta.links.wpt_fork}/blob/${w.revision}/${path}`;
    return `${state.meta.links.wpt_fork}/blob/HEAD/${path}`;
  }
  async function getJSON(url) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`${url}: ${r.status}`);
    return r.json();
  }
  function encPath(p) { return p.split("/").map(encodeURIComponent).join("/"); }
  function dirShard(dirPath) { return `data/dirs/${encPath(dirPath.slice(0, -1))}.json`; }
  function fileShard(path) { return `data/files/${encPath(path)}.json`; }
  function loadDir(dirPath) {
    if (!state.dirCache.has(dirPath)) state.dirCache.set(dirPath, getJSON(dirShard(dirPath)));
    return state.dirCache.get(dirPath);
  }
  function loadFile(path) {
    if (!state.fileCache.has(path)) state.fileCache.set(path, getJSON(fileShard(path)));
    return state.fileCache.get(path);
  }
  function sectionId(suite) { return RESERVED.has(suite) ? `suite-${suite}` : suite; }
  function selfLink(hash, label) {
    return el("a", { class: "self", href: `#${hash}`, "aria-label": `Link to ${label}`, title: "Permanent link" }, "¶");
  }
  function twisty() {
    const s = svg("svg", { class: "twisty", viewBox: "0 0 16 16", "aria-hidden": "true" });
    s.append(svg("path", { d: "M6 3.5 10.5 8 6 12.5", fill: "none", stroke: "currentColor", "stroke-width": "1.6", "stroke-linecap": "round", "stroke-linejoin": "round" }));
    return s;
  }
  const GATE_WORD = { clean: "PASS", partial: "PARTIAL", empty: "NO SUBTESTS", "none-passed": "NONE-PASSED", timeout: "TIMEOUT", error: "ERROR", crash: "CRASH", unrun: "NOT RUN" };
  const BLOCKING = new Set(["none-passed", "timeout", "error", "crash"]);
  const notPassing = (t) => t.files - t.clean - t.empty;

  function meter(t, cls) {
    const m = el("div", { class: cls, role: "img", "aria-label": `${n(t.clean)} passing every subtest, ${n(t.partial)} with some failing, ${n(t.blocking)} blocking, ${n(t.empty)} without subtests, ${n(t.unrun)} not run, of ${n(t.files)} files` });
    const parts = [["m-clean", t.clean], ["m-partial", t.partial], ["m-empty", t.empty], ["m-blocking", t.blocking], ["m-unrun", t.unrun]];
    for (const [c, v] of parts) if (v > 0) m.append(el("span", { class: c, style: `width:${(v / t.files) * 100}%` }));
    return m;
  }

  // ---------------------------------------------------------------- header
  function fill(key, ...content) {
    for (const e of document.querySelectorAll(`[data-fill="${key}"]`)) { e.replaceChildren(...content); }
  }
  function renderHeader() {
    const { meta, suites } = state;
    const g = meta.generation;
    const tot = suites.totals;
    fill("updated", `last updated ${longDate(g.at)}`);
    fill("version", `Generation ${n(g.n)}, regenerated at Crane `, commitLink(g.head), `; ${plural(tot.files, "file")} from `, el("code", { text: meta.scope.worklist }));

    const runs = Object.entries(meta.runs).sort((a, b) => b[1].files - a[1].files || (a[0] < b[0] ? -1 : 1));
    const runNodes = [];
    runs.slice(0, 2).forEach(([id, r], i) => {
      if (i > 0) runNodes.push("; ");
      runNodes.push(el("code", { text: id }), ` (${plural(r.files, "file")}, `, r.commit ? commitLink(r.commit) : "commit not in its label", ", ", el("span", { class: "nowrap", text: shortDateY(r.date) }), ")");
    });
    if (runs.length > 2) runNodes.push(el("span", { class: "runs-more", text: `; and ${plural(runs.length - 2, "more run")}, named on each file` }));
    if (!runs.length) runNodes.push("none yet");
    fill("runs", ...runNodes);

    const w = meta.wpt;
    if (w.kind === "upstream") fill("wpt", el("a", { href: `${meta.links.wpt_upstream}/tree/${w.revision}` }, el("code", { text: w.revision.slice(0, 10) })), " upstream, the commit Crane’s snapshot is based on");
    else if (w.kind === "fork") fill("wpt", el("a", { href: `${meta.links.wpt_fork}/tree/${w.revision}` }, el("code", { text: w.revision.slice(0, 10) })), " in Crane’s fork of WPT (the upstream revision it tracks is not recorded)");
    else fill("wpt", "not recorded for this generation");

    fill("n-files", n(tot.files));
    fill("n-suites", n(suites.suites.length));
    fill("n-blocking", plural(tot.blocking, "file"));
    fill("n-detail", meta.scope.detail_files ? `${n(meta.scope.detail_files)} of ${n(tot.files)} files have it in this generation` : `none has it in this generation yet, so it arrives with the next full run`);
    const enc = suites.suites.find((s) => s.name === "encoding");
    if (enc && tot.sub_reported) {
      fill("enc-share", `${Math.round((enc.totals.sub_reported / tot.sub_reported) * 100)}%`);
      fill("enc-subs", `${n(enc.totals.sub_reported)} of ${n(tot.sub_reported)}`);
      fill("enc-files", n(enc.totals.files));
    }
    fill("history-no", `${suites.suites.length + 1}`);
    const spark = drawStack(meta.history, { width: 168, height: 30, spark: true });
    fill("spark", spark, el("span", { class: "spark-text" }, `${plural(meta.history.length, "generation")} since `, el("span", { class: "nowrap", text: shortDateY(meta.history[0] && meta.history[0].at) })));
  }

  // ---------------------------------------------------------------- contents rail
  function renderToc() {
    const list = $("#toc-list");
    state.suites.suites.forEach((s, i) => {
      list.append(el("li", { class: "toc-suite" },
        el("a", { href: `#${sectionId(s.name)}`, "data-sec": sectionId(s.name) },
          el("span", { class: "secno", text: `${i + 1}` }),
          el("span", { class: "toc-name", text: s.name }),
          el("span", { class: "toc-count", "aria-label": plural(s.totals.files, "file") }, n(s.totals.files)))));
    });
    list.append(el("li", { class: "toc-back" }, el("a", { href: "#history", "data-sec": "history" },
      el("span", { class: "secno", text: `${state.suites.suites.length + 1}` }), el("span", { class: "toc-name", text: "Revision history" }))));
    $(".toc-front a").setAttribute("data-sec", "status");

    const fold = $("#toc-fold");
    const syncFold = () => { fold.open = !NARROW.matches; };
    syncFold();
    NARROW.addEventListener("change", syncFold);
    fold.querySelector("summary").addEventListener("click", (e) => { if (!NARROW.matches) e.preventDefault(); });
    list.addEventListener("click", (e) => { if (NARROW.matches && e.target.closest("a")) fold.open = false; });
  }

  // The rail follows the reading position: the current section is the last one
  // whose top has passed a third of the way down the viewport.
  function scrollSpy() {
    const links = [...document.querySelectorAll(".toc-list a[data-sec]")];
    const secs = links.map((a) => document.getElementById(a.dataset.sec));
    const where = $("#toc-where");
    let current = null, queued = false;
    const update = () => {
      queued = false;
      const line = window.innerHeight * 0.33;
      let idx = 0;
      secs.forEach((s, i) => { if (s && s.getBoundingClientRect().top <= line) idx = i; });
      if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2) idx = secs.length - 1;
      if (idx === current) return;
      current = idx;
      links.forEach((a, i) => a.setAttribute("aria-current", i === idx ? "true" : "false"));
      const a = links[idx];
      where.textContent = `${a.querySelector(".secno").textContent} ${a.querySelector(".toc-name").textContent}`.trim();
      if (!NARROW.matches) {
        const r = a.getBoundingClientRect(), toc = $("#toc").getBoundingClientRect();
        if (r.top < toc.top + 40 || r.bottom > toc.bottom - 40) a.scrollIntoView({ block: "nearest" });
      }
    };
    const queue = () => { if (!queued) { queued = true; requestAnimationFrame(update); } };
    window.addEventListener("scroll", queue, { passive: true });
    window.addEventListener("resize", queue);
    update();
  }

  // ---------------------------------------------------------------- suite sections
  function lede(s) {
    const t = s.totals;
    const bits = [];
    bits.push(`${plural(t.files, "test file")}${s.dirs ? ` in ${plural(s.dirs, "directory", "directories")}` : ""}${s.files_here && s.dirs ? `, ${n(s.files_here)} of them at the top` : ""}.`);
    const parts = [];
    if (t.clean) parts.push(`${n(t.clean)} ${t.clean === 1 ? "passes" : "pass"} every subtest`);
    if (t.partial) parts.push(`${n(t.partial)} ${t.partial === 1 ? "has" : "have"} some failing`);
    if (t.blocking) parts.push(`${n(t.blocking)} ${t.blocking === 1 ? "blocks" : "block"} the gate`);
    if (t.unrun) parts.push(`${n(t.unrun)} ${t.unrun === 1 ? "has" : "have"} not run`);
    if (parts.length) bits.push(` ${parts.length > 1 ? parts.slice(0, -1).join(", ") + " and " + parts[parts.length - 1] : parts[0]}.`.replace(/^ (\w)/, (m, c) => " " + c.toUpperCase()));
    return bits.join("");
  }

  function confBox(s) {
    const t = s.totals;
    const dl = el("dl");
    const row = (cls, key, label, value, extra) => {
      dl.append(el("div", { class: cls }, el("dt", null, el("span", { class: `key key-${key}` }), label), el("dd", null, value)));
      if (extra) dl.append(extra);
    };
    row("", "clean", "Passing every subtest", n(t.clean));
    row("", "partial", "Some subtests failing", n(t.partial));
    const kinds = [["NONE-PASSED", t.none_passed], ["TIMEOUT", t.timeout], ["ERROR", t.error], ["CRASH", t.crash]].filter((k) => k[1] > 0);
    row(t.blocking ? "blk" : "", "blocking", "Blocking", n(t.blocking),
      kinds.length ? el("p", { class: "kinds" }, ...kinds.flatMap(([k, v], i) => [i ? ", " : "", el("b", { text: n(v) }), ` ${k}`])) : null);
    if (t.empty) row("", "empty", "No subtests reported", n(t.empty));
    if (t.unrun) row("", "unrun", "Not run", n(t.unrun));
    const share = state.suites.totals.sub_reported ? t.sub_reported / state.suites.totals.sub_reported : 0;
    const subs = el("div", { class: "subs" },
      el("div", { class: "subs-figure" }, `${n(t.sub_pass)} `, el("span", { class: "box-sub", text: `of ${n(t.sub_reported)} subtests passed` })),
      el("p", { class: "subs-note", text: `Reported subtests, those of blocking files included${share >= 0.25 ? `; this suite holds ${Math.round(share * 100)}% of all of them` : ""}.` }));
    return el("aside", { class: "box conf", "aria-label": `Conformance of ${s.name}/` },
      el("div", { class: "box-head" }, el("h3", { class: "box-title", text: "Conformance" }), el("span", { class: "box-sub", text: plural(t.files, "file") })),
      el("div", { class: "conf-body" }, meter(t, "meter"), dl, subs));
  }

  function testsBox(s) {
    const tree = el("ul", { class: "tree" });
    const box = el("div", { class: "box tests" });
    const setFilter = (only) => {
      box.classList.toggle("only-failing", only);
      allBtn.setAttribute("aria-pressed", String(!only));
      failBtn.setAttribute("aria-pressed", String(only));
      applyFilter(box);
    };
    const allBtn = el("button", { class: "seg", type: "button", "aria-pressed": "true", onclick: () => setFilter(false) }, "All files");
    const failBtn = el("button", { class: "seg", type: "button", "aria-pressed": "false", onclick: () => setFilter(true) }, "Not passing");
    box.append(
      el("div", { class: "box-head" },
        el("h3", { class: "box-title", text: "Tests" }),
        el("div", { class: "tests-tools", role: "group", "aria-label": `Filter ${s.name}/ files` }, allBtn, failBtn)),
      tree);
    tree.append(el("li", { class: "loading", text: "Loading…" }));
    loadDir(s.path).then((d) => {
      fillList(tree, d);
      applyFilter(box);
    }).catch((err) => tree.replaceChildren(el("li", { class: "fetch-error", text: `Could not load ${s.path}: ${err.message}` })));
    return box;
  }

  function applyFilter(box) {
    const only = box.classList.contains("only-failing");
    for (const li of box.querySelectorAll(".row")) li.classList.toggle("is-hidden", only && li.dataset.ok === "1");
  }

  // A long list of files shows its first rows and a way to the rest, so a flat
  // suite (xhr/ keeps hundreds of files at its top) does not become the page.
  const CAP_OVER = 24, CAP_SHOW = 12;
  function fillList(ul, d) {
    const suiteNo = state.suiteNo.get(d.path);
    const dirs = d.dirs.map((x, i) => dirRow(x, suiteNo ? `${suiteNo}.${i + 1}` : null));
    const files = d.files.map(fileRow);
    ul.replaceChildren(...dirs, ...files);
    if (files.length > CAP_OVER) {
      files.forEach((li, i) => { if (i >= CAP_SHOW) li.classList.add("capped"); });
      ul.dataset.capped = "1";
      const where = d.path;
      ul.append(el("li", { class: "more" }, el("button", { class: "seg", type: "button", onclick: () => uncap(ul) },
        `Show all ${n(files.length)} files in ${where}`)));
    }
  }
  function uncap(ul) {
    if (ul.dataset.capped !== "1") return;
    ul.dataset.capped = "0";
    const more = ul.querySelector(":scope > .more");
    if (more) more.remove();
    for (const li of ul.querySelectorAll(":scope > .capped")) li.classList.remove("capped");
  }

  function dirRow(dir, secno) {
    const t = dir.totals;
    const fold = el("div", { class: "fold" }, el("div", { class: "fold-in" }));
    const id = `r-${state.rows.size}`;
    const btn = el("button", { class: "toggle", type: "button", "aria-expanded": "false", "aria-controls": id }, twisty(), secno ? el("span", { class: "dir-no", text: secno }) : null, breakable(`${dir.name}/`));
    const tally = el("span", { class: "tally" },
      el("span", { text: plural(t.files, "file") }),
      t.blocking ? el("span", { class: "blk", text: `${n(t.blocking)} blocking` }) : null,
      miniMeter(t));
    const li = el("li", { class: "row row-dir", "data-path": dir.path, "data-ok": notPassing(t) === 0 ? "1" : "0" },
      el("div", { class: "row-line" }, btn, tally, selfLink(dir.path, `${dir.path}`)), fold);
    fold.firstChild.id = id;
    let loaded = null;
    const open = async (want = true) => {
      if (want && !loaded) {
        const ul = el("ul", null, el("li", { class: "loading", text: "Loading…" }));
        fold.firstChild.replaceChildren(ul);
        loaded = loadDir(dir.path).then((d) => { fillList(ul, d); applyFilter(li.closest(".tests")); })
          .catch((err) => { ul.replaceChildren(el("li", { class: "fetch-error", text: `Could not load ${dir.path}: ${err.message}` })); loaded = null; });
      }
      btn.setAttribute("aria-expanded", String(want));
      fold.classList.toggle("open", want);
      if (want) await loaded;
    };
    btn.addEventListener("click", () => open(btn.getAttribute("aria-expanded") !== "true"));
    state.rows.set(dir.path, { li, open });
    return li;
  }

  function miniMeter(t) {
    const m = el("span", { class: "mini", "aria-hidden": "true" });
    for (const [c, v] of [["m-clean", t.clean], ["m-partial", t.partial], ["m-empty", t.empty], ["m-blocking", t.blocking], ["m-unrun", t.unrun]])
      if (v > 0) m.append(el("span", { class: c, style: `width:${(v / t.files) * 100}%` }));
    return m;
  }

  function fileRow(f) {
    const c = f.counts;
    const reported = c.pass + c.fail + c.timeout + c.notrun;
    const fold = el("div", { class: "fold" }, el("div", { class: "fold-in" }));
    const id = `r-${state.rows.size}`;
    const btn = el("button", { class: "toggle", type: "button", "aria-expanded": "false", "aria-controls": id }, twisty(), breakable(f.name));
    const blocking = BLOCKING.has(f.gate);
    const stat = el("span", { class: "tally fstat" },
      el("span", { class: "fcount" }, reported ? [el("b", { text: n(c.pass) }), ` / ${n(reported)}`] : ""),
      el("span", { class: `gate gate-${f.gate}${blocking ? " g-block" : ""}`, text: GATE_WORD[f.gate] || f.gate.toUpperCase() }));
    const li = el("li", { class: "row row-file", "data-path": f.path, "data-ok": f.gate === "clean" || f.gate === "empty" ? "1" : "0" },
      el("div", { class: "row-line" }, btn, stat, selfLink(f.path, f.path)), fold);
    fold.firstChild.id = id;
    let loaded = null;
    const open = async (want = true) => {
      if (want && !loaded) loaded = renderDetail(f, fold.firstChild);
      btn.setAttribute("aria-expanded", String(want));
      fold.classList.toggle("open", want);
      if (want) await loaded;
    };
    btn.addEventListener("click", () => open(btn.getAttribute("aria-expanded") !== "true"));
    state.rows.set(f.path, { li, open, file: f });
    return li;
  }

  function runLine(f) {
    const r = f.run ? state.meta.runs[f.run] : null;
    const bits = [];
    if (r) bits.push(el("span", null, "Run ", el("code", { text: f.run }), `, ${shortDateY(r.date)}`, r.commit ? [", Crane ", commitLink(r.commit)] : ""));
    else bits.push(el("span", { text: "Not run yet" }));
    bits.push(el("a", { href: sourceUrl(f.path) }, "Test source"));
    return el("p", { class: "detail-meta" }, ...bits);
  }

  async function renderDetail(f, into) {
    const box = el("div", { class: "detail" }, runLine(f));
    into.replaceChildren(box);
    if (f.message) box.append(el("p", { class: "harness" }, el("strong", { text: "Harness: " }), el("code", { text: f.message })));
    if (!f.detail) {
      const c = f.counts;
      const reported = c.pass + c.fail + c.timeout + c.notrun;
      const counts = reported ? `${n(c.pass)} passed, ${n(c.fail)} failed, ${n(c.timeout)} timed out and ${n(c.notrun)} did not run` : "no subtests";
      box.append(el("p", { class: "no-detail" }, el("strong", { text: "Subtest detail arrives with the next full run. " }),
        f.gate === "unrun" ? "This file has no result yet." : `This file’s latest run recorded counts only: ${counts}.`));
      return;
    }
    const wait = el("p", { class: "loading", text: "Loading subtests…" });
    box.append(wait);
    let d;
    try { d = await loadFile(f.path); } catch (err) { wait.replaceWith(el("p", { class: "fetch-error", text: `Could not load the subtests: ${err.message}` })); state.fileCache.delete(f.path); return; }
    wait.remove();
    const multi = d.runs.length > 1;
    for (const run of d.runs) {
      const sec = el("div", { class: "run", "data-test": run.test });
      const k = run.counts;
      if (multi) sec.append(el("p", { class: "run-head" }, el("code", { text: run.test }),
        el("span", { class: `gate${run.status === "OK" ? "" : " g-block"}`, text: run.status }),
        el("span", { class: "fcount" }, el("b", { text: n(k.pass) }), ` / ${n(k.total)}`)));
      else if (run.status !== "OK") sec.append(el("p", { class: "run-head" }, el("span", { class: "gate g-block", text: run.status })));
      if (run.message) sec.append(el("p", { class: "harness" }, el("code", { text: run.message })));
      const ol = el("ol", { class: "subtests" });
      sec.append(ol);
      const draw = (from, to) => { for (const s of run.subtests.slice(from, to)) ol.append(subRow(f, run, s, multi)); };
      draw(0, SUB_PAGE);
      if (run.subtests.length > SUB_PAGE) {
        const more = el("button", { class: "seg", type: "button", onclick: () => { draw(SUB_PAGE, run.subtests.length); more.remove(); } }, `Show all ${n(run.subtests.length)} subtests`);
        sec.append(el("p", { class: "omitted" }, more));
        sec._drawAll = () => { if (more.isConnected) more.click(); };
      }
      if (run.passing_omitted) sec.append(el("p", { class: "omitted", text: `${n(run.passing_omitted)} passing subtests are not listed: this file has more than ${n(d.detail_limit)} subtests, so only those that did not pass are kept.` }));
      if (!run.subtests.length && !run.passing_omitted) sec.append(el("p", { class: "omitted", text: "No subtests were reported." }));
      box.append(sec);
    }
  }

  const MARK = { PASS: "PASS", FAIL: "FAIL", TIMEOUT: "TIMEOUT", NOTRUN: "NOT RUN", PRECONDITION_FAILED: "PRECOND." };
  function subHash(f, run, s, multi) {
    return `${f.path}?sub=${encodeURIComponent(s.name)}${multi ? `&run=${encodeURIComponent(run.test)}` : ""}`;
  }
  function subRow(f, run, s, multi) {
    const cls = { PASS: "s-pass", FAIL: "s-fail", TIMEOUT: "s-timeout", NOTRUN: "s-notrun" }[s.status] || "s-other";
    const li = el("li", { class: `sub ${cls}`, "data-name": s.name },
      el("span", { class: "mark", text: MARK[s.status] || s.status }),
      el("span", { class: "sub-name", text: s.name }),
      selfLink(subHash(f, run, s, multi), `subtest ${s.name}`));
    if (s.message) li.append(el("pre", { class: "msg", text: s.message }));
    return li;
  }

  function renderSuites() {
    const host = $("#suites");
    host.replaceChildren();
    state.suites.suites.forEach((s, i) => {
      state.suiteNo.set(s.path, i + 1);
      const id = sectionId(s.name);
      const sec = el("section", { class: "suite", id, "aria-labelledby": `${id}-h` },
        el("h2", { id: `${id}-h` }, el("span", { class: "secno", text: `${i + 1}` }), breakable(`${s.name}/`), selfLink(id, `section ${i + 1}, ${s.name}`)),
        el("p", { class: "suite-lede", text: lede(s) }),
        el("div", { class: "boxes" }, confBox(s), testsBox(s)));
      host.append(sec);
      state.sections.set(s.name, sec);
    });
  }

  // ---------------------------------------------------------------- routing
  function parseHash(raw) {
    let h = raw.replace(/^#/, "");
    if (!h) return null;
    let q = "";
    const qi = h.indexOf("?");
    if (qi >= 0) { q = h.slice(qi + 1); h = h.slice(0, qi); }
    let path;
    try { path = decodeURIComponent(h); } catch { path = h; }
    const params = new URLSearchParams(q);
    return { path, sub: params.get("sub"), run: params.get("run") };
  }

  function mark(target) {
    target.classList.remove("targeted");
    void target.offsetWidth;
    target.classList.add("targeted");
  }

  async function route(raw) {
    const r = parseHash(raw);
    if (!r) return;
    if (r.path === "status" || r.path === "history") { document.getElementById(r.path).scrollIntoView(); return; }
    const suite = r.path.split("/")[0];
    const sec = state.sections.get(suite) || state.sections.get(suite.replace(/^suite-/, ""));
    if (!sec) return;
    if (!r.path.includes("/")) { sec.scrollIntoView(); return; }
    const segs = r.path.split("/");
    const isDir = r.path.endsWith("/");
    // Every directory from the suite down to the target (the target too, when it is one).
    const chain = [];
    for (let i = 2; i < segs.length; i++) chain.push(segs.slice(0, i).join("/") + "/");
    await loadDir(`${suite}/`);
    await new Promise((res) => requestAnimationFrame(res));
    for (const dp of chain) {
      const row = state.rows.get(dp);
      if (!row) return;
      await row.open(true);
    }
    const row = state.rows.get(r.path);
    if (!row) { sec.scrollIntoView(); return; }
    if (row.li.classList.contains("capped")) uncap(row.li.parentElement);
    if (!isDir) await row.open(true);
    let target = row.li;
    if (r.sub != null) {
      const runs = [...row.li.querySelectorAll(".run")];
      const run = r.run ? runs.find((x) => x.dataset.test === r.run) : runs[0];
      if (run && run._drawAll) run._drawAll();
      const hit = run && [...run.querySelectorAll(".sub")].find((x) => x.dataset.name === r.sub);
      if (hit) target = hit;
    }
    requestAnimationFrame(() => {
      const t = target === row.li ? row.li.querySelector(".row-line") : target;
      t.scrollIntoView({ block: "start" });
      mark(target);
      const focusable = target === row.li ? row.li.querySelector(".toggle") : target.querySelector(".self");
      if (focusable) focusable.focus({ preventScroll: true });
    });
  }

  // ---------------------------------------------------------------- history chart
  // Stacked bands of files by standing, one x step per generation.
  const BANDS = [
    ["clean", (g) => g.clean, "var(--pass)"],
    ["partial", (g) => g.partial, "var(--pass-2)"],
    ["blocking", (g) => g.blocking, "var(--issue)"],
    ["unrun", (g) => g.unrun, "var(--unrun)"],
  ];
  function drawStack(gens, { width, height, spark }) {
    const pad = spark ? { l: 0, r: 0, t: 1, b: 0 } : { l: 44, r: 8, t: 20, b: 26 };
    const W = width, H = height;
    const s = svg("svg", { width: W, height: H, viewBox: `0 0 ${W} ${H}`, role: "img", "aria-label": historySummary(gens) });
    if (!gens.length) return s;
    const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;
    const x = (i) => pad.l + (gens.length === 1 ? iw / 2 : (i / (gens.length - 1)) * iw);
    const maxT = Math.max(...gens.map((g) => g.total || (g.clean + g.partial + g.blocking + g.unrun)));
    const y = (v) => pad.t + ih - (v / maxT) * ih;
    const cum = gens.map(() => 0);
    for (const [, get, color] of BANDS) {
      const lo = cum.slice();
      gens.forEach((g, i) => { cum[i] += get(g) || 0; });
      let d = "";
      gens.forEach((g, i) => { d += `${i ? "L" : "M"}${x(i).toFixed(2)},${y(cum[i]).toFixed(2)}`; });
      for (let i = gens.length - 1; i >= 0; i--) d += `L${x(i).toFixed(2)},${y(lo[i]).toFixed(2)}`;
      s.append(svg("path", { d: d + "Z", fill: color, stroke: "none" }));
    }
    if (spark) return s;

    // axes: file counts at left, days along the bottom
    s.append(svg("line", { class: "axis", x1: pad.l, x2: W - pad.r, y1: pad.t + ih + 0.5, y2: pad.t + ih + 0.5 }));
    for (const v of niceTicks(maxT)) {
      const yy = y(v);
      const t = svg("text", { x: pad.l - 6, y: yy + 3.5, "text-anchor": "end" });
      t.textContent = n(v);
      s.append(t, svg("line", { class: "axis", x1: pad.l - 3, x2: pad.l, y1: yy, y2: yy }));
    }
    let lastX = -Infinity, lastDay = "";
    gens.forEach((g, i) => {
      const p = parseAt(g.at);
      if (!p || p.key === lastDay) return;
      lastDay = p.key;
      const xx = x(i);
      s.append(svg("line", { class: "axis", x1: xx, x2: xx, y1: pad.t + ih, y2: pad.t + ih + 4 }));
      if (xx - lastX < 46) return;
      lastX = xx;
      const t = svg("text", { x: xx, y: H - 8, "text-anchor": i === 0 ? "start" : "middle" });
      t.textContent = shortDate(g.at);
      s.append(t);
    });
    // the two changes of rule
    const live = gens.findIndex((g) => !g.reconstructed);
    const rule2 = gens.findIndex((g) => g.gate_rule === 2);
    const note = (i, label, anchor) => {
      if (i <= 0) return;
      const xx = (x(i - 1) + x(i)) / 2;
      s.append(svg("line", { class: "mark-line", x1: xx, x2: xx, y1: pad.t - 4, y2: pad.t + ih }));
      const t = svg("text", { x: xx + (anchor === "end" ? -4 : 4), y: pad.t - 8, "text-anchor": anchor });
      t.textContent = label;
      s.append(t);
    };
    note(live, "live history begins", "start");
    note(rule2, "NONE-PASSED blocks", "end");
    return s;
  }
  function niceTicks(max) {
    const step = [500, 1000, 2000, 5000, 10000, 20000, 50000].find((s) => max / s <= 5) || Math.ceil(max / 5);
    const out = [];
    for (let v = 0; v <= max; v += step) out.push(v);
    return out;
  }
  function historySummary(gens) {
    if (!gens.length) return "No history yet";
    const a = gens[0], b = gens[gens.length - 1];
    return `Files by standing over ${gens.length} generations, ${longDate(a.at)} to ${longDate(b.at)}: blocking went from ${n(a.blocking)} to ${n(b.blocking)}, and files passing every subtest from ${n(a.clean)} to ${n(b.clean)}. The table below lists every generation.`;
  }

  function renderHistory() {
    const gens = state.meta.history;
    const plot = $("#chart-plot");
    const readout = $("#readout");
    let cursor = gens.length - 1;
    const describe = (i) => {
      const g = gens[i];
      readout.replaceChildren(el("b", { text: `Generation ${g.n}` }), `, ${longDate(g.at)}${g.head && g.head !== "?" ? `, Crane ${g.head}` : ""}${g.reconstructed ? " (reconstructed)" : ""}: `,
        `${n(g.clean)} passing every subtest, ${n(g.partial)} with some failing, `, el("span", { class: "st-issue", text: `${n(g.blocking)} blocking` }), g.unrun ? `, ${n(g.unrun)} not run` : "", ` of ${n(g.total)}.`);
    };
    let geom = null;
    const draw = () => {
      const w = Math.max(280, Math.floor(plot.clientWidth));
      const h = Math.round(Math.min(300, Math.max(190, w * 0.34)));
      const chart = drawStack(gens, { width: w, height: h, spark: false });
      chart.setAttribute("tabindex", "0");
      chart.setAttribute("aria-describedby", "readout");
      const line = svg("line", { class: "cursor", y1: 20, y2: h - 26 });
      chart.append(line);
      geom = { w, h, l: 44, r: 8 };
      const place = (i) => {
        cursor = Math.max(0, Math.min(gens.length - 1, i));
        const iw = geom.w - geom.l - geom.r;
        const xx = geom.l + (gens.length === 1 ? iw / 2 : (cursor / (gens.length - 1)) * iw);
        line.setAttribute("x1", xx); line.setAttribute("x2", xx);
        describe(cursor);
      };
      chart.addEventListener("pointermove", (e) => {
        const r = chart.getBoundingClientRect();
        const iw = geom.w - geom.l - geom.r;
        place(Math.round(((e.clientX - r.left - geom.l) / iw) * (gens.length - 1)));
      });
      chart.addEventListener("keydown", (e) => {
        const step = { ArrowLeft: -1, ArrowRight: 1, Home: -Infinity, End: Infinity }[e.key];
        if (step === undefined) return;
        e.preventDefault();
        place(step === -Infinity ? 0 : step === Infinity ? gens.length - 1 : cursor + step);
      });
      plot.replaceChildren(chart);
      place(cursor);
    };
    draw();
    let rq = 0;
    new ResizeObserver(() => { cancelAnimationFrame(rq); rq = requestAnimationFrame(draw); }).observe(plot);

    const live = gens.find((g) => !g.reconstructed);
    const firstLive = gens.findIndex((g) => !g.reconstructed);
    fill("recon", firstLive > 0 ? `Generations 1 to ${gens[firstLive - 1].n}` : "No generation");
    const r2 = gens.find((g) => g.gate_rule === 2);
    if (r2) fill("rule2", String(r2.n));
    const last = gens[gens.length - 1], tot = state.suites.totals;
    if (last && (last.total !== tot.files || last.blocking !== tot.blocking)) {
      fill("reconcile", ` The latest generation, ${last.n}, was recorded against ${plural(last.total, "worklist file")} with ${n(last.blocking)} blocking; the sections above read the current worklist of ${n(tot.files)} files (${n(tot.files - tot.unrun)} run, ${n(tot.blocking)} blocking), and the two agree again when the progress report next records a generation.`);
    }
    void live;

    const table = el("table", null,
      el("thead", null, el("tr", null, ...["Gen.", "Date", "Crane", "Passing every subtest", "Some failing", "Blocking", "NONE-PASSED", "TIMEOUT", "ERROR", "CRASH", "Not run"].map((h) => el("th", { scope: "col", text: h })))),
      el("tbody", null, ...gens.slice().reverse().map((g) => el("tr", { class: g.reconstructed ? "recon" : null },
        el("td", { text: `${g.n}` }), el("td", { text: shortDateY(g.at) }), el("td", null, g.head && g.head !== "?" ? el("code", { text: g.head }) : "reconstructed"),
        el("td", { text: n(g.clean) }), el("td", { text: n(g.partial) }), el("td", { class: "blk", text: n(g.blocking) }),
        el("td", { text: g.none_passed == null ? "—" : n(g.none_passed) }), el("td", { text: n(g.timeout) }), el("td", { text: n(g.error) }), el("td", { text: n(g.crash) }), el("td", { text: n(g.unrun) })))));
    $("#gens-table").replaceChildren(table);
  }

  // ---------------------------------------------------------------- boot
  async function boot() {
    try {
      [state.meta, state.suites] = await Promise.all([getJSON("data/meta.json"), getJSON("data/suites.json")]);
    } catch (err) {
      $("#loading").textContent = `The results could not be loaded (${err.message}).`;
      return;
    }
    renderHeader();
    renderToc();
    renderSuites();
    renderHistory();
    scrollSpy();
    window.addEventListener("hashchange", () => route(location.hash));
    if (location.hash) route(location.hash);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();
})();
