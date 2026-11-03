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
   main's own sweep ([lesson](docs/lessons/workflow-a-branchs-wpt-run-replaces-mains-in-the-report.md)).
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

### The runner's build mode

**The WPT runner is built optimized: ReleaseSafe** (the user, 2026-10-11). Zig
optimizes a compilation at its root module's level, so `zig build wpt-runner`
puts ALL of the runner's Zig through LLVM's O3 pipeline. v8_wrapper.cpp and the
runner's own libcurl, mbedTLS, zlib and nghttp2 build at -O2, with the full C
sanitizer, so a failed check names itself as it does in Debug. Crane's modules
keep `-Doptimize`'s `builtin.mode` (Debug), so the refcount ledger, the
ownership checks and the cleanup validation stay.
`tests/wpt_runner/build_mode.zig` decides each part and pins it, and the banner
names all three: `wpt_runner: ReleaseSafe build (Crane modules Debug, C
libraries ReleaseSafe)`. gc_bench is built the same way. The snapshot generator
and every unit test stay Debug: `zig build test` builds neither the runner nor
gc_bench.

- **The price is the compile.** Any edit recompiles the whole runner: on Zig
  0.17 about 12 min and 20.5 GB cold (7 min and 14 GB on 0.16), against
  2 min and 10 GB in Debug. Locally, on a 32 GB Mac, run only one ReleaseSafe
  runner compile at a time.
- **`-Dwpt-runner-optimize=Debug`** (or an explicit `-Doptimize=Debug`) builds
  the Debug runner and gc_bench. Use it for red/green iteration and for a
  diagnosis. The leak and double-free reports are the same in both modes, but
  `CRANE_LEAK_TRACES=1` traces need the Debug runner. Optimized, an allocation
  inlined into its caller is traced from that caller's return address, so the
  trace names no allocation site, and the runner says so when it starts.
- **An A/B compares runners built in the same mode as its baseline**, and
  main's baselines are ReleaseSafe. Between modes, timeouts move. The
  parity sweep (2026-10-11, 10,035 files in each mode) found the
  dom/nodes tampered NodeList files timing out at 60 s in Debug and passing
  in 24 s, a few timing-sensitive resource-timing files passing more often,
  and nothing else once the release-only defects it exposed were fixed. The
  bars ran 2-5x faster. A release build folds identical functions and merges
  equal constants: an identity built on either is Debug-only
  ([lesson](docs/lessons/debugging-equal-constants-share-one-address-in-a-release-build.md)).
