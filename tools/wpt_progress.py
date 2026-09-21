#!/usr/bin/env python3
"""Render Crane's progress toward the 0.1 WPT gate as a standalone HTML page.

    python3 tools/wpt_progress.py
    open wpt-results/progress.html

Reads the worklist (the denominator) and every journal JSONL the runner has
written (the numerator), and emits one self-contained file - no network, no
build step, opens straight from file://.

The page leads with the gate, because the gate is the decision: 0.1 ships when
CRASHES AND TIMEOUTS REACH ZERO across the subset. Pass rate is shown, but a
crash means the engine is unsound while a failing subtest means a feature is
missing, and only one of those blocks building a product on top.
"""
import json
import glob
import os
import sys
import html
import datetime
import collections

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKLIST = os.path.join(REPO, 'tests', 'wpt_0_1_worklist.txt')
RESULTS = os.path.join(REPO, 'wpt-results')
DEFAULT_OUT = os.path.join(RESULTS, 'progress.html')

# Accumulated history, kept OUT of wpt-results/ because the runner owns that
# directory and reuses journal.shard*.jsonl on every run. A killed baseline and
# three small runs silently overwrote a 2,052-file journal set that way, and the
# report dropped from 1,510 sources to 77 with nothing to say why.
STATE = os.path.join(REPO, 'tmp', 'wpt-progress-state.json')

# status -> (label, css class). Anything unrecognised is treated as an error,
# which is the safe direction: a status we do not know about is not a pass.
GATING = {'TIMEOUT', 'CRASH', 'ERROR', 'EXTERNAL-TIMEOUT', 'PRECONDITION_FAILED'}


def load_worklist():
    if not os.path.exists(WORKLIST):
        sys.exit(f"worklist not found: {WORKLIST}\nRun: python3 tools/wpt_subset.py")
    paths = []
    for line in open(WORKLIST):
        line = line.strip()
        if line and not line.startswith('#'):
            paths.append(line)
    return paths


def load_results():
    """Latest record per path, accumulated across runs.

    Journals are transient - the runner reuses their filenames - so results are
    merged into a persistent state file and read back from there. A path a run
    did not touch keeps its previous result rather than reverting to unrun.
    """
    records = {}

    # Previously accumulated.
    try:
        with open(STATE) as f:
            records = json.load(f)
    except (OSError, json.JSONDecodeError):
        records = {}

    files = sorted(glob.glob(os.path.join(RESULTS, '*.jsonl')),
                   key=os.path.getmtime)
    for fn in files:
        for line in open(fn, errors='replace'):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if 'path' in rec:
                rec['_journal'] = os.path.basename(fn)
                rec['_mtime'] = os.path.getmtime(fn)
                prev = records.get(rec['path'])
                # Only supersede with something at least as recent, so replaying
                # an old journal cannot roll the picture backwards.
                if prev is None or rec['_mtime'] >= prev.get('_mtime', 0):
                    records[rec['path']] = rec

    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp_path = STATE + '.tmp'
    with open(tmp_path, 'w') as f:
        json.dump(records, f)
    os.replace(tmp_path, STATE)  # atomic: a crash mid-write cannot truncate it

    return records, files


def area_of(path, depth=2):
    parts = path.split('/')
    return '/'.join(parts[:depth]) if len(parts) > depth else parts[0]


def build(worklist, records):
    in_subset = set(worklist)
    areas = collections.defaultdict(lambda: collections.Counter())

    for path in worklist:
        a = area_of(path)
        areas[a]['total'] += 1
        rec = records.get(path)
        if rec is None:
            areas[a]['unrun'] += 1
            continue
        status = rec.get('status', 'ERROR')
        areas[a]['run'] += 1
        if status in GATING:
            areas[a]['gating'] += 1
            areas[a][status.lower()] += 1
        elif status == 'OK':
            if rec.get('failed', 0) == 0 and rec.get('timed_out', 0) == 0:
                areas[a]['clean'] += 1
            else:
                areas[a]['partial'] += 1
            areas[a]['sub_pass'] += rec.get('passed', 0)
            areas[a]['sub_fail'] += rec.get('failed', 0)
        else:
            areas[a]['gating'] += 1
            areas[a]['other'] += 1
    return areas, in_subset


def bar(numer, denom, cls):
    pct = (numer / denom * 100) if denom else 0
    return (f'<div class="bar"><div class="fill {cls}" '
            f'style="width:{pct:.1f}%"></div></div>')


def render(areas, worklist, records, files, out_path):
    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)

    total = len(worklist)
    run = tot['run']
    gating = tot['gating']
    clean = tot['clean']
    unrun = tot['unrun']
    gate_met = (run > 0 and gating == 0 and unrun == 0)

    rows = []
    for area in sorted(areas, key=lambda a: (-areas[a]['gating'], a)):
        c = areas[area]
        g = c['gating']
        rows.append(f"""
      <tr class="{'bad' if g else ('good' if c['run'] and not c['unrun'] else '')}">
        <td class="area">{html.escape(area)}</td>
        <td class="num">{c['total']}</td>
        <td class="num">{c['run'] or '&middot;'}</td>
        <td class="num gate">{g or '&middot;'}</td>
        <td class="num">{c['timeout'] or '&middot;'}</td>
        <td class="num">{c['crash'] or '&middot;'}</td>
        <td class="num ok">{c['clean'] or '&middot;'}</td>
        <td class="num">{c['partial'] or '&middot;'}</td>
        <td class="num dim">{c['unrun'] or '&middot;'}</td>
        <td>{bar(c['clean'], c['total'], 'ok')}</td>
      </tr>""")

    journals = ''.join(
        f'<li><code>{html.escape(os.path.basename(f))}</code> '
        f'<span class="dim">{datetime.datetime.fromtimestamp(os.path.getmtime(f)):%Y-%m-%d %H:%M}</span></li>'
        for f in files[-8:]) or '<li class="dim">none found</li>'

    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')

    doc = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Crane 0.1 — WPT progress</title>
<style>
  :root {{
    --bg:#fbfaf9; --panel:#fff; --ink:#1c1a17; --dim:#77706a;
    --line:#e6e1dc; --ok:#2f7d4f; --bad:#b4342a; --warn:#9a6b12;
    --accent:#3b5bdb;
  }}
  @media (prefers-color-scheme: dark) {{
    :root:not([data-theme="light"]) {{
      --bg:#17161a; --panel:#1f1e23; --ink:#eceaf0; --dim:#9a949f;
      --line:#302e36; --ok:#5cc98a; --bad:#f2796b; --warn:#e0b050;
      --accent:#8aa2ff;
    }}
  }}
  :root[data-theme="dark"] {{
    --bg:#17161a; --panel:#1f1e23; --ink:#eceaf0; --dim:#9a949f;
    --line:#302e36; --ok:#5cc98a; --bad:#f2796b; --warn:#e0b050;
    --accent:#8aa2ff;
  }}
  * {{ box-sizing:border-box }}
  body {{ margin:0; background:var(--bg); color:var(--ink);
    font:15px/1.55 ui-sans-serif,-apple-system,"Segoe UI",Roboto,sans-serif; }}
  .wrap {{ max-width:1100px; margin:0 auto; padding:40px 16px 80px }}
  h1 {{ font-size:22px; margin:0 0 4px; letter-spacing:-.01em }}
  .sub {{ color:var(--dim); font-size:13px; margin-bottom:28px }}
  .gate {{ background:var(--panel); border:1px solid var(--line);
    border-left:4px solid {'var(--ok)' if gate_met else 'var(--bad)'};
    border-radius:10px; padding:20px 22px; margin-bottom:28px }}
  .gate h2 {{ margin:0 0 6px; font-size:15px; letter-spacing:.02em;
    text-transform:uppercase; color:var(--dim) }}
  .verdict {{ font-size:26px; font-weight:650; letter-spacing:-.02em;
    color:{'var(--ok)' if gate_met else 'var(--bad)'} }}
  .verdict small {{ font-size:14px; font-weight:400; color:var(--dim);
    display:block; margin-top:6px; letter-spacing:0 }}
  .cards {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(160px,1fr));
    gap:12px; margin-bottom:28px }}
  .card {{ background:var(--panel); border:1px solid var(--line);
    border-radius:10px; padding:14px 16px }}
  .card .k {{ font-size:12px; color:var(--dim); text-transform:uppercase;
    letter-spacing:.04em }}
  .card .v {{ font-size:24px; font-weight:600; letter-spacing:-.02em;
    margin-top:2px; font-variant-numeric:tabular-nums }}
  table {{ width:100%; border-collapse:collapse; background:var(--panel);
    border:1px solid var(--line); border-radius:10px; overflow:hidden;
    font-variant-numeric:tabular-nums }}
  th {{ text-align:right; font-size:11px; text-transform:uppercase;
    letter-spacing:.04em; color:var(--dim); font-weight:600;
    padding:11px 10px; border-bottom:1px solid var(--line); white-space:nowrap }}
  th:first-child, td.area {{ text-align:left }}
  td {{ padding:9px 10px; border-bottom:1px solid var(--line); text-align:right }}
  tr:last-child td {{ border-bottom:0 }}
  td.area {{ font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:13px }}
  .num.gate {{ font-weight:650 }}
  tr.bad .num.gate {{ color:var(--bad) }}
  tr.good td.area {{ color:var(--ok) }}
  .num.ok {{ color:var(--ok) }}
  .dim {{ color:var(--dim) }}
  .bar {{ width:90px; height:7px; background:var(--line); border-radius:4px;
    overflow:hidden }}
  .fill {{ height:100%; border-radius:4px }}
  .fill.ok {{ background:var(--ok) }}
  footer {{ margin-top:30px; color:var(--dim); font-size:12.5px }}
  footer ul {{ padding-left:18px; margin:6px 0 }}
  code {{ font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px }}
  @media (max-width:640px) {{
    .hide-sm {{ display:none }}
    .wrap {{ padding:24px 16px 60px }}
  }}
</style></head><body><div class="wrap">

<h1>Crane 0.1 &mdash; WPT progress</h1>
<div class="sub">Generated {now} &middot; {total:,} sources in the 0.1 subset
  &middot; <code>tools/wpt_progress.py</code></div>

<div class="gate">
  <h2>Release gate</h2>
  <div class="verdict">{'MET' if gate_met else f'{gating:,} blocking'}
    <small>{'Zero crashes, zero timeouts, whole subset run.' if gate_met else
      f'0.1 ships when crashes and timeouts reach zero. {unrun:,} of {total:,} sources not yet run.'}</small>
  </div>
</div>

<div class="cards">
  <div class="card"><div class="k">Run</div><div class="v">{run:,}<span class="dim" style="font-size:14px"> / {total:,}</span></div></div>
  <div class="card"><div class="k">Timeouts</div><div class="v" style="color:var(--bad)">{tot['timeout']:,}</div></div>
  <div class="card"><div class="k">Crashes</div><div class="v" style="color:var(--bad)">{tot['crash']:,}</div></div>
  <div class="card"><div class="k">Clean files</div><div class="v" style="color:var(--ok)">{clean:,}</div></div>
  <div class="card"><div class="k">Subtests passing</div><div class="v">{tot['sub_pass']:,}</div></div>
</div>

<table>
  <thead><tr>
    <th>Area</th><th>Subset</th><th>Run</th><th>Blocking</th>
    <th>Timeout</th><th>Crash</th><th>Clean</th>
    <th class="hide-sm">Partial</th><th class="hide-sm">Unrun</th>
    <th class="hide-sm">Clean&nbsp;%</th>
  </tr></thead>
  <tbody>{''.join(rows)}</tbody>
</table>

<footer>
  <strong>Blocking</strong> = timeouts + crashes + errors. That is the gate:
  a crash means the engine is unsound, a failing subtest only means a feature
  is missing. <strong>Clean</strong> = ran to OK with zero failing subtests.
  <strong>Partial</strong> = ran to completion with some subtests failing,
  which does not block 0.1.
  <br><br>Journals read (most recent {min(len(files), 8)}):
  <ul>{journals}</ul>
  Results accumulate in <code>tmp/wpt-progress-state.json</code>; journals in
  <code>wpt-results/</code> are transient and the runner reuses their names.
  <br>Refresh with <code>zig build wpt -- --from-file=tests/wpt_0_1_worklist.txt</code>
  then re-run this script.
</footer>
</div></body></html>"""

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(doc)
    return gate_met, gating, run, total, clean


def main():
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else DEFAULT_OUT
    worklist = load_worklist()
    records, files = load_results()
    areas, _ = build(worklist, records)
    gate_met, gating, run, total, clean = render(areas, worklist, records, files, out)

    print(f"{run:,} of {total:,} sources run  |  {gating:,} blocking  |  {clean:,} clean")
    print('GATE MET' if gate_met else 'gate not met')
    print(f"\nwrote {out}\n  open {out}")


if __name__ == '__main__':
    main()
