---
paths:
  - "tests/wpt/**"
  - "tests/wpt_runner/**"
  - "tests/wpt_0_1_worklist.txt"
  - "tools/wpt*"
  - "tools/wpt*/**"
  - "wpt-results/**"
  - ".claude/worktrees/*/tests/wpt/**"
  - ".claude/worktrees/*/tests/wpt_runner/**"
  - ".claude/worktrees/*/tests/wpt_0_1_worklist.txt"
  - ".claude/worktrees/*/tools/wpt*"
  - ".claude/worktrees/*/tools/wpt*/**"
---

# The WPT workflow

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here. Claude Code loads this file for the paths above; Codex and a Bash read find it through the core's index.

### Fixing a WPT failure

```bash
zig build wpt -- <path/to/test.html>
```

1. **Isolate.** Comment out every other test in the file, leaving only the
   failing one. Confirm it fails.
2. **Fix it.** Verify the isolated test passes.
3. **Uncomment everything.** Re-run the whole file. This is not optional —
   tests interact, and shared state shows up only here.
4. **Commit** fix + test together.

Isolated or custom tests live in `tests/wpt/crane/`.

### Keep the progress report current

**The 0.1 gate: no file in the worklist blocks.** A file blocks when it times
out, errors or crashes, or when its harness finishes (OK) but none of its
subtests passes (`NONE-PASSED`, `gate_status` in `tools/wpt_progress.py`). "OK"
says only that the page ran to its end; 1,053 files were OK with nothing passing
when this rule was added (2026-09-30). Report blocking files by this rule, and
beside the headline subtest rate report the rate outside `encoding/` and the mean
per-file rate, which the page prints: `encoding/` holds most of the subtests.
One exception (the user, 2026-10-17): a file whose failures exist because ALL
THREE browsers intentionally deviate from the spec - golden rule 2's "all three
intentionally declined" case, each browser with evidence of intent - is omitted
from the blocking count. Each such file is listed with its evidence (the
wpt.fyi results and the standards position, WontFix bug or objection per
browser) in `tools/wpt_gate_exemptions.txt`, which `tools/wpt_progress.py`
reads and the page shows as its own group. A file every browser merely fails,
or that only some browsers decline, is NOT exempt.
A second exception (the user, 2026-11-08): a file that fails IDENTICALLY in Chrome,
Firefox and Safari because of a test bug filed upstream (a web-platform-tests
issue or PR) is omitted from the blocking count until that bug is resolved; it is
listed with the upstream issue and each browser's wpt.fyi result, and revisited
when the issue closes (the exemption ends then). Filing the upstream issue still
needs the user's OK.
A third exception (the user, 2026-11-09, choice (b)): a file whose EVERY failing
subtest fails only because no renderer answers geometry - Crane computes no box
itself; geometry is a read on the rendering engine the compiled-in platform plugs
in (docs/platform-protocol.md 6.9), and the default platform has none - still
runs and shows on the site, but does not block 0.1 until a renderer exists
(`needs-renderer`, its own group on the page). Its evidence is the failing
assertion and why it needs a layout box (e.g. getImageData(0, 0,
img.clientWidth, img.clientHeight) throws IndexSizeError when clientWidth is 0),
derived from a production run's messages and checked by hand. A file that also
fails for any other reason is NOT exempt.
When a generation sweep lands in `wpt-results/<label>/`, append its line to
`tools/wpt_generation_hosts.txt` (`<label> <host> <os>-<arch> <runners>`) before
regenerating the site; an unlisted run shows "not recorded for this generation".


`wpt-results/progress.html` is how the 0.1 gate is watched. It is regenerated
from journals, and only from `wpt-results/*.jsonl` and
`wpt-results/<label>/*.jsonl` - ONE directory deep: it keeps the latest record
per file, ordered by the journal file's mtime, and accumulates them in
`tmp/wpt-progress-state.json`. A run whose journal lands anywhere else - a
scratchpad, `tmp/sweepNN/`, `wpt-results/<label>/<area>/` - never reaches the
page, and nothing says so: the headline simply does not move.

After every feature commit:

1. **Put main's WPT runs where the report reads them - and only main's.** A run
   of main (a sweep, or the integrator's targeted run after a merge): point
   `--output` at `wpt-results/<label>/` (e.g. `wpt-results/sweep-<short-sha>/`),
   or copy its `journal*.jsonl` there afterwards with `cp -p` - `-p` keeps the
   mtime, and the mtime decides which result is latest. Several runs under one
   label go side by side as `journal.<area>.jsonl`, never in subdirectories.
   **A lane's run (any branch that is not main) goes to `wpt-results/lanes/<label>/`**,
   which the report never reads: it takes the newest result per file, so a
   branch's run replaces main's - on 2026-10-04 a lane's full A/B, on a branch
   without main's IndexedDB merge, made a generation 25,000 subtests lower than
   main's own sweep ([lesson](../../docs/lessons/workflow-a-branchs-wpt-run-replaces-mains-in-the-report.md)).
   **A sweep brings its result streams too:** concatenate its
   `full/chunks/*/journal*.wptreport.jsonl` into `journal.wptreport.jsonl` beside its
   `journal.jsonl`. The site's file pages list each subtest's status and failure message only from
   the stream beside the journal that supplied the file's counts; without it, every page shows
   counts alone (generations 83-111 did). Delete the previous sweep's stream when the next lands.
2. **Regenerate:** `zig build wpt-progress -j2 --cache-dir ~/Library/Caches/crane-z16-cache`.
   `wpt-progress` also regenerates Crane's public results site
   (tools/wpt_site/generate.zig, published at https://zig-whatwg.github.io/crane/) into
   `wpt-results/site/`, and when that is the `gh-pages` worktree it commits there as
   "results: generation <n>, Crane <sha>". Push `gh-pages` with main
   (`git push origin main gh-pages`). `zig build wpt-site -- --out=<dir> --no-commit` writes
   a copy anywhere.
3. **Report the headline** - blocking files and passing subtests from the page -
   in your summary.
4. **Keep the roadmap current.** The same page renders the engine roadmap from
   `docs/roadmap.toml`: the shared infrastructure to finish before feature
   areas go to parallel agents, the prerequisites for that, and the areas to
   hand out. When a commit moves a roadmap item, flip its `status` and add the
   commit to its piece's `progress`. Write no numbers there - the page measures
   blocking files per area, retained heap per file and unpushed commits itself.

And at least once per working session, or every few feature commits: a full
worklist sweep at HEAD, from a frozen copy of the runner, into
`wpt-results/sweep-<short-sha>/`, then regenerate. Targeted runs keep the areas
you touched current; only a sweep catches what moved elsewhere.

### The two runs: production and bug-finding

**WPT runs Crane only in its production configuration, the way browsers run
it** (the user, 2026-11-09, 15:38 ET: "I want our WPT to only ever run Crane
with the exact same configuration and memory setup that Crane would have
running in a production environment. We should never special case
something."; 15:40 ET: "ok then we should architect ours like the way browsers
do it"). wpt.fyi scores the browsers' SHIPPING builds. Chromium's and
Firefox's own CI also run WPT on debug, AddressSanitizer and TSan builds,
which never feed a score: their expectations carry per-build conditions
(Firefox metadata's `if debug:` / `if asan:`, Chromium's `[ Debug ]`). Speed
is measured only on release builds. Crane does the same with two builds of one
tree (`tests/wpt_runner/build_mode.zig` `RunnerBuild`, pinned by its tests):

- **The PRODUCTION run: `wpt_runner`** (the `wpt-runner` step). It is Crane
  exactly as its own browser, the release console, runs. Every part is
  ReleaseSafe, the C code is at ReleaseSafe's own sanitizer (`.trap`), it
  allocates with libc's malloc (the allocator the console passes to
  Browser.init), and it links the console's platform graph (linux, darwin),
  the very graph the release console links. It has no poisoning, no debug
  allocator and no test-only hooks, and its banner says so. **It alone
  feeds:** generation sweeps and the progress site, every lane A/B's pass
  counts, cost pairs, perf pairs and every timing gate. Its journal records
  carry `"build":"production"`.
- **The BUG-FINDING run: `wpt_runner_bug_finding`** (the
  `wpt-runner-bug-finding` step). It is the same product on the same platform
  graph with detection added. Crane's modules keep `-Doptimize`'s Debug (the
  refcount ledger, the isolate cleanup validation, the teardown-hold checks).
  The C code runs under the full sanitizer. The allocator is the leak- and
  double-free-detecting one with poison-on-free (`CRANE_POISON_FREES`,
  `CRANE_LEAK_FILES`, `CRANE_LEAK_TRACES` and `CRANE_REFCOUNT_*` live here
  only), and its children start with libc's own scribble (`MallocScribble=1`
  on macOS, `MALLOC_PERTURB_=85` on glibc). It runs the same worklist and is
  **never published and never timed**: `tools/wpt_progress.py` refuses a
  journal whose records say `"build":"bug-finding"`. **Its gate:** no crash,
  no poison read, no leak, no bad free, no panic or failed assertion, no
  refcount or ownership violation.
- **A subtest whose result differs between the two runs is a bug**, never
  accepted silently (flakes are bugs). The `wpt-build-compare` step
  (`-- --production=<dir> --bug-finding=<dir> --log=<bug sweep.log>`,
  `tests/wpt_runner/build_compare.zig`) checks the gate and every difference
  against `tools/wpt_build_differences.txt`. That file is Firefox-metadata
  style: one line per known difference, with an owner and its evidence. It
  only goes down: a difference no longer seen must be removed, and a new one
  fails the comparison until it has an owner and the integrator's OK.
- **A generation is both runs** (the integrator's `freeze-gen.sh` and
  `gen-sweep.sh`): the production journal goes to `wpt-results/<label>/` and
  the site; the bug-finding summary (`compare.txt`) goes to the held-files
  report. The first production generation carries the history's one-time
  marker, "configuration change: production build", and from then on each
  generation's line in `tools/wpt_generation_hosts.txt` records the host's
  font set (`fonts=<hash>`): the production run takes its fonts from the host,
  as a browser does.
- **WPT's own needs reach Crane the way they reach a browser.** The page
  fetches testharness.js from `wpt serve`. At /resources/testharnessreport.js
  the server serves the runner's own report through a config alias, as
  wptrunner serves its own (environment.py, `get_routes`). A runner refuses a
  server that serves the stock file. WPT's certificate authority goes in
  through the console's own `--ca-bundle` option (BrowserConfig.ca_bundle_path),
  and host names resolve through the host's resolver (/etc/hosts, as Safari
  does). The one runner-only path left is test_driver's natives: the vendor
  file, which html.embedder_scripts answers, until its commands move into
  src/webdriver and the runner becomes an in-process WebDriver client (lane
  wptcfg batch 2).

**For a lane:** pass counts and timing come from the production runner, on
both sides of an A/B. **A batch that touches memory, object lifetime,
teardown, the engine adapter or the event loop also runs a bug-finding sweep
of the same directories** and reports its gate and its differences from the
production run. It never reports bug-finding pass counts as results.

### The runner's build modes

**The production runner's modes are the release console's** (above):
ReleaseSafe throughout. **The bug-finding runner is built optimized,
ReleaseSafe** (the user, 2026-10-11). Zig optimizes a compilation at its root
module's level, so the `wpt-runner-bug-finding` step puts ALL of its Zig
through LLVM's O3 pipeline. v8_wrapper.cpp and its own libcurl, mbedTLS, zlib
and nghttp2 build at -O2, with the full C sanitizer, so a failed check names
itself as it does in Debug. Crane's modules keep `-Doptimize`'s `builtin.mode`
(Debug), so the refcount ledger, the ownership checks and the cleanup
validation stay. Each banner names its build: `wpt_runner: the PRODUCTION run`
or `wpt_runner_bug_finding: the BUG-FINDING run`. gc_bench is built in the
bug-finding root's mode (or the release build under `-Dwpt-runner-release`).
The snapshot generator and every unit test stay Debug: the `test` step builds
neither runner nor gc_bench.

- **The price is the compile.** Each runner is one ReleaseSafe compile of the
  whole tree: on Zig 0.17 about 12 min and 20.5 GB cold. Build only the one a
  step needs.
- **`-Dwpt-runner-optimize=Debug`** (or an explicit `-Doptimize=Debug`)
  builds a Debug bug-finding runner and gc_bench. Use it for red/green
  iteration and for a diagnosis. `CRANE_LEAK_TRACES=1` traces need it:
  optimized, an allocation inlined into its caller is traced from that
  caller's return address, so the trace names no allocation site, and the
  runner says so when it starts. The production runner has no Debug variant:
  it is always the release console's build.
- **An A/B compares runners built in the same mode as its baseline.** Main's
  baselines are production runs from the first production generation on, and
  generation 213 and earlier were the hybrid runner (ReleaseSafe root, Debug
  Crane modules, the debug allocator, the testing platform). Between modes,
  timeouts move. A release build folds identical functions and merges equal
  constants: an identity built on either is Debug-only
  ([lesson](../../docs/lessons/debugging-equal-constants-share-one-address-in-a-release-build.md)).
