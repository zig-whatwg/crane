/* Crane WPT results: the enhancement layer.

   Every page is complete without this file: its numbers, tables, subtests and
   messages are in the markup tools/wpt_site/generate.zig writes. This script
   reads that markup - and, for the search, paths.json - and adds what only
   script can:

     the history chart     WPT subtests over every generation, interactive,
                           redrawn from the generations table's rows
     the tables            sort by any column; on a directory page, filter by
                           name and by standing, with the view kept in the URL
     the search            any directory or test file, from every page ("/")
     the subtests          filter a test file's subtests by result and name,
                           open or close every message, open a linked one
     the rail              follows the section being read on the index
     old links             the first site's #path links land on their pages

   Red is failure and grey is blocking, in the markup and here. */
(() => {
  "use strict";

  const script = document.currentScript;
  const ROOT = new URL(".", script ? script.src : location.href).href;
  const nf = new Intl.NumberFormat("en-US");
  const compact = new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 });
  const fmt = (v) => nf.format(v);
  const signed = (v) => (v > 0 ? "+" : v < 0 ? "−" : "±") + nf.format(Math.abs(v));
  const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const SVG = "http://www.w3.org/2000/svg";

  function el(tag, attrs, ...kids) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === "text") e.textContent = v;
      else if (k === "class") e.className = v;
      else e.setAttribute(k, v === true ? "" : v);
    }
    for (const k of kids) if (k != null) e.append(k);
    return e;
  }
  function sv(tag, attrs) {
    const e = document.createElementNS(SVG, tag);
    for (const [k, v] of Object.entries(attrs || {})) if (v != null) e.setAttribute(k, v);
    return e;
  }
  /** The generator's own dates, as it recorded them: "2026-09-30T18:19:32". */
  function parseAt(at) {
    const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?/.exec(at || "");
    return m ? { y: +m[1], mo: +m[2], d: +m[3], h: m[4], mi: m[5], t: Date.UTC(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0)) } : null;
  }
  function when(at) {
    const p = parseAt(at);
    return p ? `${p.d} ${MONTHS[p.mo - 1]} ${p.y}${p.h ? `, ${p.h}:${p.mi}` : ""}` : "an unrecorded date";
  }
  function shortDay(at) {
    const p = parseAt(at);
    return p ? `${p.d} ${MONTHS[p.mo - 1]}` : "";
  }
  /** A site path ("dom/nodes/", "dom/x.html") as the URL of its page. */
  function pageUrl(p) {
    return ROOT + p.split("/").map(encodeURIComponent).join("/") + (p.endsWith("/") ? "" : "/");
  }
  function params() { return new URLSearchParams(location.search); }
  function setParams(update) {
    const q = params();
    for (const [k, v] of Object.entries(update)) {
      if (v == null || v === "") q.delete(k); else q.set(k, v);
    }
    const s = q.toString();
    history.replaceState(history.state, "", `${location.pathname}${s ? `?${s}` : ""}${location.hash}`);
  }
  function niceStep(span, ticks) {
    const raw = Math.max(span / ticks, 1);
    const mag = Math.pow(10, Math.floor(Math.log10(raw)));
    for (const k of [1, 2, 2.5, 5, 10]) if (raw <= k * mag) return k * mag;
    return 10 * mag;
  }
  function typing(e) {
    const t = e.target;
    return t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName));
  }

  // ==========================================================================
  // The history chart: WPT subtests passing and not passing, up to the total.
  // ==========================================================================

  function historyChart() {
    const fig = document.getElementById("chart");
    const tbody = document.querySelector("#gens tbody");
    if (!fig || !tbody) return;
    const num = (d, k) => (d[k] == null ? null : Number(d[k]));
    const all = [...tbody.rows].reverse().map((r) => {
      const d = r.dataset;
      return {
        n: num(d, "n"), at: d.at, head: d.head || null, pass: num(d, "pass"), total: num(d, "total"),
        fail: num(d, "fail"), timeout: num(d, "timeout"), notrun: num(d, "notrun"), est: d.est === "1",
        blocking: num(d, "blocking"), files: num(d, "files"), recon: d.recon === "1", event: d.event || null,
      };
    }).filter((g) => Number.isFinite(g.pass) && Number.isFinite(g.total));
    if (all.length < 2) return;

    // The ranges worth offering: the whole history, and the recent past, where
    // the day's progress is too small to see at the whole history's scale.
    const lastT = parseAt(all[all.length - 1].at)?.t ?? 0;
    const since = (ms) => all.filter((g) => (parseAt(g.at)?.t ?? 0) >= lastT - ms);
    const ranges = [{ key: "all", label: "All generations", gens: all }];
    for (const [key, label, ms] of [["7d", "Last 7 days", 7 * 864e5], ["24h", "Last 24 hours", 864e5]]) {
      const gens = since(ms);
      if (gens.length >= 3 && gens.length < ranges[ranges.length - 1].gens.length) ranges.push({ key, label, gens });
    }
    let range = ranges.find((r) => r.key === params().get("range")) || ranges[0];

    const readout = el("div", { class: "readout", "aria-live": "polite" });
    const rangeBar = el("div", { class: "range", role: "group", "aria-label": "Generations shown" });
    const plot = el("div", { class: "chart-plot", tabindex: "0", role: "slider", "aria-label": "Generation" });
    for (const r of ranges) {
      const b = el("button", { type: "button", "aria-pressed": String(r === range), text: r.label });
      b.addEventListener("click", () => {
        range = r;
        for (const x of rangeBar.children) x.setAttribute("aria-pressed", String(x === b));
        setParams({ range: r.key === "all" ? null : r.key });
        pinned = range.gens.length - 1;
        draw();
      });
      rangeBar.append(b);
    }
    for (const old of fig.querySelectorAll(".chart-svg")) old.remove();
    fig.classList.add("chart-live");
    fig.prepend(el("div", { class: "chart-bar" }, readout, ranges.length > 1 ? rangeBar : null), plot);

    let pinned = range.gens.length - 1;
    let shown = pinned;
    let geo = null;

    function describe(i) {
      const gens = range.gens;
      const g = gens[i];
      const prev = all[all.indexOf(g) - 1];
      readout.replaceChildren(
        el("p", { class: "ro-figure" },
          el("b", { text: fmt(g.pass) }), el("span", { class: "ro-of", text: ` / ${g.est ? "about " : ""}${fmt(g.total)}` }),
          el("span", { class: "ro-label", text: "WPT subtests passing" })),
        el("p", { class: "ro-meta" },
          `Generation ${g.n} · ${when(g.at)}`,
          g.head ? " · Crane " : g.recon ? " · reconstructed" : null,
          g.head ? el("a", { href: `https://github.com/zig-whatwg/crane/commit/${g.head}` }, el("code", { text: g.head })) : null),
        el("p", { class: "ro-detail" }, ...detail(g, prev)));
      plot.setAttribute("aria-valuenow", String(g.n));
      plot.setAttribute("aria-valuetext", `Generation ${g.n}, ${when(g.at)}: ${fmt(g.pass)} of ${g.est ? "about " : ""}${fmt(g.total)} WPT subtests passing`);
    }
    function detail(g, prev) {
      const out = [];
      const sep = () => out.length && out.push(" · ");
      if (prev) {
        out.push(el("span", { class: g.pass - prev.pass < 0 ? "fail" : null, text: `${signed(g.pass - prev.pass)} passing` }),
          `, ${signed(g.total - prev.total)} in total since generation ${prev.n}`);
      } else out.push("The first generation");
      if (g.fail != null) {
        sep();
        out.push(el("span", { class: g.fail ? "fail" : null, text: `${fmt(g.fail)} failed` }), `, ${fmt(g.timeout)} timed out, ${fmt(g.notrun)} not run`);
      } else {
        sep();
        out.push(el("span", { class: "fail", text: `${fmt(g.total - g.pass)} not passing` }));
      }
      if (g.blocking != null) { sep(); out.push(el("span", { class: "blk", text: `${fmt(g.blocking)} blocking files` }), ` of ${fmt(g.files)}`); }
      if (g.event) { sep(); out.push(el("span", { class: "ro-event", text: `measurement changed: ${g.event}` })); }
      if (g.est) { sep(); out.push(el("span", { class: "quiet", text: "total estimated by the progress report" })); }
      return out;
    }

    function draw() {
      const gens = range.gens;
      const W = Math.max(280, Math.round(plot.clientWidth || fig.clientWidth));
      const narrow = W < 560;
      const H = narrow ? 260 : 330;
      const pad = { l: narrow ? 44 : 70, r: 12, t: 0, b: 28 };
      const iw = W - pad.l - pad.r;
      const x = (i) => (gens.length === 1 ? pad.l + iw / 2 : pad.l + (i / (gens.length - 1)) * iw);
      // Changes of measurement: their labels are laid out first, in as many
      // rows as they need so none overlaps another, and the plot starts below them.
      const live = gens.findIndex((g) => !g.recon);
      const marks = [];
      if (live > 0) marks.push({ i: live, label: "live history begins" });
      gens.forEach((g, i) => { if (i > 0 && g.event) marks.push({ i, label: g.event }); });
      const placed = [];
      for (const m of marks) {
        m.x = (x(m.i - 1) + x(m.i)) / 2;
        const wEst = m.label.length * 5.7 + 6;
        m.right = m.x + 4 + wEst < W - pad.r;
        const box = m.right ? [m.x + 4, m.x + 4 + wEst] : [m.x - 4 - wEst, m.x - 4];
        m.row = 0;
        while (placed.some((p) => p.row === m.row && p.box[0] < box[1] + 6 && box[0] < p.box[1] + 6)) m.row++;
        placed.push({ row: m.row, box });
      }
      const rows = marks.length ? Math.max(...marks.map((m) => m.row)) + 1 : 0;
      pad.t = 14 + rows * 13;
      const ih = H - pad.t - pad.b;
      const tick = narrow ? (v) => compact.format(v) : fmt;
      const zero = range.key === "all";
      const maxV = Math.max(...gens.map((g) => g.total));
      const minV = zero ? 0 : Math.min(...gens.map((g) => g.pass));
      const step = niceStep(maxV - minV || maxV, narrow ? 4 : 5);
      const lo = zero ? 0 : Math.max(0, Math.floor(minV / step) * step);
      const hi = Math.max(lo + step, Math.ceil(maxV / step) * step);
      const y = (v) => pad.t + ih - ((v - lo) / (hi - lo)) * ih;
      const line = (f) => gens.map((g, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(f(g)).toFixed(1)}`).join("");
      const back = (f) => gens.map((g, i) => [i, g]).reverse().map(([i, g]) => `L${x(i).toFixed(1)},${y(f(g)).toFixed(1)}`).join("");
      const base = y(lo).toFixed(1);

      const s = sv("svg", { class: "chart-js", viewBox: `0 0 ${W} ${H}`, width: W, height: H, role: "img",
        "aria-label": `WPT subtests passing over ${gens.length} generations, ${when(gens[0].at)} to ${when(gens[gens.length - 1].at)}: from ${fmt(gens[0].pass)} to ${fmt(gens[gens.length - 1].pass)}.` });
      // Grid and subtest ticks.
      for (let v = lo; v <= hi + 0.5; v += step) {
        const yy = y(v).toFixed(1);
        s.append(sv("line", { class: v === lo ? "axis" : "grid", x1: pad.l, x2: W - pad.r, y1: yy, y2: yy }));
        const t = sv("text", { x: pad.l - 8, y: +yy + 3.5, "text-anchor": "end" });
        t.textContent = tick(v);
        s.append(t);
      }
      // Reconstructed generations, shaded.
      if (live > 0) {
        const edge = (x(live - 1) + x(live)) / 2;
        s.append(sv("rect", { class: "recon-zone", x: pad.l, y: pad.t, width: (edge - pad.l).toFixed(1), height: ih }));
      }
      // Passing from the axis; not passing from passing up to the total.
      s.append(sv("path", { class: "band-pass", d: `${line((g) => g.pass)}L${x(gens.length - 1).toFixed(1)},${base}L${x(0).toFixed(1)},${base}Z` }));
      s.append(sv("path", { class: "band-fail", d: `${line((g) => g.total)}${back((g) => g.pass)}Z` }));
      s.append(sv("path", { class: "line-pass", d: line((g) => g.pass) }));
      s.append(sv("path", { class: "line-total", d: line((g) => g.total) }));
      // Days along the bottom.
      let lastX = -1e9, lastDay = "";
      gens.forEach((g, i) => {
        const day = (g.at || "").slice(0, 10);
        if (day === lastDay) return;
        lastDay = day;
        const xx = x(i);
        s.append(sv("line", { class: "axis", x1: xx.toFixed(1), x2: xx.toFixed(1), y1: pad.t + ih, y2: pad.t + ih + 4 }));
        if (xx - lastX < (narrow ? 40 : 48) || xx > W - pad.r - 16) return;
        lastX = xx;
        const t = sv("text", { x: xx.toFixed(1), y: H - 8, "text-anchor": i === 0 ? "start" : "middle" });
        t.textContent = shortDay(g.at);
        s.append(t);
      });
      // The marks, each label on its row above the plot.
      for (const m of marks) {
        const ly = 10 + m.row * 13;
        s.append(sv("line", { class: "mark-line", x1: m.x.toFixed(1), x2: m.x.toFixed(1), y1: ly - 8, y2: pad.t + ih }));
        const t = sv("text", { class: "mark-label", x: (m.right ? m.x + 4 : m.x - 4).toFixed(1), y: ly, "text-anchor": m.right ? "start" : "end" });
        t.textContent = m.label;
        s.append(t);
      }
      // The crosshair on the generation shown.
      const cross = sv("g", { class: "cross" });
      const cl = sv("line", { y1: pad.t, y2: pad.t + ih });
      const cp = sv("circle", { class: "dot-pass", r: 4 });
      const ct = sv("circle", { class: "dot-total", r: 3.5 });
      cross.append(cl, cp, ct);
      s.append(cross);
      plot.replaceChildren(s);
      geo = { x, y, pad, iw, W, cl, cp, ct, n: gens.length };
      plot.setAttribute("aria-valuemin", String(gens[0].n));
      plot.setAttribute("aria-valuemax", String(gens[gens.length - 1].n));
      show(Math.min(shown, gens.length - 1));
    }

    function show(i) {
      const gens = range.gens;
      shown = Math.max(0, Math.min(gens.length - 1, i));
      if (!geo) return;
      const g = gens[shown];
      const xx = geo.x(shown).toFixed(1);
      geo.cl.setAttribute("x1", xx); geo.cl.setAttribute("x2", xx);
      geo.cp.setAttribute("cx", xx); geo.cp.setAttribute("cy", geo.y(g.pass).toFixed(1));
      geo.ct.setAttribute("cx", xx); geo.ct.setAttribute("cy", geo.y(g.total).toFixed(1));
      describe(shown);
    }
    function indexAt(clientX) {
      const r = plot.getBoundingClientRect();
      const px = ((clientX - r.left) / r.width) * geo.W;
      return Math.round(((px - geo.pad.l) / geo.iw) * (geo.n - 1));
    }

    plot.addEventListener("pointermove", (e) => { if (geo) show(indexAt(e.clientX)); });
    plot.addEventListener("pointerdown", (e) => { if (geo) { pinned = Math.max(0, Math.min(geo.n - 1, indexAt(e.clientX))); show(pinned); } });
    plot.addEventListener("pointerleave", (e) => { if (e.pointerType !== "touch") show(pinned); });
    plot.addEventListener("keydown", (e) => {
      const n = range.gens.length;
      const to = { ArrowLeft: shown - 1, ArrowDown: shown - 1, ArrowRight: shown + 1, ArrowUp: shown + 1, Home: 0, End: n - 1, PageUp: shown + 10, PageDown: shown - 10 }[e.key];
      if (to == null) return;
      e.preventDefault();
      pinned = Math.max(0, Math.min(n - 1, to));
      show(pinned);
    });

    let queued = false;
    new ResizeObserver(() => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => { queued = false; draw(); });
    }).observe(fig);
    draw();
  }

  // ==========================================================================
  // Tables: sort by any column.
  // ==========================================================================

  // Most severe first. Blocking standings, then not run, then the rest.
  const SEVERITY = { crash: 7, error: 6, timeout: 5, "none-passed": 4, unrun: 3, partial: 2, empty: 1, clean: 0 };

  function sortKey(table, row, col) {
    const cell = row.cells[col];
    if (!cell) return null;
    if (col === 0) return cell.textContent.trim().toLowerCase();
    if (table.classList.contains("listing-files") && col === row.cells.length - 1) return SEVERITY[row.dataset.gate] ?? null;
    if (cell.dataset.of != null) return +cell.dataset.of === 0 ? null : +cell.dataset.v / +cell.dataset.of;
    return cell.dataset.v == null ? null : +cell.dataset.v;
  }
  // The direction a column sorts in first: names A to Z, the share passing
  // lowest first, every other count highest first - failures surface first.
  function firstDir(table, col) {
    if (col === 0) return "ascending";
    const cell = table.tBodies[0].rows[0]?.cells[col];
    return cell && cell.dataset.of != null ? "ascending" : "descending";
  }
  function sortRows(table, col, dir) {
    const body = table.tBodies[0];
    const rows = [...body.rows];
    const k = new Map(rows.map((r) => [r, sortKey(table, r, col)]));
    const sign = dir === "ascending" ? 1 : -1;
    rows.sort((a, b) => {
      const ka = k.get(a), kb = k.get(b);
      if (ka == null || kb == null) return ka == null && kb == null ? a._i - b._i : ka == null ? 1 : -1;
      const c = typeof ka === "string" ? ka.localeCompare(kb, "en", { numeric: true }) : ka - kb;
      return c ? sign * c : a._i - b._i;
    });
    body.append(...rows);
    const ths = table.tHead.rows[0].cells;
    for (let i = 0; i < ths.length; i++) {
      if (i === col) ths[i].setAttribute("aria-sort", dir); else ths[i].removeAttribute("aria-sort");
    }
  }
  function sortable(table, onSort) {
    const head = table.tHead?.rows[0];
    const body = table.tBodies[0];
    if (!head || !body || body.rows.length < 2) return;
    [...body.rows].forEach((r, i) => (r._i = i));
    [...head.cells].forEach((th, col) => {
      const btn = el("button", { type: "button", class: "sort" }, th.textContent, el("span", { class: "sort-ind", "aria-hidden": "true" }));
      th.replaceChildren(btn);
      btn.addEventListener("click", () => {
        const first = firstDir(table, col);
        const dir = th.getAttribute("aria-sort") === first ? (first === "ascending" ? "descending" : "ascending") : first;
        sortRows(table, col, dir);
        if (onSort) onSort(col, dir);
      });
    });
  }

  // ==========================================================================
  // A directory page: filter its tables by name and by standing.
  // ==========================================================================

  const STANDINGS = [
    ["all", "All", () => true],
    ["blocking", "Blocking", (g) => ["none-passed", "timeout", "error", "crash"].includes(g)],
    ["partial", "With failures", (g) => g === "partial"],
    ["clean", "Clean", (g) => g === "clean"],
    ["empty", "No subtests", (g) => g === "empty"],
    ["unrun", "Not run", (g) => g === "unrun"],
  ];

  function directoryTools() {
    if (document.getElementById("history")) return; // the index: its tables are short
    const box = document.querySelector("main > .boxes > .box.tests");
    if (!box) return;
    const files = box.querySelector("table.listing-files");
    const dirs = box.querySelector("table.listing-dirs");
    const fileRows = files ? [...files.tBodies[0].rows] : [];
    const dirRows = dirs ? [...dirs.tBodies[0].rows] : [];
    const tables = [dirs, files].filter(Boolean);
    const q0 = params();

    for (const t of tables) {
      const tag = t === files ? "f" : "d";
      sortable(t, (col, dir) => setParams({ sort: `${tag}${col}${dir === "ascending" ? "a" : "d"}` }));
    }
    const sortParam = /^([fd])(\d)([ad])$/.exec(q0.get("sort") || "");
    if (sortParam) {
      const t = sortParam[1] === "f" ? files : dirs;
      if (t && +sortParam[2] < t.tHead.rows[0].cells.length) sortRows(t, +sortParam[2], sortParam[3] === "a" ? "ascending" : "descending");
    }
    if (fileRows.length + dirRows.length < 8) return;

    const input = el("input", { type: "search", class: "filter", placeholder: "Filter by name", "aria-label": "Filter these tests by name", spellcheck: "false", autocomplete: "off" });
    const chips = el("div", { class: "chips", role: "group", "aria-label": "Show test files" });
    if (dirRows.length && fileRows.length) chips.append(el("span", { class: "chips-label", text: "Test files" }));
    const shown = el("p", { class: "shown", "aria-live": "polite" });
    let show = STANDINGS.find(([k]) => k === q0.get("show")) || STANDINGS[0];
    input.value = q0.get("q") || "";

    for (const st of STANDINGS) {
      const count = fileRows.filter((r) => st[2](r.dataset.gate)).length;
      if (st[0] !== "all" && count === 0) continue;
      const b = el("button", { type: "button", class: `chip chip-${st[0]}`, "aria-pressed": String(st === show) },
        st[1], el("span", { class: "chip-n", text: fmt(count) }));
      b.addEventListener("click", () => {
        show = st;
        for (const c of chips.querySelectorAll("button")) c.setAttribute("aria-pressed", String(c === b));
        apply();
      });
      chips.append(b);
    }
    if (fileRows.length === 0) chips.hidden = true;

    function apply() {
      const words = input.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
      const hit = (row) => { const name = row.cells[0].textContent.toLowerCase(); return words.every((w) => name.includes(w)); };
      let files = 0, dirsOn = 0;
      for (const r of fileRows) { const on = show[2](r.dataset.gate) && hit(r); r.hidden = !on; files += on; }
      for (const r of dirRows) {
        // A directory stays while showing everything, or blocking files it holds.
        const on = hit(r) && (show[0] === "all" || (show[0] === "blocking" && +r.cells[3].dataset.v > 0));
        r.hidden = !on; dirsOn += on;
      }
      for (const t of tables) t.hidden = [...t.tBodies[0].rows].every((r) => r.hidden);
      const part = (on, all, one, many) => (all ? `${on === all ? fmt(all) : `${fmt(on)} of ${fmt(all)}`} ${all === 1 ? one : many}` : null);
      const filtered = files < fileRows.length || dirsOn < dirRows.length;
      shown.textContent = (filtered ? "Showing " : "") +
        [part(dirsOn, dirRows.length, "directory", "directories"), part(files, fileRows.length, "test file", "test files")].filter(Boolean).join(", ");
      empty.hidden = files + dirsOn > 0;
      setParams({ q: input.value.trim() || null, show: show[0] === "all" ? null : show[0] });
    }
    const empty = el("p", { class: "none-shown", hidden: true, text: "Nothing here matches the filter." });
    input.addEventListener("input", apply);
    input.addEventListener("keydown", (e) => { if (e.key === "Escape" && input.value) { input.value = ""; apply(); } });
    box.querySelector(".box-head").after(el("div", { class: "toolbar" }, input, chips, shown));
    box.append(empty);
    apply();
  }

  // ==========================================================================
  // The search: every directory and test file, from every page.
  // ==========================================================================

  let pathsPromise = null;
  function loadPaths() {
    pathsPromise ||= fetch(ROOT + "paths.json").then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); });
    return pathsPromise;
  }
  function score(p, words) {
    const lower = p.toLowerCase();
    const base = lower.replace(/\/$/, "").split("/").pop();
    let s = 0;
    for (const w of words) {
      const at = lower.indexOf(w);
      if (at < 0) return -1;
      s += base.startsWith(w) ? 0 : base.includes(w) ? 1 : 3;
    }
    return s * 1000 + p.length;
  }

  function search() {
    const rail = document.querySelector(".toc");
    if (!rail) return;
    const id = "find-results";
    const input = el("input", {
      type: "search", id: "find", class: "find-input", placeholder: "Find a test file", autocomplete: "off", spellcheck: "false",
      role: "combobox", "aria-autocomplete": "list", "aria-expanded": "false", "aria-controls": id,
    });
    const list = el("ul", { class: "find-results", id, role: "listbox", hidden: true, "aria-label": "Matching tests" });
    const note = el("p", { class: "find-note", hidden: true });
    const form = el("form", { class: "find", role: "search" },
      el("label", { class: "find-label", for: "find" }, "Find a test ", el("kbd", { text: "/" })), input, list, note);
    form.addEventListener("submit", (e) => { e.preventDefault(); go(active >= 0 ? active : 0); });

    // At the top of the rail on wide screens; at the top of the page where the
    // rail follows the document.
    const narrow = matchMedia("(max-width: 52rem)");
    const place = () => {
      if (narrow.matches) document.querySelector("main.doc")?.prepend(form);
      else rail.prepend(form);
    };
    place();
    narrow.addEventListener("change", place);

    let hits = [];
    let active = -1;
    function render() {
      list.replaceChildren(...hits.map((p, i) => {
        const dir = p.endsWith("/");
        const trimmed = dir ? p.slice(0, -1) : p;
        const cut = trimmed.lastIndexOf("/");
        return el("li", { role: "option", id: `find-${i}`, "aria-selected": String(i === active), class: dir ? "find-dir" : null },
          el("a", { href: pageUrl(p), tabindex: "-1" },
            el("code", { class: "find-base", text: trimmed.slice(cut + 1) + (dir ? "/" : "") }),
            el("span", { class: "find-parent", text: cut >= 0 ? trimmed.slice(0, cut + 1) : "" })));
      }));
      list.hidden = hits.length === 0;
      input.setAttribute("aria-expanded", String(!list.hidden));
      if (active >= 0) input.setAttribute("aria-activedescendant", `find-${active}`); else input.removeAttribute("aria-activedescendant");
    }
    async function update() {
      const words = input.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
      if (!words.length) { hits = []; active = -1; note.hidden = true; render(); return; }
      let paths;
      try { paths = await loadPaths(); } catch { note.textContent = "The list of tests did not load."; note.hidden = false; return; }
      const scored = [];
      for (const p of paths) { const s = score(p, words); if (s >= 0) scored.push([s, p]); }
      scored.sort((a, b) => a[0] - b[0] || (a[1] < b[1] ? -1 : 1));
      hits = scored.slice(0, 12).map(([, p]) => p);
      active = hits.length ? 0 : -1;
      note.textContent = scored.length === 0 ? "No directory or test file matches." :
        scored.length > hits.length ? `${fmt(hits.length)} of ${fmt(scored.length)} matches` : `${fmt(scored.length)} ${scored.length === 1 ? "match" : "matches"}`;
      note.hidden = false;
      render();
    }
    function go(i) { if (hits[i]) location.href = pageUrl(hits[i]); }
    input.addEventListener("focus", () => { loadPaths().catch(() => {}); });
    input.addEventListener("input", update);
    input.addEventListener("keydown", (e) => {
      if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        if (!hits.length) return;
        e.preventDefault();
        active = (active + (e.key === "ArrowDown" ? 1 : -1) + hits.length) % hits.length;
        render();
        document.getElementById(`find-${active}`)?.scrollIntoView({ block: "nearest" });
      } else if (e.key === "Escape") {
        input.value = ""; update(); input.blur();
      }
    });
    list.addEventListener("pointerdown", (e) => e.preventDefault()); // keep focus while choosing
    document.addEventListener("keydown", (e) => {
      if (e.key === "/" && !typing(e) && !e.metaKey && !e.ctrlKey && !e.altKey) { e.preventDefault(); input.focus(); input.select(); }
    });
  }

  // ==========================================================================
  // A test file's subtests: filter by result and name; open every message.
  // ==========================================================================

  const RESULTS = [
    ["all", "All", () => true],
    ["fail", "Failed", (li) => li.classList.contains("s-fail")],
    ["timeout", "Timed out", (li) => li.classList.contains("s-timeout")],
    ["notrun", "Not run", (li) => li.classList.contains("s-notrun")],
    ["other", "Other", (li) => li.classList.contains("s-other")],
    ["pass", "Passed", (li) => li.classList.contains("s-pass")],
  ];

  function subtestTools() {
    const section = document.querySelector(".subtests-section");
    const items = section ? [...section.querySelectorAll("li.sub")] : [];
    if (!items.length) return;
    const details = [...section.querySelectorAll("li.sub details")];
    const q0 = params();
    let result = RESULTS.find(([k]) => k === q0.get("result")) || RESULTS[0];

    const input = el("input", { type: "search", class: "filter", placeholder: "Filter subtests by name", "aria-label": "Filter subtests by name", spellcheck: "false", autocomplete: "off" });
    input.value = q0.get("q") || "";
    const chips = el("div", { class: "chips", role: "group", "aria-label": "Show subtests" });
    for (const r of RESULTS) {
      const count = items.filter(r[2]).length;
      if (r[0] !== "all" && count === 0) continue;
      const b = el("button", { type: "button", class: `chip chip-${r[0]}`, "aria-pressed": String(r === result) },
        r[1], el("span", { class: "chip-n", text: fmt(count) }));
      b.addEventListener("click", () => {
        result = r;
        for (const c of chips.children) c.setAttribute("aria-pressed", String(c === b));
        apply();
      });
      chips.append(b);
    }
    const shown = el("p", { class: "shown", "aria-live": "polite" });
    const tools = el("div", { class: "toolbar toolbar-subs" }, input, chips, shown);
    if (details.length) {
      const open = el("button", { type: "button", class: "text-button", text: "Open all messages" });
      const close = el("button", { type: "button", class: "text-button", text: "Close all" });
      open.addEventListener("click", () => { for (const d of details) if (!d.closest("li").hidden) d.open = true; });
      close.addEventListener("click", () => { for (const d of details) d.open = false; });
      tools.append(el("div", { class: "msg-buttons" }, open, close));
    }
    function apply() {
      const words = input.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
      let seen = 0;
      for (const li of items) {
        const name = (li.querySelector(".sub-name")?.textContent || "").toLowerCase();
        const on = result[2](li) && words.every((w) => name.includes(w));
        li.hidden = !on;
        seen += on;
      }
      shown.textContent = seen === items.length ? `${fmt(items.length)} subtests` : `Showing ${fmt(seen)} of ${fmt(items.length)}`;
      setParams({ q: input.value.trim() || null, result: result[0] === "all" ? null : result[0] });
    }
    input.addEventListener("input", apply);
    input.addEventListener("keydown", (e) => { if (e.key === "Escape" && input.value) { input.value = ""; apply(); } });
    (section.querySelector(".sub-hint") || section.querySelector("h2")).after(tools);
    apply();

    // A link to one subtest opens its message. The first site linked subtests
    // by name (?sub=), so those land here too.
    function openTarget() {
      let li = location.hash ? document.getElementById(decodeURIComponent(location.hash.slice(1))) : null;
      const byName = params().get("sub");
      if (!li && byName != null) li = items.find((x) => x.querySelector(".sub-name")?.textContent === byName) || null;
      if (!li || !li.classList.contains("sub")) return;
      if (li.hidden) { result = RESULTS[0]; input.value = ""; for (const c of chips.children) c.setAttribute("aria-pressed", String(c === chips.firstChild)); apply(); }
      const d = li.querySelector("details");
      if (d) d.open = true;
      li.classList.add("is-target");
      li.scrollIntoView({ block: "center" });
    }
    window.addEventListener("hashchange", openTarget);
    openTarget();
  }

  // ==========================================================================
  // The index: the rail follows the section being read; old links land.
  // ==========================================================================

  function railFollows() {
    const sections = [...document.querySelectorAll("section.suite")];
    const rail = document.querySelector(".toc");
    if (!sections.length || !rail || !("IntersectionObserver" in window)) return;
    const links = new Map();
    for (const a of rail.querySelectorAll(".toc-suite a")) links.set(a.getAttribute("href").replace(/\/$/, ""), a);
    const bySection = new Map(sections.map((s) => [s, links.get(s.querySelector("h2 .h-link")?.getAttribute("href").replace(/\/$/, ""))]));
    const visible = new Set();
    let current = null;
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) { if (e.isIntersecting) visible.add(e.target); else visible.delete(e.target); }
      const top = sections.find((s) => visible.has(s));
      const a = top ? bySection.get(top) : null;
      if (a === current) return;
      current?.classList.remove("is-here");
      current = a || null;
      if (current) {
        current.classList.add("is-here");
        const r = current.getBoundingClientRect(), rr = rail.getBoundingClientRect();
        if (r.top < rr.top || r.bottom > rr.bottom) current.scrollIntoView({ block: "nearest" });
      }
    }, { rootMargin: "-10% 0px -60% 0px" });
    for (const s of sections) io.observe(s);
  }

  // The first, script-rendered site linked everything from the index's hash:
  // #dom/nodes/, #dom/nodes/x.html, #dom/nodes/x.html?sub=name. Each now has a page.
  function oldLinks() {
    if (!document.getElementById("history") || location.hash.length < 2) return;
    let h = location.hash.slice(1), sub = null;
    const qi = h.indexOf("?");
    if (qi >= 0) { sub = new URLSearchParams(h.slice(qi + 1)).get("sub"); h = h.slice(0, qi); }
    try { h = decodeURIComponent(h); } catch { return; }
    if (!h.includes("/") || document.getElementById(h)) return;
    location.replace(pageUrl(h) + (sub != null && !h.endsWith("/") ? `?sub=${encodeURIComponent(sub)}` : ""));
  }

  // ==========================================================================

  oldLinks();
  historyChart();
  for (const t of document.querySelectorAll("table.listing")) {
    if (!t.closest("main > .boxes")) sortable(t); // a directory page's tables are set up with their filter
  }
  directoryTools();
  subtestTools();
  search();
  railFollows();
})();
