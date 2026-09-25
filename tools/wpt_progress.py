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
import re
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

# The static shape of each source: how many times the runner fans it out, and -
# for a file that has never reported a subtest - how many subtests it looks like
# it declares. Cached because building it opens 4,323 sources plus the scripts
# they include; invalidated by the mtime and size of the source AND of every
# script it pulls in, since the tests are often declared in the include.
ESTIMATES = os.path.join(REPO, 'tmp', 'wpt-subtest-estimates.json')

# The engine roadmap: the shared infrastructure to finish before feature areas
# go to parallel agents, the prerequisites for that, and the areas to hand out.
# Hand-edited; everything the page can measure about it is measured here.
ROADMAP = os.path.join(REPO, 'docs', 'roadmap.toml')
WPT_ROOT = os.path.join(REPO, 'tests', 'wpt')

# A subtest-declaring call. The lookbehind stops `subsetTest(` matching `test(`
# inside itself, and keeps a regex's `.test(` out.
TEST_CALL = re.compile(
    r'(?<![\w.$])(?:async_test|promise_test|promise_setup|subsetTest|test)\s*\(')
# A test call inside one of these declares an unknown number of subtests, so a
# static count of it is a FLOOR, not an estimate. Measured against the files
# whose real count is known, a loopy file's static count has a median ratio of
# 1.5 and a p90 of 24 - useless as an estimate, sound as a lower bound.
LOOPY = re.compile(r'\b(?:for|while)\s*\(|\.(?:forEach|map)\s*\(|\bgenerate_tests\s*\(')
VARIANT_META = re.compile(r'name=["\']variant["\']')
VARIANT_JS = re.compile(r'^//\s*META:\s*variant=', re.M)
GLOBAL_JS = re.compile(r'^//\s*META:\s*global=(.*)$', re.M)
SCRIPT_META = re.compile(r'^//\s*META:\s*script=(\S+)', re.M)
SCRIPT_SRC = re.compile(r'<script[^>]*\ssrc=["\']([^"\']+)["\']')

# The globals `tests/wpt_runner/test_parser.zig:isImplemented` actually runs.
# The rest are skipped rather than run, so their subtests are not targeted.
IMPLEMENTED_GLOBALS = {'window', 'worker', 'dedicatedworker'}

# How the per-file subtest count was arrived at, best evidence first. The page
# prints this table verbatim, because a denominator whose composition is not
# stated is a denominator nobody can check.
TIERS = ('exact', 'partial', 'est', 'floor', 'unknown')
COMPOSITION = (
    ('exact', 'Measured, exact',
     'ran to completion, so testharness reported every subtest the file declared'),
    ('partial', 'Measured, lower bound',
     'timed out or errored but still reported subtests &mdash; declared-but-unrun ones '
     'come back NOTRUN. A floor, because declaration itself may have been cut short'),
    ('est', 'Estimated',
     'reported nothing; a static count of its test call sites, with no loop around them. '
     'Against the 2,014 straight-line files whose real number is known this is exact for '
     '90% and within 2&times; for 97%'),
    ('floor', 'Floor only',
     'reported nothing, and declares tests inside a loop or <code>forEach</code>, so the '
     'static count is a lower bound and the real number is higher'),
    ('unknown', 'Unknown',
     'reported nothing and has no countable call site. Contributes zero rather than a '
     'guess, so the total is understated by whatever these hold'),
)


def load_worklist():
    if not os.path.exists(WORKLIST):
        sys.exit(f"worklist not found: {WORKLIST}\nRun: python3 tools/wpt_subset.py")
    paths = []
    for line in open(WORKLIST):
        line = line.strip()
        if line and not line.startswith('#'):
            paths.append(line)
    return paths


def subtotal(rec):
    """Subtests the run REPORTED for this file: pass + fail + timeout + notrun.

    This is a count of subtest RESULTS, not of distinct subtests. The runner
    executes a file once per implemented global times once per declared
    `<meta name="variant">` and sums every run into one journal line
    (`FileTally.add` in tests/wpt_runner/main.zig), and the variant never
    reaches `location.search`, so each of a file's variant runs registers the
    file's WHOLE set of subtests instead of the slice the variant names.
    `subtest_model` divides that back out.
    """
    if not rec:
        return 0
    return (rec.get('passed', 0) + rec.get('failed', 0) +
            rec.get('timed_out', 0) + rec.get('notrun', 0))


def load_results():
    """Latest record per path, accumulated across runs.

    Journals are transient - the runner reuses their filenames - so results are
    merged into a persistent state file and read back from there. A path a run
    did not touch keeps its previous result rather than reverting to unrun.

    Also carries `_sub_hw`, the most subtests any run of that file has EVER
    reported. A file that reported 40 subtests last week and crashes today still
    HAS 40, and the journal that saw them is about to be overwritten, so the
    high-water mark is kept in the state file where it survives.
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
                # The high-water mark rises on ANY journal line, superseding or
                # not: what a file once declared, it still declares.
                hw = max(subtotal(rec),
                         (prev or {}).get('_sub_hw', 0), subtotal(prev))
                # Only supersede with something at least as recent, so replaying
                # an old journal cannot roll the picture backwards.
                if prev is None or rec['_mtime'] >= prev.get('_mtime', 0):
                    records[rec['path']] = rec
                records[rec['path']]['_sub_hw'] = hw

    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp_path = STATE + '.tmp'
    with open(tmp_path, 'w') as f:
        json.dump(records, f)
    os.replace(tmp_path, STATE)  # atomic: a crash mid-write cannot truncate it

    return records, files


def area_of(path, depth=2):
    parts = path.split('/')
    return '/'.join(parts[:depth]) if len(parts) > depth else parts[0]


def _read(path):
    try:
        with open(path, errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def _scan_source(path):
    """Variants, implemented globals and a static subtest count for one source.

    The static count is deliberately crude - a count of test-declaring call
    sites - because it is only ever used for a file that has told us nothing.
    What makes it usable is the `loopy` flag beside it: without a loop the count
    is the answer, with one it is a floor.
    """
    full = os.path.join(WPT_ROOT, path)
    txt = _read(full)
    stamp = []
    try:
        st = os.stat(full)
        stamp.append([path, int(st.st_mtime), st.st_size])
    except OSError:
        pass

    variants = max(len(VARIANT_META.findall(txt)) + len(VARIANT_JS.findall(txt)), 1)

    declared = GLOBAL_JS.findall(txt)
    if declared:
        names = [x.strip().lower() for x in ','.join(declared).split(',') if x.strip()]
        # A file none of whose globals are implemented still runs once, and
        # reports one skip - test_parser.zig:runCount does the same.
        globals_ = sum(1 for x in names if x in IMPLEMENTED_GLOBALS) or 1
    elif path.endswith('.any.js'):
        globals_ = 2          # window + worker, parseAnyJs's default
    else:
        globals_ = 1

    # The tests are often declared in an included script, not in the file: every
    # encoding/legacy-mb-* sweep is one `subsetTest` call site in a shared
    # encode-*-common.js. Counting only the file itself would score them zero.
    bodies = [txt]
    base = os.path.dirname(path)
    for ref in SCRIPT_META.findall(txt) + SCRIPT_SRC.findall(txt):
        if 'testharness' in ref or ref.startswith('http'):
            continue
        rel = ref[1:] if ref.startswith('/') else os.path.normpath(os.path.join(base, ref))
        inc = os.path.join(WPT_ROOT, rel)
        if not os.path.exists(inc):
            continue
        bodies.append(_read(inc))
        try:
            st = os.stat(inc)
            stamp.append([rel, int(st.st_mtime), st.st_size])
        except OSError:
            pass

    calls, loopy = 0, False
    for body in bodies:
        hits = len(TEST_CALL.findall(body))
        calls += hits
        if hits and LOOPY.search(body):
            loopy = True

    return {'v': variants, 'g': globals_, 'calls': calls * globals_,
            'loopy': loopy, 'stamp': stamp}


def _stamp_ok(entry):
    stamp = entry.get('stamp') or ()
    if not stamp:
        return False
    for name, mtime, size in stamp:
        try:
            st = os.stat(os.path.join(WPT_ROOT, name))
        except OSError:
            return False
        if int(st.st_mtime) != mtime or st.st_size != size:
            return False
    return True


def load_shape(worklist):
    """Per-source static shape, cached in ESTIMATES and checked against mtimes."""
    try:
        with open(ESTIMATES) as f:
            cache = json.load(f)
    except (OSError, json.JSONDecodeError):
        cache = {}

    shape, rescanned = {}, 0
    for path in worklist:
        entry = cache.get(path)
        if entry is None or not _stamp_ok(entry):
            entry = _scan_source(path)
            rescanned += 1
        shape[path] = entry

    if rescanned or len(cache) != len(shape):
        os.makedirs(os.path.dirname(ESTIMATES), exist_ok=True)
        tmp_path = ESTIMATES + '.tmp'
        with open(tmp_path, 'w') as f:
            json.dump(shape, f)
        os.replace(tmp_path, ESTIMATES)
    return shape, rescanned


def subtest_model(worklist, records, shape):
    """How many subtests each source TARGETS, and how many of them pass.

    The unit is WPT's own: one count per (source, implemented global), with a
    file's `<meta name="variant">` slices folded back together. Variants
    PARTITION a file's subtests - `?1-1000` plus `?1001-2000` is the same set of
    assertions split in two - so they must not multiply the total. Globals do
    multiply it: `foo.any.html` and `foo.any.worker.html` are separate URLs in
    MANIFEST.json with separate results, and worker support is a real axis.

    That distinction is what makes this number differ from the raw sum by 12x.
    The runner sums every (global, variant) run of a file into one journal line,
    and the variant never reaches `location.search`, so `/common/subset-tests.js`
    sees no range and each variant run re-registers the file's WHOLE set:
    euckr-encode-href-errors-han.html declares 23,097 subtests and reports
    554,328, exactly 24x for its 24 variants. Dividing the reported total by the
    variant count comes out EXACT for 250 of the 251 multi-variant files that
    have reported anything, which is the evidence for the model; the one
    exception is noted on the page.

    Five tiers, best evidence first:

      exact    the file ran to OK, so testharness reported every test it declared
      partial  it timed out or errored but still reported subtests - declared-
               but-unrun ones come back NOTRUN - so the count is a LOWER BOUND,
               since declaration itself may have been cut short
      est      it reported nothing; the static count of its call sites, with no
               loop around them. Against the 2,014 straight-line files whose
               real count is known this is EXACT for 90% and within 2x for 97%
      floor    it reported nothing and declares tests inside a loop: a floor
      unknown  it reported nothing and has no countable call site. Contributes
               ZERO rather than a guess, and the file count is disclosed

    `targeted` uses the per-file high-water mark - a file that once reported 40
    subtests still has 40 even if it crashes today - but `passing` uses only the
    CURRENT run. Progress is what passes now, not what passed on the best day.
    """
    model = {}
    for path in worklist:
        sh = shape[path]
        variants = sh['v']
        rec = records.get(path)
        observed = max(subtotal(rec), (rec or {}).get('_sub_hw', 0))
        if observed:
            model[path] = {
                'tier': 'exact' if (rec or {}).get('status') == 'OK' else 'partial',
                'targeted': observed / variants,
                'passing': (rec or {}).get('passed', 0) / variants,
                # Whether the fan-out divided cleanly. It does everywhere but one
                # file, and where it does not the run fan-out did not complete
                # uniformly, so that file's share is approximate.
                'even': variants == 1 or observed % variants == 0,
            }
        elif sh['calls'] == 0:
            model[path] = {'tier': 'unknown', 'targeted': 0.0,
                           'passing': 0.0, 'even': True}
        else:
            model[path] = {'tier': 'floor' if sh['loopy'] else 'est',
                           'targeted': float(sh['calls']), 'passing': 0.0,
                           'even': True}
    return model


def build(worklist, records, shape=None):
    in_subset = set(worklist)
    areas = collections.defaultdict(lambda: collections.Counter())
    model = subtest_model(worklist, records, shape) if shape else {}

    for path in worklist:
        a = area_of(path)
        areas[a]['total'] += 1
        m = model.get(path)
        if m:
            # Floats on purpose: a file's share of a fan-out is not always a
            # whole number, and rounding per FILE would bias the total. Rounding
            # happens once, at the point of display.
            areas[a]['sub_targeted'] += m['targeted']
            areas[a]['sub_passing'] += m['passing']
            areas[a]['tier_' + m['tier']] += 1
            areas[a]['sub_t_' + m['tier']] += m['targeted']
            if not m['even']:
                areas[a]['sub_uneven'] += 1
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
    return areas, in_subset, model


def bar(numer, denom, cls):
    pct = (numer / denom * 100) if denom else 0
    return (f'<div class="bar"><div class="fill {cls}" '
            f'style="width:{pct:.1f}%"></div></div>')


def load_roadmap():
    """docs/roadmap.toml, or None when it is missing or does not parse."""
    try:
        import tomllib
        with open(ROADMAP, 'rb') as f:
            return tomllib.load(f)
    except (OSError, ImportError, ValueError):
        return None


def git_unpushed():
    """Commits on HEAD that origin/main does not have, or None when unknown."""
    try:
        out = subprocess.run(['git', 'rev-list', '--count', 'origin/main..HEAD'], cwd=REPO,
                             capture_output=True, text=True, timeout=5)
        return int(out.stdout.strip()) if out.returncode == 0 else None
    except Exception:
        return None


def area_stats(prefixes, worklist, records):
    """Subset files under any of `prefixes`: total, blocking, clean, unrun."""
    c = collections.Counter()
    for p in worklist:
        if not any(p.startswith(pre) for pre in prefixes):
            continue
        c['total'] += 1
        rec = records.get(p)
        st = status_of(rec)
        if st == 'UNRUN':
            c['unrun'] += 1
        elif st in GATING:
            c['blocking'] += 1
        elif not rec.get('failed') and not rec.get('timed_out'):
            c['clean'] += 1
    return c


def _slope(ys):
    """Least-squares slope of `ys` against their position."""
    n = len(ys)
    mx = (n - 1) / 2
    my = sum(ys) / n
    den = sum((i - mx) ** 2 for i in range(n))
    return sum((i - mx) * (y - my) for i, y in enumerate(ys)) / den if den else 0.0


def heap_trend(min_files=30):
    """Retained-heap growth per file, from the journals that record heap_used_kb.

    One process runs the files of one journal in order, so the slope of its
    heap readings is what each file leaves behind. A journal merged from shards
    interleaves several processes, each with its own heap, and a slope across
    them means nothing - so only a journal whose `index` never decreases, one
    process's records in order, is read. Readings without CRANE_HEAP_GC include
    garbage not yet collected; over dozens of files the slope is retention.
    """
    files = sorted(glob.glob(os.path.join(RESULTS, '*.jsonl')) +
                   glob.glob(os.path.join(RESULTS, '*', '*.jsonl')),
                   key=os.path.getmtime, reverse=True)
    for fn in files:
        base = os.path.basename(fn)
        if base == 'journal.jsonl' and glob.glob(os.path.join(os.path.dirname(fn), 'journal.shard*.jsonl')):
            continue
        ys = []
        last_index = -1
        one_process = True
        for line in open(fn, errors='replace'):
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            idx = rec.get('index', 0)
            if idx < last_index:
                one_process = False
                break
            last_index = idx
            if rec.get('heap_used_kb'):
                ys.append(rec['heap_used_kb'])
        if one_process and len(ys) >= min_files:
            return {'kb_per_file': _slope(ys), 'files': len(ys), 'first_mb': ys[0] / 1024,
                    'last_mb': ys[-1] / 1024,
                    'journal': os.path.relpath(fn, RESULTS)}
    return None


def item_status(items):
    """An infrastructure piece's status, from its items'."""
    states = {i.get('status', 'todo') for i in items}
    if states == {'done'}:
        return 'done'
    if states <= {'todo'}:
        return 'todo'
    return 'doing'


def pill(status):
    label = {'done': 'done', 'doing': 'in progress', 'todo': 'not started'}.get(status, status)
    return f'<span class="pill {html.escape(status)}">{label}</span>'


def render_roadmap(roadmap, worklist, records):
    """The roadmap sections: infrastructure, parallel-work prerequisites, and
    the areas to delegate - each status from the TOML, each number measured."""
    if not roadmap:
        return ''
    infra = roadmap.get('infra', [])
    unpushed = git_unpushed()
    heap = heap_trend()

    status_by_id = {}
    cards = []
    items_done = items_total = 0
    for piece in infra:
        items = piece.get('items', [])
        st = item_status(items)
        status_by_id[piece['id']] = st
        done = sum(1 for i in items if i.get('status') == 'done')
        doing = sum(1 for i in items if i.get('status') == 'doing')
        items_done += done
        items_total += len(items)
        li = ''.join(
            f'<li class="{html.escape(i.get("status", "todo"))}">{html.escape(i["name"])}</li>'
            for i in items)
        live = []
        if piece.get('areas'):
            a = area_stats(piece['areas'], worklist, records)
            live.append(f'<b>{a["blocking"]:,}</b> blocking of {a["total"]:,} subset files in '
                        + ', '.join(f'<code>{html.escape(x)}</code>' for x in piece['areas']))
        if piece.get('metric') == 'heap':
            if heap:
                live.append(f'Retained heap: <b>{heap["kb_per_file"]:+,.0f} KB per file</b> '
                            f'over {heap["files"]:,} files ({heap["first_mb"]:.0f} &rarr; '
                            f'{heap["last_mb"]:.0f} MB) in <code>{html.escape(heap["journal"])}</code>. '
                            f'Flat is the goal.')
            else:
                live.append('Retained heap: no journal with <code>heap_used_kb</code> yet.')
        prog = ''.join(f'<li>{html.escape(x)}</li>' for x in piece.get('progress', []))
        cards.append(f"""
  <div class="rm-card {st}">
    <div class="rm-head"><span class="rm-title">{html.escape(piece['title'])}</span>{pill(st)}</div>
    <div class="rm-bar">{bar(done + doing * 0.5, len(items), 'ok')}<span class="dim">{done} of {len(items)} done</span></div>
    <p class="rm-why">{html.escape(piece.get('why', ''))}</p>
    {''.join(f'<p class="rm-live">{x}</p>' for x in live)}
    <ul class="rm-items">{li}</ul>
    <p class="rm-done"><b>Done when:</b> {html.escape(piece.get('done_when', ''))}</p>
    {f'<details><summary class="dim">Progress</summary><ul class="rm-prog">{prog}</ul></details>' if prog else ''}
  </div>""")

    par_rows = []
    par_done = 0
    for pre in roadmap.get('parallel', []):
        st = pre.get('status', 'todo')
        note = ''
        if pre.get('metric') == 'unpushed' and unpushed is not None:
            st = 'done' if unpushed == 0 else st
            note = f' <span class="dim">&middot; {unpushed:,} commit{"s" if unpushed != 1 else ""} not on origin</span>'
        par_done += st == 'done'
        how = f'<div class="dim rm-how">{html.escape(pre["how"])}</div>' if pre.get('how') else ''
        par_rows.append(f'<li class="{st}">{pill(st)} {html.escape(pre["name"])}{note}{how}</li>')
    parallel_ready = par_done == len(roadmap.get('parallel', []))

    del_rows = []
    ready = 0
    for d in roadmap.get('delegable', []):
        a = area_stats(d.get('areas', []), worklist, records)
        waiting = [n for n in d.get('needs', []) if status_by_id.get(n) != 'done']
        is_ready = not waiting and parallel_ready
        ready += is_ready
        titles = {p['id']: p['title'] for p in infra}
        why = ('ready' if is_ready else
               'waiting on ' + ', '.join(titles.get(n, n) for n in waiting) if waiting else
               'waiting on the parallel-work prerequisites')
        del_rows.append(f"""
      <tr class="{'good' if is_ready else ''}">
        <td class="area">{html.escape(d['name'])}<div class="dim rm-paths">{', '.join(html.escape(x) for x in d.get('areas', []))}</div></td>
        <td class="num">{a['total']:,}</td>
        <td class="num gate">{a['blocking'] or '&middot;'}</td>
        <td class="num ok">{a['clean'] or '&middot;'}</td>
        <td class="rm-wait">{pill('done') if is_ready else ''}<span class="dim">{html.escape(why)}</span></td>
      </tr>""")

    lane_rows = []
    for lane in roadmap.get('lane', []):
        a = area_stats(next((p.get('areas', []) for p in infra if p['id'] == lane.get('infra')), []),
                       worklist, records)
        st = lane.get('status', 'todo')
        branch = f'<div class="dim rm-paths">{html.escape(lane["branch"])}</div>' if lane.get('branch') else ''
        lane_rows.append(f"""
      <tr>
        <td class="area">{html.escape(lane['name'])}{branch}</td>
        <td>{html.escape(lane.get('owner', ''))}</td>
        <td>{pill(st)}</td>
        <td class="num gate">{a['blocking'] or '&middot;'}</td>
        <td class="dim rm-paths">{', '.join(html.escape(x) for x in lane.get('paths', []))}</td>
      </tr>""")
    lanes_html = ''
    if lane_rows:
        lanes_html = f"""
<h2>Lanes <small class="dim">who owns which paths now</small></h2>
<table>
  <thead><tr><th>Lane</th><th>Owner</th><th>Status</th><th>Blocking in its areas</th><th>Claimed paths</th></tr></thead>
  <tbody>{''.join(lane_rows)}</tbody>
</table>
"""

    infra_done = sum(1 for v in status_by_id.values() if v == 'done')
    goal = html.escape(roadmap.get('meta', {}).get('goal', ''))
    return f"""
<h2 class="section">Engine roadmap <small class="dim">docs/roadmap.toml</small></h2>
<p class="dim rm-goal">{goal}</p>
<div class="cards">
  <div class="card"><div class="k">Infrastructure done</div><div class="v">{infra_done}<span class="dim" style="font-size:14px"> / {len(infra)}</span></div></div>
  <div class="card"><div class="k">Infrastructure items</div><div class="v">{items_done}<span class="dim" style="font-size:14px"> / {items_total}</span></div></div>
  <div class="card"><div class="k">Parallel-work prerequisites</div><div class="v">{par_done}<span class="dim" style="font-size:14px"> / {len(par_rows)}</span></div></div>
  <div class="card"><div class="k">Areas ready to hand out</div><div class="v">{ready}<span class="dim" style="font-size:14px"> / {len(del_rows)}</span></div></div>
</div>

<h2>Engine infrastructure <small class="dim">finish before work goes parallel</small></h2>
<div class="rm-grid">{''.join(cards)}</div>

<h2>Prerequisites for parallel work</h2>
<div class="panel"><ul class="rm-par">{''.join(par_rows)}</ul></div>
{lanes_html}
<h2>Areas to hand out <small class="dim">once what they need is done</small></h2>
<table>
  <thead><tr><th>Area</th><th>Subset</th><th>Blocking</th><th>Clean</th><th>Readiness</th></tr></thead>
  <tbody>{''.join(del_rows)}</tbody>
</table>
"""


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
        'sub_targeted': round(tot['sub_targeted']),
        'sub_passing': round(tot['sub_passing']),
        'tiers': {t: tot['tier_' + t] for t in TIERS},
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


def rebuild_history(worklist, records, shape=None):
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
        areas, _, _ = build(worklist, seen, shape)
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
            'sub_targeted': round(tot['sub_targeted']),
            'sub_passing': round(tot['sub_passing']),
            'tiers': {t: tot['tier_' + t] for t in TIERS},
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
    if prev is None or cur.get(key) is None or prev.get(key) is None:
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
        st_, sp_ = g.get('sub_targeted'), g.get('sub_passing')
        if st_ is None:
            subcell = '<span class="dim">&mdash;</span>'
        else:
            pct_ = (sp_ / st_ * 100) if st_ else 0.0
            subcell = (f'{sp_:,} {_delta(g, prev, "sub_passing", False)}'
                       f'<br><span class="dim">{pct_:.2f}% of {st_:,}</span>')
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
        <td class="num hide-sm">{subcell}</td>
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
The same applies to the subtest percentage, and harder: a newly run file adds its whole
declared set to the denominator at once, so the % can drop sharply on a generation in which
nothing got worse.
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


def render(areas, worklist, records, files, out_path, history=None, shape=None, roadmap=None):
    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)

    # The number the page argues against: every subtest result the runner
    # reported, variant fan-out and all.
    raw_reported = sum(subtotal(records.get(p)) for p in worklist)
    raw_ratio = raw_reported / tot['sub_targeted'] if tot['sub_targeted'] else 0
    even_multi = all_multi = 0
    if shape:
        for p in worklist:
            if shape[p]['v'] > 1 and subtotal(records.get(p)):
                all_multi += 1
                if subtotal(records.get(p)) % shape[p]['v'] == 0:
                    even_multi += 1

    total = len(worklist)
    run = tot['run']
    gating = tot['gating']
    clean = tot['clean']
    unrun = tot['unrun']
    gate_met = (run > 0 and gating == 0 and unrun == 0)

    # The two senses of "how far along are we". They answer different questions
    # and routinely disagree, so the page shows both rather than picking one.
    sub_targeted = round(tot['sub_targeted'])
    sub_passing = round(tot['sub_passing'])
    sub_pct = (sub_passing / sub_targeted * 100) if sub_targeted else 0.0
    clean_pct = (clean / total * 100) if total else 0.0

    comp_rows = []
    for tier, label, why in COMPOSITION:
        n_files = tot['tier_' + tier]
        n_subs = round(tot['sub_t_' + tier])
        shown = '&mdash;' if tier == 'unknown' else f'{n_subs:,}'
        comp_rows.append(
            f'<tr><td class="num compn">{shown}</td>'
            f'<td class="compl">{label}</td>'
            f'<td class="num dim">{n_files:,} files</td>'
            f'<td class="dim compw">{why}</td></tr>')

    # The percentage is diluted by coverage, so point at the evidence for that
    # rather than asserting it - and read the evidence out of the history, which
    # moves, instead of writing today's numbers into the prose.
    cov_note = ''
    usable = [g for g in (history or {}).get('generations', []) if g.get('sub_targeted')]
    if len(usable) >= 2:
        peak = max(usable, key=lambda g: g['sub_passing'] / g['sub_targeted'])
        peak_pct = peak['sub_passing'] / peak['sub_targeted'] * 100
        if peak_pct > sub_pct + 0.005:
            cov_note = (f' It read {peak_pct:.2f}% at generation {peak["n"]}, when only '
                        f'{peak["run"]:,} of {peak["total"]:,} sources had run and just '
                        f'{peak["sub_targeted"]:,} subtests were known to exist.')

    uneven = tot['sub_uneven']
    uneven_note = (f' {uneven:,} file{"s" if uneven != 1 else ""} did not divide evenly, '
                   f'so that share is approximate.' if uneven else '')
    subtest_html = f"""
<div class="panel">
  <h2 class="panelh">Subtests targeted</h2>
  <div class="headline">{sub_passing:,}<span class="dim"> of </span>{sub_targeted:,}
    <span class="pct">{sub_pct:.2f}%</span></div>
  <div class="dim sub2">Subtests passing, of the subtests the 0.1 worklist targets.
    Counted once per source per implemented global, with a file's
    <code>&lt;meta name="variant"&gt;</code> slices folded back together &mdash; variants
    <em>partition</em> a file's subtests, they do not multiply them.
    The other sense of &ldquo;progressed&rdquo; is whole files:
    <b>{clean:,} of {total:,}</b> ran clean, <b class="pct2">{clean_pct:.2f}%</b>.
    <br><b>This percentage falls when coverage grows.</b> A subtest only exists once its
    file runs, so every newly run file adds its whole declared set to the denominator
    before it adds anything to the numerator.{cov_note}
    Read it against the generation table, never alone.</div>
  <table class="comp"><tbody>{''.join(comp_rows)}</tbody></table>
  <p class="dim note">The denominator is <b>not</b> the raw sum of reported subtest
    results, which is {raw_reported:,} &mdash; about {raw_ratio:.0f}&times; larger. The runner
    executes a file once per implemented global times once per declared variant and sums
    every run into one journal line, and the variant never reaches
    <code>location.search</code>, so <code>/common/subset-tests.js</code> sees no range and
    each variant run re-registers the file's <em>whole</em> set:
    <code>euckr-encode-href-errors-han.html</code> declares 23,097 subtests and reports
    554,328, exactly 24&times; for its 24 variants. Dividing back out by the variant count
    comes out <b>exact</b> for {even_multi:,} of the {all_multi:,} multi-variant files that have
    reported anything, which is the evidence for the model.{uneven_note}
    A file's target uses the most subtests any run has <em>ever</em> reported for it;
    its passes use only the current run.</p>
</div>"""

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
        <td class="num hide-sm">{round(c['sub_passing']):,}<span class="dim"> / {round(c['sub_targeted']):,}</span></td>
        <td>{bar(c['clean'], c['total'], 'ok')}</td>
      </tr>""")

    journals = ''.join(
        f'<li><code>{html.escape(os.path.basename(f))}</code> '
        f'<span class="dim">{datetime.datetime.fromtimestamp(os.path.getmtime(f)):%Y-%m-%d %H:%M}</span></li>'
        for f in files[-8:]) or '<li class="dim">none found</li>'

    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')

    history_html = render_history(history) if history else ''
    roadmap_html = render_roadmap(roadmap, worklist, records)
    doc = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Crane Engine Progress</title>
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

  .panel {{ background:var(--panel); border:1px solid var(--line); border-radius:10px;
    padding:18px 22px 14px; margin-bottom:28px }}
  .panelh {{ margin:0 0 8px; font-size:15px; letter-spacing:.02em;
    text-transform:uppercase; color:var(--dim) }}
  .headline {{ font-size:30px; font-weight:650; letter-spacing:-.02em;
    font-variant-numeric:tabular-nums }}
  .headline .dim {{ font-size:18px; font-weight:400 }}
  .pct {{ color:var(--accent); margin-left:10px }}
  .pct2 {{ color:var(--accent) }}
  .sub2 {{ font-size:13px; margin:6px 0 14px; max-width:78ch }}
  table.comp {{ border:0; background:transparent; font-size:12.5px }}
  table.comp td {{ border-bottom:1px solid var(--line); padding:7px 10px 7px 0;
    vertical-align:top; text-align:left }}
  table.comp tr:last-child td {{ border-bottom:0 }}
  td.compn {{ text-align:right; font-weight:650; white-space:nowrap; width:1%;
    font-variant-numeric:tabular-nums }}
  td.compl {{ white-space:nowrap; width:1% }}
  td.compw {{ line-height:1.45 }}
  .note {{ font-size:12px; margin:12px 0 0; max-width:88ch; line-height:1.5 }}
  @media (max-width:640px) {{ td.compw {{ display:none }} }}

  h2.section {{ font-size:18px; margin:40px 0 4px; }}
  .rm-goal {{ font-size:13.5px; max-width:80ch; margin:0 0 16px }}
  .rm-grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(320px,1fr));
    gap:12px; margin-bottom:28px }}
  .rm-card {{ background:var(--panel); border:1px solid var(--line); border-radius:10px;
    padding:14px 16px; border-left:4px solid var(--dimline) }}
  .rm-card.done {{ border-left-color:var(--ok) }}
  .rm-card.doing {{ border-left-color:var(--warn) }}
  .rm-head {{ display:flex; justify-content:space-between; gap:10px; align-items:baseline }}
  .rm-title {{ font-weight:650 }}
  .rm-bar {{ display:flex; gap:10px; align-items:center; font-size:12px; margin:6px 0 8px }}
  .rm-why, .rm-done, .rm-live {{ font-size:12.5px; margin:6px 0; line-height:1.45 }}
  .rm-live {{ color:var(--ink) }}
  .rm-items, .rm-prog, .rm-par {{ margin:6px 0; padding-left:0; list-style:none; font-size:12.5px }}
  .rm-items li {{ padding:2px 0 2px 20px; position:relative }}
  .rm-items li::before {{ position:absolute; left:2px; font-weight:700 }}
  .rm-items li.done::before {{ content:"\\2713"; color:var(--ok) }}
  .rm-items li.doing::before {{ content:"\\25D0"; color:var(--warn) }}
  .rm-items li.todo::before {{ content:"\\25CB"; color:var(--dim) }}
  .rm-items li.todo {{ color:var(--dim) }}
  .rm-prog li {{ padding:2px 0; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:11.5px }}
  .rm-par li {{ padding:5px 0; border-bottom:1px solid var(--line) }}
  .rm-par li:last-child {{ border-bottom:0 }}
  .rm-paths {{ font-size:11px }}
  .rm-how {{ font-size:12px; margin:2px 0 6px 0; line-height:1.4 }}
  td.rm-wait {{ text-align:left; font-size:12.5px }}
  .pill {{ display:inline-block; font-size:10.5px; font-weight:650; letter-spacing:.03em;
    text-transform:uppercase; padding:1px 7px; border-radius:9px; margin-right:6px;
    border:1px solid currentColor; white-space:nowrap }}
  .pill.done {{ color:var(--ok) }}
  .pill.doing {{ color:var(--warn) }}
  .pill.todo {{ color:var(--dim) }}
</style></head><body><div class="wrap">

<h1>Crane engine progress</h1>
<div class="sub">Generated {now} &middot; WPT: {total:,} sources in the 0.1 subset
  &middot; roadmap: <code>docs/roadmap.toml</code> &middot; <code>tools/wpt_progress.py</code></div>

<div class="gate">
  <h2>WPT 0.1 release gate</h2>
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
  <div class="card"><div class="k">Subtests passing</div><div class="v">{sub_passing:,}<span class="dim" style="font-size:14px"> / {sub_targeted:,}</span></div></div>
</div>

{roadmap_html}

<h2 class="section">WPT detail</h2>

{subtest_html}

{history_html}

<h2>By area <small class="dim">current state</small></h2>
<table>
  <thead><tr>
    <th>Area</th><th>Subset</th><th>Run</th><th>Blocking</th>
    <th>Timeout</th><th>Crash</th><th>Clean</th>
    <th class="hide-sm">Partial</th><th class="hide-sm">Unrun</th>
    <th class="hide-sm">Subtests&nbsp;pass&nbsp;/&nbsp;target</th>
    <th class="hide-sm">Clean&nbsp;%</th>
  </tr></thead>
  <tbody>{''.join(rows)}</tbody>
</table>

<footer>
  <strong>Subtests targeted</strong> is one count per source per implemented global
  (window, worker), with a file's <code>&lt;meta name="variant"&gt;</code> slices folded
  back together, since a variant partitions a file's subtests rather than adding any.
  Where a file has never reported a subtest the number is estimated from its source and
  labelled as such above; nothing estimated is presented as measured.
  <br><br><strong>Blocking</strong> = timeouts + crashes + errors. That is the gate:
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
    shape, rescanned = load_shape(worklist)
    areas, _, model = build(worklist, records, shape)
    if '--rebuild-history' in sys.argv:
        rebuild_history(worklist, records, shape)
        print(f"history rebuilt from per-record timestamps -> {HISTORY}")
    history = record_generation(worklist, records, areas)
    gate_met, gating, run, total, clean = render(
        areas, worklist, records, files, out, history, shape, load_roadmap())

    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)
    targeted, passing = round(tot['sub_targeted']), round(tot['sub_passing'])
    print(f"{run:,} of {total:,} sources run  |  {gating:,} blocking  |  {clean:,} clean")
    print(f"subtests: {passing:,} passing of {targeted:,} targeted  "
          f"({passing / targeted * 100 if targeted else 0:.2f}%)  |  "
          f"files clean {clean / total * 100 if total else 0:.2f}%")
    print('  composition: ' + '  '.join(
        f"{t}={round(tot['sub_t_' + t]):,}/{tot['tier_' + t]}f" for t in TIERS))
    if rescanned:
        print(f"  (rescanned {rescanned:,} sources -> {ESTIMATES})")
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
