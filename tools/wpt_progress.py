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
import subprocess

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKLIST = os.path.join(REPO, 'tests', 'wpt_0_1_worklist.txt')
RESULTS = os.path.join(REPO, 'wpt-results')
DEFAULT_OUT = os.path.join(RESULTS, 'progress.html')

# Accumulated history, kept OUT of wpt-results/ because the runner owns that
# directory and reuses journal.shard*.jsonl on every run. A killed baseline and
# three small runs silently overwrote a 2,052-file journal set that way, and the
# report dropped from 1,510 sources to 77 with nothing to say why.
STATE = os.path.join(REPO, 'tmp', 'wpt-progress-state.json')

# One entry per GENERATION of this report in which something moved: totals,
# the per-area picture, the git head, and - the part a single snapshot cannot
# give - which files changed status since the previous generation. It lives
# beside the report rather than in tmp/, so clearing scratch does not erase the
# record of how the numbers got where they are. A regeneration in which nothing
# moved does not add a row; it bumps `regenerations` on the last one.
HISTORY = os.path.join(RESULTS, 'progress-history.json')
HISTORY_SAMPLE = 15   # paths kept per movement bucket, so the file stays small

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

    # Subdirectories too, so archived journals can be dropped in without
    # colliding with the filenames the runner reuses.
    files = sorted(glob.glob(os.path.join(RESULTS, '*.jsonl')) +
                   glob.glob(os.path.join(RESULTS, '*', '*.jsonl')),
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


def git_head():
    try:
        return subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=REPO,
                              capture_output=True, text=True, timeout=5).stdout.strip() or '?'
    except Exception:
        return '?'


def status_of(rec):
    """One word per file for the history diff: OK, UNRUN, or the gating status."""
    if rec is None:
        return 'UNRUN'
    st = rec.get('status', 'ERROR')
    if st == 'OK':
        return 'OK'
    return st if st in GATING else 'ERROR'


def record_generation(worklist, records, areas):
    """Append this generation to HISTORY if anything moved; return the history.

    The diff is against `last_statuses`, the per-path status map of the previous
    generation, which is the only full map kept - each generation stores counts
    plus a few sample paths, not 4,300 entries.
    """
    try:
        with open(HISTORY) as f:
            history = json.load(f)
    except (OSError, json.JSONDecodeError):
        history = {'generations': [], 'last_statuses': None}

    cur = {p: status_of(records.get(p)) for p in worklist}
    prev = history.get('last_statuses')

    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)
    snap = {
        'n': len(history['generations']) + 1,
        'at': datetime.datetime.now().isoformat(timespec='seconds'),
        'head': git_head(),
        'total': len(worklist), 'run': tot['run'], 'unrun': tot['unrun'],
        'blocking': tot['gating'], 'crash': tot['crash'], 'timeout': tot['timeout'],
        'error': tot['gating'] - tot['crash'] - tot['timeout'],
        'clean': tot['clean'], 'partial': tot['partial'],
        'sub_pass': tot['sub_pass'], 'sub_fail': tot['sub_fail'],
        'areas': {a: {'run': c['run'], 'blocking': c['gating'], 'clean': c['clean']}
                  for a, c in areas.items()},
        'regenerations': 0,
    }

    if prev is None:
        snap['moves'] = None          # history starts here; nothing to diff against
    else:
        moves = collections.Counter()
        samples = collections.defaultdict(list)
        for path, now in cur.items():
            before = prev.get(path, 'UNRUN')
            if before == now:
                continue
            moves['changed'] += 1
            if before == 'UNRUN':
                key = 'newly_run_blocking' if now in GATING else 'newly_run_ok'
            elif now == 'OK' and before in GATING:
                key = 'unblocked'
            elif before == 'OK' and now in GATING:
                key = 'regressed'
            elif now == 'UNRUN':
                key = 'dropped'
            else:
                key = 'reshuffled'   # e.g. TIMEOUT -> CRASH: still blocking, different way
            moves[key] += 1
            if len(samples[key]) < HISTORY_SAMPLE:
                samples[key].append(f'{path}  {before} -> {now}')
        if not moves:
            # Nothing moved: not a new generation. Note the regeneration and keep
            # the map as it is.
            if history['generations']:
                last = history['generations'][-1]
                last['regenerations'] = last.get('regenerations', 0) + 1
                last['regenerated_at'] = snap['at']
            history['last_statuses'] = cur
            _save_history(history)
            return history
        snap['moves'] = dict(moves)
        snap['samples'] = dict(samples)

    history['generations'].append(snap)
    history['last_statuses'] = cur
    _save_history(history)
    return history


def rebuild_history(worklist, records):
    """Reconstruct generations from the state file's per-record timestamps.

    Every accumulated record remembers the journal that last set it and when
    (`_journal`, `_mtime`). Grouping records by that gives one generation per
    surviving measurement batch, in time order. It is a lower bound on what was
    known at each point - a path re-measured later counts only at its latest
    measurement, so earlier generations show less coverage than there really
    was - and every move it can see is "newly run", because only the latest
    status per path survives. The final reconstructed generation equals the
    current state exactly; live history continues from it.
    """
    groups = collections.defaultdict(list)
    for path in worklist:
        rec = records.get(path)
        if rec is None:
            continue
        mt = rec.get('_mtime', 0)
        key = int(mt // 300) * 300   # 5-minute buckets: a sharded run is ONE generation
        groups[key].append(path)

    history = {'generations': [], 'last_statuses': None}
    seen = {}
    for bucket, paths in sorted(groups.items()):
        journal = ', '.join(sorted({records[p].get('_journal', '?') for p in paths}))
        for path in paths:
            seen[path] = records[path]
        areas, _ = build(worklist, seen)
        tot = collections.Counter()
        for c in areas.values():
            tot.update(c)
        cur = {p: status_of(seen.get(p)) for p in worklist}
        prev = history['last_statuses']
        snap = {
            'n': len(history['generations']) + 1,
            'at': datetime.datetime.fromtimestamp(bucket).isoformat(timespec='seconds'),
            'head': '?',
            'reconstructed': True, 'journal': journal,
            'total': len(worklist), 'run': tot['run'], 'unrun': tot['unrun'],
            'blocking': tot['gating'], 'crash': tot['crash'], 'timeout': tot['timeout'],
            'error': tot['gating'] - tot['crash'] - tot['timeout'],
            'clean': tot['clean'], 'partial': tot['partial'],
            'sub_pass': tot['sub_pass'], 'sub_fail': tot['sub_fail'],
            'areas': {a: {'run': c['run'], 'blocking': c['gating'], 'clean': c['clean']}
                      for a, c in areas.items()},
            'regenerations': 0,
        }
        if prev is None:
            snap['moves'] = None
        else:
            moves = collections.Counter(); samples = collections.defaultdict(list)
            for path, now in cur.items():
                before = prev.get(path, 'UNRUN')
                if before == now:
                    continue
                moves['changed'] += 1
                key = 'newly_run_blocking' if now in GATING else 'newly_run_ok'
                moves[key] += 1
                if len(samples[key]) < HISTORY_SAMPLE:
                    samples[key].append(f'{path}  {before} -> {now}')
            snap['moves'] = dict(moves); snap['samples'] = dict(samples)
        history['generations'].append(snap)
        history['last_statuses'] = cur
    _save_history(history)
    return history


def _save_history(history):
    os.makedirs(os.path.dirname(HISTORY), exist_ok=True)
    tmp_path = HISTORY + '.tmp'
    with open(tmp_path, 'w') as f:
        json.dump(history, f)
    os.replace(tmp_path, HISTORY)


def _delta(cur, prev, key, good_when_down):
    if prev is None:
        return ''
    d = cur[key] - prev[key]
    if d == 0:
        return '<span class="dim">&plusmn;0</span>'
    cls = ('good' if (d < 0) == good_when_down else 'badtext')
    return f'<span class="{cls}">{d:+,}</span>'


def render_history(history):
    gens = history.get('generations', [])
    if not gens:
        return ''

    # --- chart: blocking, clean and run across every generation ---
    W, H, PAD = 640, 170, 28
    n = len(gens)
    top = max(g['total'] for g in gens) or 1
    def x(i): return PAD + (i * (W - 2 * PAD) / max(n - 1, 1))
    def y(v): return H - PAD - (v / top) * (H - 2 * PAD)
    def line(key, color):
        pts = ' '.join(f'{x(i):.1f},{y(g[key]):.1f}' for i, g in enumerate(gens))
        dots = ''.join(f'<circle cx="{x(i):.1f}" cy="{y(g[key]):.1f}" r="2.5" fill="{color}"/>'
                       for i, g in enumerate(gens)) if n <= 60 else ''
        return (f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2"/>' + dots)
    chart = f"""
  <svg class="chart" viewBox="0 0 {W} {H}" role="img" aria-label="blocking, clean and run files per generation">
    <line x1="{PAD}" y1="{y(0):.1f}" x2="{W-PAD}" y2="{y(0):.1f}" stroke="var(--line)"/>
    <line x1="{PAD}" y1="{y(top):.1f}" x2="{W-PAD}" y2="{y(top):.1f}" stroke="var(--line)" stroke-dasharray="3 3"/>
    <text x="{PAD}" y="{y(top)-6:.1f}" class="lbl">{top:,} = whole subset</text>
    {line('run', 'var(--dimline)')}
    {line('blocking', 'var(--bad)')}
    {line('clean', 'var(--ok)')}
    <text x="{PAD}" y="{H-6}" class="lbl">gen 1 &middot; {html.escape(gens[0]['at'][:16].replace('T',' '))}</text>
    <text x="{W-PAD}" y="{H-6}" class="lbl" text-anchor="end">gen {n} &middot; {html.escape(gens[-1]['at'][:16].replace('T',' '))}</text>
  </svg>
  <div class="legend"><span><i style="background:var(--dimline)"></i>run</span>
    <span><i style="background:var(--bad)"></i>blocking</span>
    <span><i style="background:var(--ok)"></i>clean</span></div>"""

    # --- table: newest first, with deltas against the previous generation ---
    rows = []
    for i in range(n - 1, -1, -1):
        g = gens[i]; prev = gens[i - 1] if i > 0 else None
        mv = g.get('moves')
        if mv is None:
            movement = '<span class="dim">baseline &mdash; history starts here</span>'
        else:
            parts = []
            if mv.get('unblocked'): parts.append(f'<span class="good">{mv["unblocked"]:,} unblocked</span>')
            if mv.get('regressed'): parts.append(f'<span class="badtext">{mv["regressed"]:,} regressed</span>')
            nr = mv.get('newly_run_ok', 0) + mv.get('newly_run_blocking', 0)
            if nr: parts.append(f'{nr:,} newly run <span class="dim">({mv.get("newly_run_blocking",0):,} blocking)</span>')
            if mv.get('reshuffled'): parts.append(f'<span class="dim">{mv["reshuffled"]:,} reshuffled</span>')
            if mv.get('dropped'): parts.append(f'<span class="dim">{mv["dropped"]:,} dropped</span>')
            movement = ', '.join(parts) or '<span class="dim">no file changed status</span>'
            samples = g.get('samples') or {}
            if samples:
                items = []
                for key in ('regressed', 'unblocked', 'newly_run_blocking', 'reshuffled', 'newly_run_ok', 'dropped'):
                    for line_ in samples.get(key, []):
                        items.append(f'<li class="{key}">{html.escape(line_)}</li>')
                movement += (f'<details><summary class="dim">files</summary>'
                             f'<ul class="samples">{"".join(items)}</ul></details>')
        regen = g.get('regenerations', 0)
        when = html.escape(g['at'][:16].replace('T', ' '))
        if g.get('reconstructed'):
            when += f' <span class="dim" title="reconstructed from the state file: {html.escape(str(g.get("journal","")))}">~</span>'
        if regen:
            when += f' <span class="dim" title="regenerated {regen} more time(s) with no change; last {html.escape(g.get("regenerated_at","")[:16].replace("T"," "))}">+{regen}&times;</span>'
        rows.append(f"""
      <tr>
        <td class="num">{g['n']}</td>
        <td class="when">{when}<br><code class="dim">{html.escape(g['head'])}</code></td>
        <td class="num">{g['run']:,} {_delta(g, prev, 'run', False)}</td>
        <td class="num gate">{g['blocking']:,} {_delta(g, prev, 'blocking', True)}</td>
        <td class="num">{g['crash']:,} {_delta(g, prev, 'crash', True)}</td>
        <td class="num">{g['timeout']:,} {_delta(g, prev, 'timeout', True)}</td>
        <td class="num">{g['error']:,} {_delta(g, prev, 'error', True)}</td>
        <td class="num">{g['clean']:,} {_delta(g, prev, 'clean', False)}</td>
        <td class="num hide-sm">{g['sub_pass']:,} {_delta(g, prev, 'sub_pass', False)}</td>
        <td class="moves">{movement}</td>
      </tr>""")

    first, last = gens[0], gens[-1]
    since = (f"Since generation 1: blocking {first['blocking']:,} &rarr; {last['blocking']:,}, "
             f"clean {first['clean']:,} &rarr; {last['clean']:,}, "
             f"run {first['run']:,} &rarr; {last['run']:,} of {last['total']:,}.")
    return f"""
<h2>Progress by generation <small class="dim">{n} generation{'s' if n != 1 else ''} in which something moved</small></h2>
<p class="dim">{since} A generation is one run of this report where at least one file changed
status; deltas are against the previous generation. <em>Newly run</em> is coverage, not regression -
a file measured for the first time that blocks was always blocking, it just was not counted.
Rows marked <span class="dim">~</span> are reconstructed from the state file's per-record timestamps: a
lower bound on coverage at that time, and they can only show "newly run", since only each file's latest
status survives.</p>
{chart}
<table class="history">
  <thead><tr>
    <th>#</th><th>When / head</th><th>Run</th><th>Blocking</th>
    <th>Crash</th><th>Timeout</th><th>Error</th><th>Clean</th>
    <th class="hide-sm">Subtests&nbsp;pass</th><th>What moved</th>
  </tr></thead>
  <tbody>{''.join(rows)}</tbody>
</table>
"""


def render(areas, worklist, records, files, out_path, history=None):
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

    history_html = render_history(history) if history else ''
    doc = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Crane 0.1 — WPT progress</title>
<style>
  :root {{
    --bg:#fbfaf9; --panel:#fff; --ink:#1c1a17; --dim:#77706a; --line:#e4dfd9; --dimline:#b9b2aa;
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

  h2 {{ font-size: 15px; margin: 28px 0 6px; }}
  h2 small {{ font-weight: normal; }}
  .chart {{ width: 100%; max-width: 640px; height: auto; display: block; margin: 8px 0 2px; }}
  .chart .lbl {{ font-size: 10px; fill: var(--dim); }}
  .legend {{ font-size: 12px; color: var(--dim); margin-bottom: 10px; }}
  .legend span {{ margin-right: 14px; }}
  .legend i {{ display: inline-block; width: 18px; height: 3px; vertical-align: middle; margin-right: 5px; }}
  .history td.when {{ white-space: nowrap; font-size: 12px; }}
  .history td.moves {{ font-size: 12px; max-width: 320px; }}
  .history .good {{ color: var(--ok); }}
  .history .badtext {{ color: var(--bad); }}
  .samples {{ margin: 6px 0 0; padding-left: 16px; font-size: 11px; font-family: ui-monospace, monospace; }}
  .samples li.regressed {{ color: var(--bad); }}
  .samples li.unblocked {{ color: var(--ok); }}
  details summary {{ cursor: pointer; }}
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

{history_html}

<h2>By area <small class="dim">current state</small></h2>
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
    if '--rebuild-history' in sys.argv:
        rebuild_history(worklist, records)
        print(f"history rebuilt from per-record timestamps -> {HISTORY}")
    history = record_generation(worklist, records, areas)
    gate_met, gating, run, total, clean = render(areas, worklist, records, files, out, history)

    print(f"{run:,} of {total:,} sources run  |  {gating:,} blocking  |  {clean:,} clean")
    print('GATE MET' if gate_met else 'gate not met')
    gens = history.get('generations', [])
    if gens:
        g = gens[-1]; mv = g.get('moves')
        if mv is None:
            print(f"history: generation {g['n']} (baseline)")
        else:
            print(f"history: generation {g['n']}  +{mv.get('unblocked',0)} unblocked  "
                  f"-{mv.get('regressed',0)} regressed  {mv.get('newly_run_ok',0)+mv.get('newly_run_blocking',0)} newly run")
    print(f"\nwrote {out}\n  open {out}")


if __name__ == '__main__':
    main()
