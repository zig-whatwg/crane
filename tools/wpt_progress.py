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
missing. Publication additionally requires an explanation for every per-file
passing-subtest loss, or the explicit --allow-unexplained override.
"""
import json
import glob
import os
import posixpath
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
GATING = {'TIMEOUT', 'CRASH', 'ERROR', 'EXTERNAL-TIMEOUT', 'PRECONDITION_FAILED', 'NONE-PASSED'}

# A derived status, not one the runner writes: the harness finished (OK) but not
# one of the file's subtests passed. It blocks the gate like a timeout - "OK" said
# only that the page ran to the end, and 1,053 files were OK with nothing passing
# when this rule was added (2026-09-30, the user's decision). A file with no
# subtests at all is not NONE-PASSED: there was nothing to fail.
NONE_PASSED = 'NONE-PASSED'
# Which rule `last_statuses` in the history was computed under. A generation that
# follows a rule change files OK -> NONE-PASSED as "reclassified", not "regressed":
# the file did not get worse, the gate got stricter.
GATE_RULE = 2


def alt_rates(worklist, records):
    """Two readings the subtest headline hides: the pass rate outside encoding/ and
    the mean per-file pass rate, both from the journal's own counts.

    encoding/ held ~87% of all subtests when these were added (2026-09-30), so the
    headline percentage is mostly one directory; a per-file mean weights every file
    the same, however many subtests it has.
    """
    np_pass = np_all = 0
    rates = []
    for p in worklist:
        rec = records.get(p)
        if not rec:
            continue
        n = rec.get('passed', 0) + rec.get('failed', 0) + rec.get('timed_out', 0) + rec.get('notrun', 0)
        if n == 0:
            continue
        rates.append(rec.get('passed', 0) / n)
        if not p.startswith('encoding/'):
            np_pass += rec.get('passed', 0)
            np_all += n
    return (np_pass / np_all * 100 if np_all else 0.0,
            sum(rates) / len(rates) * 100 if rates else 0.0)


def gate_status(rec, path=None):
    """The status the gate judges `rec` by: the runner's, or NONE-PASSED - or
    EXEMPT, when `path` is listed in the gate's exemptions and would block."""
    st = rec.get('status', 'ERROR')
    if st == 'OK' and rec.get('passed', 0) == 0 and (
            rec.get('failed', 0) + rec.get('timed_out', 0) + rec.get('notrun', 0)) > 0:
        st = NONE_PASSED
    # Anything but OK blocks (an unknown status included), so anything but OK
    # is what an exemption turns into EXEMPT.
    if path is not None and path in EXEMPTIONS and st != 'OK':
        return EXEMPT
    return st


# Reference runs (lane chromeref1; the user, 2026-11-03: "I want the chrome results on the
# same files represented in our progress report"): another engine's results on the same
# worklist - `wpt run chrome` over the worklist's test URLs - joined to its sources through the
# manifest by `zig build wpt-site -- import-reference` (tools/wpt_site/reference.zig) into
# wpt-results/reference/<run>/reference.json. They are shown beside Crane's and never counted
# as Crane's: nothing under wpt-results/reference/ is a journal, and a journal or state record
# whose `engine` is not Crane's is refused wherever it sits, with a message. Every line Crane's
# runner writes has no `engine`; every record of a reference run carries its own.
REFERENCE_SUBDIR = 'reference'
REFERENCE_FORMAT = 'crane-wpt-reference/1'


def is_crane(rec):
    """Whether a record may be counted as Crane's: no `engine` (the runner's own lines) or 'crane'."""
    return rec.get('engine') in (None, 'crane')


# The WPT runner's two builds (tests/wpt_runner/build_mode.zig RunnerBuild; the user, 2026-11-09:
# WPT runs Crane only "with the exact same configuration and memory setup that Crane would have
# running in a production environment"). Each journal record names the build that wrote it; only
# the PRODUCTION run is published. A record naming none predates the split (the hybrid runner of
# generation 213 and before).
BUG_FINDING = 'bug-finding'
CONFIGURATION_CHANGE_PRODUCTION = 'configuration change: production build'


def is_bug_finding(rec):
    """Whether a record is the bug-finding run's: never published, never timed."""
    return rec.get('build') == BUG_FINDING


def generation_build(worklist, records):
    """'production' when every worklist file with a record has the production run's, else None
    (the hybrid runner's records, or a mix while a production sweep has not covered the worklist)."""
    recs = [records[p] for p in worklist if p in records]
    if recs and all(r.get('build') == 'production' for r in recs):
        return 'production'
    return None


def configuration_change(previous_generation, build):
    """The marker the first production generation carries (the site draws it on the history), or None."""
    if build != 'production':
        return None
    if previous_generation is not None and previous_generation.get('build') == 'production':
        return None
    return CONFIGURATION_CHANGE_PRODUCTION


def engine_label(engine):
    return {'chrome': 'Chrome', 'firefox': 'Firefox', 'safari': 'Safari'}.get(engine, engine)


# The gate's exemptions (the user, 2026-10-17 and 2026-11-08; AGENTS.md "The 0.1
# gate", in full in .claude/rules/wpt-workflow.md): worklist files omitted from the
# blocking count, each listed with its evidence in tools/wpt_gate_exemptions.txt
# (its header is the format; the public site, tools/wpt_site/model.zig, reads it by
# the same rules). Three kinds: `intentional` - ALL THREE of Chrome, Firefox and
# Safari intentionally deviate from the spec the file tests (an entry with no kind
# is this one, as every entry was before kinds) - `test-bug` - the file fails
# identically in all three because of a test bug filed upstream, exempt until that
# bug is resolved - and `needs-renderer` - the file fails ONLY because no renderer
# answers geometry (the user, 2026-11-09): it still runs and shows, but does not
# block 0.1 until a renderer exists. A listed file that would block is EXEMPT:
# counted in its kind's own group, never as blocking. One that does not block keeps its standing. An invalid
# entry stops the report - an exemption is never applied, or dropped, silently.
EXEMPTIONS_FILE = os.path.join(REPO, 'tools', 'wpt_gate_exemptions.txt')
EXEMPT = 'EXEMPT'
EXEMPTION_KEYS = ('why', 'spec', 'chrome.result', 'chrome.intent', 'firefox.result',
                  'firefox.intent', 'safari.result', 'safari.intent')
# The keys of each kind: every one required, no other allowed (`kind` itself is
# optional for an intentional entry, which predates kinds).
TEST_BUG_KEYS = ('kind', 'why', 'upstream', 'chrome.result', 'firefox.result', 'safari.result', 'revisit')
# `why`: why the failing assertion needs a layout box; `assertion`: that assertion,
# as the run reports it.
NEEDS_RENDERER_KEYS = ('kind', 'why', 'assertion')
KIND_KEYS = {'intentional': ('kind',) + EXEMPTION_KEYS, 'test-bug': TEST_BUG_KEYS,
             'needs-renderer': NEEDS_RENDERER_KEYS}
# What an entry of each kind is missing without one of its keys.
KIND_NEEDS = {
    'intentional': "an exemption needs the spec and every browser's evidence",
    'test-bug': "a test-bug exemption needs the upstream issue, every browser's result and when to revisit",
    'needs-renderer': 'a needs-renderer exemption needs the failing assertion and why it needs a layout box',
}
ALL_EXEMPTION_KEYS = set(EXEMPTION_KEYS) | set(TEST_BUG_KEYS) | set(NEEDS_RENDERER_KEYS)
_WPT_ISSUE = re.compile(r'https://github\.com/web-platform-tests/wpt/(issues|pull)/\d+$')
_REVISIT = re.compile(r'when (\S+) is resolved$')
_COUNTS = re.compile(r'wpt\.fyi run \d+: *(\d+/\d+)')
BROWSERS = (('chrome', 'Chrome'), ('firefox', 'Firefox'), ('safari', 'Safari'))
_URL = re.compile(r'https?://\S+$')
_RESULT = re.compile(r'wpt\.fyi run \d+: *\d+/\d+')
# path -> entry (key -> value), set by main() from EXEMPTIONS_FILE.
EXEMPTIONS = {}


class ExemptionError(Exception):
    pass


def parse_exemptions(text, worklist):
    """tools/wpt_gate_exemptions.txt -> {path: {key: value}} (with 'kind' always set);
    ExemptionError on any invalid entry (with its line), including a path outside
    `worklist`."""
    out = {}
    cur = None

    def finish(entry):
        vals, lines = entry['values'], entry['lines']
        # No kind: intentional, the one kind before the user's 2026-11-08 ruling.
        kind = vals.get('kind', 'intentional')
        keys = KIND_KEYS[kind]
        article = 'an' if kind == 'intentional' else 'a'
        for k in vals:
            if k not in keys:
                raise ExemptionError(f'line {lines[k]}: [{entry["path"]}]: "{k}" is not a key of {article} {kind} exemption')
        for k in keys:
            if k != 'kind' and k not in vals:
                raise ExemptionError(f"line {entry['line']}: [{entry['path']}]: missing \"{k}\" - {KIND_NEEDS[kind]}")
        if kind == 'test-bug':
            if _REVISIT.match(vals['revisit']).group(1) != vals['upstream']:
                raise ExemptionError(f'line {lines["revisit"]}: [{entry["path"]}]: revisit must read '
                                     f'"when {vals["upstream"]} is resolved"')
            # "Fails IDENTICALLY in Chrome, Firefox and Safari": the same passes of the same total.
            counts = [_COUNTS.match(vals[b + '.result']).group(1) for b, _ in BROWSERS]
            if len(set(counts)) != 1:
                raise ExemptionError(f"line {entry['line']}: [{entry['path']}]: a test-bug exemption needs the same "
                                     f"result in all three browsers (Chrome {counts[0]}, Firefox {counts[1]}, Safari {counts[2]})")
        out[entry['path']] = dict(vals, kind=kind)

    for n, raw in enumerate(text.split('\n'), 1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            inner = line[1:-1] if line.endswith(']') else ''
            if not inner or any(ch in inner for ch in ' \t[]'):
                raise ExemptionError(f'line {n}: "{line}": expected [path], a worklist path in brackets')
            if cur:
                finish(cur)
            if inner in out:
                raise ExemptionError(f'line {n}: [{inner}] is listed twice')
            cur = {'path': inner, 'line': n, 'values': {}, 'lines': {}}
            continue
        if '=' not in line:
            raise ExemptionError(f'line {n}: "{line}": expected key = value')
        key, value = (x.strip() for x in line.split('=', 1))
        if cur is None:
            raise ExemptionError(f'line {n}: "{key}" before any [path]')
        if key not in ALL_EXEMPTION_KEYS:
            raise ExemptionError(f'line {n}: [{cur["path"]}]: unknown key "{key}"')
        if key in cur['values']:
            raise ExemptionError(f'line {n}: [{cur["path"]}]: "{key}" given twice')
        if not value:
            raise ExemptionError(f'line {n}: [{cur["path"]}]: "{key}" is empty')
        if key.endswith('.result') and not _RESULT.match(value):
            raise ExemptionError(f'line {n}: [{cur["path"]}]: {key} must read "wpt.fyi run <id>: <passes>/<total>"')
        if (key == 'spec' or key.endswith('.intent')) and not _URL.match(value):
            raise ExemptionError(f'line {n}: [{cur["path"]}]: {key} must be an http(s) URL')
        if key == 'kind' and value not in KIND_KEYS:
            raise ExemptionError(f'line {n}: [{cur["path"]}]: kind must be intentional, test-bug or needs-renderer, not "{value}"')
        if key == 'upstream' and not _WPT_ISSUE.match(value):
            raise ExemptionError(f'line {n}: [{cur["path"]}]: upstream must be a web-platform-tests issue or pull '
                                 'request (https://github.com/web-platform-tests/wpt/issues/<n> or /pull/<n>)')
        if key == 'revisit' and not _REVISIT.match(value):
            raise ExemptionError(f'line {n}: [{cur["path"]}]: revisit must read "when <upstream> is resolved"')
        cur['values'][key] = value
        cur['lines'][key] = n
    if cur:
        finish(cur)
    in_worklist = set(worklist)
    for path in out:
        if path not in in_worklist:
            raise ExemptionError(f'[{path}]: an exempt path is not in the worklist')
    return out


def load_exemptions(worklist, path=EXEMPTIONS_FILE):
    """The exemptions file, validated; exits loudly when it is invalid."""
    try:
        with open(path) as f:
            text = f.read()
    except FileNotFoundError:
        return {}
    try:
        return parse_exemptions(text, worklist)
    except ExemptionError as err:
        sys.exit(f'wpt_progress: {os.path.relpath(path, REPO)}: {err}')


def render_exempt(records, worklist):
    """The exempt groups, one per kind: each listed file, its standing, and its evidence."""
    if not EXEMPTIONS:
        return ''
    out = ''
    intentional = [(p, e) for p, e in EXEMPTIONS.items() if e['kind'] == 'intentional']
    test_bug = [(p, e) for p, e in EXEMPTIONS.items() if e['kind'] == 'test-bug']
    needs_renderer = [(p, e) for p, e in EXEMPTIONS.items() if e['kind'] == 'needs-renderer']
    if intentional:
        items = []
        for path, e in intentional:
            rec = records.get(path)
            st = status_of(rec, path)
            ev = ''.join(
                f'<li>{label}: {html.escape(e[key + ".result"])}; intent: '
                f'<a href="{html.escape(e[key + ".intent"])}">{html.escape(e[key + ".intent"])}</a></li>'
                for key, label in BROWSERS)
            items.append(
                f'<li><code>{html.escape(path)}</code> <span class="dim">{html.escape(st)}</span>'
                f'<div>{html.escape(e["why"])}</div>'
                f'<ul class="samples"><li>spec: <a href="{html.escape(e["spec"])}">{html.escape(e["spec"])}</a></li>{ev}</ul></li>')
        n = sum(1 for p, _ in intentional if status_of(records.get(p), p) == EXEMPT)
        out += f"""
<div class="panel">
  <h2 class="panelh">Exempt (all three browsers intentionally deviate)</h2>
  <div class="dim sub2"><b>{n:,}</b> files that would block are not counted as blocking: all three of
    Chrome, Firefox and Safari intentionally deviate from the spec each tests, with the evidence
    below (<code>tools/wpt_gate_exemptions.txt</code>). A listed file that does not block keeps its standing.</div>
  <ol>{''.join(items)}</ol>
</div>"""
    if test_bug:
        items = []
        for path, e in test_bug:
            st = status_of(records.get(path), path)
            ev = ''.join(f'<li>{label}: {html.escape(e[key + ".result"])}</li>' for key, label in BROWSERS)
            items.append(
                f'<li><code>{html.escape(path)}</code> <span class="dim">{html.escape(st)}</span>'
                f'<div>{html.escape(e["why"])}</div>'
                f'<ul class="samples"><li>upstream: <a href="{html.escape(e["upstream"])}">{html.escape(e["upstream"])}</a></li>'
                f'{ev}<li>revisit: {html.escape(e["revisit"])}</li></ul></li>')
        n = sum(1 for p, _ in test_bug if status_of(records.get(p), p) == EXEMPT)
        out += f"""
<div class="panel">
  <h2 class="panelh">Exempt until an upstream test bug is fixed</h2>
  <div class="dim sub2"><b>{n:,}</b> files that would block are not counted as blocking until the bug in the
    test is resolved: Chrome, Firefox and Safari fail each identically because of it, and it is filed with
    web-platform-tests (<code>tools/wpt_gate_exemptions.txt</code>). When the upstream issue is resolved the
    exemption ends and the file is revisited. A listed file that does not block keeps its standing.</div>
  <ol>{''.join(items)}</ol>
</div>"""
    if needs_renderer:
        items = []
        for path, e in needs_renderer:
            st = status_of(records.get(path), path)
            items.append(
                f'<li><code>{html.escape(path)}</code> <span class="dim">{html.escape(st)}</span>'
                f'<div>{html.escape(e["why"])}</div>'
                f'<ul class="samples"><li>failing assertion: <code>{html.escape(e["assertion"])}</code></li></ul></li>')
        n = sum(1 for p, _ in needs_renderer if status_of(records.get(p), p) == EXEMPT)
        out += f"""
<div class="panel">
  <h2 class="panelh">Exempt until a renderer answers geometry</h2>
  <div class="dim sub2"><b>{n:,}</b> files that would block are not counted as blocking until Crane has a renderer:
    each fails only because no renderer answers geometry - a layout box's size or position - with the failing
    assertion and why it needs a layout box below (<code>tools/wpt_gate_exemptions.txt</code>; the user,
    2026-11-09). They still run and show. A listed file that does not block keeps its standing.</div>
  <ol>{''.join(items)}</ol>
</div>"""
    return out


LOSS_DISPOSITIONS_FILE = os.path.join(REPO, 'tools', 'wpt_loss_dispositions.txt')
LOSS_KEYS = {
    'flake': {'pair.1', 'pair.2', 'pair.3'},
    'user-ruling': {'date', 'decision'},
    'upstream-test-change': {'wpt.before', 'wpt.after'},
    'fixed': {'commit', 'test', 'repro'},
    'timing-bound': {'tick_us', 'gap_us', 'pass_rate', 'condition', 'measured_at', 'paths'},
}


# The `fixed` kind (lane flaky5, 2026-11-05): under the one-flake rule a repeat flake
# is a bug, and what explains its loss is the bug's fix - a commit of this repository,
# merged (an ancestor of HEAD), whose own tree holds its red test, with the failure
# counts under the reproduction before and after it. It explains the loss only in a
# generation whose head does NOT contain the fix: the same loss once the fix is in is
# the bug again, and unexplained. Every answer git cannot give is the unexplained one.
_GIT_ANSWERS = {}


def _git_ok(repo, *args):
    """Whether `git <args>` succeeds in `repo` (cached: the answers name commits)."""
    key = (repo, args)
    if key not in _GIT_ANSWERS:
        try:
            _GIT_ANSWERS[key] = subprocess.run(['git', *args], cwd=repo, capture_output=True,
                                               timeout=20).returncode == 0
        except (OSError, subprocess.SubprocessError):
            _GIT_ANSWERS[key] = False
    return _GIT_ANSWERS[key]


def test_in_commit(commit, test, repo):
    """Whether red test `test` is in `commit`'s tree. A Crane test lives in the WPT fork
    (tests/wpt/crane/, a submodule): it is in the commit when the tests/wpt revision that
    commit records holds it - the integrator commits a lane's Crane tests to the fork and
    bumps the submodule at the merge, so that merge-side commit is where the fix and its
    test first stand together (the integrator, 2026-11-10: lane docopen1's do1- test)."""
    if test.startswith('tests/wpt/'):
        rest = test[len('tests/wpt/'):]
        if not rest.startswith('crane/'):
            return False   # only Crane's own tests; an upstream file is never a red test of ours
        try:
            out = subprocess.run(['git', 'ls-tree', commit, '--', 'tests/wpt'], cwd=repo,
                                 capture_output=True, text=True, timeout=20)
        except (OSError, subprocess.SubprocessError):
            return False
        match = re.fullmatch(r'160000 commit ([0-9a-f]{40})\ttests/wpt\n?', out.stdout)
        if out.returncode != 0 or not match:
            return False
        return _git_ok(os.path.join(repo, 'tests', 'wpt'), 'cat-file', '-e', f'{match.group(1)}:{rest}')
    return _git_ok(repo, 'cat-file', '-e', f'{commit}:{test}')


def git_is_commit(commit, repo):
    return bool(commit) and _git_ok(repo, 'cat-file', '-e', f'{commit}^{{commit}}')


def git_contains(head, commit, repo):
    """True when `head` contains `commit` (is it, or a descendant), False when it does not;
    None when either is not a commit of `repo` - nothing is known."""
    if not head or not re.fullmatch(r'[0-9A-Za-z_./-]+', head) or not git_is_commit(head, repo) \
            or not git_is_commit(commit, repo):
        return None
    return _git_ok(repo, 'merge-base', '--is-ancestor', commit, head)


# The `timing-bound` kind (the user, 2026-11-06; lane flaky6): a file whose result
# provably depends on whether a gap shorter than Crane's coarsening tick crosses a tick
# - two marks the spec puts back to back, on a clock floored to 125 us. Its evidence is
# the tick, the measured gap (min / p50 / max, the median below the tick), the pass rate
# under the condition that exposes it (both outcomes seen), the merged commit it was
# measured at, and the code the gap runs through. It explains the path's losses in its
# own generation and every later one, so a flip no longer blocks publication; it puts
# the file on the progress page's watch list; and it is STALE - a warning, never a
# block - once a commit after the measurement touches that code, which may have moved
# the gap. It is not a flake: the one-flake rule does not count it.
def timing_bound_for(path, generation, dispositions):
    """The latest timing-bound entry for `path` recorded at or before `generation`."""
    entries = [e for (p, g), e in dispositions.items()
               if p == path and g <= generation and e['kind'] == 'timing-bound']
    return max(entries, key=lambda e: int(e['generation'])) if entries else None


def timing_bound_stale(entry, repo=None, head='HEAD'):
    """The commits after `entry`'s measurement, up to `head`, that touch a path it lists
    (short ids, newest first): non-empty means the gap may have moved. Git failing to
    answer is reported as a stale mark too, never as fresh."""
    paths = [p.strip() for p in entry['paths'].split(',') if p.strip()]
    try:
        out = subprocess.run(['git', 'log', '--format=%h', f'{entry["measured_at"]}..{head}', '--', *paths],
                             cwd=repo or REPO, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return ['?']
    if out.returncode != 0:
        return ['?']
    return out.stdout.split()


def render_timing_bound(dispositions, repo=None, head='HEAD'):
    """The progress page's timing-bound watch list: every such entry with its evidence,
    marked STALE when code it runs through changed after its measurement."""
    entries = sorted((key, e) for key, e in dispositions.items() if e['kind'] == 'timing-bound')
    if not entries:
        return ''
    items = []
    for (path, _), e in entries:
        stale = timing_bound_stale(e, repo=repo, head=head)
        mark = (f' <b>STALE</b> <span class="dim">(changed since: {html.escape(", ".join(stale))})</span>'
                if stale else '')
        items.append(
            f'<li><code>{html.escape(path)}</code> <span class="dim">since generation {e["generation"]}</span>{mark}'
            f'<div>{html.escape(e["why"])}</div><ul class="samples">'
            f'<li>condition: {html.escape(e["condition"])}</li>'
            f'<li>gap: {html.escape(e["gap_us"])} us against a {html.escape(e["tick_us"])} us tick; '
            f'passes {html.escape(e["pass_rate"])} under the condition</li>'
            f'<li>measured at <code>{html.escape(e["measured_at"])}</code>; runs through '
            f'{html.escape(e["paths"])}</li></ul></li>')
    return f"""
<div class="panel">
  <h2 class="panelh">Timing-bound watch list</h2>
  <div class="dim sub2">Files whose result depends on whether a gap shorter than Crane's
    coarsening tick crosses a tick. Their losses are explained from the generation listed on; an
    entry is STALE once the code its gap runs through has changed since it was measured
    (<code>tools/wpt_loss_dispositions.txt</code>, kind <code>timing-bound</code>).</div>
  <ol>{''.join(items)}</ol>
</div>"""


# The one-flake rule (the user, 2026-10-31; lane flaky1): a path may carry ONE
# `kind = flake` disposition across all generations. A file that flakes again is
# a bug with an owner, not another disposition: the second entry is an error
# naming the path and its first generation. The paths below already carried more
# than one when the rule came in. They are grandfathered for exactly the
# generations listed - a new flake entry for any of them is an error too - and
# each says what lane flaky1 did about it.
FLAKE_GRANDFATHERED = {
    'hr-time/timeOrigin.html': ((178, 194),
        'explained: lane flaky1 - the worker origin falls in the window\'s last 100 us bucket and windowOrigin + now() rounds one ulp above it in doubles (gen 194: 898.4 vs 898.4001); the epoch estimate is also per Performance object, not shared (src/webidl/impls/Performance.zig timeOriginOf). Owner: lane flaky2'),
    'html/cross-origin-opener-policy/coep-with-same-origin.https.html': ((176, 195),
        'explained: lane flaky1 - a sweep-only stall of the COOP/COEP popup files under load (TIMEOUT, OK alone). Owner: lane flaky3'),
    'html/cross-origin-opener-policy/coop-coep-sandbox.https.html': ((177, 181, 190, 194, 196),
        'explained: lane flaky1 - the same sweep-only stall (supervisor kill after 150 s of no progress; OK 3/4 alone). Owner: lane flaky3'),
    'html/semantics/scripting-1/the-script-element/module/dynamic-import/microtasks/basic.any.js':
        ((179, 185, 194, 195, 197),
        'explained: lane flaky1 - the sharedworker variant resolves a "new" module in 3 microtasks: tests 2 and 3 build their specifier from Date.now(), so a fetch that ends inside the same millisecond makes test 3 import test 2\'s module from the module map (a hypothesis to measure). Owner: lane flaky2'),
    'html/webappapis/dynamic-markup-insertion/opening-the-input-stream/abort-refresh-immediate.window.js':
        ((179, 184, 186, 188, 191, 193, 196),
        'explained: lane flaky1 - the fetch() variants flip on whether the 0 ms refresh navigation is ongoing when document.open() runs (the file times out on both sides every run). Owner: lane flaky3'),
    'navigation-timing/secure-connection-start-reuse.https.html': ((183, 198),
        'explained: lane flaky1 - the test frame\'s navigation sometimes opens a new connection instead of reusing the interim frame\'s keep-alive one, so secureConnectionStart is the TLS start, not fetchStart. Owner: lane flaky4'),
    'navigation-timing/test-performance-attributes.sub.html': ((175, 177, 179, 184, 188, 195),
        'explained: lane flaky1 - legacy performance.timing.secureConnectionStart reads a relative 0 (a localhost connect under 1 ms, at the time origin) as "no TLS" and returns 0 below connectStart (src/webidl/impls/PerformanceTiming.zig fromEntry); patch in tmp/scratch/flaky1-handoff/. Owner: lane flaky4'),
    'service-workers/service-worker/navigation-timing-extended.https.html':
        ((171, 177, 183, 185, 188, 190, 196),
        'explained: lane flaky1 - fetchStart and the fetch handler\'s time tie at coarse resolution in some runs. Owner: lane flaky4'),
    'service-workers/service-worker/static-router-main-resource.https.html': ((175, 183, 196),
        'explained: lane flaky1 - a sweep-only loss of "Main resource load matched with the cache source" (9/9 alone). Owner: lane flaky4'),
    'xhr/send-redirect.htm': ((173, 176, 179, 185, 189, 192, 194, 198),
        'explained: lane flaky1 - one of 34 concurrent redirected XHRs reads a final response without X-Request-Method (a different method/code each time: a connection-level race, sweep-only). Owner: lane flaky4'),
}


class LossDispositionError(Exception):
    pass


def parse_loss_dispositions(text, worklist, repo=None):
    """Strict [path] / key = value entries, keyed by (path, generation).

    Each kind requires its evidence; a typo must never silently accept a loss.
    Repeating a path is allowed only for a different generation, and a path may
    be a flake only once (FLAKE_GRANDFATHERED lists the exceptions it inherited).
    A `fixed` entry's commit and test are checked against `repo` (this checkout).
    """
    repo = repo or REPO
    out, cur = {}, None
    first_flake = {}
    common = {'generation', 'kind', 'why'}
    allowed = common.union(*LOSS_KEYS.values())
    in_worklist = set(worklist)

    def finish(entry):
        path, values = entry['path'], entry['values']
        prefix = f'line {entry["line"]}: [{path}]'

        def error(message):
            raise LossDispositionError(f'{prefix}: {message}')

        if path not in in_worklist:
            error('path is not in the worklist')
        for key in sorted(common):
            if key not in values:
                error(f'missing "{key}"')
        if not re.fullmatch(r'[1-9][0-9]*', values['generation']):
            error('generation must be a positive integer')
        generation = int(values['generation'])
        kind = values['kind']
        if kind not in LOSS_KEYS:
            error('kind must be flake, user-ruling, upstream-test-change, fixed or timing-bound')
        required = common | LOSS_KEYS[kind]
        for key in sorted(required - values.keys()):
            error(f'missing "{key}" for {kind}')
        for key in sorted(values.keys() - required):
            error(f'key "{key}" is not evidence for {kind}')
        if kind == 'flake':
            for key in sorted(LOSS_KEYS[kind]):
                match = re.fullmatch(r'base (\d+)/(\d+); tip (\d+)/(\d+)', values[key])
                if not match:
                    error(f'{key} must read "base <passes>/<total>; tip <passes>/<total>"')
                bp, bt, tp, tt = map(int, match.groups())
                if bp > bt or tp > tt:
                    error(f'{key}: passes exceed total')
        elif kind == 'user-ruling':
            try:
                if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', values['date']):
                    raise ValueError()
                datetime.date.fromisoformat(values['date'])
            except ValueError:
                error('date must be a valid YYYY-MM-DD date')
        elif kind == 'fixed':
            commit = values['commit']
            if not re.fullmatch(r'[0-9a-f]{7,40}', commit):
                error('commit must be the fix\'s commit id (7 to 40 lowercase hex digits)')
            if not git_is_commit(commit, repo):
                error(f'commit {commit} is not a commit of this repository')
            if not git_contains('HEAD', commit, repo):
                error(f'commit {commit} is not an ancestor of HEAD: a fix explains a loss once it is merged')
            for test in (t.strip() for t in values['test'].split(',')):
                if not test or not test_in_commit(commit, test, repo):
                    error(f'test "{test}" is not in the fix commit {commit}: the red test comes with its fix')
            match = re.fullmatch(r'before (\d+)/(\d+); after (\d+)/(\d+)', values['repro'])
            if not match:
                error('repro must read "before <failures>/<runs>; after <failures>/<runs>"')
            bf, br, af, ar = map(int, match.groups())
            if bf > br or af > ar or br == 0 or ar == 0:
                error('repro: failures exceed runs, or no runs')
            if bf == 0:
                error('repro: before must show the bug (at least one failure)')
            if af * br >= bf * ar:
                error('repro: after must fail less often than before')
        elif kind == 'timing-bound':
            if not re.fullmatch(r'[1-9][0-9]*', values['tick_us']):
                error('tick_us must be the coarsening tick in microseconds (a positive integer)')
            tick = int(values['tick_us'])
            number = r'(\d+(?:\.\d+)?)'
            match = re.fullmatch(rf'min {number} / p50 {number} / max {number}', values['gap_us'])
            if not match:
                error('gap_us must read "min <us> / p50 <us> / max <us>"')
            low, mid, high = map(float, match.groups())
            if not low <= mid <= high:
                error('gap_us: min <= p50 <= max')
            if mid >= tick:
                error('gap_us: its median must be below tick_us - a gap that usually crosses the tick '
                      'does not make the result depend on it')
            match = re.fullmatch(r'(\d+)/(\d+)', values['pass_rate'])
            if not match:
                error('pass_rate must read "<passes>/<runs>" under the condition')
            passes, runs = map(int, match.groups())
            if not 0 < passes < runs:
                error('pass_rate must show both outcomes under the condition (0 < passes < runs)')
            commit = values['measured_at']
            if not re.fullmatch(r'[0-9a-f]{7,40}', commit):
                error('measured_at must be the measured commit id (7 to 40 lowercase hex digits)')
            if not git_is_commit(commit, repo):
                error(f'measured_at {commit} is not a commit of this repository')
            if not git_contains('HEAD', commit, repo):
                error(f'measured_at {commit} is not an ancestor of HEAD: a measurement counts once it is merged')
            for listed in (p.strip() for p in values['paths'].split(',')):
                if not listed or not _git_ok(repo, 'cat-file', '-e', f'{commit}:{listed}'):
                    error(f'path "{listed}" is not in the measured commit {commit}: paths name the code '
                          'the gap runs through')
        else:
            for key in LOSS_KEYS[kind]:
                if not re.fullmatch(r'[0-9a-f]{40}', values[key]):
                    error(f'{key} must be a full WPT revision (40 lowercase hex digits)')
            if values['wpt.before'] == values['wpt.after']:
                error('WPT revisions must be different')
            change = upstream_test_change(path, values['wpt.before'], values['wpt.after'],
                                          os.path.join(repo, 'tests', 'wpt'))
            if change is not None and not change['own'] and not change['shared']:
                error(f'the file and every resource it loads are byte-identical between '
                      f'{values["wpt.before"][:10]} and {values["wpt.after"][:10]}: a loss there is unexplained '
                      '(a flake or a real bug), never an upstream test change')
        identity = path, generation
        if identity in out:
            error(f'generation {generation} is listed twice')
        if kind == 'flake':
            grandfathered = FLAKE_GRANDFATHERED.get(path, ((), ''))[0]
            if path in first_flake and generation not in grandfathered:
                error(f'a second flake disposition (its first is generation {first_flake[path]}): a path may be '
                      'a flake once - a file that flakes again is a bug with an owner, not another disposition')
            first_flake.setdefault(path, generation)
        out[identity] = dict(values)

    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            inner = line[1:-1] if line.endswith(']') else ''
            if not inner or any(ch in inner for ch in ' \t[]'):
                raise LossDispositionError(f'line {n}: expected [path], a worklist path in brackets')
            if cur:
                finish(cur)
            cur = {'path': inner, 'line': n, 'values': {}}
            continue
        if '=' not in line:
            raise LossDispositionError(f'line {n}: expected key = value')
        key, value = (part.strip() for part in line.split('=', 1))
        if cur is None:
            raise LossDispositionError(f'line {n}: "{key}" before any [path]')
        if key not in allowed:
            raise LossDispositionError(f'line {n}: unknown key "{key}"')
        if key in cur['values']:
            raise LossDispositionError(f'line {n}: "{key}" given twice')
        if not value:
            raise LossDispositionError(f'line {n}: "{key}" is empty')
        cur['values'][key] = value
    if cur:
        finish(cur)
    return out


def load_loss_dispositions(worklist, path=LOSS_DISPOSITIONS_FILE):
    try:
        with open(path) as f:
            text = f.read()
    except FileNotFoundError:
        return {}
    try:
        return parse_loss_dispositions(text, worklist)
    except LossDispositionError as err:
        sys.exit(f'wpt_progress: {os.path.relpath(path, REPO)}: {err}')


def loss_disposition(generation, loss, dispositions, head=None, repo=None):
    """The disposition that explains `loss` in `generation` (whose head commit is `head`),
    or None."""
    entry = dispositions.get((loss['path'], generation))
    if entry is None:
        # A timing-bound entry also explains every later generation's loss of its path.
        entry = timing_bound_for(loss['path'], generation, dispositions)
    if entry and entry['kind'] == 'upstream-test-change':
        # A disposition for different (or unidentified) snapshots explains nothing.
        if (entry['wpt.before'], entry['wpt.after']) != (loss.get('before_revision'), loss.get('after_revision')):
            return None
    if entry and entry['kind'] == 'fixed':
        # A fix explains only a generation measured without it: one whose head contains
        # the fix lost the subtest with the fix in, and one git cannot place proves nothing.
        if git_contains(head, entry['commit'], repo or REPO) is not False:
            return None
    return entry


# The WPT update (lane wptup1, 2026-11-14; plan step 5 of the user's 2026-11-12 "we can update the
# WPT"): a generation swept on another WPT revision than the one before it is a WPT-UPDATE
# generation (`wpt_update` in its history record). A loss there is explained per file, and ONLY
# where the test file or a resource it loads changed between the two revisions (kind
# upstream-test-change, wpt.before/wpt.after = the two fork commits the loss records); a loss in a
# file that is byte-identical, resources included, is unexplained as always - a flake or a real
# bug. `--upstream-test-changes` proposes the entries from the diff for review; nothing is
# written by itself, and the parser refuses an entry for a byte-identical file.
WPT_SHARED_PREFIXES = ('resources/', 'common/')   # the harness and the shared helpers
_LOAD_ATTR = re.compile(r'<(?:script|link|iframe|frame|img|object|embed|audio|video|source|track)\b[^>]*?'
                        r'\s(?:src|href|data)\s*=\s*["\']([^"\'#?]+)', re.I)
_IMPORT_SCRIPTS = re.compile(r'importScripts\(\s*["\']([^"\'#?]+)["\']')
_ES_IMPORT = re.compile(r'\bimport\b[^"\';]*?["\']((?:\.{1,2}/|/)[^"\'#?]+)["\']')
_WRAPPED_JS = ('.any.js', '.window.js', '.worker.js', '.serviceworker.js', '.sharedworker.js')


def _wpt_git(wpt_repo, *args):
    try:
        out = subprocess.run(['git', *args], cwd=wpt_repo, capture_output=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout if out.returncode == 0 else None


def _wpt_blobs(wpt_repo, revision, paths):
    """{path: blob id} for the files of `paths` that exist at `revision`."""
    blobs = {}
    paths = sorted(paths)
    for i in range(0, len(paths), 200):
        out = _wpt_git(wpt_repo, 'ls-tree', '-z', revision, '--', *paths[i:i + 200])
        if out is None:
            return None
        for item in out.decode('utf-8', 'replace').split('\0'):
            meta, _, name = item.partition('\t')
            if name and meta.split(' ')[1:2] == ['blob']:
                blobs[name] = meta.split(' ')[2]
    return blobs


def wpt_loaded_files(path, revision, wpt_repo, depth=2):
    """The tree paths test `path` loads at `revision`, statically: the file itself and its
    .headers, every src/href/data of a loading element, META script= lines, importScripts()
    and relative ES imports - and theirs, `depth` levels down. A wrapped .any.js-style test
    also loads the harness the runner wraps it in. A URL to another origin is not a file."""
    seen, frontier = set(), [path]
    if path.endswith(_WRAPPED_JS):
        seen.update(('resources/testharness.js', 'resources/testharnessreport.js'))
    for level in range(depth + 1):
        nxt = []
        for f in frontier:
            if f in seen:
                continue
            seen.update((f, f + '.headers'))
            if level == depth or not re.search(r'\.(?:html?|xhtml|js|mjs)$', f):
                continue
            text = _wpt_git(wpt_repo, 'cat-file', '-p', f'{revision}:{f}')
            if text is None:
                continue
            text = text.decode('utf-8', 'replace')
            base = posixpath.dirname(f)
            for ref in (_LOAD_ATTR.findall(text) + SCRIPT_META.findall(text) +
                        _IMPORT_SCRIPTS.findall(text) + _ES_IMPORT.findall(text)):
                if re.match(r'^[a-z][a-z0-9+.-]*:|^//', ref, re.I):
                    continue
                joined = posixpath.normpath(ref.lstrip('/') if ref.startswith('/') else posixpath.join(base, ref))
                if not joined.startswith('..') and joined != '.':
                    nxt.append(joined)
        frontier = nxt
    return seen


def upstream_test_change(path, before, after, wpt_repo):
    """{'own': [...], 'shared': [...]}: the files `path` loads (at either revision) whose
    content differs between WPT revisions `before` and `after`, outside and inside the shared
    harness directories; None when git cannot resolve a revision (nothing is known)."""
    if not all(r and re.fullmatch(r'[0-9a-f]{7,40}', r) for r in (before, after)):
        return None
    if any(_wpt_git(wpt_repo, 'cat-file', '-e', f'{r}^{{commit}}') is None for r in (before, after)):
        return None
    files = wpt_loaded_files(path, before, wpt_repo) | wpt_loaded_files(path, after, wpt_repo)
    old, new = _wpt_blobs(wpt_repo, before, files), _wpt_blobs(wpt_repo, after, files)
    if old is None or new is None:
        return None
    changed = sorted(f for f in files if old.get(f) != new.get(f))
    return {'own': [f for f in changed if not f.startswith(WPT_SHARED_PREFIXES)],
            'shared': [f for f in changed if f.startswith(WPT_SHARED_PREFIXES)]}


def generation_wpt_revision(worklist, records):
    """The WPT revision most of the generation's files were measured on, or None."""
    counts = collections.Counter(records[p].get('_wpt_revision') for p in worklist if p in records)
    counts.pop(None, None)
    return counts.most_common(1)[0][0] if counts else None


def wpt_upstream_revision(fork_commit, wpt_repo=None):
    """The upstream WPT revision a fork commit is synced to (its .crane-upstream-revision,
    CRANE-UPSTREAM.md), or None when git cannot read it."""
    if not fork_commit or not re.fullmatch(r'[0-9a-f]{7,40}', fork_commit):
        return None
    out = _wpt_git(wpt_repo or WPT_ROOT, 'cat-file', '-p', f'{fork_commit}:.crane-upstream-revision')
    text = out.decode('ascii', 'replace').strip() if out is not None else ''
    return text if re.fullmatch(r'[0-9a-f]{40}', text) else None


def wpt_update(previous_generation, revision, previous_passes=None, wpt_repo=None):
    """{'before', 'after', 'upstream_before', 'upstream_after'} when this generation was
    measured on a fork commit synced to another UPSTREAM revision than the previous
    generation's; None otherwise. The fork moves with every Crane test it takes, so only the
    upstream revision (.crane-upstream-revision) marks a WPT update. The previous fork commit is
    the one the generation recorded, else the one most of its per-file counts (history's
    last_passes) were measured on - generations before lane wptup1 recorded none. Whatever git
    cannot read claims nothing."""
    before = (previous_generation or {}).get('wpt_revision')
    if not before and previous_generation and previous_passes:
        counts = collections.Counter(v.get('revision') for v in previous_passes.values())
        counts.pop(None, None)
        before = counts.most_common(1)[0][0] if counts else None
    if not before or not revision or before == revision:
        return None
    ub, ua = wpt_upstream_revision(before, wpt_repo), wpt_upstream_revision(revision, wpt_repo)
    if ub and ua and ub != ua:
        return {'before': before, 'after': revision, 'upstream_before': ub, 'upstream_after': ua}
    return None


def upstream_change_report(history, dispositions, generation, wpt_repo=None):
    """The `--upstream-test-changes` text for `generation`: proposed upstream-test-change
    entries (reviewed by a person before they go into tools/wpt_loss_dispositions.txt), the
    losses only a shared-harness change touches (to review), and the losses no change explains."""
    wpt_repo = wpt_repo or WPT_ROOT
    g = next((x for x in history.get('generations', []) if x['n'] == generation), None)
    if not g or not g.get('wpt_update'):
        return (f'generation {generation} is not a WPT-update generation: it was measured on the WPT '
                'revision of the generation before it (or recorded none), so its losses are explained '
                'as any other generation\'s\n')
    up = g['wpt_update']
    proposed, review, unexplained = [], [], []
    for loss in g.get('losses', []):
        if loss_disposition(generation, loss, dispositions, g.get('head')) is not None:
            continue
        b, a = loss.get('before_revision'), loss.get('after_revision')
        lost = f'{loss["path"]} ({loss["before"]} -> {loss["after"]})'
        if not b or not a:
            unexplained.append(f'{lost}: a revision is unknown')
            continue
        if b == a:
            unexplained.append(f'{lost}: measured on the same WPT revision both times')
            continue
        change = upstream_test_change(loss['path'], b, a, wpt_repo)
        if change is None:
            unexplained.append(f'{lost}: git cannot resolve {b[:10]} or {a[:10]} in tests/wpt')
        elif change['own']:
            files = ', '.join(change['own'])
            harness = f' (and the shared harness: {", ".join(change["shared"])})' if change['shared'] else ''
            proposed.append(f'[{loss["path"]}]\ngeneration = {generation}\nkind = upstream-test-change\n'
                            f'why = the test or a resource it loads changed between the two WPT revisions: '
                            f'{files}{harness}; lost {loss["before"] - loss["after"]} subtests '
                            f'(git -C tests/wpt diff {b[:10]} {a[:10]} -- {files})\n'
                            f'wpt.before = {b}\nwpt.after = {a}\n')
        elif change['shared']:
            review.append(f'{lost}: only the shared harness changed ({", ".join(change["shared"])})')
        else:
            unexplained.append(f'{lost}: the file and every resource it loads are byte-identical')
    out = [f'generation {generation} is the WPT update to upstream {up.get("upstream_after", "?")[:10]} from '
           f'{up.get("upstream_before", "?")[:10]} (fork {up["before"][:10]} -> {up["after"][:10]}): '
           f'{len(proposed)} proposed, {len(review)} to review, {len(unexplained)} unexplained\n']
    out.append('\nPROPOSED - review each against its upstream diff before adding it to '
               'tools/wpt_loss_dispositions.txt:\n\n' + '\n'.join(proposed))
    out.append('\nREVIEW - the file is byte-identical and only a shared harness file changed; '
               'add an entry only after reading the harness diff:\n' + ''.join(f'  {r}\n' for r in review))
    out.append('\nUNEXPLAINED - no upstream change explains these (a flake or a real bug):\n' +
               ''.join(f'  {u}\n' for u in unexplained))
    return ''.join(out)


def unexplained_losses(history, dispositions, repo=None):
    """Outstanding file/generation losses; a later generation cannot wash one away."""
    return [(g['n'], loss) for g in history.get('generations', []) for loss in g.get('losses', [])
            if loss_disposition(g['n'], loss, dispositions, g.get('head'), repo) is None]


def render_losses(history, dispositions, repo=None):
    generations = history.get('generations', [])
    latest = generations[-1] if generations else {}
    current, earlier = [], []
    for g in reversed(generations):
        for loss in g.get('losses', []):
            entry = loss_disposition(g['n'], loss, dispositions, g.get('head'), repo)
            status = ('explained: ' + entry['kind']) if entry else 'UNEXPLAINED'
            evidence = '; '.join(f'{k}: {v}' for k, v in entry.items()
                                 if k not in ('kind', 'generation')) if entry else 'No matching disposition.'
            row = (f'<tr><td>{g["n"]}</td><td><code>{html.escape(loss["path"])}</code></td>'
                   f'<td class="num">{loss["before"]:,} &rarr; {loss["after"]:,}</td>'
                   f'<td class="num">&minus;{loss["before"] - loss["after"]:,}</td>'
                   f'<td class="num">{loss["best"]:,}</td>'
                   f'<td><b>{html.escape(status)}</b><div class="dim">{html.escape(evidence)}</div></td></tr>')
            (current if g is latest else earlier).append(row)

    def table(rows):
        return ('<table><thead><tr><th>Generation</th><th>File</th><th>Passing</th><th>Lost</th>'
                '<th>Best in snapshot</th><th>Disposition</th></tr></thead><tbody>' +
                ''.join(rows) + '</tbody></table>')

    missing = latest.get('loss_baseline_missing', [])
    warning = (f'<p class="dim">Previous per-file counts unavailable for {len(missing):,} files; '
               'comparison for those files starts with this generation.</p>') if missing else ''
    return (f'<div class="panel"><h2 class="panelh">Subtests lost since the last generation</h2>'
            f'<p><b>{len(unexplained_losses(history, dispositions, repo)):,} unexplained subtest losses</b> '
            '(file/generation entries, including earlier unresolved losses). '
            'Every loss requires evidence in <code>tools/wpt_loss_dispositions.txt</code>.</p>' +
            (table(current) if current else '<p>No new per-file pass losses in this generation.</p>') + warning +
            ('<details><summary>Losses from earlier generations</summary>' + table(earlier) + '</details>'
             if earlier else '') + '</div>')

# When a variant's query started reaching the page: 71ffd213a (2026-09-22
# 11:42 -0400) put the navigated URL into location.*. Before it
# location.search was "" in every top-level test document, so each variant run
# of a file registered the file's WHOLE set whatever its query said - a journal
# line older than this counts a variant file's subtests once per variant (the
# archived 2026-09-19 sweep has euckr-encode-href-errors-han.html at 554,328,
# 24 x its 23,097). Such a line says nothing about how many subtests that file
# has, so `subtest_model` does not use it for one.
QUERY_REACHES_PAGE = 1790091762
# Bump to rebuild every file's high-water marks from the journals present, when
# the rule for which runs may raise them changes. 2: pre-fix runs are kept
# apart (`_sub_hw_pre`) and divided by the fan-out they ran, never mixed in.
# 3: floors and best passes belong to a WPT revision, never to all snapshots.
HW_MODEL = 3

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
# A variant's query, from `<meta name="variant" content="...">` (either
# attribute order, quoted or not - `<meta name=variant content="?wss">` is
# common) or `// META: variant=...`.
META_TAG = re.compile(r'<meta\b([^>]*)>', re.I)
TAG_ATTR = re.compile(r'([\w-]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s>]+))')
VARIANT_JS_CONTENT = re.compile(r'^//\s*META:\s*variant=(\S*)', re.M)
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

    The runner executes a file once per implemented global times once per
    declared `<meta name="variant">` and sums every run into one journal line
    (`FileTally.add` in tests/wpt_runner/main.zig). Each run is one WPT test -
    MANIFEST.json lists `foo.html?1-1000` and `foo.html?1001-last`, like
    `foo.any.html` and `foo.any.worker.html`, as separate URLs - and each
    variant's query reaches `location.search`, so this is WPT's own count: a
    slice variant (`?1-1000`, read by /common/subset-tests.js) reports its
    slice, a filtering one (`?load fires normally`) the tests it names, a
    rerunning one (`?encoding=windows-1252`) the set under its condition.
    Only a line from before `QUERY_REACHES_PAGE` overcounts, for files that
    declare variants.
    """
    if not rec:
        return 0
    return (rec.get('passed', 0) + rec.get('failed', 0) +
            rec.get('timed_out', 0) + rec.get('notrun', 0))


def query_reached_page(rec):
    """Whether `rec`'s run gave each variant its query (`QUERY_REACHES_PAGE`)."""
    return rec.get('_mtime', 0) >= QUERY_REACHES_PAGE


def high_water(rec):
    """(after, before): the most subtests `rec`'s file has reported in runs from
    after and from before `QUERY_REACHES_PAGE`, `rec`'s own run included."""
    if not rec:
        return 0, 0
    after, before = rec.get('_sub_hw', 0), rec.get('_sub_hw_pre', 0)
    if query_reached_page(rec):
        after = max(after, subtotal(rec))
    else:
        before = max(before, subtotal(rec))
    return after, before


def wpt_revision_at(commit):
    """The WPT gitlink in a measured Crane commit, or None without evidence.

    Do not use today's checkout for old, unlabelled journals: their mtime is not
    a source revision. Resolved identities are persisted so journal rotation or
    an unavailable git object cannot detach a floor from its snapshot.
    """
    if not commit:
        return None
    try:
        result = subprocess.run(['git', 'ls-tree', commit, '--', 'tests/wpt'], cwd=REPO,
                                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    match = re.fullmatch(r'160000 commit ([0-9a-f]{40})\ttests/wpt\n?', result.stdout)
    return match.group(1) if result.returncode == 0 and match else None


def record_revision(rec, cache):
    """Resolve once per distinct label, keeping unidentified evidence unknown."""
    revision = rec.get('_wpt_revision')
    if revision and re.fullmatch(r'[0-9a-f]{40}', revision):
        return revision
    commit = commit_of_label(rec.get('_label'))
    if commit not in cache:
        cache[commit] = wpt_revision_at(commit)
    return cache[commit]


def merge_result(rec, prev):
    """Latest measurement wins; only its snapshot may contribute historical floors."""
    if (prev is not None and not rec.get('_wpt_revision') and
            record_identity(rec) == record_identity(prev)):
        # The identical journal may outlive the git objects that identified it.
        # Preserve its established provenance instead of resetting its floor.
        rec['_wpt_revision'] = prev.get('_wpt_revision')
    chosen = rec if prev is None or rec['_mtime'] >= prev.get('_mtime', 0) else prev
    compatible = (prev is not None and rec.get('_wpt_revision') == prev.get('_wpt_revision') and
                  (rec.get('_wpt_revision') is not None or record_identity(rec) == record_identity(prev)))
    contributors = (rec, prev) if compatible else (chosen,)
    hw = tuple(max(high_water(r)[i] for r in contributors) for i in range(2))
    best = max(max(r.get('_pass_hw', 0), r.get('passed', 0)) for r in contributors)
    chosen.update(_sub_hw=hw[0], _sub_hw_pre=hw[1], _pass_hw=best, _hw_model=HW_MODEL)
    return chosen


def load_results():
    """Latest record per path, accumulated across runs.

    Journals are transient - the runner reuses their filenames - so results are
    merged into a persistent state file and read back from there. A path a run
    did not touch keeps its previous result rather than reverting to unrun.

    `_sub_hw` and `_pass_hw` keep the most reported subtests and passes under
    the latest record's WPT revision. A crash in that snapshot preserves its
    floor; a new snapshot resets it. Runs before `QUERY_REACHES_PAGE` still
    raise the separate `_sub_hw_pre` bucket. Unidentified records cannot raise
    a known snapshot's floor. No current-checkout or timestamp guess is made.
    """
    records = {}

    # Previously accumulated.
    try:
        with open(STATE) as f:
            records = json.load(f)
    except (OSError, json.JSONDecodeError):
        records = {}
    # A reference run's record in the state is not Crane's, however it got there.
    dropped = [p for p, r in records.items() if not is_crane(r)]
    for p in dropped:
        del records[p]
    if dropped:
        print(f"wpt_progress: dropped {len(dropped)} record{'s' if len(dropped) != 1 else ''} "
              f"of another engine from {STATE}: a reference run is never Crane's")
    # Nor is a bug-finding run's record ever published (lane wptcfg).
    dropped_bug = [p for p, r in records.items() if is_bug_finding(r)]
    for p in dropped_bug:
        del records[p]
    if dropped_bug:
        print(f"wpt_progress: dropped {len(dropped_bug)} bug-finding record{'s' if len(dropped_bug) != 1 else ''} "
              f"from {STATE}: only the production run is published")
    # A reference.json is read only from wpt-results/reference/<run>/, and never as Crane's.
    for fn in sorted(glob.glob(os.path.join(RESULTS, 'reference.json')) +
                     glob.glob(os.path.join(RESULTS, '*', 'reference.json'))):
        print(f"wpt_progress: ignored {os.path.relpath(fn, RESULTS)}: a reference run is read only "
              f"from wpt-results/{REFERENCE_SUBDIR}/<run>/reference.json, never as Crane's")
    refused = collections.Counter()
    bug_finding = collections.Counter()
    # High-water marks kept under an older rule are rebuilt from the journals
    # present, and from the record itself (`high_water` counts it).
    revisions = {}
    for rec in records.values():
        if rec.get('_hw_model') != HW_MODEL:
            rec.pop('_sub_hw', None)
            rec.pop('_sub_hw_pre', None)
            rec.pop('_pass_hw', None)
            rec['_hw_model'] = HW_MODEL
        rec['_wpt_revision'] = record_revision(rec, revisions)
        rec['_pass_hw'] = max(rec.get('_pass_hw', 0), rec.get('passed', 0))

    files = journal_files()
    for fn in files:
        # Provenance is shared by every line in this journal. Stat/resolve once,
        # rather than repeating filesystem and git work per subtest source.
        label = label_of_journal(fn)
        mtime = os.path.getmtime(fn)
        journal = os.path.basename(fn)
        revision = record_revision({'_label': label}, revisions)
        for line in open(fn, errors='replace'):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if 'path' in rec and not is_crane(rec):
                refused[(os.path.relpath(fn, RESULTS), str(rec.get('engine')))] += 1
                continue
            if 'path' in rec and is_bug_finding(rec):
                bug_finding[os.path.relpath(fn, RESULTS)] += 1
                continue
            if 'path' in rec:
                rec['_journal'] = journal
                # The run's label: the directory under wpt-results/ ('' for a
                # journal at its top), which by convention ends in the commit
                # the run measured (`ab-<sha>`, `sweep-<sha>`, `<lane>-<sha>`).
                rec['_label'] = label
                rec['_mtime'] = mtime
                rec['_wpt_revision'] = (record_revision(rec, revisions)
                                        if rec.get('_wpt_revision') else revision)
                prev = records.get(rec['path'])
                # Only supersede with something at least as recent, so replaying
                # an old journal cannot roll the picture backwards. It may raise
                # a floor only when it measured the same WPT snapshot.
                records[rec['path']] = merge_result(rec, prev)

    if bug_finding:
        named = ', '.join(f'{rel} ({n} record{"s" if n != 1 else ""})' for rel, n in sorted(bug_finding.items()))
        sys.exit(f"wpt_progress: refused a bug-finding run given as a generation: {named}. Only the "
                 "production run (wpt_runner) is published; the bug-finding run's (wpt_runner_bug_finding) "
                 "summary goes to the held-files report, never under wpt-results/ (lane wptcfg).")
    for (rel, engine), n in sorted(refused.items()):
        print(f"wpt_progress: refused {n} record{'s' if n != 1 else ''} of engine {engine} in {rel}: "
              f"a reference run is never Crane's; it belongs in wpt-results/{REFERENCE_SUBDIR}/<run>/ "
              "(zig build wpt-site -- import-reference)")

    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp_path = STATE + '.tmp'
    with open(tmp_path, 'w') as f:
        json.dump(records, f)
    os.replace(tmp_path, STATE)  # atomic: a crash mid-write cannot truncate it

    return records, files


def journal_files():
    """The journals under wpt-results/, oldest first: its top level and ONE
    directory deep (subdirectories too, so archived journals can be dropped in
    without colliding with the filenames the runner reuses). A result stream
    beside a journal (`X.wptreport.jsonl`, the site's per-subtest detail) is not
    a journal and is never read here."""
    files = glob.glob(os.path.join(RESULTS, '*.jsonl')) + glob.glob(os.path.join(RESULTS, '*', '*.jsonl'))
    # wpt-results/reference/ holds reference runs, never Crane's journals.
    ref_dir = os.path.join(RESULTS, REFERENCE_SUBDIR) + os.sep
    return sorted((f for f in files if not f.endswith('.wptreport.jsonl') and not f.startswith(ref_dir)),
                  key=os.path.getmtime)


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

    variants = len(declared_variants(txt))

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

    return {'v': variants, 'vq': True, 'g': globals_, 'calls': calls * globals_,
            'loopy': loopy, 'stamp': stamp}


def declared_variants(txt):
    """The queries a source declares as variants, in order.

    Only whether there are any matters to the model (see `QUERY_REACHES_PAGE`):
    every variant run is its own WPT test and reports its own subtests, so
    nothing is divided by how many there are.
    """
    queries = VARIANT_JS_CONTENT.findall(txt)
    for attrs in META_TAG.findall(txt):
        found = {m.group(1).lower(): next(g for g in m.groups()[1:] if g is not None)
                 for m in TAG_ATTR.finditer(attrs)}
        if found.get('name', '').lower() == 'variant' and 'content' in found:
            queries.append(found['content'])
    return queries


def _check_declared_variants():
    """The reading above, pinned. Run with `python3 tools/wpt_progress.py --self-test`."""
    assert declared_variants('<meta name="variant" content="?1-1000">\n'
                             '<meta name="variant" content="?1001-last">') == ['?1-1000', '?1001-last']
    assert declared_variants('<meta name=variant content="?load fires normally">') == \
        ['?load fires normally'], 'unquoted name, as the xhr timeout files write it'
    assert declared_variants("<meta content='?wpt_flags=h2' name='variant'>") == \
        ['?wpt_flags=h2'], 'either attribute order, single quotes'
    assert declared_variants('<meta name=variant content=?encoding=windows-1252>') == \
        ['?encoding=windows-1252'], 'unquoted content'
    assert declared_variants('<meta name="viewport" content="width=device-width">') == []
    assert declared_variants('// META: variant=?1-5\n// META: variant=?6-last\n') == ['?1-5', '?6-last']
    assert declared_variants('no variants here') == []


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
        # `vq` marks an entry whose `v` counts variants by `declared_variants`,
        # which reads unquoted attributes; one scanned before it is rescanned.
        if entry is None or not entry.get('vq') or not _stamp_ok(entry):
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

    The unit is WPT's own: one count per test URL - per (source, implemented
    global, declared variant) - which is what MANIFEST.json lists and what the
    runner's journal line sums (`subtotal`). `foo.any.html` and
    `foo.any.worker.html` are separate tests, and so are `foo.html?1-1000` and
    `foo.html?1001-last`. Nothing is divided out: a slice variant reports its
    slice (euckr-encode-href-errors-han.html's 24 slices report its 23,097
    subtests once between them), a filtering variant the tests it names, a
    rerunning variant (`?encoding=windows-1252`) its set under its condition.

    Except for a run from before `QUERY_REACHES_PAGE`: then every variant run
    registered the file's whole set with no query, so its count is divided by
    the file's variant count - which is exactly the no-query set. (From
    2026-09-22 to 2026-09-29 EVERY run was divided that way, so the slice files
    were undercounted by their slice count - 24x for the euc-kr sweeps - and the
    xhr timeout files, whose unquoted `name=variant` went unseen, were not.)

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

    `targeted` uses the high-water mark within the latest measured WPT snapshot:
    40 subtests remain 40 after a crash in that snapshot, but a newer snapshot
    can remove tests. `passing` uses only the CURRENT run, never the best day.
    """
    model = {}
    for path in worklist:
        sh = shape[path]
        # What a run from before QUERY_REACHES_PAGE reported per variant.
        pre_fanout = max(sh['v'], 1)
        rec = records.get(path)
        after, before = high_water(rec)
        observed = max(after, before / pre_fanout)
        if observed:
            passed = (rec or {}).get('passed', 0)
            model[path] = {
                'tier': 'exact' if (rec or {}).get('status') == 'OK' else 'partial',
                'targeted': observed,
                'passing': passed if rec and query_reached_page(rec) else passed / pre_fanout,
            }
        elif sh['calls'] == 0:
            model[path] = {'tier': 'unknown', 'targeted': 0.0, 'passing': 0.0}
        else:
            model[path] = {'tier': 'floor' if sh['loopy'] else 'est',
                           'targeted': float(sh['calls']), 'passing': 0.0}
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
            # Floats on purpose: a pre-fix run's share of its fan-out is not
            # always a whole number, and rounding per FILE would bias the total.
            # Rounding happens once, at the point of display.
            areas[a]['sub_targeted'] += m['targeted']
            areas[a]['sub_passing'] += m['passing']
            areas[a]['tier_' + m['tier']] += 1
            areas[a]['sub_t_' + m['tier']] += m['targeted']
        rec = records.get(path)
        if rec is None:
            areas[a]['unrun'] += 1
            continue
        status = gate_status(rec, path)
        areas[a]['run'] += 1
        if status == EXEMPT:
            areas[a]['exempt'] += 1
            if EXEMPTIONS[path]['kind'] == 'test-bug':
                areas[a]['exempt_test_bug'] += 1
            elif EXEMPTIONS[path]['kind'] == 'needs-renderer':
                areas[a]['exempt_needs_renderer'] += 1
            areas[a]['sub_pass'] += rec.get('passed', 0)
            areas[a]['sub_fail'] += rec.get('failed', 0)
        elif status in GATING:
            areas[a]['gating'] += 1
            areas[a][status.lower()] += 1
            if status == NONE_PASSED:
                areas[a]['sub_fail'] += rec.get('failed', 0)
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
        st = status_of(rec, p)
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
    for fn in reversed(journal_files()):
        base = os.path.basename(fn)
        if base == 'journal.jsonl' and glob.glob(os.path.join(os.path.dirname(fn), 'journal.shard*.jsonl')):
            continue
        ys = []
        contexts = []
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
            # Live V8 native contexts after the file (journals from 2026-09-25
            # on): exact where the heap is noisy - a page that leaves its
            # windows or frames alive adds one per realm.
            if rec.get('native_contexts'):
                contexts.append(rec['native_contexts'])
        if one_process and len(ys) >= min_files:
            trend = {'kb_per_file': _slope(ys), 'files': len(ys), 'first_mb': ys[0] / 1024,
                     'last_mb': ys[-1] / 1024,
                     'journal': os.path.relpath(fn, RESULTS)}
            if len(contexts) >= min_files:
                trend.update(contexts_per_file=_slope(contexts), first_contexts=contexts[0],
                             last_contexts=contexts[-1])
            return trend
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
                if 'contexts_per_file' in heap:
                    live.append(f'Live V8 contexts: <b>{heap["contexts_per_file"]:+.2f} per file</b> '
                                f'({heap["first_contexts"]:,} &rarr; {heap["last_contexts"]:,}). '
                                f'A finished page should leave none of its realms behind.')
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
        a = area_stats([lane['area']] if lane.get('area') else next((p.get('areas', []) for p in infra if p['id'] == lane.get('infra')), []),
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


def label_of_journal(fn):
    """The label of a journal under RESULTS: its directory there, '' at the top."""
    rel = os.path.relpath(os.path.dirname(os.path.abspath(fn)), os.path.abspath(RESULTS))
    return '' if rel == '.' else rel


def commit_of_label(label):
    """The commit a run label names - its trailing `-<hex>` (7 to 40 digits) - or None."""
    m = re.search(r'(?:^|-)([0-9a-f]{7,40})$', label or '')
    return m.group(1) if m else None


def record_identity(rec):
    """Which measurement a state record is: its journal and that journal's mtime. A
    regeneration that re-reads the same journal gives the same identity."""
    return f"{rec.get('_label', '?')}/{rec.get('_journal', '?')}@{rec.get('_mtime', 0)}"


def generation_sources(worklist, records, cur, prev, last_idents, idents):
    """The journals that moved this generation, most-moving first.

    A worklist file counts toward the journal its record now comes from when that record
    is a new measurement since the last generation (its identity changed). A history kept
    before identities were recorded has none: then only the files whose status changed
    count. `moved` is how many of a journal's files changed status; `commit` is the
    label's, or - for a journal at the top of wpt-results/, which the main checkout's
    runner writes - the checkout's HEAD."""
    by = {}
    for path in worklist:
        rec = records.get(path)
        if rec is None:
            continue
        changed = prev is not None and prev.get(path, 'UNRUN') != cur.get(path)
        if last_idents is not None:
            if last_idents.get(path) == idents.get(path):
                continue
        elif not changed and prev is not None:
            continue
        key = (rec.get('_label', '?'), rec.get('_journal', '?'))
        src = by.get(key)
        if src is None:
            label = key[0]
            commit = commit_of_label(label) if label else git_head()
            src = by[key] = {'label': label, 'journal': key[1], 'commit': commit, 'files': 0, 'moved': 0}
        src['files'] += 1
        if changed:
            src['moved'] += 1
    return sorted(by.values(), key=lambda s_: (-s_['moved'], -s_['files'], s_['label']))


def status_of(rec, path=None):
    """One word per file for the history diff: OK, UNRUN, EXEMPT, or the gating status."""
    if rec is None:
        return 'UNRUN'
    st = gate_status(rec, path)
    if st in ('OK', EXEMPT):
        return st
    return st if st in GATING else 'ERROR'


def subtest_sums(worklist, records):
    """The headline's subtest sums: every worklist file's latest record, whatever its
    status - the same sums the public site's headline prints (tools/wpt_site)."""
    out = {'passed': 0, 'failed': 0, 'timed_out': 0, 'notrun': 0}
    for path in worklist:
        rec = records.get(path)
        if rec is None:
            continue
        for k in out:
            out[k] += rec.get(k, 0) or 0
    return out


def prepare_loss_baseline(worklist):
    """Save a legacy generation's pass map before journal loading replaces STATE.

    Otherwise an interrupted first regeneration could overwrite its only copy
    of the old counts, and the retry would silently miss that generation's loss.
    """
    try:
        with open(HISTORY) as f:
            history = json.load(f)
    except FileNotFoundError:
        return
    except (OSError, json.JSONDecodeError) as err:
        sys.exit(f'wpt_progress: cannot read loss history: {err}')
    if 'last_passes' in history or history.get('last_statuses') is None:
        return
    try:
        with open(STATE) as f:
            previous = json.load(f)
    except (OSError, json.JSONDecodeError):
        previous = {}
    passes, revisions = {}, {}
    for path in worklist:
        rec = previous.get(path)
        if rec is not None and history.get('last_sources', {}).get(path) == record_identity(rec):
            passes[path] = {'passed': rec.get('passed', 0), 'revision': record_revision(rec, revisions)}
    history['last_passes'] = passes
    if history['generations']:
        history['generations'][-1]['loss_baseline_missing'] = sorted(
            p for p in worklist if p in history['last_statuses'] and p not in passes)
    _save_history(history)


def flaky_paths(worklist, records):
    """Worklist files whose latest record is flaky: the sweep retried the file
    (it did not fully pass) and the retry disagreed with the first run."""
    return sorted(p for p in worklist if (records.get(p) or {}).get('flaky') is True)


def retry_counts(worklist, records):
    """How the sweep's retries stand, so a flaky count is read against what was
    asked of it. `retried` files had a second run (record has "retry"),
    `skipped` did not fully pass but matched the baseline journal and were not
    retried (record has "retry_skipped"), `flaky` are the retried files whose
    second run disagreed. A flaky count can shrink because fewer files were
    retried; these three numbers say so."""
    retried = skipped = flaky = 0
    for p in worklist:
        rec = records.get(p) or {}
        if rec.get('retry') is not None:
            retried += 1
        if rec.get('retry_skipped'):
            skipped += 1
        if rec.get('flaky') is True:
            flaky += 1
    return {'retried': retried, 'retry_skipped': skipped, 'flaky': flaky}


def retry_summary(counts):
    """The three numbers as one line."""
    return (f"{counts['flaky']:,} flaky of {counts['retried']:,} retried, "
            f"{counts['retry_skipped']:,} not retried (same as the previous generation)")


def record_generation(worklist, records, areas, previous_records=None):
    """Append this generation to HISTORY if anything moved; return the history.

    Diff the previous generation's per-file statuses and passes. Each generation
    retains every pass loss; the two full maps are kept only for the latest one.
    """
    try:
        with open(HISTORY) as f:
            history = json.load(f)
    except FileNotFoundError:
        history = {'generations': [], 'last_statuses': None}
    except (OSError, json.JSONDecodeError) as err:
        sys.exit(f'wpt_progress: cannot read loss history: {err}')

    cur = {p: status_of(records.get(p), p) for p in worklist}
    prev = history.get('last_statuses')
    passes = {p: {'passed': records.get(p, {}).get('passed', 0),
                  'revision': records.get(p, {}).get('_wpt_revision')} for p in worklist}
    prev_passes = history.get('last_passes')
    migrating_passes = prev_passes is None
    if prev_passes is None and prev is not None:
        # Migration: only the pre-load state tied to the previous generation is
        # evidence of its per-file counts. Aggregate sums cannot recover them.
        prev_passes = {}
        revisions = {}
        for p, rec in (previous_records or {}).items():
            if history.get('last_sources', {}).get(p) == record_identity(rec):
                prev_passes[p] = {'passed': rec.get('passed', 0), 'revision': record_revision(rec, revisions)}
    losses = []
    for path, now in passes.items():
        before = (prev_passes or {}).get(path)
        if before and now['passed'] < before['passed']:
            losses.append({'path': path, 'before': before['passed'], 'after': now['passed'],
                           'before_revision': before['revision'], 'after_revision': now['revision'],
                           'best': max(now['passed'], records.get(path, {}).get('_pass_hw', 0))})
    losses.sort(key=lambda loss: (-(loss['before'] - loss['after']), loss['path']))
    # `prev` was computed under the rule the history records (1 if it records none).
    rule_changed = prev is not None and history.get('gate_rule', 1) != GATE_RULE
    # Where this generation's results came from. `head` is the commit whose results
    # moved it - the leading source's - and `checkout` the main checkout's HEAD when
    # the report was made, which is not the same thing when a lane's journal moved it
    # (generations 88-89 named cef789b3a for results from another branch).
    idents = {p: record_identity(records[p]) for p in worklist if p in records}
    sources = generation_sources(worklist, records, cur, prev, history.get('last_sources'), idents)
    checkout = git_head()
    head = next((s_['commit'] for s_ in sources if s_['commit']), None) if sources else None

    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)
    subs = subtest_sums(worklist, records)
    build = generation_build(worklist, records)
    change = configuration_change(history['generations'][-1] if history['generations'] else None, build)
    revision = generation_wpt_revision(worklist, records)
    update = wpt_update(history['generations'][-1] if history['generations'] else None, revision,
                        history.get('last_passes'))
    snap = {
        'n': history['generations'][-1]['n'] + 1 if history['generations'] else 1,
        'at': datetime.datetime.now().isoformat(timespec='seconds'),
        'head': head or checkout,
        'checkout': checkout,
        'sources': sources,
        'total': len(worklist), 'run': tot['run'], 'unrun': tot['unrun'],
        'blocking': tot['gating'], 'crash': tot['crash'], 'timeout': tot['timeout'],
        'error': tot['gating'] - tot['crash'] - tot['timeout'] - tot['none-passed'],
        'none_passed': tot['none-passed'],
        'exempt': tot['exempt'],
        'exempt_test_bug': tot['exempt_test_bug'],
        'exempt_needs_renderer': tot['exempt_needs_renderer'],
        # Files the sweep re-ran because they did not fully pass, whose second run
        # disagreed with the first (the runner's --retry-failures: "flaky" in the
        # journal record). The first result is the one counted everywhere else.
        'flaky': len(flaky_paths(worklist, records)),
        'flaky_paths': flaky_paths(worklist, records),
        'retried': retry_counts(worklist, records)['retried'],
        'retry_skipped': retry_counts(worklist, records)['retry_skipped'],
        'clean': tot['clean'], 'partial': tot['partial'],
        'sub_pass': tot['sub_pass'], 'sub_fail': tot['sub_fail'],
        'sub_targeted': round(tot['sub_targeted']),
        'sub_passing': round(tot['sub_passing']),
        'subs': subs,
        'tiers': {t: tot['tier_' + t] for t in TIERS},
        'areas': {a: {'run': c['run'], 'blocking': c['gating'], 'clean': c['clean']}
                  for a, c in areas.items()},
        'regenerations': 0,
        # The runner build whose results these are ('production', or None: the hybrid runner's).
        'build': build,
        # The WPT revision most files were measured on; `wpt_update` when it moved (lane wptup1).
        'wpt_revision': revision,
        'losses': losses,
        'loss_baseline_missing': sorted(p for p in worklist if prev is not None and
                                       p in prev and p not in (prev_passes or {})),
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
            elif now == EXEMPT:
                key = 'exempted'     # listed in tools/wpt_gate_exemptions.txt
            elif before == EXEMPT and now in GATING:
                key = 'unexempted'   # its entry was removed
            elif now == 'OK' and before in GATING:
                key = 'unblocked'
            elif before == 'OK' and now == NONE_PASSED and rule_changed:
                key = 'reclassified'   # the gate got stricter; the file did not change
            elif before == 'OK' and now in GATING:
                key = 'regressed'
            elif now == 'UNRUN':
                key = 'dropped'
            else:
                key = 'reshuffled'   # e.g. TIMEOUT -> CRASH: still blocking, different way
            moves[key] += 1
            if len(samples[key]) < HISTORY_SAMPLE:
                samples[key].append(f'{path}  {before} -> {now}')
        last_subs = history['generations'][-1].get('subs') if history['generations'] else None
        last_targeted = history['generations'][-1].get('sub_targeted') if history['generations'] else None
        pass_changed = any(p in (prev_passes or {}) and prev_passes[p] != now for p, now in passes.items())
        if not moves and subs == last_subs and not pass_changed and snap['sub_targeted'] == last_targeted:
            # Nothing moved - no file changed standing and the subtest sums are
            # the same: not a new generation. Note the regeneration and keep
            # the map as it is. (Subtests that moved inside files that kept their
            # standing do make a generation: the public site charts subtests.)
            if history['generations']:
                last = history['generations'][-1]
                last['regenerations'] = last.get('regenerations', 0) + 1
                last['regenerated_at'] = snap['at']
                if migrating_passes:
                    last['loss_baseline_missing'] = snap['loss_baseline_missing']
            history['last_statuses'] = cur
            history['last_sources'] = idents
            history['last_passes'] = passes
            history['gate_rule'] = GATE_RULE
            _save_history(history)
            return history
        snap['moves'] = dict(moves)
        snap['samples'] = dict(samples)

    snap['gate_rule'] = GATE_RULE
    if change:
        snap['configuration_change'] = change
    if update:
        snap['wpt_update'] = update   # a WPT-UPDATE generation: losses need upstream-test-change evidence
    history['generations'].append(snap)
    history['last_statuses'] = cur
    history['last_sources'] = idents
    history['last_passes'] = passes
    history['gate_rule'] = GATE_RULE
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
        cur = {p: status_of(seen.get(p), p) for p in worklist}
        prev = history['last_statuses']
        snap = {
            'n': len(history['generations']) + 1,
            'at': datetime.datetime.fromtimestamp(bucket).isoformat(timespec='seconds'),
            'head': '?',
            'reconstructed': True, 'journal': journal,
            'total': len(worklist), 'run': tot['run'], 'unrun': tot['unrun'],
            'blocking': tot['gating'], 'crash': tot['crash'], 'timeout': tot['timeout'],
            'error': tot['gating'] - tot['crash'] - tot['timeout'] - tot['none-passed'],
            'none_passed': tot['none-passed'],
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
    history['last_sources'] = {p: record_identity(records[p]) for p in worklist if p in records}
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


# The chart is drawn at the column's own width (the page's .wrap is 1100px less
# 16px padding each side), so its text renders at true size on a desktop and the
# whole figure scales down, never up, on a narrow screen.
CHART_W, CHART_H = 1068, 300
PAGE_CSS_CHART = """
  .chartbox { position: relative; margin: 8px 0 2px; }
  .chart { width: 100%; height: auto; display: block; overflow: visible; }
  .chart .lbl { font-size: 12px; fill: var(--dim); }
  .chart .pt { stroke: var(--panel); stroke-width: 1.5; }
  .chart .hit { fill: transparent; cursor: crosshair; }
  .chart .guide { stroke: var(--dim); stroke-width: 1; stroke-dasharray: 3 3; opacity: 0; pointer-events: none; }
  .chart .guide.on { opacity: .9; }
  .tip { position: absolute; top: 0; left: 0; z-index: 2; pointer-events: none; min-width: 190px;
    background: var(--panel); color: var(--ink); border: 1px solid var(--line); border-radius: 8px;
    padding: 9px 11px; font-size: 12px; line-height: 1.5; white-space: nowrap;
    box-shadow: 0 6px 20px rgba(0,0,0,.18); }
  .tip .t { font-weight: 600; margin-bottom: 3px; }
  .tip table { border: 0; border-collapse: collapse; background: none; width: 100%; }
  .tip td { border: 0; padding: 1px 0; text-align: left; }
  .tip td.v { text-align: right; padding-left: 14px; font-variant-numeric: tabular-nums; }
  .tip i { display: inline-block; width: 9px; height: 9px; border-radius: 50%; margin-right: 6px; vertical-align: -1px; }
  .tip .mv { margin-top: 4px; color: var(--dim); white-space: normal; max-width: 240px; }
  .tip .good { color: var(--ok); }
  .tip .badtext { color: var(--bad); }
  .chartscroll { overflow: visible; }
  @media (max-width: 640px) {
    .chartscroll { overflow-x: auto; }
    .chart { min-width: 620px; }
    .tip { position: static; margin-top: 8px; min-width: 0; box-shadow: none;
      box-sizing: border-box; width: 100%; white-space: normal; }
    .tip td.v { white-space: nowrap; }
  }
  .legend { font-size: 12px; color: var(--dim); margin-bottom: 10px; }
  .legend span { margin-right: 14px; }
  .legend i { display: inline-block; width: 18px; height: 3px; vertical-align: middle; margin-right: 5px; }
"""

# Hover: one invisible band per generation; entering it lights that
# generation's points and a guide line and fills the tooltip from the embedded
# JSON. The bands' <title>s are the no-JavaScript fallback and are removed once
# the script runs, so the native tooltip never doubles the custom one.
_CHART_SCRIPT = """<script>
(function () {
  var box = document.currentScript.closest('.chartbox');
  var svg = box.querySelector('svg'), tip = box.querySelector('.tip');
  var guide = svg.querySelector('.guide');
  var data = JSON.parse(box.querySelector('.histdata').textContent);
  var W = +svg.getAttribute('viewBox').split(' ')[2], cur = -1;
  var narrow = window.matchMedia('(max-width: 640px)');
  svg.querySelectorAll('.hit title').forEach(function (t) { t.remove(); });
  function fmt(v) { return v.toLocaleString('en-US'); }
  function delta(v, goodDown) {
    if (v === null || v === undefined) return '';
    if (v === 0) return ' <span class="dim">&plusmn;0</span>';
    return ' <span class="' + ((v < 0) === goodDown ? 'good' : 'badtext') + '">' + (v > 0 ? '+' : '') + fmt(v) + '</span>';
  }
  function row(color, name, v, d, goodDown) {
    return '<tr><td><i style="background:' + color + '"></i>' + name + '</td><td class="v">' + fmt(v) + delta(d, goodDown) + '</td></tr>';
  }
  function show(i) {
    var g = data[i];
    if (i !== cur) {
      svg.querySelectorAll('.pt.on').forEach(function (p) { p.classList.remove('on'); p.setAttribute('r', 3); });
      svg.querySelectorAll('.pt[data-i="' + i + '"]').forEach(function (p) { p.classList.add('on'); p.setAttribute('r', 5.5); });
      guide.setAttribute('x1', g.x); guide.setAttribute('x2', g.x); guide.classList.add('on');
      tip.innerHTML = '<div class="t">Generation ' + g.n + ' <span class="dim">&middot; ' + g.at + '</span></div>' +
        '<table>' + row('var(--dimline)', 'run', g.run, g.d_run, false) +
        row('var(--bad)', 'blocking', g.blocking, g.d_blocking, true) +
        row('var(--ok)', 'clean', g.clean, g.d_clean, false) +
        (g.sub_passing === null ? '' : '<tr><td class="dim">subtests</td><td class="v">' + fmt(g.sub_passing) +
          delta(g.d_sub, false) + ' <span class="dim">' + g.sub_pct + '%</span></td></tr>') +
        '</table>' + (g.moves ? '<div class="mv">' + g.moves + '</div>' : '') +
        '<div class="mv"><code>' + g.head + '</code></div>';
      cur = i;
    }
    tip.hidden = false;
    // On a narrow screen the tip is a static panel under the chart. Otherwise it
    // sits beside the guide, flipped left near the right edge, inside the box.
    if (narrow.matches) { tip.style.left = ''; tip.style.top = ''; return; }
    var sr = svg.getBoundingClientRect(), br = box.getBoundingClientRect();
    var scale = sr.width / W, px = sr.left - br.left + g.x * scale;
    var tw = tip.offsetWidth, bw = box.clientWidth;
    var left = px + 14;
    if (left + tw > bw) left = px - 14 - tw;
    tip.style.left = Math.min(Math.max(0, left), Math.max(0, bw - tw)) + 'px';
    tip.style.top = (sr.top - br.top + g.ytop * scale + 4) + 'px';
  }
  function hide() {
    tip.hidden = true; guide.classList.remove('on'); cur = -1;
    svg.querySelectorAll('.pt.on').forEach(function (p) { p.classList.remove('on'); p.setAttribute('r', 3); });
  }
  svg.querySelectorAll('.hit').forEach(function (r) {
    r.addEventListener('pointerenter', function () { show(+r.dataset.i); });
  });
  svg.addEventListener('pointerleave', hide);
})();
</script>"""


def _render_history_chart(gens):
    W, H = CHART_W, CHART_H
    L, R, T, B = 16, 16, 30, 34          # plot area margins
    n = len(gens)
    top = max(g['total'] for g in gens) or 1
    span = (W - L - R) / max(n - 1, 1)
    def x(i): return L + i * span if n > 1 else W / 2
    def y(v): return T + (1 - v / top) * (H - T - B)
    series = (('run', 'var(--dimline)'), ('blocking', 'var(--bad)'), ('clean', 'var(--ok)'))

    lines, points = [], []
    for key, color in series:
        pts = ' '.join(f'{x(i):.1f},{y(g[key]):.1f}' for i, g in enumerate(gens))
        lines.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/>')
        points.extend(f'<circle class="pt {key}" data-i="{i}" cx="{x(i):.1f}" cy="{y(g[key]):.1f}" r="3" fill="{color}"/>'
                      for i, g in enumerate(gens))

    def moves_text(g):
        mv = g.get('moves')
        if mv is None:
            return 'baseline - history starts here'
        parts = [f'{mv[k]:,} {label}' for k, label in (('unblocked', 'unblocked'), ('regressed', 'regressed'),
                                                       ('reshuffled', 'reshuffled'), ('dropped', 'dropped')) if mv.get(k)]
        nr = mv.get('newly_run_ok', 0) + mv.get('newly_run_blocking', 0)
        if nr:
            parts.append(f'{nr:,} newly run')
        return ', '.join(parts) or 'no file changed status'

    data, hits = [], []
    for i, g in enumerate(gens):
        prev = gens[i - 1] if i > 0 else None
        def d(key):
            return None if prev is None or g.get(key) is None or prev.get(key) is None else g[key] - prev[key]
        st, sp = g.get('sub_targeted'), g.get('sub_passing')
        at = g['at'][:16].replace('T', ' ')
        entry = {
            'n': g['n'], 'at': html.escape(at), 'head': html.escape(str(g.get('head', ''))),
            'x': round(x(i), 1), 'ytop': round(min(y(g[k]) for k, _ in series), 1),
            'run': g['run'], 'blocking': g['blocking'], 'clean': g['clean'],
            'd_run': d('run'), 'd_blocking': d('blocking'), 'd_clean': d('clean'),
            'sub_passing': sp, 'd_sub': d('sub_passing'),
            'sub_pct': f'{sp / st * 100:.2f}' if st else None,
            'moves': html.escape(moves_text(g)),
        }
        data.append(entry)
        lo = max(L, x(i) - span / 2) if n > 1 else L
        hi = min(W - R, x(i) + span / 2) if n > 1 else W - R
        title = (f"gen {g['n']} · {at} · run {g['run']:,} · blocking {g['blocking']:,} · clean {g['clean']:,}")
        hits.append(f'<rect class="hit" data-i="{i}" x="{lo:.1f}" y="{T - 10}" width="{hi - lo:.1f}" '
                    f'height="{H - T - B + 20}"><title>{html.escape(title)}</title></rect>')

    blob = json.dumps(data, separators=(',', ':')).replace('</', '<\\/')
    return f"""
 <div class="chartbox">
  <div class="chartscroll">
  <svg class="chart" viewBox="0 0 {W} {H}" role="img" aria-label="run, blocking and clean files for each of {n} generations">
    <line x1="{L}" y1="{y(0):.1f}" x2="{W-R}" y2="{y(0):.1f}" stroke="var(--line)"/>
    <line x1="{L}" y1="{y(top):.1f}" x2="{W-R}" y2="{y(top):.1f}" stroke="var(--line)" stroke-dasharray="3 3"/>
    <text x="{L}" y="{y(top)-8:.1f}" class="lbl">{top:,} = whole subset</text>
    <line class="guide" x1="0" y1="{T - 10}" x2="0" y2="{H - B}"/>
    {''.join(lines)}
    {''.join(points)}
    {''.join(hits)}
    <text x="{L}" y="{H-8}" class="lbl">gen 1 &middot; {html.escape(gens[0]['at'][:16].replace('T',' '))}</text>
    <text x="{W-R}" y="{H-8}" class="lbl" text-anchor="end">gen {n} &middot; {html.escape(gens[-1]['at'][:16].replace('T',' '))}</text>
  </svg>
  </div>
  <div class="tip" hidden></div>
  <script type="application/json" class="histdata">{blob}</script>
  {_CHART_SCRIPT}
  </div>
  <div class="legend"><span><i style="background:var(--dimline)"></i>run</span>
    <span><i style="background:var(--bad)"></i>blocking</span>
    <span><i style="background:var(--ok)"></i>clean</span>
    <span class="dim">hover a generation for its numbers</span></div>"""


def _render_sources(g):
    """Under a generation's commit: the run labels whose journals moved it, and the
    checkout's HEAD when it differs from the commit shown."""
    srcs = g.get('sources') or []
    parts = []
    for s_ in srcs[:3]:
        label = s_['label'] or 'wpt-results/'
        parts.append(f'<span title="{html.escape(s_["journal"])}: {s_["files"]:,} files measured, '
                     f'{s_["moved"]:,} changed status">{html.escape(label)}</span>')
    if len(srcs) > 3:
        parts.append(f'+{len(srcs) - 3} more')
    out = ''
    if parts:
        out += '<br><span class="dim">from ' + ', '.join(parts) + '</span>'
    co = g.get('checkout')
    if co and co != g.get('head'):
        out += f'<br><span class="dim">checkout {html.escape(co)}</span>'
    return out


def render_history(history):
    gens = history.get('generations', [])
    if not gens:
        return ''

    n = len(gens)
    # --- chart: run, blocking and clean for every generation, full column width ---
    chart = _render_history_chart(gens)

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
            if mv.get('reclassified'): parts.append(f'<span class="dim">{mv["reclassified"]:,} reclassified as blocking (OK with none passed, gate rule {g.get("gate_rule", GATE_RULE)})</span>')
            nr = mv.get('newly_run_ok', 0) + mv.get('newly_run_blocking', 0)
            if nr: parts.append(f'{nr:,} newly run <span class="dim">({mv.get("newly_run_blocking",0):,} blocking)</span>')
            if mv.get('reshuffled'): parts.append(f'<span class="dim">{mv["reshuffled"]:,} reshuffled</span>')
            if mv.get('dropped'): parts.append(f'<span class="dim">{mv["dropped"]:,} dropped</span>')
            movement = ', '.join(parts) or '<span class="dim">no file changed status</span>'
            samples = g.get('samples') or {}
            if samples:
                items = []
                for key in ('regressed', 'reclassified', 'unblocked', 'newly_run_blocking', 'reshuffled', 'newly_run_ok', 'dropped'):
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
        if g.get('flaky') is None:
            flakycell = '<span class="dim" title="measured from generation 199 on: the runner retries files that did not fully pass">&mdash;</span>'
        else:
            flakytip = ", ".join(g.get("flaky_paths", []))
            if g.get('retried') is not None:
                flakytip = (f'{g["flaky"]:,} flaky of {g["retried"]:,} retried; {g.get("retry_skipped", 0):,} not retried '
                            f'(same result as the previous generation). ' + flakytip)
            flakycell = (f'<span title="{html.escape(flakytip)}">{g["flaky"]:,}</span> '
                         f'{_delta(g, prev, "flaky", True) if prev and prev.get("flaky") is not None else ""}')
            if g.get('retried') is not None:
                flakycell += (f'<br><span class="dim">of {g["retried"]:,} retried'
                              f'{", " + format(g.get("retry_skipped", 0), ",") + " skipped" if g.get("retry_skipped") else ""}</span>')
        regen = g.get('regenerations', 0)
        when = html.escape(g['at'][:16].replace('T', ' '))
        if g.get('reconstructed'):
            when += f' <span class="dim" title="reconstructed from the state file: {html.escape(str(g.get("journal","")))}">~</span>'
        if regen:
            when += f' <span class="dim" title="regenerated {regen} more time(s) with no change; last {html.escape(g.get("regenerated_at","")[:16].replace("T"," "))}">+{regen}&times;</span>'
        rows.append(f"""
      <tr>
        <td class="num">{g['n']}</td>
        <td class="when">{when}<br><code class="dim">{html.escape(g['head'])}</code>{_render_sources(g)}</td>
        <td class="num">{g['run']:,} {_delta(g, prev, 'run', False)}</td>
        <td class="num gate">{g['blocking']:,} {_delta(g, prev, 'blocking', True)}</td>
        <td class="num">{flakycell}</td>
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
    <th>#</th><th>When / head</th><th>Run</th><th>Blocking</th><th title="files whose retry disagreed with their first run">Flaky</th>
    <th>Crash</th><th>Timeout</th><th>Error</th><th>Clean</th>
    <th class="hide-sm">Subtests&nbsp;pass</th><th>What moved</th>
  </tr></thead>
  <tbody>{''.join(rows)}</tbody>
</table>
"""


def reference_invalid(ref):
    """Why `ref` (a parsed reference.json) cannot be shown, or None."""
    if not isinstance(ref, dict) or ref.get('format') != REFERENCE_FORMAT:
        return f"not {REFERENCE_FORMAT}"
    engine = ref.get('engine')
    if not isinstance(engine, str) or not engine:
        return 'it names no engine'
    if engine == 'crane':
        return "a reference run of Crane itself: Crane's results are its journals"
    run = ref.get('run') or {}
    for key in ('browser_version', 'wpt_revision', 'worklist_commit', 'processes', 'date'):
        if not run.get(key):
            return f'run.{key} is missing'
    for path, rec in (ref.get('files') or {}).items():
        if not isinstance(rec, dict) or rec.get('engine') != engine:
            return f"{path}: record of engine {rec.get('engine') if isinstance(rec, dict) else '?'} in a {engine} reference"
    return None


def load_reference(engine='chrome'):
    """The newest valid reference run of `engine` (by its run date) under
    wpt-results/reference/<run>/reference.json, with `_dir` set, or None. Each
    invalid one is named and skipped."""
    best = None
    for fn in sorted(glob.glob(os.path.join(RESULTS, REFERENCE_SUBDIR, '*', 'reference.json'))):
        rel = os.path.relpath(fn, RESULTS)
        try:
            with open(fn) as f:
                ref = json.load(f)
        except (OSError, json.JSONDecodeError) as err:
            print(f'wpt_progress: ignored {rel}: {err}')
            continue
        why = reference_invalid(ref)
        if why:
            print(f'wpt_progress: ignored {rel}: {why}')
            continue
        if ref['engine'] != engine:
            continue
        if best is None or ref['run']['date'] > best['run']['date']:
            ref['_dir'] = os.path.dirname(fn)
            best = ref
    return best


def compare_reference(worklist, records, ref):
    """Both engines over the worklist, from journal counts alone (passed of
    reported, as the reference reports them), under the same gate rule; and
    the files where one passes more subtests than the other, the most first."""
    files = ref.get('files', {})

    def blank():
        return dict(pass_=0, reported=0, fail=0, timeout=0, notrun=0, blocking=0, clean=0, run=0)

    def add(t, rec, path):
        t['pass_'] += rec.get('passed', 0)
        t['reported'] += subtotal(rec)
        t['fail'] += rec.get('failed', 0)
        t['timeout'] += rec.get('timed_out', 0)
        t['notrun'] += rec.get('notrun', 0)
        t['run'] += 1
        st = gate_status(rec, path)
        if st not in ('OK', EXEMPT):
            t['blocking'] += 1
        elif st == 'OK' and rec.get('failed', 0) == 0 and rec.get('timed_out', 0) == 0:
            t['clean'] += 1

    # The totals compare the files both have a result for; the files only one has are listed.
    crane, refc = blank(), blank()
    areas = collections.defaultdict(lambda: dict(pass_=0, reported=0, blocking=0, run=0))
    ahead_ref, ahead_crane, only_ref, only_crane = [], [], [], []
    for p in worklist:
        c, r = records.get(p), files.get(p)
        if c is not None and r is not None:
            add(crane, c, p)
            add(refc, r, p)
        if r is not None:
            a = areas[area_of(p)]
            a['pass_'] += r.get('passed', 0)
            a['reported'] += subtotal(r)
            a['run'] += 1
            if gate_status(r, p) not in ('OK', EXEMPT):
                a['blocking'] += 1
        if c is None and r is None:
            continue
        if c is None:
            only_ref.append(p)
            continue
        if r is None:
            only_crane.append(p)
            continue
        d = r.get('passed', 0) - c.get('passed', 0)
        if d > 0:
            ahead_ref.append((p, d))
        elif d < 0:
            ahead_crane.append((p, -d))
    ahead_ref.sort(key=lambda x: (-x[1], x[0]))
    ahead_crane.sort(key=lambda x: (-x[1], x[0]))
    rename = lambda t: {('pass' if k == 'pass_' else k): v for k, v in t.items()}
    return {'crane': rename(crane), 'ref': rename(refc), 'common': crane['run'],
            'areas': {a: rename(v) for a, v in areas.items()},
            'ahead_ref': ahead_ref, 'ahead_crane': ahead_crane,
            'only_ref': only_ref, 'only_crane': only_crane}


def harness_split(files, wall, small_files=0, small_wall=None):
    """(per_test_s, startup_s) from overhead runs of empty tests, as
    tools/wpt_site/reference.zig harnessSplit: two sizes separate the fixed
    start-up from the wall clock each test adds to the runner pool."""
    if not files:
        return 0.0, 0.0
    if small_wall is not None and small_files and files > small_files and wall > small_wall:
        per = (wall - small_wall) / (files - small_files)
        return per, max(small_wall - per * small_files, 0.0)
    return wall / files, 0.0


def measure_cpu(m):
    """The run's CPU, as reference.zig Measure.cpu: the larger of its rusage (user + system of
    what it waited for) and its process tree sampled once a second (which also sees processes no
    parent waited for), plus its share of a server it did not start."""
    return max(m['user_s'] + m['sys_s'], m.get('tree_cpu_s', 0)) + m.get('server_cpu_s', 0)


def fmt_mb(mb):
    """As the public site says it: "800 MB", "6.0 GB"."""
    if mb is None or mb != mb or mb < 0:
        return '&mdash;'
    if mb >= 1024:
        return f'{mb / 1024:.1f} GB'
    return f'{int(mb + 0.5):,} MB'


V8_BUILD_NOTE = ('a release build (<code>is_debug=false</code>, no V8 checks, no heap verification: '
                 '<code>scripts/build-v8-static.sh</code>) but not an official one: no ThinLTO and no PGO, which '
                 'Chrome&rsquo;s V8 is built with.')
V8_NOTE = 'Crane links ' + V8_BUILD_NOTE
V8_OFFICIAL_NOTE = ('built as Chrome&rsquo;s official build is: ThinLTO and PGO (<code>-Dv8-build=official</code>, '
                    '<code>scripts/build-v8-official.sh</code>).')
MEMORY_METHOD = ('Memory is each process&rsquo;s phys_footprint (Activity Monitor&rsquo;s Memory: its own dirty pages, '
                 'anonymous and compressed; the kernel charges a page shared between processes to one owner, so a sum '
                 'counts it once), sampled every second and summed over the engine&rsquo;s processes - Chrome&rsquo;s '
                 'browser, renderer, GPU and utility processes; Crane&rsquo;s runner processes that run the files - and, '
                 'apart, over the harness&rsquo;s: wptrunner&rsquo;s Python, its servers and ChromeDriver; Crane&rsquo;s '
                 'supervising runner and the shared WPT server.')


def fmt_duration(secs):
    """As the public site says it: "250 ms", "1.50 s", "40 min 0 s", "2 h 20 min"."""
    if secs is None or secs != secs or secs < 0:
        return '&mdash;'
    if secs < 1:
        return f'{int(secs * 1000 + 0.5)} ms'
    if secs < 10:
        return f'{secs:.2f} s'
    if secs < 60:
        return f'{secs:.1f} s'
    whole = int(secs + 0.5)
    if whole < 3600:
        return f'{whole // 60} min {whole % 60} s'
    return f'{whole // 3600} h {(whole % 3600) // 60} min'


_SORT_SCRIPT = """<script>
document.querySelectorAll('table.sortable').forEach(function (t) {
  t.querySelectorAll('thead th').forEach(function (th, col) {
    th.style.cursor = 'pointer';
    th.addEventListener('click', function () {
      var rows = Array.from(t.tBodies[0].rows), up = th.dataset.dir !== 'up';
      rows.sort(function (a, b) {
        var x = a.cells[col].dataset.v, y = b.cells[col].dataset.v;
        var c = (x != null && y != null) ? (+x - +y) : a.cells[col].textContent.localeCompare(b.cells[col].textContent);
        return up ? c : -c;
      });
      th.dataset.dir = up ? 'up' : 'down';
      rows.forEach(function (r) { t.tBodies[0].appendChild(r); });
    });
  });
});
</script>"""


def render_reference(worklist, records, ref):
    """The comparison with a reference run: the run's identity, both engines'
    numbers on the same files, the wall time with the harness overhead, and
    the files each passes more subtests of."""
    if not ref:
        return ''
    name = engine_label(ref['engine'])
    run = ref['run']
    cmp = compare_reference(worklist, records, ref)
    cr, rf = cmp['crane'], cmp['ref']
    esc = html.escape
    when = run['date'].replace('T', ' ').replace('Z', ' UTC')
    driver = (f", {'ChromeDriver' if ref['engine'] == 'chrome' else 'WebDriver'} "
              f"<code>{esc(run['webdriver_version'])}</code>") if run.get('webdriver_version') else ''
    channel = f" ({esc(run['channel'])})" if run.get('channel') else ''
    where = f", {esc(run['host'])}" if run.get('host') else ''
    src = os.path.relpath(ref.get('_dir', ''), REPO) if ref.get('_dir') else 'wpt-results/reference/'
    tm0 = ref.get('timing') or {}
    runner = ((tm0.get('crane') or {}).get('runner') or '')
    same_window = (f" In the same window Crane&rsquo;s frozen runner, <code>{esc(runner)}</code>, ran the same files "
                   "with the same runners." if runner else '')

    def row(label, a, b):
        return f'<tr><td class="area">{label}</td><td class="num">{a}</td><td class="num">{b}</td></tr>'

    nums = ''.join([
        row('WPT subtests passing', f"{cr['pass']:,} / {cr['reported']:,}", f"{rf['pass']:,} / {rf['reported']:,}"),
        row('Failed', f"{cr['fail']:,}", f"{rf['fail']:,}"),
        row('Timed out', f"{cr['timeout']:,}", f"{rf['timeout']:,}"),
        row('Not run', f"{cr['notrun']:,}", f"{rf['notrun']:,}"),
        row('Blocking files', f"{cr['blocking']:,}", f"{rf['blocking']:,}"),
        row('Clean files', f"{cr['clean']:,}", f"{rf['clean']:,}"),
    ])

    timing_html = ''
    tm = ref.get('timing')
    cov = ref.get('coverage', {})
    if tm:
        procs = tm['processes']
        c, r = tm.get('crane'), tm['reference']
        rows = []
        if (c or {}).get('reported') or r.get('reported'):
            rows.append(row('WPT subtests passing in this run',
                            f"{c['passed']:,} / {c['reported']:,}" if (c or {}).get('reported') else 'not recorded',
                            f"{r['passed']:,} / {r['reported']:,}" if r.get('reported') else 'not recorded'))
        rows.append(row('The worklist, wall clock', fmt_duration(c['wall_s']) if c else 'not measured', fmt_duration(r['wall_s'])))
        # Where each pool's wall clock went (reference.zig Pool): the tests' own, and what a chunked sweep lost.
        cpool, rpool = (c or {}).get('pool'), r.get('pool')
        if cpool or rpool:
            def lost(pool, key):
                if not pool:
                    return 'not measured'
                return fmt_duration(pool.get(key, 0)) if pool.get('chunks') else 'none: one queue'
            rows.append(row('The tests&rsquo; own wall clock, per runner',
                            fmt_duration(cpool['work_s']) if cpool else 'not measured',
                            fmt_duration(rpool['work_s']) if rpool else 'not measured'))
            rows.append(row('Of the wall clock: waiting for a chunk&rsquo;s slowest runner', lost(cpool, 'barrier_s'), lost(rpool, 'barrier_s')))
            rows.append(row('Of the wall clock: chunk start-up', lost(cpool, 'startup_s'), lost(rpool, 'startup_s')))
        rows.append(row('CPU, user + system', fmt_duration(measure_cpu(c)) if c else 'not measured',
                        fmt_duration(measure_cpu(r))))
        cmem, rmem = (c or {}).get('memory'), r.get('memory')
        if cmem or rmem:
            for label, key in (('Memory of the engine, peak', 'engine_peak_mb'), ('Memory of the engine, mean', 'engine_mean_mb'),
                               ('Memory of the harness, peak', 'harness_peak_mb'), ('Memory of the harness, mean', 'harness_mean_mb'),
                               ('One runner&rsquo;s engine, largest peak', 'group_peak_max_mb'),
                               ('One runner&rsquo;s engine, mean of the peaks', 'group_peak_mean_mb')):
                rows.append(row(label, fmt_mb(cmem[key]) if cmem else 'not measured', fmt_mb(rmem[key]) if rmem else 'not measured'))
                mw = (c or {}).get('memory_without')
                if mw and key == 'engine_mean_mb':
                    # The engine without a file whose runner ran away, beside the measured; the reference's own figures.
                    for what, k in (('peak', 'engine_peak_mb'), ('mean', 'engine_mean_mb')):
                        rows.append(row(f'Memory of the engine without the runaway file, {what}', fmt_mb(mw[k]),
                                        fmt_mb(rmem[k]) if rmem else 'not measured'))
        o = tm.get('overhead')
        urls = cov.get('urls_expected', 0)
        if o and o.get('files'):
            def split(side):
                small = o.get('small_' + side)
                return harness_split(o['files'], o[side]['wall_s'], o.get('small_files', 0),
                                     small['wall_s'] if small else None)
            (pc, sc), (pr, sr) = split('crane'), split('reference')
            rows.append(row('One empty test, harness alone', fmt_duration(pc * procs), fmt_duration(pr * procs)))
            if o.get('small_files'):
                rows.append(row('Start-up, before the first test', fmt_duration(sc), fmt_duration(sr)))
            # Each run is split over the test URLs it ran (the worklist's, when it recorded none).
            uc = (c.get('tests') or urls) if c else urls
            ur = r.get('tests') or urls
            if ur:
                hc, hr = sc + pc * uc, sr + pr * ur
                rows.append(row('Of the wall clock: harness (estimate)', fmt_duration(hc), fmt_duration(hr)))
                rows.append(row('Of the wall clock: the tests (estimate)',
                                fmt_duration(max(c['wall_s'] - hc, 0)) if c else 'not measured',
                                fmt_duration(max(r['wall_s'] - hr, 0))))
        timing_html = f"""
  <h3 class="panelh" style="margin-top:18px">Wall time <span class="dim">{procs} runners each{where}</span></h3>
  <table class="comp versus"><thead><tr><th></th><th>Crane</th><th>{name}</th></tr></thead>
  <tbody>{''.join(rows)}</tbody></table>"""
        if cpool and not cpool.get('chunks'):
            timing_html += ('<p class="dim note">Crane&rsquo;s run is one shared queue: each runner takes the next file when '
                            'it is free, so no runner waits for another' +
                            (f', and each runner process runs {cpool["files_per_runner"]:,} files before a fresh one takes '
                             f'its place' if cpool.get('files_per_runner') else '') +
                            f'. The tests&rsquo; own wall clock is every file&rsquo;s summed over the {procs} runners: what '
                            f'a pool that never waits would take.' +
                            (f' {name}&rsquo;s <code>wptrunner</code> feeds its processes from one queue too.'
                             if rpool and not rpool.get('chunks') else '') + '</p>')
        if cpool and cpool.get('chunks'):
            timing_html += (f'<p class="dim note">Crane&rsquo;s run went in {cpool["chunks"]:,} chunks of {cpool.get("chunk_files", 0):,} '
                            f'files, each split into fixed shards of {cpool.get("shard_files", 0):,} files, one per runner; a chunk '
                            f'ends when its slowest shard does, so the other runners wait for it. The tests&rsquo; own wall '
                            f'clock is every file&rsquo;s summed over the {procs} runners: what a pool that never waits would take.' +
                            (f' {name}&rsquo;s <code>wptrunner</code> feeds its processes from one queue.'
                             if rpool and not rpool.get('chunks') else '') + '</p>')
        mw = (c or {}).get('memory_without')
        if mw:
            timing_html += (f'<p class="dim note">Crane&rsquo;s engine peak is one file, <code>{esc(mw["path"])}</code>' +
                            (f': {esc(mw["note"])}' if mw.get('note') else '') +
                            f'. The rows without the runaway file leave out {esc(mw.get("excluded") or "its samples")}; '
                            f'{name}&rsquo;s are its whole run.</p>')
        if o and o.get('files'):
            timing_html += (f'<p class="dim note">Each harness also ran {o["files"]:,} files holding one empty test '
                            f'(<code>tests/wpt/crane/harness-overhead/</code>) with the same {procs} runners: what one '
                            f'costs is the harness alone, and the estimates split each run at that rate over the '
                            f'{urls:,} test URLs of the worklist.</p>')
        timing_html += ('<p class="dim note">CPU is the larger of what the run&rsquo;s harness waited for (rusage) and a '
                        'once-a-second sample of its whole process tree, which also counts the browser&rsquo;s processes '
                        'no parent waited for; Crane&rsquo;s includes its share of the shared WPT server, which it does '
                        'not start.' + (' ' + MEMORY_METHOD if (cmem or rmem) else '') + '</p>')
        product = 'Chrome for Testing' if ref['engine'] == 'chrome' else name
        builds = [f"{name}: {product} <code>{esc(run['browser_version'])}</code>" +
                  (f", {esc(run['build'])}" if run.get('build') else '')]
        if c:
            builds.append('Crane: ' + (esc(c['build']) + '; ' if c.get('build') else '') +
                          f"runner <code>{esc(c.get('runner', ''))}</code>")
        elif run.get('crane_build'):
            builds.append('Crane: ' + esc(run['crane_build']))
        v8 = (f"Crane links V8 <code>{esc(run['crane_js_engine'].removeprefix('V8 '))}</code>, " +
              (V8_OFFICIAL_NOTE if run.get('crane_v8_build') == 'official' else V8_BUILD_NOTE)
              if run.get('crane_js_engine') else V8_NOTE)
        if run.get('js_engine'):
            v8 += (f" {name} <code>{esc(run['browser_version'])}</code> ships V8 "
                   f"<code>{esc(run['js_engine'].removeprefix('V8 '))}</code>.")
        builds.append('V8: ' + v8)
        if tm.get('reference_reused'):
            builds.append(f"{name}&rsquo;s figures are from its run of {esc(run['date'][:10])}, reused beside "
                          f"Crane&rsquo;s: {esc(tm['reference_reused'])}.")
        timing_html += '<ul class="samples">' + ''.join(f'<li>{b}</li>' for b in builds) + '</ul>'

    def file_rows(items):
        out = []
        for p, d in items:
            c, r = records[p], ref['files'][p]
            out.append(f'<tr><td class="area">{esc(p)}</td>'
                       f'<td class="num" data-v="{c.get("passed", 0)}">{c.get("passed", 0):,} / {subtotal(c):,}</td>'
                       f'<td class="num" data-v="{r.get("passed", 0)}">{r.get("passed", 0):,} / {subtotal(r):,}</td>'
                       f'<td class="num" data-v="{d}">+{d:,}</td>'
                       f'<td class="num">{esc(gate_status(c, p))}</td><td class="num">{esc(gate_status(r, p))}</td></tr>')
        return ''.join(out)

    def table(items, lead):
        if not items:
            return '<p class="dim">None.</p>'
        return (f'<table class="sortable"><thead><tr><th>Test file</th><th>Crane</th><th>{name}</th>'
                f'<th>{lead} ahead by</th><th>Crane status</th><th>{name} status</th></tr></thead>'
                f'<tbody>{file_rows(items)}</tbody></table>')

    def only(paths, side):
        if not paths:
            return '<p class="dim">None.</p>'
        out = []
        for p in paths:
            rec = ref['files'][p] if side == 'ref' else records[p]
            out.append(f'<li><code>{esc(p)}</code> <span class="dim">{rec.get("passed", 0):,} / {subtotal(rec):,}, '
                       f'{esc(gate_status(rec, p))}</span></li>')
        return f'<ul class="samples">{"".join(out)}</ul>'

    sr_, srcs = cov.get('sources_reported', 0), cov.get('sources', len(worklist))
    ran = (f'has a result for {sr_:,} of the {len(worklist):,} worklist files, run' if sr_ < srcs
           else f'ran the {len(worklist):,} worklist files')
    sum_ref = sum(d for _, d in cmp['ahead_ref'])
    sum_crane = sum(d for _, d in cmp['ahead_crane'])
    missing = cov.get('urls_missing', 0)
    return f"""
<h2 class="section" id="versus">Crane and {name} <small class="dim">the same files, a reference run</small></h2>
<div class="panel">
  <p class="sub2">{name} <code>{esc(run['browser_version'])}</code>{channel} {ran} on {esc(when)} with WPT&rsquo;s own runner (<code>wpt run</code>, headless{driver},
    {run['processes']} processes{where}), on WPT revision <code>{esc(run['wpt_revision'][:10])}</code>, over the
    worklist of Crane <code>{esc(run['worklist_commit'])}</code>.{same_window} Read from <code>{esc(src)}</code>;
    never counted as Crane&rsquo;s. Both columns are journal counts: subtests passed of those reported.</p>
  <table class="comp versus"><thead><tr><th></th><th>Crane</th><th>{name}</th></tr></thead>
  <tbody>{nums}</tbody></table>
  <p class="dim note">Both columns are over the {cmp['common']:,} files both ran.
    Not compared: {len(cmp['only_ref']):,} file{'s' if len(cmp['only_ref']) != 1 else ''} with a result from {name} alone, {len(cmp['only_crane']):,} from Crane alone.
    {name} reported {cov.get('urls_reported', 0):,} of the {cov.get('urls_expected', 0):,} test
    URLs of these files{f'; the other {missing:,} have no result, so those files compare over fewer URLs' if missing else ''}.
    Each engine runs under its own harness: Crane&rsquo;s runner, and WPT&rsquo;s <code>wptrunner</code> over WebDriver.</p>
  {timing_html}
</div>
<details open><summary><b>Where {name} passes subtests Crane does not</b> &mdash; {len(cmp['ahead_ref']):,} files,
  {sum_ref:,} subtests (sortable: click a column)</summary>
{table(cmp['ahead_ref'], name)}
</details>
<details><summary><b>Where Crane passes subtests {name} does not</b> &mdash; {len(cmp['ahead_crane']):,} files,
  {sum_crane:,} subtests</summary>
{table(cmp['ahead_crane'], 'Crane')}
</details>
<details><summary><b>Files only one of them ran</b> &mdash; {name} alone {len(cmp['only_ref']):,},
  Crane alone {len(cmp['only_crane']):,}</summary>
<p class="dim">{name} has a result, Crane has none:</p>{only(cmp['only_ref'], 'ref')}
<p class="dim">Crane has a result, {name} has none:</p>{only(cmp['only_crane'], 'crane')}
</details>
{_SORT_SCRIPT}"""


def render(areas, worklist, records, files, out_path, history=None, shape=None, roadmap=None,
           dispositions=None, reference=None):
    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)

    # Files that declare variants, and how many of them still take a count
    # from a run older than QUERY_REACHES_PAGE (divided by the fan-out then).
    variant_files = pre_fix_files = 0
    if shape:
        for p in worklist:
            rec = records.get(p)
            if not shape[p]['v'] or not rec:
                continue
            variant_files += 1
            after, before = high_water(rec)
            if not query_reached_page(rec) or before / shape[p]['v'] > after:
                pre_fix_files += 1

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
    non_enc_pct, file_mean_pct = alt_rates(worklist, records)

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

    subtest_html = f"""
<div class="panel">
  <h2 class="panelh">Subtests targeted</h2>
  <div class="headline">{sub_passing:,}<span class="dim"> of </span>{sub_targeted:,}
    <span class="pct">{sub_pct:.2f}%</span></div>
  <div class="dim sub2">Subtests passing, of the subtests the 0.1 worklist targets.
    Counted once per test URL &mdash; per source, implemented global and declared
    <code>&lt;meta name="variant"&gt;</code> &mdash; the unit MANIFEST.json and wpt.fyi use.
    The other sense of &ldquo;progressed&rdquo; is whole files:
    <b>{clean:,} of {total:,}</b> ran clean, <b class="pct2">{clean_pct:.2f}%</b>.
    <br><b>This percentage falls when coverage grows.</b> A subtest only exists once its
    file runs, so every newly run file adds its whole declared set to the denominator
    before it adds anything to the numerator.{cov_note}
    Read it against the generation table, never alone.</div>
  <table class="comp"><tbody>{''.join(comp_rows)}</tbody></table>
  <p class="dim note">{variant_files:,} files that have reported declare variants. Each
    variant's query reaches <code>location.search</code>, so a slice variant
    (<code>?1-1000</code>, read by <code>/common/subset-tests.js</code>) reports only its
    slice and nothing is divided out: <code>euckr-encode-href-errors-han.html</code>'s 24
    slices report its 23,097 subtests once between them. Runs from before 71ffd213a
    (2026-09-22) are the exception: <code>location.search</code> was empty, every variant
    run registered the whole set, and such a run is divided by the file's variant count
    ({pre_fix_files:,} file{"s" if pre_fix_files != 1 else ""} still counted that way).
    A file's target uses the most subtests reported under its latest measured WPT
    revision; a newer snapshot resets that floor, a crash in the same snapshot
    preserves it. Its passes use only the current run.</p>
</div>"""

    ref_areas = compare_reference(worklist, records, reference)['areas'] if reference else None
    ref_name = engine_label(reference['engine']) if reference else ''
    rows = []
    for area in sorted(areas, key=lambda a: (-areas[a]['gating'], a)):
        c = areas[area]
        g = c['gating']
        ra = (ref_areas or {}).get(area, {'pass': 0, 'reported': 0, 'blocking': 0, 'run': 0})
        ref_cells = (f'<td class="num hide-sm">{ra["pass"]:,}<span class="dim"> / {ra["reported"]:,}</span></td>'
                     f'<td class="num hide-sm">{ra["blocking"] or "&middot;"}</td>') if reference else ''
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
        {ref_cells}<td>{bar(c['clean'], c['total'], 'ok')}</td>
      </tr>""")

    journals = ''.join(
        f'<li><code>{html.escape(os.path.basename(f))}</code> '
        f'<span class="dim">{datetime.datetime.fromtimestamp(os.path.getmtime(f)):%Y-%m-%d %H:%M}</span></li>'
        for f in files[-8:]) or '<li class="dim">none found</li>'

    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')

    history_html = render_history(history) if history else ''
    losses_html = render_losses(history or {}, dispositions or {})
    timing_bound_html = render_timing_bound(dispositions or {})
    unexplained = len(unexplained_losses(history or {}, dispositions or {}))
    roadmap_html = render_roadmap(roadmap, worklist, records)
    exempt_html = render_exempt(records, worklist)
    # Each kind's own count (the user, 2026-11-08: a test bug filed upstream is
    # the second kind, counted apart from the browsers' intentional deviations).
    # And the third (the user, 2026-11-09): a file that fails only because no
    # renderer answers geometry.
    exempt_intentional = tot['exempt'] - tot['exempt_test_bug'] - tot['exempt_needs_renderer']
    exempt_note = ''.join((
        f' Not counted: {exempt_intentional:,} exempt (all three browsers intentionally deviate).' if exempt_intentional else '',
        f' Not counted: {tot["exempt_test_bug"]:,} exempt until an upstream test bug is fixed.' if tot['exempt_test_bug'] else '',
        f' Not counted: {tot["exempt_needs_renderer"]:,} exempt until a renderer answers geometry.' if tot['exempt_needs_renderer'] else ''))
    reference_html = render_reference(worklist, records, reference)
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
{PAGE_CSS_CHART}
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
  table.versus {{ max-width:560px; margin-top:6px }}
  table.versus th {{ text-align:right }}
  table.sortable td.area {{ font-size:12px }}
</style></head><body><div class="wrap">

<h1>Crane engine progress</h1>
<div class="sub">Generated {now} &middot; WPT: {total:,} sources in the 0.1 subset
  &middot; roadmap: <code>docs/roadmap.toml</code> &middot; <code>tools/wpt_progress.py</code></div>

<div class="gate">
  <h2>WPT 0.1 release gate</h2>
  <div class="verdict">{'MET' if gate_met else f'{gating:,} blocking'}
    <small>{'Zero crashes, timeouts, errors and files with none passing; whole subset run.' if gate_met else
      f'0.1 ships when no file crashes, times out, errors, or passes none of its subtests. {unrun:,} of {total:,} sources not yet run.'}{exempt_note}</small>
  </div>
  <div class="headline">{unexplained:,} unexplained subtest losses</div>
</div>
{exempt_html}

<div class="cards">
  <div class="card"><div class="k">Run</div><div class="v">{run:,}<span class="dim" style="font-size:14px"> / {total:,}</span></div></div>
  <div class="card"><div class="k">Timeouts</div><div class="v" style="color:var(--bad)">{tot['timeout']:,}</div></div>
  <div class="card"><div class="k">Crashes</div><div class="v" style="color:var(--bad)">{tot['crash']:,}</div></div>
  <div class="card"><div class="k">Flaky</div><div class="v" style="color:var(--bad)">{len(flaky_paths(worklist, records)):,}</div><div class="dim" style="font-size:12px">of {retry_counts(worklist, records)['retried']:,} retried, {retry_counts(worklist, records)['retry_skipped']:,} skipped as unchanged</div></div>
  <div class="card"><div class="k">OK, none passed</div><div class="v" style="color:var(--bad)">{tot['none-passed']:,}</div></div>
  {f'<div class="card"><div class="k">Exempt</div><div class="v">{exempt_intentional:,}</div></div>' if any(e['kind'] == 'intentional' for e in EXEMPTIONS.values()) else ''}
  {f'<div class="card"><div class="k">Exempt: upstream test bug</div><div class="v">{tot["exempt_test_bug"]:,}</div></div>' if any(e['kind'] == 'test-bug' for e in EXEMPTIONS.values()) else ''}
  {f'<div class="card"><div class="k">Exempt: needs a renderer</div><div class="v">{tot["exempt_needs_renderer"]:,}</div></div>' if any(e['kind'] == 'needs-renderer' for e in EXEMPTIONS.values()) else ''}
  <div class="card"><div class="k">Clean files</div><div class="v" style="color:var(--ok)">{clean:,}</div></div>
  <div class="card"><div class="k">Subtests passing</div><div class="v">{sub_passing:,}<span class="dim" style="font-size:14px"> / {sub_targeted:,}</span></div></div>
  <div class="card"><div class="k">Pass rate outside encoding/</div><div class="v">{non_enc_pct:.1f}%</div></div>
  <div class="card"><div class="k">Mean per-file pass rate</div><div class="v">{file_mean_pct:.1f}%</div></div>
</div>

{reference_html}

{roadmap_html}

<h2 class="section">WPT detail</h2>

{subtest_html}

{losses_html}
{timing_bound_html}

{history_html}

<h2>By area <small class="dim">current state</small></h2>
<table>
  <thead><tr>
    <th>Area</th><th>Subset</th><th>Run</th><th>Blocking</th>
    <th>Timeout</th><th>Crash</th><th>Clean</th>
    <th class="hide-sm">Partial</th><th class="hide-sm">Unrun</th>
    <th class="hide-sm">Subtests&nbsp;pass&nbsp;/&nbsp;target</th>
    {f'<th class="hide-sm">{ref_name}&nbsp;pass&nbsp;/&nbsp;reported</th><th class="hide-sm">{ref_name}&nbsp;blocking</th>' if reference else ''}
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
  <br><br><strong>Blocking</strong> = timeouts + crashes + errors + files with none passing,
  less the files <code>tools/wpt_gate_exemptions.txt</code> exempts. That is the gate:
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
    global EXEMPTIONS
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else DEFAULT_OUT
    worklist = load_worklist()
    EXEMPTIONS = load_exemptions(worklist)
    dispositions = load_loss_dispositions(worklist)
    # A timing-bound entry whose code changed since its measurement still explains its
    # losses, but its gap may have moved: say so, never block.
    for (path, generation), entry in sorted(dispositions.items()):
        if entry['kind'] == 'timing-bound':
            moved = timing_bound_stale(entry)
            if moved:
                print(f'warning: timing-bound {path} (generation {generation}) is STALE: '
                      f'{", ".join(moved)} changed {entry["paths"]} after {entry["measured_at"]}; '
                      're-measure its gap', file=sys.stderr)
    if '--upstream-test-changes' in sys.argv:
        # Read-only: proposes upstream-test-change entries for a WPT-update generation (the
        # latest, or --generation N) from the diff between its two WPT revisions; records nothing.
        try:
            with open(HISTORY) as f:
                existing = json.load(f)
        except (OSError, json.JSONDecodeError) as err:
            sys.exit(f'wpt_progress: cannot read loss history: {err}')
        gens = existing.get('generations', [])
        if not gens:
            sys.exit('wpt_progress: no generation recorded')
        n = int(sys.argv[sys.argv.index('--generation') + 1]) if '--generation' in sys.argv else gens[-1]['n']
        print(upstream_change_report(existing, dispositions, n), end='')
        return 0
    if '--rebuild-history' in sys.argv:
        try:
            with open(HISTORY) as f:
                existing = json.load(f)
        except FileNotFoundError:
            existing = {}
        except (OSError, json.JSONDecodeError) as err:
            sys.exit(f'wpt_progress: cannot read loss history: {err}')
        if 'last_passes' in existing:
            sys.exit('wpt_progress: cannot rebuild tracked generation history: this would erase loss evidence')
    else:
        prepare_loss_baseline(worklist)
    records, files = load_results()
    shape, rescanned = load_shape(worklist)
    areas, _, model = build(worklist, records, shape)
    if '--rebuild-history' in sys.argv:
        rebuild_history(worklist, records, shape)
        print(f"history rebuilt from per-record timestamps -> {HISTORY}")
    history = record_generation(worklist, records, areas)
    reference = load_reference()
    gate_met, gating, run, total, clean = render(
        areas, worklist, records, files, out, history, shape, load_roadmap(), dispositions, reference)

    tot = collections.Counter()
    for c in areas.values():
        tot.update(c)
    targeted, passing = round(tot['sub_targeted']), round(tot['sub_passing'])
    unexplained = unexplained_losses(history, dispositions)
    print(f"{run:,} of {total:,} sources run  |  {gating:,} blocking  |  "
          f"{retry_summary(retry_counts(worklist, records))}  |  {clean:,} clean  |  "
          f"{len(unexplained):,} unexplained subtest losses")
    print(f"subtests: {passing:,} passing of {targeted:,} targeted  "
          f"({passing / targeted * 100 if targeted else 0:.2f}%)  |  "
          f"files clean {clean / total * 100 if total else 0:.2f}%")
    non_enc_pct, file_mean_pct = alt_rates(worklist, records)
    listed_bug = sum(1 for e in EXEMPTIONS.values() if e['kind'] == 'test-bug')
    listed_renderer = sum(1 for e in EXEMPTIONS.values() if e['kind'] == 'needs-renderer')
    print(f"  exempt (all three browsers intentionally deviate; not blocking): "
          f"{tot['exempt'] - tot['exempt_test_bug'] - tot['exempt_needs_renderer']:,} "
          f"of {len(EXEMPTIONS) - listed_bug - listed_renderer:,} listed in {os.path.relpath(EXEMPTIONS_FILE, REPO)}")
    print(f"  exempt until an upstream test bug is fixed (not blocking): {tot['exempt_test_bug']:,} "
          f"of {listed_bug:,} listed in {os.path.relpath(EXEMPTIONS_FILE, REPO)}")
    print(f"  exempt until a renderer answers geometry (not blocking): {tot['exempt_needs_renderer']:,} "
          f"of {listed_renderer:,} listed in {os.path.relpath(EXEMPTIONS_FILE, REPO)}")
    print(f"  of which OK with none passed: {tot['none-passed']:,}  |  pass rate outside encoding/ "
          f"{non_enc_pct:.1f}%  |  mean per-file pass rate {file_mean_pct:.1f}%")
    print('  composition: ' + '  '.join(
        f"{t}={round(tot['sub_t_' + t]):,}/{tot['tier_' + t]}f" for t in TIERS))
    unknown_revisions = sum(1 for p in worklist if p in records and not records[p].get('_wpt_revision'))
    if unknown_revisions:
        print(f'  WPT revision unknown for {unknown_revisions:,} measured files; '
              'their floors are scoped to the individual journal measurement')
    if rescanned:
        print(f"  (rescanned {rescanned:,} sources -> {ESTIMATES})")
    if reference:
        cmp = compare_reference(worklist, records, reference)
        cr, rf = cmp['crane'], cmp['ref']
        name = engine_label(reference['engine'])
        print(f"beside {name} {reference['run']['browser_version']} ({reference['run']['date']}, same files; "
              f"never counted as Crane's): Crane {cr['pass']:,} / {cr['reported']:,} subtests passing, "
              f"{cr['blocking']:,} blocking  |  {name} {rf['pass']:,} / {rf['reported']:,}, {rf['blocking']:,} blocking  |  "
              f"{name} passes more in {len(cmp['ahead_ref']):,} files, Crane in {len(cmp['ahead_crane']):,}")
    else:
        print('no reference run under wpt-results/reference/: no comparison')
    print('GATE MET' if gate_met else 'gate not met')
    gens = history.get('generations', [])
    if gens:
        g = gens[-1]; mv = g.get('moves')
        if mv is None:
            print(f"history: generation {g['n']} (baseline)")
        else:
            print(f"history: generation {g['n']}  +{mv.get('unblocked',0)} unblocked  "
                  f"-{mv.get('regressed',0)} regressed  {mv.get('reclassified',0)} reclassified  "
                  f"{mv.get('newly_run_ok',0)+mv.get('newly_run_blocking',0)} newly run")
        print('Subtests lost since the last generation:')
        current = [(g['n'], loss) for loss in g.get('losses', [])]
        outstanding = [(n, loss) for n, loss in unexplained if n != g['n']]
        heads = {gen['n']: gen.get('head') for gen in gens}
        for n, loss in current + outstanding:
            entry = loss_disposition(n, loss, dispositions, heads.get(n))
            status = ('explained: ' + entry['kind'] + ' — ' + entry['why']) if entry else 'UNEXPLAINED'
            print(f"  generation {n}: {loss['path']}  {loss['before']} -> {loss['after']} "
                  f"(-{loss['before'] - loss['after']})  {status}")
        if not current:
            print('  none in this generation')
        if g.get('loss_baseline_missing'):
            print(f"  previous per-file counts unavailable for {len(g['loss_baseline_missing'])} files; "
                  "their comparison starts here")
    print(f"\nwrote {out}\n  open {out}")
    if unexplained:
        if '--allow-unexplained' in sys.argv:
            print('publication check overridden explicitly by --allow-unexplained; losses remain unexplained')
        else:
            print('publication blocked: explain every loss in tools/wpt_loss_dispositions.txt '
                  'or explicitly pass --allow-unexplained')
            return 1
    return 0


def _check_fixed_crane_test_in_fork():
    """A fixed disposition's red test may be a Crane test in the WPT fork: it is in the
    commit when the tests/wpt revision that commit records holds tests/wpt/crane/<file>
    (lane docopen1, 2026-11-10). An upstream WPT path never is."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
                   GIT_COMMITTER_EMAIL='t@t', GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')

        def git(cwd, *args):
            return subprocess.run(['git', *args], cwd=cwd, env=env, check=True,
                                  capture_output=True, text=True).stdout.strip()
        repo = os.path.join(d, 'repo')
        sub = os.path.join(repo, 'tests', 'wpt')
        os.makedirs(os.path.join(sub, 'crane'))
        git(sub, 'init', '-q')
        with open(os.path.join(sub, 'crane', 'red.html'), 'w') as f:
            f.write('<!doctype html>')
        git(sub, 'add', '.')
        git(sub, 'commit', '-q', '-m', 'crane test')
        with_test = git(sub, 'rev-parse', 'HEAD')
        git(repo, 'init', '-q')
        with open(os.path.join(repo, 'fix.zig'), 'w') as f:
            f.write('// fix')
        git(repo, 'add', 'fix.zig')
        git(repo, 'update-index', '--add', '--cacheinfo', f'160000,{with_test},tests/wpt')
        git(repo, 'commit', '-q', '-m', 'fix + its Crane test')
        bump = git(repo, 'rev-parse', 'HEAD')
        _GIT_ANSWERS.clear()
        assert test_in_commit(bump, 'tests/wpt/crane/red.html', repo)
        assert not test_in_commit(bump, 'tests/wpt/crane/missing.html', repo)
        assert not test_in_commit(bump, 'tests/wpt/dom/upstream.html', repo), 'an upstream file is never ours'
        assert test_in_commit(bump, 'fix.zig', repo)
        assert not test_in_commit(bump, 'tests/v8/none_test.zig', repo)
        _GIT_ANSWERS.clear()


def _check_gate_rule():
    """The gate's status rule, pinned: OK with none passed blocks; OK with no
    subtests, or with any pass, does not; the runner's own statuses pass through."""
    assert gate_status({'status': 'OK', 'passed': 0, 'failed': 40}) == NONE_PASSED
    assert gate_status({'status': 'OK', 'passed': 0, 'failed': 0, 'timed_out': 1}) == NONE_PASSED
    assert gate_status({'status': 'OK', 'passed': 0, 'notrun': 3}) == NONE_PASSED
    assert gate_status({'status': 'OK', 'passed': 1, 'failed': 40}) == 'OK'
    assert gate_status({'status': 'OK', 'passed': 0, 'failed': 0}) == 'OK'
    assert gate_status({'status': 'TIMEOUT', 'passed': 0, 'failed': 0}) == 'TIMEOUT'
    assert NONE_PASSED in GATING
    assert status_of({'status': 'OK', 'passed': 0, 'failed': 2}) == NONE_PASSED
    # A rule change files OK -> NONE-PASSED as reclassified, never as regressed.
    import tempfile
    global HISTORY
    saved = HISTORY
    with tempfile.TemporaryDirectory() as d:
        HISTORY = os.path.join(d, 'h.json')
        with open(HISTORY, 'w') as f:
            json.dump({'generations': [{'n': 1}], 'last_statuses': {'a.html': 'OK', 'b.html': 'OK'}}, f)
        recs = {'a.html': {'status': 'OK', 'passed': 0, 'failed': 3},
                'b.html': {'status': 'TIMEOUT', 'passed': 0, 'failed': 0}}
        h = record_generation(['a.html', 'b.html'], recs, {})
        mv = h['generations'][-1]['moves']
        assert mv.get('reclassified') == 1 and mv.get('regressed') == 1, mv
        assert h['gate_rule'] == GATE_RULE
    HISTORY = saved


def _check_history_subs():
    """Each generation records the headline's subtest sums over every worklist file,
    whatever its status; subtests that move with no file changing standing still make
    a generation, and a regeneration that moves nothing still does not."""
    import tempfile
    global HISTORY
    saved = HISTORY
    wl = ['a.html', 'b.html', 'c.html']
    recs = {'a.html': {'status': 'OK', 'passed': 5, 'failed': 1, 'timed_out': 1, 'notrun': 0},
            'b.html': {'status': 'TIMEOUT', 'passed': 2, 'failed': 0, 'timed_out': 0, 'notrun': 3}}
    try:
        with tempfile.TemporaryDirectory() as d:
            HISTORY = os.path.join(d, 'h.json')
            h = record_generation(wl, recs, {})
            assert h['generations'][-1]['subs'] == {'passed': 7, 'failed': 1, 'timed_out': 1, 'notrun': 3}, h['generations'][-1].get('subs')
            h = record_generation(wl, recs, {})
            assert len(h['generations']) == 1 and h['generations'][-1]['regenerations'] == 1
            more = dict(recs, **{'a.html': dict(recs['a.html'], passed=6, failed=0)})
            h = record_generation(wl, more, {})
            assert len(h['generations']) == 2, 'moved subtests make a generation'
            assert h['generations'][-1]['moves'] == {} and h['generations'][-1]['subs']['passed'] == 8
    finally:
        HISTORY = saved


def _check_history_chart():
    """The history chart plots every generation as a point on each line, fills the
    column, and carries each generation's data for the hover tooltip."""
    def gen(i):
        return {'n': i + 1, 'at': f'2026-09-{19 + i % 10:02d}T12:{i % 60:02d}:00', 'head': f'h{i:03d}',
                'total': 4323, 'run': 4000 + i, 'unrun': 323 - i, 'blocking': 400 - i,
                'crash': 1, 'timeout': 300 - i, 'error': 99, 'clean': 1800 + 3 * i,
                'partial': 0, 'sub_targeted': 1116000, 'sub_passing': 750000 + 100 * i,
                'moves': None if i == 0 else {'changed': 2, 'unblocked': 1, 'regressed': 1},
                'regenerations': 0}
    for count in (3, 80):   # 80: more generations than the old 60-point dot cutoff
        gens = [gen(i) for i in range(count)]
        out = render_history({'generations': gens})
        assert out.count('class="pt ') == 3 * count, f'{count} gens: {out.count(chr(34) + "pt ")} points'
        assert out.count('class="hit"') == count, 'one hover band per generation'
        m = re.search(r'<script type="application/json" class="histdata">(.*?)</script>', out, re.S)
        assert m, 'the tooltip data block is embedded'
        data = json.loads(m.group(1))
        assert len(data) == count and data[-1]['n'] == count
        assert data[-1]['blocking'] == gens[-1]['blocking'] and data[-1]['d_blocking'] == -1
        assert not re.search(r'(^|\n)\s*\.chart \{[^}]*max-width', PAGE_CSS_CHART), 'the chart fills the column'
        assert '<title>' in out, 'each band carries a native tooltip without JavaScript'


def _check_history_sources():
    """Each generation names the journals that moved it - label (the directory under
    wpt-results/) and commit - not the checkout's HEAD: a lane's sweep journal dropped
    into wpt-results/<lane>-<sha>/ is that lane's commit's result. A record re-read from
    the same journal moves nothing and names nothing."""
    import tempfile
    global HISTORY, RESULTS, STATE, git_head
    saved = (HISTORY, RESULTS, STATE, git_head)
    try:
        with tempfile.TemporaryDirectory() as d:
            HISTORY = os.path.join(d, 'h.json')
            RESULTS = os.path.join(d, 'wpt-results')
            STATE = os.path.join(d, 'state.json')
            git_head = lambda: 'cef789b3a'
            os.makedirs(os.path.join(RESULTS, 'flakes-3d0cf4ef0'))
            wl = ['a.html', 'b.html', 'c.html']

            def write(rel, recs, mtime):
                fn = os.path.join(RESULTS, rel)
                with open(fn, 'w') as f:
                    for r in recs:
                        f.write(json.dumps(r) + '\n')
                os.utime(fn, (mtime, mtime))

            # Generation 1: the main checkout's own run, written to wpt-results/.
            write('journal.jsonl', [{'path': p, 'status': 'OK', 'passed': 1} for p in wl], 1_000)
            records, _ = load_results()
            assert records['a.html']['_label'] == '' and records['a.html']['_journal'] == 'journal.jsonl'
            h = record_generation(wl, records, {})
            g = h['generations'][-1]
            assert g['head'] == 'cef789b3a' and g['checkout'] == 'cef789b3a', g
            assert [s_['label'] for s_ in g['sources']] == [''], g['sources']
            assert g['sources'][0]['files'] == 3 and g['sources'][0]['commit'] == 'cef789b3a'

            # Generation 2: a lane's sweep journal moves a.html; the checkout is
            # still at cef789b3a, but the result is 3d0cf4ef0's.
            write('flakes-3d0cf4ef0/journal.jsonl', [{'path': 'a.html', 'status': 'TIMEOUT', 'passed': 0}], 2_000)
            records, _ = load_results()
            assert records['a.html']['_label'] == 'flakes-3d0cf4ef0'
            h = record_generation(wl, records, {})
            g = h['generations'][-1]
            assert g['n'] == 2 and g['head'] == '3d0cf4ef0', g
            assert g['checkout'] == 'cef789b3a'
            assert g['sources'] == [{'label': 'flakes-3d0cf4ef0', 'journal': 'journal.jsonl',
                                     'commit': '3d0cf4ef0', 'files': 1, 'moved': 1}], g['sources']

            # A result stream beside a journal (X.wptreport.jsonl, the site's subtest
            # detail - 200 MB for a sweep) is never read as a journal, even newer.
            write('flakes-3d0cf4ef0/journal.wptreport.jsonl', [{'path': 'b.html', 'status': 'CRASH', 'passed': 0}], 2_500)
            records, files = load_results()
            assert records['b.html']['status'] == 'OK', records['b.html']
            assert not any(f.endswith('.wptreport.jsonl') for f in files), files
            assert not any(f.endswith('.wptreport.jsonl') for f in journal_files()), 'retention reads journals only'
            os.remove(os.path.join(RESULTS, 'flakes-3d0cf4ef0/journal.wptreport.jsonl'))

            # Regenerating with nothing new: no generation, and nothing is attributed
            # to the next one that was not new by then.
            records, _ = load_results()
            h = record_generation(wl, records, {})
            assert len(h['generations']) == 2 and h['generations'][-1]['regenerations'] == 1
            os.makedirs(os.path.join(RESULTS, 'ab-1a2b3c4d5'))
            write('ab-1a2b3c4d5/journal.jsonl', [{'path': 'b.html', 'status': 'OK', 'passed': 7}], 3_000)
            records, _ = load_results()
            h = record_generation(wl, records, {})
            g = h['generations'][-1]
            assert g['n'] == 3 and [s_['label'] for s_ in g['sources']] == ['ab-1a2b3c4d5'], g['sources']
            assert g['sources'][0]['moved'] == 0 and g['sources'][0]['files'] == 1, 'subtests moved, status did not'
            assert g['head'] == '1a2b3c4d5'

            # A label with no commit in it names no commit, and the head falls back
            # to the checkout.
            assert commit_of_label('scratch') is None
            assert commit_of_label('sweep-21edba80f') == '21edba80f'
            assert commit_of_label('main-d86955400') == 'd86955400'
            assert commit_of_label('') is None

            # The table shows where a generation's results came from.
            out = render_history(h)
            assert 'ab-1a2b3c4d5' in out and 'flakes-3d0cf4ef0' in out
    finally:
        HISTORY, RESULTS, STATE, git_head = saved


_EXEMPTION_FIXTURE = """# a comment
[css/x/declined.html]
why = all three keep the old behaviour on purpose
spec = https://example.org/spec#step
chrome.result = wpt.fyi run 6218298311311360: 0/4
chrome.intent = https://issues.chromium.org/issues/1
firefox.result = wpt.fyi run 4877098740350976: 0/4
firefox.intent = https://bugzilla.mozilla.org/show_bug.cgi?id=2
safari.result = wpt.fyi run 5164107446878208: 1/4
safari.intent = https://github.com/WebKit/standards-positions/issues/3
"""


def _check_exemptions():
    """The gate's exemptions (tools/wpt_gate_exemptions.txt), pinned by the same
    rules tools/wpt_site/model.zig tests: every key required, URLs and wpt.fyi
    results checked, worklist paths only, an invalid entry an error; a listed
    file that would block is EXEMPT and counted apart, never as blocking."""
    global EXEMPTIONS
    wl = ['css/x/declined.html', 'css/x/other.html', 'css/x/clean.html']
    ex = parse_exemptions(_EXEMPTION_FIXTURE, wl)
    e = ex['css/x/declined.html']
    assert e['why'] == 'all three keep the old behaviour on purpose'
    assert e['safari.intent'] == 'https://github.com/WebKit/standards-positions/issues/3'
    assert parse_exemptions('', wl) == {} and parse_exemptions('# only comments\n\n', wl) == {}

    def invalid(text, needle, worklist=wl):
        try:
            parse_exemptions(text, worklist)
        except ExemptionError as err:
            assert needle in str(err), (needle, str(err))
            return
        raise AssertionError('accepted an invalid exemption: ' + needle)

    for key in EXEMPTION_KEYS:
        text = '\n'.join(l for l in _EXEMPTION_FIXTURE.split('\n') if not l.startswith(key + ' '))
        invalid(text, 'missing')
    invalid(_EXEMPTION_FIXTURE.replace('https://bugzilla.mozilla.org/show_bug.cgi?id=2', 'bug 2'), 'URL')
    invalid(_EXEMPTION_FIXTURE.replace('https://example.org/spec#step', 'the spec'), 'URL')
    invalid(_EXEMPTION_FIXTURE.replace('wpt.fyi run 6218298311311360: 0/4', 'fails'), 'wpt.fyi run')
    invalid(_EXEMPTION_FIXTURE.replace('chrome.intent', 'edge.intent'), 'unknown key')
    invalid(_EXEMPTION_FIXTURE.replace('why = all', 'why all'), 'key = value')
    invalid(_EXEMPTION_FIXTURE.replace('[css/x/declined.html]', '[]'), 'path')
    invalid('why = x\n', 'before')
    invalid(_EXEMPTION_FIXTURE.replace('spec = ', 'spec = https://a.example/\nspec = '), 'twice')
    invalid(_EXEMPTION_FIXTURE + _EXEMPTION_FIXTURE, 'listed twice')
    invalid(_EXEMPTION_FIXTURE, 'not in the worklist', ['css/x/other.html'])

    saved = EXEMPTIONS
    try:
        EXEMPTIONS = parse_exemptions(_EXEMPTION_FIXTURE +
                                      _EXEMPTION_FIXTURE.replace('css/x/declined.html', 'css/x/clean.html'), wl)
        none_passed = {'status': 'OK', 'passed': 0, 'failed': 4}
        clean = {'status': 'OK', 'passed': 4, 'failed': 0}
        assert gate_status(none_passed, 'css/x/declined.html') == EXEMPT
        assert gate_status({'status': 'TIMEOUT'}, 'css/x/declined.html') == EXEMPT
        assert gate_status(none_passed, 'css/x/other.html') == NONE_PASSED
        assert gate_status(none_passed) == NONE_PASSED
        # A listed file that does not block keeps its standing.
        assert gate_status(clean, 'css/x/clean.html') == 'OK'
        assert EXEMPT not in GATING
        assert status_of(none_passed, 'css/x/declined.html') == EXEMPT
        recs = {'css/x/declined.html': none_passed, 'css/x/other.html': none_passed, 'css/x/clean.html': clean}
        areas, _, _ = build(wl, recs)
        tot = collections.Counter()
        for c in areas.values():
            tot.update(c)
        assert tot['gating'] == 1 and tot['exempt'] == 1 and tot['clean'] == 1, dict(tot)
        assert area_stats(['css/'], wl, recs)['blocking'] == 1
        html_out = render_exempt(recs, wl)
        assert 'css/x/declined.html' in html_out and 'https://github.com/WebKit/standards-positions/issues/3' in html_out
        assert 'wpt.fyi run 4877098740350976: 0/4' in html_out
    finally:
        EXEMPTIONS = saved


_TEST_BUG_FIXTURE = """[html/x/posts-a-report.https.html]
kind = test-bug
why = the test posts a platform object, which structured clone rejects in every engine
upstream = https://github.com/web-platform-tests/wpt/issues/99999
chrome.result = wpt.fyi run 5070179567140864: 3/9 TIMEOUT
firefox.result = wpt.fyi run 5140459022974976: 3/9 TIMEOUT
safari.result = wpt.fyi run 5107094106406912: 3/9 TIMEOUT
revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved
"""


def _check_exemption_kinds():
    """The second exemption kind (the user, 2026-11-08), pinned by the same rules
    tools/wpt_site/model.zig tests: kind = test-bug needs why, the upstream
    web-platform-tests issue or PR, every browser's wpt.fyi result - the same in all
    three - and revisit = when <upstream> is resolved; an entry with no kind is
    intentional, exactly as before; mixing the kinds' keys is an error. A test-bug
    file that would block is EXEMPT, and the page counts it on its own."""
    global EXEMPTIONS
    wl = ['css/x/declined.html', 'html/x/posts-a-report.https.html', 'css/x/other.html']
    e = parse_exemptions(_TEST_BUG_FIXTURE, wl)['html/x/posts-a-report.https.html']
    assert e['kind'] == 'test-bug', e
    assert e['upstream'] == 'https://github.com/web-platform-tests/wpt/issues/99999'
    assert e['revisit'] == 'when https://github.com/web-platform-tests/wpt/issues/99999 is resolved'
    assert e['firefox.result'] == 'wpt.fyi run 5140459022974976: 3/9 TIMEOUT'
    assert 'spec' not in e and 'chrome.intent' not in e
    pr = parse_exemptions(_TEST_BUG_FIXTURE.replace('issues/99999', 'pull/12345'), wl)
    assert pr['html/x/posts-a-report.https.html']['upstream'].endswith('/pull/12345')
    # No kind: intentional, as every entry was before kinds; kind = intentional is the same entry.
    legacy = parse_exemptions(_EXEMPTION_FIXTURE, wl)['css/x/declined.html']
    assert legacy['kind'] == 'intentional', legacy
    explicit = parse_exemptions(_EXEMPTION_FIXTURE.replace('why = ', 'kind = intentional\nwhy = '), wl)['css/x/declined.html']
    assert explicit == legacy, (explicit, legacy)
    both = parse_exemptions(_EXEMPTION_FIXTURE + _TEST_BUG_FIXTURE, wl)
    assert [x['kind'] for x in both.values()] == ['intentional', 'test-bug']

    def invalid(text, needle, worklist=wl):
        try:
            parse_exemptions(text, worklist)
        except ExemptionError as err:
            assert needle in str(err), (needle, str(err))
            return
        raise AssertionError('accepted an invalid exemption: ' + needle)

    for key in ('kind', 'why', 'upstream', 'chrome.result', 'firefox.result', 'safari.result', 'revisit'):
        text = '\n'.join(l for l in _TEST_BUG_FIXTURE.split('\n') if not l.startswith(key + ' '))
        invalid(text, 'not a key of an intentional exemption' if key == 'kind' else 'missing')
    up = 'upstream = https://github.com/web-platform-tests/wpt/issues/99999'
    rv = 'revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved'
    for frm, to, needle in (
            ('kind = test-bug', 'kind = testbug', 'kind must be intentional, test-bug or needs-renderer'),
            (up, 'upstream = https://bugs.webkit.org/show_bug.cgi?id=1', 'web-platform-tests issue or pull request'),
            (up, 'upstream = https://github.com/web-platform-tests/wpt/issues/', 'web-platform-tests issue or pull request'),
            (up, 'upstream = https://github.com/web-platform-tests/wpt.fyi/issues/99999', 'web-platform-tests issue or pull request'),
            (up, 'upstream = wpt#99999', 'web-platform-tests issue or pull request'),
            (rv, 'revisit = later', 'revisit must read'),
            (rv, 'revisit = when https://github.com/web-platform-tests/wpt/issues/1 is resolved', 'revisit must read'),
            ('wpt.fyi run 5070179567140864: 3/9 TIMEOUT', 'TIMEOUT', 'wpt.fyi run'),
            ('wpt.fyi run 5107094106406912: 3/9 TIMEOUT', 'wpt.fyi run 5107094106406912: 9/9', 'the same result in all three browsers'),
            ('wpt.fyi run 5140459022974976: 3/9 TIMEOUT', 'wpt.fyi run 5140459022974976: 3/10 TIMEOUT', 'the same result in all three browsers'),
            ('why = ', 'spec = https://example.org/spec#step\nwhy = ', '"spec" is not a key of a test-bug exemption'),
            ('why = ', 'chrome.intent = https://issues.chromium.org/issues/1\nwhy = ', '"chrome.intent" is not a key of a test-bug exemption'),
            ('kind = test-bug', 'kind = test-bug\nkind = test-bug', 'twice')):
        assert frm in _TEST_BUG_FIXTURE, frm
        invalid(_TEST_BUG_FIXTURE.replace(frm, to), needle)
    invalid(_EXEMPTION_FIXTURE.replace('why = ', up + '\nwhy = '), '"upstream" is not a key of an intentional exemption')
    invalid(_TEST_BUG_FIXTURE, 'not in the worklist', ['css/x/other.html'])

    saved = EXEMPTIONS
    try:
        EXEMPTIONS = parse_exemptions(_EXEMPTION_FIXTURE + _TEST_BUG_FIXTURE, wl)
        none_passed = {'status': 'OK', 'passed': 0, 'failed': 4}
        timeout = {'status': 'TIMEOUT', 'passed': 3, 'timed_out': 1, 'notrun': 5}
        assert gate_status(timeout, 'html/x/posts-a-report.https.html') == EXEMPT
        recs = {'css/x/declined.html': none_passed, 'html/x/posts-a-report.https.html': timeout,
                'css/x/other.html': none_passed}
        areas, _, _ = build(wl, recs)
        tot = collections.Counter()
        for c in areas.values():
            tot.update(c)
        # Both are exempt, neither blocks; the test-bug one is also its own count.
        assert tot['gating'] == 1 and tot['exempt'] == 2 and tot['exempt_test_bug'] == 1, dict(tot)
        html_out = render_exempt(recs, wl)
        assert 'Exempt (all three browsers intentionally deviate)' in html_out
        assert 'Exempt until an upstream test bug is fixed' in html_out
        intentional, bug = html_out.split('Exempt until an upstream test bug is fixed', 1)
        assert 'css/x/declined.html' in intentional and 'posts-a-report' not in intentional
        assert 'html/x/posts-a-report.https.html' in bug and 'css/x/declined.html' not in bug
        assert '<a href="https://github.com/web-platform-tests/wpt/issues/99999">' in bug
        assert 'wpt.fyi run 5107094106406912: 3/9 TIMEOUT' in bug
        assert 'when https://github.com/web-platform-tests/wpt/issues/99999 is resolved' in bug
        # Intentional entries alone render exactly as before kinds.
        EXEMPTIONS = parse_exemptions(_EXEMPTION_FIXTURE, wl)
        assert 'upstream test bug' not in render_exempt(recs, wl)
    finally:
        EXEMPTIONS = saved


_NEEDS_RENDERER_FIXTURE = """[html/x/decodes-image-data.html]
kind = needs-renderer
why = common/security-features decodeImageData reads the image back with getImageData(0, 0, img.clientWidth, img.clientHeight); with no renderer clientWidth is 0 (CSSOM View's no-box answer), so getImageData throws IndexSizeError
assertion = promise_test: Unhandled rejection with value: object "IndexSizeError: IndexSizeError"
"""


def _check_needs_renderer_kind():
    """The third exemption kind (the user, 2026-11-09): a file that fails ONLY
    because no renderer answers geometry still runs and shows, but does not block
    0.1 until a renderer exists. kind = needs-renderer needs `why` (why the
    assertion needs a layout box) and `assertion` (the failing assertion as the
    run reports it), and no other key; the same rules tools/wpt_site/model.zig
    tests. A needs-renderer file that would block is EXEMPT, in its own group and
    its own count."""
    global EXEMPTIONS
    wl = ['css/x/declined.html', 'html/x/posts-a-report.https.html', 'html/x/decodes-image-data.html', 'css/x/other.html']
    e = parse_exemptions(_NEEDS_RENDERER_FIXTURE, wl)['html/x/decodes-image-data.html']
    assert e['kind'] == 'needs-renderer', e
    assert e['assertion'] == 'promise_test: Unhandled rejection with value: object "IndexSizeError: IndexSizeError"', e
    assert e['why'].startswith('common/security-features decodeImageData reads the image back'), e
    assert set(e) == {'kind', 'why', 'assertion'}, e
    every = parse_exemptions(_EXEMPTION_FIXTURE + _TEST_BUG_FIXTURE + _NEEDS_RENDERER_FIXTURE, wl)
    assert [x['kind'] for x in every.values()] == ['intentional', 'test-bug', 'needs-renderer']

    def invalid(text, needle, worklist=wl):
        try:
            parse_exemptions(text, worklist)
        except ExemptionError as err:
            assert needle in str(err), (needle, str(err))
            return
        raise AssertionError('accepted an invalid exemption: ' + needle)

    # Every key is required: without its kind it reads as intentional, whose
    # keys it lacks and whose entry has no `assertion`.
    for key, needle in (('kind', '"assertion" is not a key of an intentional exemption'),
                        ('why', 'missing "why" - a needs-renderer exemption needs the failing assertion and why it needs a layout box'),
                        ('assertion', 'missing "assertion" - a needs-renderer exemption needs the failing assertion and why it needs a layout box')):
        text = '\n'.join(l for l in _NEEDS_RENDERER_FIXTURE.split('\n') if not l.startswith(key + ' '))
        invalid(text, needle)
    asrt = 'assertion = promise_test'
    for frm, to, needle in (
            # No other key: not another kind's, and not an unknown one.
            ('why = ', 'spec = https://example.org/spec#step\nwhy = ', '"spec" is not a key of a needs-renderer exemption'),
            ('why = ', 'upstream = https://github.com/web-platform-tests/wpt/issues/99999\nwhy = ', '"upstream" is not a key of a needs-renderer exemption'),
            ('why = ', 'chrome.result = wpt.fyi run 5070179567140864: 0/2\nwhy = ', '"chrome.result" is not a key of a needs-renderer exemption'),
            ('why = ', 'renderer = none\nwhy = ', 'unknown key "renderer"'),
            ('kind = needs-renderer', 'kind = needs-a-renderer', 'kind must be intentional, test-bug or needs-renderer'),
            ('kind = needs-renderer', 'kind = needs-renderer\nkind = needs-renderer', 'twice'),
            (asrt, 'assertion = \nassertion_ = promise_test', '"assertion" is empty')):
        assert frm in _NEEDS_RENDERER_FIXTURE, frm
        invalid(_NEEDS_RENDERER_FIXTURE.replace(frm, to), needle)
    # Its `assertion` belongs to no other kind.
    a_line = 'assertion = promise_test: x\n'
    invalid(_EXEMPTION_FIXTURE.replace('why = ', a_line + 'why = '), '"assertion" is not a key of an intentional exemption')
    invalid(_TEST_BUG_FIXTURE.replace('why = ', a_line + 'why = '), '"assertion" is not a key of a test-bug exemption')
    invalid(_NEEDS_RENDERER_FIXTURE, 'not in the worklist', ['css/x/other.html'])

    saved = EXEMPTIONS
    try:
        EXEMPTIONS = parse_exemptions(_EXEMPTION_FIXTURE + _TEST_BUG_FIXTURE + _NEEDS_RENDERER_FIXTURE, wl)
        none_passed = {'status': 'OK', 'passed': 0, 'failed': 4}
        timeout = {'status': 'TIMEOUT', 'passed': 3, 'timed_out': 1, 'notrun': 5}
        assert gate_status(none_passed, 'html/x/decodes-image-data.html') == EXEMPT
        recs = {'css/x/declined.html': none_passed, 'html/x/posts-a-report.https.html': timeout,
                'html/x/decodes-image-data.html': none_passed, 'css/x/other.html': none_passed}
        areas, _, _ = build(wl, recs)
        tot = collections.Counter()
        for c in areas.values():
            tot.update(c)
        # All three are exempt, none blocks; each kind has its own count.
        assert tot['gating'] == 1 and tot['exempt'] == 3, dict(tot)
        assert tot['exempt_test_bug'] == 1 and tot['exempt_needs_renderer'] == 1, dict(tot)
        html_out = render_exempt(recs, wl)
        head = 'Exempt until a renderer answers geometry'
        assert head in html_out, html_out
        before, group = html_out.split(head, 1)
        assert 'html/x/decodes-image-data.html' in group and 'html/x/decodes-image-data.html' not in before
        assert 'css/x/declined.html' not in group and 'posts-a-report' not in group
        assert html.escape('promise_test: Unhandled rejection with value: object "IndexSizeError: IndexSizeError"') in group
        assert 'getImageData(0, 0, img.clientWidth, img.clientHeight)' in group
        # A listed file that does not block keeps its standing.
        clean = {'status': 'OK', 'passed': 4, 'failed': 0}
        assert gate_status(clean, 'html/x/decodes-image-data.html') == 'OK'
        # Without the kind, the other groups render exactly as before.
        EXEMPTIONS = parse_exemptions(_EXEMPTION_FIXTURE + _TEST_BUG_FIXTURE, wl)
        assert 'renderer' not in render_exempt(recs, wl)
    finally:
        EXEMPTIONS = saved


def _check_revision_high_water():
    """A WPT snapshot owns its floors; crashes preserve them, older snapshots do not."""
    import tempfile
    global RESULTS, STATE
    saved = RESULTS, STATE
    try:
        with tempfile.TemporaryDirectory() as d:
            RESULTS, STATE = d, os.path.join(d, 'state.json')
            path = 'html/events.html'

            def write(name, passed, revision, mtime, status='OK'):
                fn = os.path.join(d, name + '.jsonl')
                with open(fn, 'w') as f:
                    f.write(json.dumps({'path': path, 'status': status, 'passed': passed,
                                        '_wpt_revision': revision}) + '\n')
                os.utime(fn, (mtime, mtime))

            mt = QUERY_REACHES_PAGE + 100
            write('old', 376, 'a' * 40, mt)
            records, _ = load_results()
            assert high_water(records[path]) == (376, 0)
            write('new', 140, 'b' * 40, mt + 1)
            records, _ = load_results()
            assert high_water(records[path]) == (140, 0), 'old snapshot inflated current target'
            assert records[path]['_pass_hw'] == 140
            write('crash', 0, 'b' * 40, mt + 2, 'CRASH')
            records, _ = load_results()
            assert high_water(records[path]) == (140, 0), 'same-snapshot crash lost the floor'
            assert records[path]['_pass_hw'] == 140
            # A raw journal has no revision field. Losing access to its git
            # object on a later regeneration must not erase persisted evidence.
            write('crash', 0, None, mt + 2, 'CRASH')
            records, _ = load_results()
            assert records[path]['_wpt_revision'] == 'b' * 40
            assert high_water(records[path]) == (140, 0)
            # Replaying all the older journals must neither raise nor erase the floor.
            records, _ = load_results()
            assert high_water(records[path]) == (140, 0)
            os.remove(os.path.join(d, 'new.jsonl'))
            records, _ = load_results()
            assert high_water(records[path]) == (140, 0), 'state must survive journal rotation'
            write('latest', 8, 'c' * 40, mt + 3)
            records, _ = load_results()
            assert high_water(records[path]) == (8, 0) and records[path]['_pass_hw'] == 8
            # Unidentified evidence is not evidence for a known snapshot.
            write('unknown', 999, None, mt - 1)
            records, _ = load_results()
            assert high_water(records[path]) == (8, 0)
            # Migration cannot attribute a mixed legacy floor to the last run.
            with open(STATE, 'w') as f:
                json.dump({path: dict(records[path], _hw_model=2, _sub_hw=999)}, f)
            records, _ = load_results()
            assert high_water(records[path]) == (8, 0)
            # Keep the pre-query-fix bucket separate within its snapshot.
            for fn in journal_files():
                os.remove(fn)
            os.remove(STATE)
            write('pre', 280, 'b' * 40, QUERY_REACHES_PAGE - 1)
            write('post', 140, 'b' * 40, QUERY_REACHES_PAGE + 1)
            records, _ = load_results()
            assert high_water(records[path]) == (140, 280)
            # Unknown snapshots are not interchangeable merely because neither
            # could be identified. They retain only an identical source's floor.
            for fn in journal_files():
                os.remove(fn)
            os.remove(STATE)
            write('unknown-old', 376, None, mt)
            write('unknown-new', 140, None, mt + 1)
            records, _ = load_results()
            assert high_water(records[path]) == (140, 0)
    finally:
        RESULTS, STATE = saved


def _check_subtest_losses():
    """Balanced changes and OK -> OK drops are losses; rerunning cannot hide them."""
    import tempfile
    global HISTORY
    saved = HISTORY
    try:
        with tempfile.TemporaryDirectory() as d:
            HISTORY = os.path.join(d, 'history.json')
            wl = ['a.html', 'b.html']
            recs = {p: {'status': 'OK', 'passed': n, 'failed': 30 - n,
                        '_wpt_revision': 'a' * 40, '_pass_hw': n} for p, n in zip(wl, (29, 20))}
            h = record_generation(wl, recs, {})
            assert h['generations'][-1]['losses'] == []
            recs['a.html'].update(passed=26, failed=4)
            recs['b.html'].update(passed=23, failed=7)
            h = record_generation(wl, recs, {})
            assert len(h['generations']) == 2, 'balanced pass changes must make a generation'
            loss = h['generations'][-1]['losses'][0]
            assert (loss['path'], loss['before'], loss['after']) == ('a.html', 29, 26)
            assert loss['best'] == 29 and loss['before_revision'] == 'a' * 40
            h = record_generation(wl, recs, {})
            assert len(h['generations']) == 2 and len(unexplained_losses(h, {})) == 1
            recs['b.html'].update(passed=24, failed=6)
            h = record_generation(wl, recs, {})
            assert h['generations'][-1]['losses'] == []
            assert len(unexplained_losses(h, {})) == 1, 'later gains cannot erase an unexplained loss'
            explained = {('a.html', 2): {'kind': 'user-ruling', 'why': 'approved <reason>',
                                         'date': '2026-10-20', 'decision': 'keep the correct behavior'}}
            assert unexplained_losses(h, explained) == []
            assert len(unexplained_losses(h, {('a.html', 3): explained[('a.html', 2)]})) == 1
            out = render_losses(h, explained)
            assert 'Subtests lost since the last generation' in out
            assert 'a.html' in out and '29' in out and '26' in out
            assert 'approved &lt;reason&gt;' in out and 'user-ruling' in out
            assert 'UNEXPLAINED' in render_losses(h, {})
            recs['a.html'].update(passed=20, failed=0, _wpt_revision='b' * 40, _pass_hw=20)
            h = record_generation(wl, recs, {})
            loss = h['generations'][-1]['losses'][0]
            assert loss['before_revision'] == 'a' * 40 and loss['after_revision'] == 'b' * 40
            assert loss['best'] == 20, 'best count must belong to the current snapshot'
            change = {('a.html', h['generations'][-1]['n']): {
                'kind': 'upstream-test-change', 'why': 'test removed',
                'wpt.before': 'a' * 40, 'wpt.after': 'b' * 40}}
            assert loss_disposition(h['generations'][-1]['n'], loss, change)
            change[('a.html', h['generations'][-1]['n'])]['wpt.before'] = 'c' * 40
            assert loss_disposition(h['generations'][-1]['n'], loss, change) is None
            # A denominator-only correction also changes the reported generation.
            n = len(h['generations'])
            h = record_generation(wl, recs, {'x': collections.Counter(sub_targeted=60)})
            assert len(h['generations']) == n + 1
    finally:
        HISTORY = saved


_LOSS_FIXTURE = """# Three isolated BASE/TIP pairs, recorded for this generation only.
[a.html]
generation = 170
kind = flake
why = intermittent network timeout; isolated file on the same base and tip
pair.1 = base 3/4; tip 4/4
pair.2 = base 4/4; tip 3/4
pair.3 = base 4/4; tip 4/4
"""


def _check_loss_dispositions():
    wl = ['a.html']
    parsed = parse_loss_dispositions(_LOSS_FIXTURE, wl)
    assert parsed[('a.html', 170)]['kind'] == 'flake'
    assert parse_loss_dispositions('# no entries\n', wl) == {}
    ruling171 = '[a.html]\ngeneration = 171\nkind = user-ruling\nwhy = accepted\ndate = 2026-10-20\ndecision = the user accepted it\n'
    assert len(parse_loss_dispositions(_LOSS_FIXTURE + ruling171, wl)) == 2

    def invalid(text, needle):
        try:
            parse_loss_dispositions(text, wl)
        except LossDispositionError as err:
            assert needle in str(err), (needle, str(err))
            return
        raise AssertionError('accepted invalid disposition: ' + needle)

    for key in ('generation', 'kind', 'why', 'pair.1', 'pair.2', 'pair.3'):
        invalid('\n'.join(l for l in _LOSS_FIXTURE.splitlines() if not l.startswith(key + ' =')), 'missing')
    invalid(_LOSS_FIXTURE + _LOSS_FIXTURE, 'twice')
    invalid(_LOSS_FIXTURE.replace('170', '0'), 'generation')
    invalid(_LOSS_FIXTURE.replace('170', '1.5'), 'generation')
    invalid(_LOSS_FIXTURE.replace('flake', 'maybe'), 'kind')
    invalid(_LOSS_FIXTURE.replace('pair.1', 'pair.4'), 'key')
    invalid(_LOSS_FIXTURE.replace('base 3/4; tip 4/4', 'base 5/4; tip 4/4'), 'pair')
    invalid(_LOSS_FIXTURE.replace('base 3/4; tip 4/4', 'both passed'), 'pair')
    invalid(_LOSS_FIXTURE.replace('[a.html]', '[other.html]'), 'worklist')
    invalid(_LOSS_FIXTURE.replace('[a.html]', '[]'), 'path')
    invalid('why = x\n' + _LOSS_FIXTURE, 'before')
    invalid(_LOSS_FIXTURE + 'why = again\n', 'twice')
    ruling = '[a.html]\ngeneration = 2\nkind = user-ruling\nwhy = accepted\ndate = 2026-10-20\ndecision = user chose this behavior\n'
    assert parse_loss_dispositions(ruling, wl)[('a.html', 2)]['date'] == '2026-10-20'
    invalid(ruling.replace('2026-10-20', '2026-02-30'), 'date')
    change = ('[a.html]\ngeneration = 3\nkind = upstream-test-change\nwhy = removed tests\n'
              'wpt.before = ' + 'a' * 40 + '\nwpt.after = ' + 'b' * 40 + '\n')
    assert parse_loss_dispositions(change, wl)[('a.html', 3)]['wpt.after'] == 'b' * 40
    invalid(change.replace('b' * 40, 'a' * 40), 'different')
    invalid(change.replace('b' * 40, 'unknown'), 'revision')


def _fixed_fixture_repo(d):
    """A git repository for the `fixed` kind's checks: base A, the fix B (which adds
    its red test), C after it on the main line (HEAD), and D on a branch off A that
    never took B. Returns the repo and the full ids."""
    repo = os.path.join(d, 'repo')
    os.makedirs(os.path.join(repo, 'tests'))
    env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
               GIT_COMMITTER_EMAIL='t@t', GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')

    def git(*args):
        return subprocess.run(['git', *args], cwd=repo, env=env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def commit(path, text, message):
        with open(os.path.join(repo, path), 'w') as f:
            f.write(text)
        git('add', path)
        git('commit', '-q', '-m', message)
        return git('rev-parse', 'HEAD')

    git('init', '-q', '-b', 'main')
    a = commit('README', 'a\n', 'A')
    b = commit('tests/red_test.zig', 'test "red" {}\n', 'B: the fix and its red test')
    c = commit('README', 'c\n', 'C')
    git('checkout', '-q', '-b', 'side', a)
    d_ = commit('side.txt', 'd\n', 'D')
    git('checkout', '-q', 'main')
    return repo, {'A': a, 'B': b, 'C': c, 'D': d_}


def _fixed_entry(commit, test='tests/red_test.zig', repro='before 7/200; after 0/200', generation=203):
    return (f'[a.html]\ngeneration = {generation}\nkind = fixed\n'
            'why = a repeat flake is a bug: its cause and fix\n'
            f'commit = {commit}\ntest = {test}\nrepro = {repro}\n')


def _check_fixed_disposition():
    """A fixed bug explains its loss: the fix exists, is merged (an ancestor of HEAD), carries
    its red test and a before/after reproduction - and explains only generations whose head
    lacks the fix, so the same loss after the fix is unexplained again."""
    import tempfile
    wl = ['a.html']
    with tempfile.TemporaryDirectory() as d:
        repo, ids = _fixed_fixture_repo(d)
        b = ids['B']
        parsed = parse_loss_dispositions(_fixed_entry(b[:10]), wl, repo=repo)
        entry = parsed[('a.html', 203)]
        assert entry['kind'] == 'fixed' and entry['commit'] == b[:10]

        def invalid(text, needle):
            try:
                parse_loss_dispositions(text, wl, repo=repo)
            except LossDispositionError as err:
                assert needle in str(err), (needle, str(err))
                return
            raise AssertionError('accepted invalid fixed disposition: ' + needle)

        for key in ('commit', 'test', 'repro'):
            invalid('\n'.join(l for l in _fixed_entry(b).splitlines() if not l.startswith(key + ' =')),
                    f'missing "{key}" for fixed')
        invalid(_fixed_entry(b) + 'pair.1 = base 1/1; tip 1/1\n', 'not evidence for fixed')
        invalid(_fixed_entry('not-a-commit'), 'commit must be')
        invalid(_fixed_entry('0123456789abcdef0123456789abcdef01234567'), 'not a commit of this repository')
        invalid(_fixed_entry(ids['D']), 'not an ancestor of HEAD')
        invalid(_fixed_entry(b, test='tests/missing_test.zig'), 'not in the fix commit')
        # The test must be in the fix's own tree: A predates it.
        invalid(_fixed_entry(ids['A'], test='tests/red_test.zig'), 'not in the fix commit')
        invalid(_fixed_entry(b, repro='it passes now'), 'repro must read')
        invalid(_fixed_entry(b, repro='before 3/2; after 0/2'), 'repro: failures exceed runs')
        invalid(_fixed_entry(b, repro='before 0/200; after 0/200'), 'before must show the bug')
        invalid(_fixed_entry(b, repro='before 2/200; after 4/400'), 'after must fail less often')
        assert parse_loss_dispositions(_fixed_entry(b, repro='before 200/200; after 1/400'), wl, repo=repo)

        # A generation whose head lacks the fix: explained. One that has it - the fix
        # itself or a later head - is not: the bug came back.
        loss = {'path': 'a.html', 'before': 3, 'after': 2, 'best': 3}
        assert loss_disposition(203, loss, parsed, head=ids['A'], repo=repo) == entry
        assert loss_disposition(203, loss, parsed, head=ids['D'][:10], repo=repo) == entry
        assert loss_disposition(203, loss, parsed, head=b, repo=repo) is None
        assert loss_disposition(203, loss, parsed, head=ids['C'], repo=repo) is None
        # A head the repository cannot resolve proves nothing.
        for unknown in (None, '?', 'f' * 40):
            assert loss_disposition(203, loss, parsed, head=unknown, repo=repo) is None, unknown
        # Through the history: generation 203 (head A) explained, 204 (head C) not.
        history = {'generations': [{'n': 203, 'head': ids['A'], 'losses': [loss]},
                                   {'n': 204, 'head': ids['C'], 'losses': [loss]}]}
        both = dict(parsed)
        both[('a.html', 204)] = dict(entry, generation='204')
        assert [n for n, _ in unexplained_losses(history, both, repo=repo)] == [204]
        assert 'explained: fixed' in render_losses(history, both, repo=repo)
        # A fixed entry may follow the path's one flake disposition.
        assert len(parse_loss_dispositions(_LOSS_FIXTURE + _fixed_entry(b), wl, repo=repo)) == 2


def _upstream_fixture_repo(d):
    """A Crane checkout whose tests/wpt is a git repository of two WPT revisions (lane wptup1):
    BEFORE and AFTER differ in a/helper.js (loaded by a/test.html), e/helper2.js (an .any.js's
    META script), resources/testharness.js (the shared harness, loaded by c/shared.html) and
    d/other.js (loaded by nothing). b/same.html loads nothing that changed."""
    repo = os.path.join(d, 'crane')
    wpt = os.path.join(repo, 'tests', 'wpt')
    env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
               GIT_COMMITTER_EMAIL='t@t', GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')

    def git(*args):
        return subprocess.run(['git', *args], cwd=wpt, env=env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def write(files):
        for path, text in files.items():
            os.makedirs(os.path.dirname(os.path.join(wpt, path)), exist_ok=True)
            with open(os.path.join(wpt, path), 'w') as f:
                f.write(text)
        git('add', '-A')

    os.makedirs(wpt)
    git('init', '-q', '-b', 'main')
    harness = '<script src="/resources/testharness.js"></script>\n'
    write({'resources/testharness.js': 'v1\n',
           'a/test.html': harness + '<script src="helper.js"></script>\n',
           'a/helper.js': 'one\n',
           'b/same.html': '<p>nothing loaded</p>\n',
           'c/shared.html': harness,
           'd/unloaded.html': harness.replace('testharness', 'testharnessreport'),
           'resources/testharnessreport.js': 'r\n',
           'd/other.js': 'x\n',
           'e/meta.any.js': '// META: script=helper2.js\ntest(() => {});\n',
           'e/helper2.js': 'h1\n',
           '.crane-upstream-revision': '1' * 40 + '\n'})
    git('commit', '-q', '-m', 'BEFORE')
    before = git('rev-parse', 'HEAD')
    write({'crane/new-test.html': 'ours\n'})   # a Crane test: the fork moves, upstream does not
    git('commit', '-q', '-m', 'CRANE TEST')
    crane_only = git('rev-parse', 'HEAD')
    write({'resources/testharness.js': 'v2\n', 'a/helper.js': 'two\n', 'd/other.js': 'y\n',
           'e/helper2.js': 'h2\n', '.crane-upstream-revision': '2' * 40 + '\n'})
    git('commit', '-q', '-m', 'AFTER')
    return repo, wpt, before, git('rev-parse', 'HEAD'), crane_only


def _upstream_entry(path, before, after, generation=223):
    return (f'[{path}]\ngeneration = {generation}\nkind = upstream-test-change\n'
            f'why = changed upstream\nwpt.before = {before}\nwpt.after = {after}\n')


def _check_upstream_test_change():
    """The WPT update (lane wptup1, 2026-11-14): a loss at a generation that moved to another
    WPT revision is explained per file ONLY where the file or a resource it loads changed
    between the two revisions - never blanket. The tool proposes entries for review and
    names the losses it cannot explain; the parser refuses an entry for a file that is
    byte-identical, resources included."""
    import tempfile
    wl = ['a/test.html', 'b/same.html', 'c/shared.html', 'd/unloaded.html', 'e/meta.any.js']
    with tempfile.TemporaryDirectory() as d:
        repo, wpt, before, after, crane_only = _upstream_fixture_repo(d)
        change = lambda p: upstream_test_change(p, before, after, wpt)
        assert change('a/test.html') == {'own': ['a/helper.js'], 'shared': ['resources/testharness.js']}
        assert change('b/same.html') == {'own': [], 'shared': []}
        assert change('c/shared.html') == {'own': [], 'shared': ['resources/testharness.js']}
        # A sibling nothing loads does not explain a loss.
        assert change('d/unloaded.html') == {'own': [], 'shared': []}
        # A wrapped .any.js test loads the harness the runner wraps it in, too.
        assert change('e/meta.any.js') == {'own': ['e/helper2.js'], 'shared': ['resources/testharness.js']}
        # A revision git cannot resolve proves nothing.
        assert upstream_test_change('a/test.html', before, 'f' * 40, wpt) is None

        # The parser: an entry for a byte-identical file (resources included) is refused.
        parsed = parse_loss_dispositions(_upstream_entry('a/test.html', before, after), wl, repo=repo)
        assert parsed[('a/test.html', 223)]['kind'] == 'upstream-test-change'
        try:
            parse_loss_dispositions(_upstream_entry('b/same.html', before, after), wl, repo=repo)
            raise AssertionError('accepted an upstream-test-change entry for a byte-identical file')
        except LossDispositionError as err:
            assert 'byte-identical' in str(err), str(err)
        # Unknown revisions cannot be checked here; the loss's own revisions decide at explain time.
        assert parse_loss_dispositions(_upstream_entry('b/same.html', 'a' * 40, 'b' * 40), wl, repo=repo)

        # The generation's WPT revision and the WPT-update label.
        recs = {p: {'path': p, '_wpt_revision': after} for p in wl}
        recs['b/same.html']['_wpt_revision'] = before
        assert generation_wpt_revision(wl, recs) == after
        assert generation_wpt_revision(wl, {}) is None
        moved = {'before': before, 'after': after, 'upstream_before': '1' * 40, 'upstream_after': '2' * 40}
        assert wpt_update({'n': 222, 'wpt_revision': before}, after, wpt_repo=wpt) == moved
        assert wpt_update({'n': 222, 'wpt_revision': after}, after, wpt_repo=wpt) is None
        # The fork moves with every Crane test it takes; only a new UPSTREAM revision is an update.
        assert wpt_update({'n': 222, 'wpt_revision': before}, crane_only, wpt_repo=wpt) is None
        assert wpt_update({'n': 222}, after, wpt_repo=wpt) is None            # no revision recorded: no claim
        assert wpt_update(None, after, wpt_repo=wpt) is None
        # An upstream revision git cannot read claims nothing either.
        assert wpt_update({'n': 222, 'wpt_revision': 'f' * 40}, after, wpt_repo=wpt) is None
        # A generation from before `wpt_revision` existed: its per-file revisions (last_passes) tell.
        last = {p: {'passed': 1, 'revision': before} for p in wl}
        assert wpt_update({'n': 222}, after, last, wpt_repo=wpt) == moved
        assert wpt_update({'n': 222}, before, last, wpt_repo=wpt) is None
        assert wpt_update({'n': 222}, after, {p: {'passed': 1, 'revision': None} for p in wl}, wpt_repo=wpt) is None

        # The report proposes entries for review, and only where the evidence is.
        mk = lambda p, n: {'path': p, 'before': n, 'after': n - 1, 'best': n,
                           'before_revision': before, 'after_revision': after}
        history = {'generations': [{'n': 223, 'head': 'x', 'wpt_update': {'before': before, 'after': after},
                                    'losses': [mk(p, 5) for p in wl] +
                                              [dict(mk('a/test.html', 3), after_revision=before)]}]}
        out = upstream_change_report(history, {}, 223, wpt)
        assert out.count('kind = upstream-test-change') == 2, out          # a/test.html and e/meta.any.js
        assert f'[a/test.html]\ngeneration = 223\nkind = upstream-test-change' in out
        assert f'wpt.before = {before}\nwpt.after = {after}' in out
        assert 'a/helper.js' in out
        unexplained = out.split('UNEXPLAINED')[1]
        for p in ('b/same.html', 'd/unloaded.html'):
            assert p in unexplained, p
        assert 'c/shared.html' in out.split('REVIEW')[1].split('UNEXPLAINED')[0]
        # An entry already recorded is not proposed again.
        recorded = parse_loss_dispositions(_upstream_entry('a/test.html', before, after), wl, repo=repo)
        assert upstream_change_report(history, recorded, 223, wpt).count('kind = upstream-test-change') == 1
        # A generation that did not move to another WPT revision is not a WPT-update generation.
        assert 'not a WPT-update generation' in upstream_change_report(
            {'generations': [{'n': 224, 'losses': []}]}, {}, 224, wpt)


def _timing_bound_fixture_repo(d):
    """A git repository for the `timing-bound` kind's checks: A adds src/gap.zig (the
    code the gap runs through) and src/other.zig, B is the measured commit, C changes
    only the README (HEAD of main), E (branch "moved", off C) changes src/gap.zig, and
    D is a side branch off A that never took B. Returns the repo and the full ids."""
    repo = os.path.join(d, 'repo')
    os.makedirs(os.path.join(repo, 'src'))
    env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
               GIT_COMMITTER_EMAIL='t@t', GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')

    def git(*args):
        return subprocess.run(['git', *args], cwd=repo, env=env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def commit(files, message):
        for path, text in files.items():
            with open(os.path.join(repo, path), 'w') as f:
                f.write(text)
            git('add', path)
        git('commit', '-q', '-m', message)
        return git('rev-parse', 'HEAD')

    git('init', '-q', '-b', 'main')
    a = commit({'src/gap.zig': 'gap\n', 'src/other.zig': 'other\n', 'README': 'a\n'}, 'A')
    b = commit({'README': 'b\n'}, 'B: measured')
    c = commit({'README': 'c\n'}, 'C')
    git('checkout', '-q', '-b', 'moved', c)
    e = commit({'src/gap.zig': 'gap moved\n'}, 'E: moves the gap')
    git('checkout', '-q', '-b', 'side', a)
    d_ = commit({'side.txt': 'd\n'}, 'D')
    git('checkout', '-q', 'main')
    return repo, {'A': a, 'B': b, 'C': c, 'D': d_, 'E': e}


def _timing_bound_entry(measured_at, generation=205, tick='125', gap='min 63 / p50 76 / max 100',
                        rate='17/30', paths='src/gap.zig, src/other.zig',
                        condition='a reused connection from an earlier https file in the runner process'):
    return (f'[a.html]\ngeneration = {generation}\nkind = timing-bound\n'
            'why = passes when the navigate -> fetch-start gap crosses a coarsening tick\n'
            f'tick_us = {tick}\ngap_us = {gap}\npass_rate = {rate}\ncondition = {condition}\n'
            f'measured_at = {measured_at}\npaths = {paths}\n')


def _check_timing_bound_disposition():
    """A timing-bound file (the user, 2026-11-06): its result depends on whether a gap
    shorter than Crane's coarsening tick crosses a tick. The entry carries the tick, the
    measured gap, the pass rate under its condition, the commit measured (merged) and the
    code the gap runs through; it explains the path's losses in its own generation and
    every later one, lists the file on the watch list, and is STALE - a warning, never a
    block - once a commit after the measurement touches that code. It is not a flake."""
    import tempfile
    wl = ['a.html']
    with tempfile.TemporaryDirectory() as d:
        repo, ids = _timing_bound_fixture_repo(d)
        b = ids['B']
        parsed = parse_loss_dispositions(_timing_bound_entry(b[:10]), wl, repo=repo)
        entry = parsed[('a.html', 205)]
        assert entry['kind'] == 'timing-bound' and entry['measured_at'] == b[:10]

        def invalid(text, needle):
            try:
                parse_loss_dispositions(text, wl, repo=repo)
            except LossDispositionError as err:
                assert needle in str(err), (needle, str(err))
                return
            raise AssertionError('accepted invalid timing-bound disposition: ' + needle)

        for key in ('tick_us', 'gap_us', 'pass_rate', 'condition', 'measured_at', 'paths'):
            invalid('\n'.join(l for l in _timing_bound_entry(b).splitlines() if not l.startswith(key + ' =')),
                    f'missing "{key}" for timing-bound')
        invalid(_timing_bound_entry(b) + 'pair.1 = base 1/1; tip 1/1\n', 'not evidence for timing-bound')
        invalid(_timing_bound_entry(b, tick='0'), 'tick_us must be')
        invalid(_timing_bound_entry(b, tick='125us'), 'tick_us must be')
        invalid(_timing_bound_entry(b, gap='about 70'), 'gap_us must read')
        invalid(_timing_bound_entry(b, gap='min 80 / p50 76 / max 100'), 'gap_us: min <= p50 <= max')
        # A gap that usually crosses the tick does not make a result depend on it.
        invalid(_timing_bound_entry(b, gap='min 63 / p50 130 / max 400'), 'below tick_us')
        invalid(_timing_bound_entry(b, rate='17'), 'pass_rate must read')
        invalid(_timing_bound_entry(b, rate='0/30'), 'both outcomes')
        invalid(_timing_bound_entry(b, rate='30/30'), 'both outcomes')
        invalid(_timing_bound_entry(b, rate='31/30'), 'both outcomes')
        invalid(_timing_bound_entry('not-a-commit'), 'measured_at must be')
        invalid(_timing_bound_entry('0123456789abcdef0123456789abcdef01234567'), 'not a commit of this repository')
        invalid(_timing_bound_entry(ids['D']), 'not an ancestor of HEAD')
        invalid(_timing_bound_entry(b, paths='src/gap.zig, src/missing.zig'), 'not in the measured commit')
        invalid(_timing_bound_entry(b, paths='src/gap.zig,'), 'not in the measured commit')

        # It explains its own generation and every later one, whatever the head; never
        # an earlier one.
        loss = {'path': 'a.html', 'before': 1, 'after': 0, 'best': 1}
        assert loss_disposition(205, loss, parsed, head=ids['C'], repo=repo) == entry
        assert loss_disposition(209, loss, parsed, head=ids['C'], repo=repo) == entry
        assert loss_disposition(204, loss, parsed, head=ids['C'], repo=repo) is None
        assert loss_disposition(209, {'path': 'b.html', 'before': 1, 'after': 0, 'best': 1}, parsed) is None
        history = {'generations': [{'n': 204, 'head': ids['A'], 'losses': [loss]},
                                   {'n': 205, 'head': ids['B'], 'losses': [loss]},
                                   {'n': 207, 'head': ids['C'], 'losses': [loss]}]}
        assert [n for n, _ in unexplained_losses(history, parsed, repo=repo)] == [204]
        assert 'explained: timing-bound' in render_losses(history, parsed, repo=repo)
        # An exact entry for a later generation is that generation's disposition.
        later = parse_loss_dispositions(
            _timing_bound_entry(b) + '[a.html]\ngeneration = 207\nkind = user-ruling\nwhy = accepted\n'
            'date = 2026-11-06\ndecision = the user accepted it\n', wl, repo=repo)
        assert loss_disposition(207, loss, later, head=ids['C'], repo=repo)['kind'] == 'user-ruling'
        assert loss_disposition(206, loss, later, head=ids['C'], repo=repo)['kind'] == 'timing-bound'

        # STALE once a commit after the measurement touches a listed path - a warning.
        assert timing_bound_stale(entry, repo=repo, head=ids['C']) == []
        moved = timing_bound_stale(entry, repo=repo, head=ids['E'])
        assert len(moved) == 1 and ids['E'].startswith(moved[0]), moved
        assert timing_bound_stale(dict(entry, paths='src/other.zig'), repo=repo, head=ids['E']) == []
        assert loss_disposition(209, loss, parsed, head=ids['E'], repo=repo) == entry
        page = render_timing_bound(parsed, repo=repo, head=ids['E'])
        assert 'Timing-bound watch list' in page and 'a.html' in page and '<b>STALE</b>' in page
        assert 'min 63 / p50 76 / max 100' in page and '17/30' in page and '125' in page
        assert '<b>STALE</b>' not in render_timing_bound(parsed, repo=repo, head=ids['C'])
        assert render_timing_bound({}, repo=repo) == ''

        # Not a flake: the path's one flake disposition is still free, and a flake
        # entry beside it is accepted.
        both = parse_loss_dispositions(_LOSS_FIXTURE + _timing_bound_entry(b), wl, repo=repo)
        assert {e['kind'] for e in both.values()} == {'flake', 'timing-bound'}


def _check_flaky_count():
    """A file is flaky in a generation when its latest record says so; nothing else counts."""
    wl = ['a.html', 'b.html', 'c.html', 'd.html']
    records = {'a.html': {'flaky': True, 'passed': 3}, 'b.html': {'flaky': False, 'retry': {'passed': 1}},
               'c.html': {'passed': 2}, 'other.html': {'flaky': True}}
    assert flaky_paths(wl, records) == ['a.html']


def _check_retry_counts():
    """Retried, skipped-as-unchanged and flaky are counted apart, so a flaky
    number cannot shrink unseen because fewer files were retried."""
    wl = ['flaky.html', 'agreed.html', 'skipped.html', 'clean.html', 'unrun.html']
    records = {
        'flaky.html': {'flaky': True, 'retry': {'status': 'OK', 'passed': 4}, 'passed': 3, 'failed': 1},
        'agreed.html': {'flaky': False, 'retry': {'status': 'OK', 'passed': 3}, 'passed': 3, 'failed': 1},
        'skipped.html': {'retry_skipped': 'matches baseline', 'passed': 3, 'failed': 1},
        'clean.html': {'passed': 4},
        'other.html': {'flaky': True, 'retry': {}},
    }
    c = retry_counts(wl, records)
    assert c == {'retried': 2, 'retry_skipped': 1, 'flaky': 1}, c
    assert retry_summary(c) == '1 flaky of 2 retried, 1 not retried (same as the previous generation)'
    # A skipped file is neither retried nor flaky.
    assert 'skipped.html' not in flaky_paths(wl, records)
    # A sweep without retries reports zeros for all three.
    assert retry_counts(wl, {'clean.html': {'passed': 4}}) == {'retried': 0, 'retry_skipped': 0, 'flaky': 0}


def _check_one_flake_rule():
    """A path may carry one flake disposition; the inherited exceptions are exact."""
    wl = ['a.html'] + list(FLAKE_GRANDFATHERED)
    second = _LOSS_FIXTURE.replace('170', '175')
    try:
        parse_loss_dispositions(_LOSS_FIXTURE + second, wl)
    except LossDispositionError as err:
        assert '[a.html]' in str(err) and 'first is generation 170' in str(err), str(err)
    else:
        raise AssertionError('accepted a second flake disposition for one path')
    # The order in the file does not matter: the earlier entry in the file is "the first".
    try:
        parse_loss_dispositions(second + _LOSS_FIXTURE, wl)
    except LossDispositionError as err:
        assert 'first is generation 175' in str(err), str(err)
    else:
        raise AssertionError('accepted a second flake disposition for one path')
    # A flake and another kind for one path are fine (a flake, then a ruling).
    ruling = '[a.html]\ngeneration = 180\nkind = user-ruling\nwhy = x\ndate = 2026-10-20\ndecision = y\n'
    assert len(parse_loss_dispositions(_LOSS_FIXTURE + ruling, wl)) == 2

    def flake(path, generation):
        return _LOSS_FIXTURE.replace('[a.html]', f'[{path}]').replace('170', str(generation))

    # A grandfathered path keeps exactly its listed generations, and no more.
    for path, (generations, reason) in FLAKE_GRANDFATHERED.items():
        assert len(generations) > 1 and reason.strip(), path
        assert reason.startswith(('fixed', 'explained')), (path, reason)
        text = ''.join(flake(path, g) for g in generations)
        assert len(parse_loss_dispositions(text, wl)) == len(generations)
        try:
            parse_loss_dispositions(text + flake(path, 999), wl)
        except LossDispositionError as err:
            assert path in str(err) and f'first is generation {generations[0]}' in str(err), str(err)
        else:
            raise AssertionError('accepted a new flake disposition for a grandfathered path: ' + path)

    # The list is exactly the real file's inherited duplicates: none missing, none stale.
    with open(LOSS_DISPOSITIONS_FILE) as f:
        text = f.read()
    flakes = collections.defaultdict(list)
    path = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('['):
            path, generation = line[1:-1], None
        elif line.startswith('generation ='):
            generation = int(line.split('=', 1)[1])
        elif line == 'kind = flake':
            flakes[path].append(generation)
    repeated = {p: tuple(sorted(g)) for p, g in flakes.items() if len(g) > 1}
    assert repeated == {p: tuple(sorted(g)) for p, (g, _) in FLAKE_GRANDFATHERED.items()}, repeated


def _check_loss_baseline_migration():
    """Use the old state only if its source still matches the previous generation."""
    import tempfile
    global HISTORY, STATE
    saved = HISTORY, STATE
    try:
        with tempfile.TemporaryDirectory() as d:
            HISTORY = os.path.join(d, 'h.json')
            STATE = os.path.join(d, 'state.json')
            old = {'a.html': {'status': 'OK', 'passed': 29, '_mtime': 1}}
            current = {'a.html': {'status': 'OK', 'passed': 26, '_mtime': 2}}
            legacy = {'generations': [{'n': 169, 'subs': {'passed': 29}}],
                      'last_statuses': {'a.html': 'OK'}, 'gate_rule': GATE_RULE,
                      'last_sources': {'a.html': record_identity(old['a.html'])}}
            with open(HISTORY, 'w') as f:
                json.dump(legacy, f)
            h = record_generation(['a.html'], current, {}, previous_records=old)
            assert h['generations'][-1]['n'] == 170
            assert h['generations'][-1]['losses'][0]['before'] == 29
            with open(HISTORY, 'w') as f:
                json.dump(legacy, f)
            h = record_generation(['a.html'], current, {}, previous_records=current)
            assert h['generations'][-1]['losses'] == [], 'do not invent previous per-file counts'
            assert h['generations'][-1]['loss_baseline_missing'] == ['a.html']
            # Persist the legacy baseline BEFORE load_results replaces STATE.
            # A failed/aborted first report must not discard the old pass count.
            with open(HISTORY, 'w') as f:
                json.dump(legacy, f)
            with open(STATE, 'w') as f:
                json.dump(old, f)
            prepare_loss_baseline(['a.html'])
            with open(STATE, 'w') as f:
                json.dump(current, f)
            prepare_loss_baseline(['a.html'])
            h = record_generation(['a.html'], current, {})
            assert h['generations'][-1]['losses'][0]['before'] == 29
            with open(HISTORY, 'w') as f:
                f.write('{broken history')
            try:
                prepare_loss_baseline(['a.html'])
            except SystemExit as err:
                assert 'cannot read loss history' in str(err)
            else:
                raise AssertionError('corrupt history silently discarded loss evidence')
    finally:
        HISTORY, STATE = saved


def _check_loss_exit_status():
    """The report is reviewable on failure; a no-op rerun still fails; override is explicit."""
    import tempfile
    import io
    import contextlib
    from unittest.mock import patch
    with tempfile.TemporaryDirectory() as d:
        records = {'a.html': {'path': 'a.html', 'status': 'OK', 'passed': 29,
                             '_mtime': QUERY_REACHES_PAGE + 1, '_wpt_revision': 'a' * 40}}
        shape = {'a.html': {'v': 0, 'calls': 30, 'loopy': False}}
        out = os.path.join(d, 'progress.html')
        with patch.multiple(__name__, HISTORY=os.path.join(d, 'history.json'),
                            STATE=os.path.join(d, 'state.json'),
                            load_worklist=lambda: ['a.html'], load_exemptions=lambda *a: {},
                            load_loss_dispositions=lambda *a: {},
                            load_results=lambda: (records, []), load_shape=lambda wl: (shape, 0),
                            load_roadmap=lambda: None, git_head=lambda: 'test'):
            def run(*args):
                capture = io.StringIO()
                with patch.object(sys, 'argv', ['wpt_progress.py', '--out', out, *args]), contextlib.redirect_stdout(capture):
                    code = main()
                return code, capture.getvalue()
            assert run()[0] == 0
            records['a.html']['passed'] = 26
            code, console = run()
            assert code == 1 and '1 unexplained subtest losses' in console
            assert 'a.html' in console and '29 -> 26' in console and 'UNEXPLAINED' in console
            with open(out) as f:
                page = f.read()
            assert '1 unexplained subtest losses' in page
            assert page.index('Subtests lost since the last generation') < page.index('Progress by generation')
            assert run()[0] == 1, 'rerunning must not bypass the gate'
            code, console = run('--allow-unexplained')
            assert code == 0 and '1 unexplained subtest losses' in console
            accepted = {('a.html', 2): {'kind': 'user-ruling', 'why': 'accepted in review',
                                       'date': '2026-10-20', 'decision': 'retain correct behavior'}}
            with patch.object(sys.modules[__name__], 'load_loss_dispositions', lambda *a: accepted):
                code, console = run()
            assert code == 0 and '0 unexplained subtest losses' in console and 'explained: user-ruling' in console
            try:
                run('--rebuild-history', '--allow-unexplained')
            except SystemExit as err:
                assert 'erase loss evidence' in str(err)
            else:
                raise AssertionError('history rebuild erased tracked losses')


# ============================================================================
# Reference runs (lane chromeref1): another engine's results beside Crane's
# ============================================================================

def _reference_fixture(date='2026-11-04T11:00:00Z', version='150.0.7000.1', engine='chrome'):
    files = {
        'dom/a.html': {'status': 'OK', 'passed': 3, 'failed': 0, 'timed_out': 0, 'notrun': 0, 'urls': 1, 'missing_urls': 0},
        'dom/b.html': {'status': 'OK', 'passed': 1, 'failed': 0, 'timed_out': 0, 'notrun': 0, 'urls': 1, 'missing_urls': 0},
        'url/u.html': {'status': 'OK', 'passed': 1, 'failed': 2, 'timed_out': 0, 'notrun': 0, 'urls': 1, 'missing_urls': 0},
        'url/never.html': {'status': 'TIMEOUT', 'passed': 1, 'failed': 0, 'timed_out': 1, 'notrun': 0, 'urls': 1, 'missing_urls': 1},
    }
    for rec in files.values():
        rec['engine'] = engine
    return {
        'format': 'crane-wpt-reference/1', 'engine': engine,
        'run': {'browser_version': version, 'webdriver_version': version, 'channel': 'stable',
                'wpt_revision': '56d7fe562b35dfcb063fac457f24bd0a38205481', 'worklist_commit': '0c228a97aa9',
                'processes': 5, 'host': 'chat.local', 'command': 'wpt run chrome', 'date': date},
        'product': engine, 'time_start': None, 'time_end': None,
        'timing': {'processes': 5, 'reference': {'wall_s': 3600.5, 'user_s': 9000, 'sys_s': 1200},
                   'crane': {'wall_s': 2400, 'user_s': 8000, 'sys_s': 400, 'files': 4, 'runner': 'main-0c228a97aa'},
                   'overhead': {'files': 200, 'reference': {'wall_s': 60, 'user_s': 100, 'sys_s': 20},
                                'crane': {'wall_s': 10, 'user_s': 30, 'sys_s': 5}}},
        'coverage': {'sources': 4, 'sources_in_manifest': 4, 'sources_reported': 4, 'urls_expected': 6,
                     'urls_reported': 5, 'urls_skipped': 0, 'urls_missing': 1, 'urls_outside': 0, 'urls_unknown': 0},
        'files': files,
    }


def _check_reference_never_crane():
    """A reference run's record is never Crane's: a journal line of another engine is refused
    with a message, a state record of one is dropped, wpt-results/reference/ holds no journals,
    and a reference.json outside it is ignored, named."""
    import tempfile, io, contextlib
    global RESULTS, STATE
    saved = RESULTS, STATE
    try:
        with tempfile.TemporaryDirectory() as d:
            RESULTS, STATE = d, os.path.join(d, 'state.json')

            def journal(rel, recs, mtime):
                fn = os.path.join(d, rel)
                os.makedirs(os.path.dirname(fn), exist_ok=True)
                with open(fn, 'w') as f:
                    for r in recs:
                        f.write(json.dumps(r) + '\n')
                os.utime(fn, (mtime, mtime))

            mt = QUERY_REACHES_PAGE + 100
            journal('sweep-abc1234/journal.jsonl', [
                {'path': 'dom/a.html', 'status': 'OK', 'passed': 1, 'failed': 1},
                {'path': 'dom/b.html', 'engine': 'chrome', 'status': 'OK', 'passed': 9}], mt)
            # A reference run copied where Crane's runs are read, newer than Crane's.
            journal('chrome-copy/journal.jsonl', [
                {'path': 'dom/a.html', 'engine': 'chrome', 'status': 'OK', 'passed': 7}], mt + 1)
            journal('top.jsonl', [{'path': 'url/u.html', 'engine': 'firefox', 'status': 'OK', 'passed': 4}], mt + 2)
            # Nothing under reference/ is a journal, whatever its name.
            journal('reference/journal.jsonl', [{'path': 'dom/a.html', 'status': 'OK', 'passed': 5}], mt + 3)
            journal('reference/chrome-150/journal.jsonl', [{'path': 'dom/a.html', 'status': 'OK', 'passed': 6}], mt + 4)
            with open(os.path.join(d, 'reference', 'chrome-150', 'reference.json'), 'w') as f:
                json.dump(_reference_fixture(), f)
            with open(os.path.join(d, 'sweep-abc1234', 'reference.json'), 'w') as f:
                json.dump(_reference_fixture(), f)

            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                records, files = load_results()
            msg = out.getvalue()
            assert records['dom/a.html']['passed'] == 1, records['dom/a.html']
            assert 'dom/b.html' not in records and 'url/u.html' not in records
            assert not any(os.sep + 'reference' + os.sep in f for f in files), files
            assert 'refused 1 record of engine chrome in chrome-copy/journal.jsonl' in msg, msg
            assert 'refused 1 record of engine chrome in sweep-abc1234/journal.jsonl' in msg, msg
            assert 'refused 1 record of engine firefox in top.jsonl' in msg, msg
            assert 'ignored sweep-abc1234/reference.json' in msg, msg

            # A state that already holds another engine's record loses it, and says so.
            with open(STATE) as f:
                state = json.load(f)
            state['url/never.html'] = {'path': 'url/never.html', 'engine': 'chrome', 'status': 'OK', 'passed': 3, '_mtime': 1}
            with open(STATE, 'w') as f:
                json.dump(state, f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                records, _ = load_results()
            assert 'url/never.html' not in records
            assert 'dropped 1 record of another engine from' in out.getvalue(), out.getvalue()
    finally:
        RESULTS, STATE = saved


def _check_reference_load():
    """The newest valid reference of an engine is read from wpt-results/reference/<run>/;
    one of Crane, of another format, or holding another engine's record is refused, named."""
    import tempfile, io, contextlib
    global RESULTS
    saved = RESULTS
    try:
        with tempfile.TemporaryDirectory() as d:
            RESULTS = d

            def put(run, ref):
                os.makedirs(os.path.join(d, 'reference', run), exist_ok=True)
                with open(os.path.join(d, 'reference', run, 'reference.json'), 'w') as f:
                    json.dump(ref, f)

            assert load_reference() is None
            put('chrome-149', _reference_fixture(date='2026-10-01T00:00:00Z', version='149.0.1'))
            put('chrome-150', _reference_fixture())
            put('crane', _reference_fixture(engine='crane'))
            bad = _reference_fixture(date='2026-12-01T00:00:00Z', version='151.0.1')
            bad['files']['dom/a.html']['engine'] = 'firefox'
            put('chrome-151', bad)
            old = _reference_fixture(date='2026-12-02T00:00:00Z', version='152.0.1')
            old['format'] = 'crane-wpt-reference/0'
            put('chrome-152', old)
            put('firefox-140', _reference_fixture(date='2026-12-03T00:00:00Z', version='140.0', engine='firefox'))
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                ref = load_reference()
            assert ref['run']['browser_version'] == '150.0.7000.1', ref['run']
            assert ref['_dir'].endswith('chrome-150')
            msg = out.getvalue()
            assert 'reference/crane/reference.json' in msg and 'Crane' in msg, msg
            assert 'reference/chrome-151/reference.json' in msg and 'firefox' in msg, msg
            assert 'reference/chrome-152/reference.json' in msg, msg
            with contextlib.redirect_stdout(io.StringIO()):
                assert load_reference('firefox')['run']['browser_version'] == '140.0'
    finally:
        RESULTS = saved


def _check_reference_compare():
    """Both engines' numbers over the same worklist, Crane's from its journal counts alone,
    and the files each passes more subtests of, the most first."""
    worklist = ['dom/a.html', 'dom/b.html', 'dom/c.html', 'url/never.html', 'url/u.html']
    records = {
        'dom/a.html': {'path': 'dom/a.html', 'status': 'OK', 'passed': 2, 'failed': 1, 'timed_out': 0, 'notrun': 0},
        'dom/b.html': {'path': 'dom/b.html', 'status': 'TIMEOUT', 'passed': 0, 'failed': 0, 'timed_out': 0, 'notrun': 0},
        'dom/c.html': {'path': 'dom/c.html', 'status': 'OK', 'passed': 2, 'failed': 0, 'timed_out': 0, 'notrun': 0},
        'url/u.html': {'path': 'url/u.html', 'status': 'OK', 'passed': 3, 'failed': 0, 'timed_out': 0, 'notrun': 0},
    }
    cmp = compare_reference(worklist, records, _reference_fixture())
    # Both engines over the files both ran (a, b, u): dom/c.html is Crane's alone, url/never.html Chrome's.
    assert cmp['common'] == 3
    assert cmp['crane'] == {'pass': 5, 'reported': 6, 'fail': 1, 'timeout': 0, 'notrun': 0,
                            'blocking': 1, 'clean': 1, 'run': 3}, cmp['crane']
    assert cmp['ref'] == {'pass': 5, 'reported': 7, 'fail': 2, 'timeout': 0, 'notrun': 0,
                          'blocking': 0, 'clean': 2, 'run': 3}, cmp['ref']
    assert [(p, d) for p, d in cmp['ahead_ref']] == [('dom/a.html', 1), ('dom/b.html', 1)], cmp['ahead_ref']
    assert [(p, d) for p, d in cmp['ahead_crane']] == [('url/u.html', 2)], cmp['ahead_crane']
    assert cmp['only_ref'] == ['url/never.html'] and cmp['only_crane'] == ['dom/c.html']
    assert cmp['areas']['dom'] == {'pass': 4, 'reported': 4, 'blocking': 0, 'run': 2}, cmp['areas']['dom']
    assert cmp['areas']['url'] == {'pass': 2, 'reported': 5, 'blocking': 1, 'run': 2}, cmp['areas']['url']


def _check_harness_split():
    """Two sizes of overhead run separate the start-up; one size makes everything per test."""
    assert harness_split(200, 60) == (0.3, 0.0)
    per, start = harness_split(200, 60, 50, 30)
    assert abs(per - 0.2) < 1e-9 and abs(start - 20) < 1e-9
    assert harness_split(200, 60, 50, 61) == (0.3, 0.0)
    assert harness_split(0, 60) == (0.0, 0.0)
    assert measure_cpu({'user_s': 1, 'sys_s': 2}) == 3 and measure_cpu({'user_s': 1, 'sys_s': 2, 'server_cpu_s': 4}) == 7
    # The sampled process tree wins when rusage missed processes no parent waited for, and not otherwise.
    assert measure_cpu({'user_s': 72, 'sys_s': 28, 'tree_cpu_s': 120}) == 120
    assert measure_cpu({'user_s': 25.5, 'sys_s': 7, 'tree_cpu_s': 30, 'server_cpu_s': 11.5}) == 44


def _check_reference_window():
    """Each side's build is named, and the window's runs give pass counts, CPU and memory side by side."""
    import tempfile
    worklist = ['dom/a.html', 'dom/b.html', 'url/never.html', 'url/u.html']
    records = {'dom/a.html': {'path': 'dom/a.html', 'status': 'OK', 'passed': 2, 'failed': 1, 'timed_out': 0, 'notrun': 0}}
    ref = _reference_fixture()
    ref['run']['build'] = 'Chrome for Testing, official release build'
    ref['timing']['reference'].update(passed=8, reported=11, memory={
        'samples': 3600, 'engine_peak_mb': 6144, 'engine_mean_mb': 3000.4, 'harness_peak_mb': 900, 'harness_mean_mb': 700,
        'groups': 5, 'group_peak_max_mb': 1500, 'group_peak_mean_mb': 1200})
    ref['timing']['crane'].update(runner='release-0c228a97aa', build='release runner: ReleaseSafe throughout, libc malloc',
                                  passed=5, reported=8, memory={
        'samples': 2400, 'engine_peak_mb': 800, 'engine_mean_mb': 512, 'harness_peak_mb': 250.6, 'harness_mean_mb': 200,
        'groups': 330, 'group_peak_max_mb': 400, 'group_peak_mean_mb': 150})
    areas, _, _ = build(worklist, records)
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        page = open(out).read()
    assert '<tr><td class="area">WPT subtests passing in this run</td><td class="num">5 / 8</td><td class="num">8 / 11</td></tr>' in page
    assert '<tr><td class="area">Memory of the engine, peak</td><td class="num">800 MB</td><td class="num">6.0 GB</td></tr>' in page
    assert '<tr><td class="area">Memory of the engine, mean</td><td class="num">512 MB</td><td class="num">2.9 GB</td></tr>' in page
    assert '<tr><td class="area">Memory of the harness, peak</td><td class="num">251 MB</td><td class="num">900 MB</td></tr>' in page
    assert '<tr><td class="area">One runner&rsquo;s engine, largest peak</td><td class="num">400 MB</td><td class="num">1.5 GB</td></tr>' in page
    assert 'Chrome: Chrome for Testing <code>150.0.7000.1</code>, Chrome for Testing, official release build' in page
    assert 'Crane: release runner: ReleaseSafe throughout, libc malloc' in page
    assert 'no ThinLTO and no PGO' in page and 'phys_footprint' in page
    ref['run'].update(js_engine='V8 15.7.1', crane_js_engine='V8 13.1.203')
    ref['timing']['reference_reused'] = 'the host and its load matched'
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        page2 = open(out).read()
    assert 'Crane links V8 <code>13.1.203</code>' in page2 and 'Chrome <code>150.0.7000.1</code> ships V8 <code>15.7.1</code>' in page2
    assert "Chrome&rsquo;s figures are from its run of 2026-11-04, reused beside Crane&rsquo;s: the host and its load matched." in page2
    # On the official-style V8, the V8 line says so instead of naming a gap.
    ref['run']['crane_v8_build'] = 'official'
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        page4 = open(out).read()
    assert 'Crane links V8 <code>13.1.203</code>, built as Chrome&rsquo;s official build is: ThinLTO and PGO' in page4
    assert 'no ThinLTO and no PGO' not in page4
    del ref['run']['crane_v8_build']
    # Before Crane's full run, its build is still named.
    del ref['timing']['crane']
    ref['run']['crane_build'] = 'release runner, overhead only'
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        page3 = open(out).read()
    assert 'Crane: release runner, overhead only' in page3
    assert '<tr><td class="area">The worklist, wall clock</td><td class="num">not measured</td>' in page3


def _check_reference_pool_and_runaway():
    """Beside the wall clock, where each pool's time goes; beside the measured memory, the engine without a runaway file."""
    import tempfile
    worklist = ['dom/a.html', 'dom/b.html', 'url/never.html', 'url/u.html']
    records = {'dom/a.html': {'path': 'dom/a.html', 'status': 'OK', 'passed': 2, 'failed': 1, 'timed_out': 0, 'notrun': 0}}
    ref = _reference_fixture()
    ref['timing']['reference'].update(pool={'work_s': 1538.8}, memory={
        'samples': 3600, 'engine_peak_mb': 6144, 'engine_mean_mb': 3000.4, 'harness_peak_mb': 900, 'harness_mean_mb': 700,
        'groups': 5, 'group_peak_max_mb': 1500, 'group_peak_mean_mb': 1200})
    ref['timing']['crane'].update(
        memory={'samples': 2240, 'engine_peak_mb': 62353, 'engine_mean_mb': 1458, 'harness_peak_mb': 1058,
                'harness_mean_mb': 1053, 'groups': 332, 'group_peak_max_mb': 62214, 'group_peak_mean_mb': 438},
        pool={'work_s': 1347.8, 'chunks': 66, 'chunk_files': 200, 'shard_files': 40, 'barrier_s': 904.6, 'startup_s': 100.9},
        memory_without={'path': 'html/x/runaway.html', 'note': 'a runaway on main too, queued for a fix',
                        'excluded': 'its chunk', 'engine_peak_mb': 1525, 'engine_mean_mb': 572})
    areas, _, _ = build(worklist, records)
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        page = open(out).read()
        render(areas, worklist, records, [], out, reference=_reference_fixture())
        plain = open(out).read()
    assert ('<tr><td class="area">The tests&rsquo; own wall clock, per runner</td><td class="num">22 min 28 s</td>'
            '<td class="num">25 min 39 s</td></tr>') in page
    assert ('<tr><td class="area">Of the wall clock: waiting for a chunk&rsquo;s slowest runner</td>'
            '<td class="num">15 min 5 s</td><td class="num">none: one queue</td></tr>') in page
    assert ('<tr><td class="area">Of the wall clock: chunk start-up</td><td class="num">1 min 41 s</td>'
            '<td class="num">none: one queue</td></tr>') in page
    assert ('Crane&rsquo;s run went in 66 chunks of 200 files, each split into fixed shards of 40 files, one per runner; '
            'a chunk ends when its slowest shard does') in page
    assert 'Chrome&rsquo;s <code>wptrunner</code> feeds its processes from one queue.' in page
    assert '<tr><td class="area">Memory of the engine, peak</td><td class="num">60.9 GB</td><td class="num">6.0 GB</td></tr>' in page
    assert ('<tr><td class="area">Memory of the engine without the runaway file, peak</td><td class="num">1.5 GB</td>'
            '<td class="num">6.0 GB</td></tr>') in page
    assert ('<tr><td class="area">Memory of the engine without the runaway file, mean</td><td class="num">572 MB</td>'
            '<td class="num">2.9 GB</td></tr>') in page
    assert ('Crane&rsquo;s engine peak is one file, <code>html/x/runaway.html</code>: a runaway on main too, queued for a '
            'fix. The rows without the runaway file leave out its chunk; Chrome&rsquo;s are its whole run.') in page
    # A window that measured neither shows neither.
    assert 'own wall clock, per runner' not in plain and 'without the runaway file' not in plain
    # A run that is one shared queue (lane sweepq1) waits for no chunk, and the page says so.
    ref['timing']['crane']['pool'] = {'work_s': 1345.1, 'files_per_runner': 40}
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        queue = open(out).read()
    assert ('<tr><td class="area">The tests&rsquo; own wall clock, per runner</td><td class="num">22 min 25 s</td>'
            '<td class="num">25 min 39 s</td></tr>') in queue
    assert ('<tr><td class="area">Of the wall clock: waiting for a chunk&rsquo;s slowest runner</td>'
            '<td class="num">none: one queue</td><td class="num">none: one queue</td></tr>') in queue
    assert ('Crane&rsquo;s run is one shared queue: each runner takes the next file when it is free, so no runner waits '
            'for another, and each runner process runs 40 files before a fresh one takes its place. The tests&rsquo; own '
            'wall clock is every file&rsquo;s summed over the 5 runners: what a pool that never waits would take. '
            'Chrome&rsquo;s <code>wptrunner</code> feeds its processes from one queue too.') in queue
    assert 'chunks of' not in queue


def _check_reference_render():
    """The page shows the reference beside Crane's numbers, never in them."""
    import tempfile
    worklist = ['dom/a.html', 'dom/b.html', 'url/never.html', 'url/u.html']
    records = {
        'dom/a.html': {'path': 'dom/a.html', 'status': 'OK', 'passed': 2, 'failed': 1, 'timed_out': 0, 'notrun': 0},
        'dom/b.html': {'path': 'dom/b.html', 'status': 'TIMEOUT', 'passed': 0, 'failed': 0, 'timed_out': 0, 'notrun': 0},
        'url/u.html': {'path': 'url/u.html', 'status': 'OK', 'passed': 3, 'failed': 0, 'timed_out': 0, 'notrun': 0},
    }
    ref = _reference_fixture()
    areas, _, _ = build(worklist, records)
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref)
        page = open(out).read()
        render(areas, worklist, records, [], out)
        plain = open(out).read()
    assert '<h2 class="section" id="versus">Crane and Chrome' in page
    assert 'Chrome <code>150.0.7000.1</code>' in page and 'ChromeDriver <code>150.0.7000.1</code>' in page
    assert "In the same window Crane&rsquo;s frozen runner, <code>main-0c228a97aa</code>, ran the same files" in page
    assert '<code>56d7fe562b</code>' in page and '2026-11-04' in page
    assert '<tr><td class="area">WPT subtests passing</td><td class="num">5 / 6</td><td class="num">5 / 7</td></tr>' in page
    assert '<tr><td class="area">Blocking files</td><td class="num">1</td><td class="num">0</td></tr>' in page
    assert 'over the 3 files both ran' in page and 'Not compared: 1 file with a result from Chrome alone, 0 from Crane alone' in page
    # Without a test count, a run is split over the worklist's 6 URLs; with one, over its own.
    assert '<tr><td class="area">Of the wall clock: harness (estimate)</td><td class="num">300 ms</td><td class="num">1.80 s</td></tr>' in page
    ref3 = _reference_fixture()
    ref3['timing']['reference']['tests'] = 3
    ref3['timing']['crane']['tests'] = 3
    ref3['coverage']['sources_reported'] = 2
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'p.html')
        render(areas, worklist, records, [], out, reference=ref3)
        page3 = open(out).read()
    assert '<tr><td class="area">Of the wall clock: harness (estimate)</td><td class="num">150 ms</td><td class="num">900 ms</td></tr>' in page3
    assert 'has a result for 2 of the 4 worklist files' in page3
    assert '<tr><td class="area">The worklist, wall clock</td><td class="num">40 min 0 s</td><td class="num">1 h 0 min</td></tr>' in page
    assert '<tr><td class="area">One empty test, harness alone</td><td class="num">250 ms</td><td class="num">1.50 s</td></tr>' in page
    assert 'CPU is the larger of what the run&rsquo;s harness waited for (rusage) and a once-a-second sample of its whole process tree' in page
    assert 'Where Chrome passes subtests Crane does not' in page and 'Where Crane passes subtests Chrome does not' in page
    assert page.index('>dom/a.html<') < page.index('>dom/b.html<') < page.index('Where Crane passes subtests')
    assert '<th class="hide-sm">Chrome&nbsp;pass&nbsp;/&nbsp;reported</th>' in page
    # Crane's own gate and headline are untouched by the reference.
    assert '<div class="verdict">1 blocking' in page and '<div class="verdict">1 blocking' in plain
    assert 'Crane and Chrome' not in plain and 'Chrome&nbsp;pass' not in plain


def _check_production_journal_only():
    """Only the production run is published (the user, 2026-11-09: WPT runs Crane only "with the
    exact same configuration and memory setup that Crane would have running in a production
    environment"; lane wptcfg): a production record is read, a bug-finding journal given as a
    generation is refused - the report stops, naming it - and a bug-finding record already in the
    state is dropped."""
    import tempfile, io, contextlib
    global RESULTS, STATE
    saved = RESULTS, STATE
    try:
        with tempfile.TemporaryDirectory() as d:
            RESULTS, STATE = d, os.path.join(d, 'state.json')

            def journal(rel, recs, mtime):
                fn = os.path.join(d, rel)
                os.makedirs(os.path.dirname(fn), exist_ok=True)
                with open(fn, 'w') as f:
                    for r in recs:
                        f.write(json.dumps(r) + '\n')
                os.utime(fn, (mtime, mtime))

            mt = QUERY_REACHES_PAGE + 100
            journal('sweep-abc1234/journal.jsonl', [
                {'path': 'dom/a.html', 'status': 'OK', 'passed': 3, 'failed': 0, 'build': 'production'},
                # Records from before the split name no build: today's hybrid runner's.
                {'path': 'dom/b.html', 'status': 'OK', 'passed': 2, 'failed': 1}], mt)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                records, _ = load_results()
            assert records['dom/a.html']['passed'] == 3 and records['dom/a.html']['build'] == 'production'
            assert records['dom/b.html']['passed'] == 2

            # A bug-finding run's journal copied where the generations are read.
            journal('sweep-def5678/journal.jsonl', [
                {'path': 'dom/a.html', 'status': 'CRASH', 'passed': 0, 'build': 'bug-finding'}], mt + 1)
            out = io.StringIO()
            try:
                with contextlib.redirect_stdout(out):
                    load_results()
            except SystemExit as err:
                assert 'bug-finding' in str(err) and 'sweep-def5678/journal.jsonl' in str(err), str(err)
            else:
                raise AssertionError('a bug-finding journal was read as a generation')

            # A bug-finding record in the state (put there by hand, or by an older report) is dropped.
            os.remove(os.path.join(d, 'sweep-def5678', 'journal.jsonl'))
            with open(STATE) as f:
                state = json.load(f)
            state['dom/c.html'] = {'path': 'dom/c.html', 'status': 'OK', 'passed': 1, 'build': 'bug-finding'}
            with open(STATE, 'w') as f:
                json.dump(state, f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                records, _ = load_results()
            assert 'dom/c.html' not in records, records.keys()
            assert 'bug-finding' in out.getvalue()
    finally:
        RESULTS, STATE = saved


def _check_configuration_marker():
    """The generation whose results are the production run's, after hybrid ones, records the
    configuration change - once - and names its build; the site marks it on the history chart,
    as it marks a new snapshot (lane wptcfg)."""
    hybrid = {'a.html': {'path': 'a.html', 'status': 'OK', 'passed': 1}, 'b.html': {'path': 'b.html', 'status': 'OK', 'passed': 1}}
    production = {p: dict(r, build='production') for p, r in hybrid.items()}
    assert generation_build(['a.html', 'b.html'], hybrid) is None
    assert generation_build(['a.html', 'b.html'], production) == 'production'
    # A targeted production run over part of a hybrid generation's files does not yet make it production.
    mixed = dict(hybrid, **{'a.html': production['a.html']})
    assert generation_build(['a.html', 'b.html'], mixed) is None
    assert configuration_change(None, 'production') == CONFIGURATION_CHANGE_PRODUCTION
    assert configuration_change({'n': 213}, 'production') == CONFIGURATION_CHANGE_PRODUCTION
    assert configuration_change({'n': 214, 'build': 'production'}, 'production') is None
    assert configuration_change({'n': 213}, None) is None
    assert CONFIGURATION_CHANGE_PRODUCTION == 'configuration change: production build'


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']:
        _check_production_journal_only()
        _check_configuration_marker()
        _check_declared_variants()
        _check_history_chart()
        _check_gate_rule()
        _check_fixed_crane_test_in_fork()
        _check_history_subs()
        _check_history_sources()
        _check_exemptions()
        _check_exemption_kinds()
        _check_needs_renderer_kind()
        _check_revision_high_water()
        _check_subtest_losses()
        _check_loss_dispositions()
        _check_one_flake_rule()
        _check_fixed_disposition()
        _check_timing_bound_disposition()
        _check_upstream_test_change()
        _check_flaky_count()
        _check_retry_counts()
        _check_loss_baseline_migration()
        _check_loss_exit_status()
        _check_reference_never_crane()
        _check_reference_load()
        _check_reference_compare()
        _check_harness_split()
        _check_reference_window()
        _check_reference_pool_and_runaway()
        _check_reference_render()
        print('wpt_progress self-test: ok')
    else:
        sys.exit(main())
