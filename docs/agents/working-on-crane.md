# Working on Crane: the details behind AGENTS.md

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here.

## What Crane is: the details

A web platform engine in Zig. ~1M lines, 6,300+ files. V8 for JavaScript via a
hand-written C++ FFI wrapper (`src/runtime/engines/v8/v8_wrapper.cpp`, ~9.8k
lines).

Subsystems in `src/`: browser, dom, html, css, selector, fetch, streams, xhr,
websocket, service_worker, storage, cookiestore, csp, trusted_types,
permissions, webdriver, intl (CLDR), url, encoding, mimesniff, infra, webidl,
file, fs, quirks, referrer_policy, urlpattern, console, hr_time, platform,
js_bindings.

The WebIDL surface is **generated** from 341 official IDL files into 1,263
interfaces, with 1,270 hand-written impls behind them.

Layout is a pluggable backend (`src/platform/layout_backend.zig`) — Crane is the
web platform, the host supplies pixels. It links for `aarch64-ios`.

Conformance is judged by WPT (`zig build wpt`), not by our own tests.

So **"framework X does not use this" is not a reason to leave something out**,
and neither is it a reason to stop halfway through an algorithm. That criterion
was used by mistake early in this work and produced two real defects: an
`addEventListener` options flatten that handled only the boolean form because
"React passes booleans", which made `addEventListener(t, fn, 2.3)` register as
a bubble listener when the spec says capture; and `navigation-api/` excluded
from the WPT worklist on the grounds that React and Phoenix do not need it.
When in doubt, implement what the spec says and let WPT report the gap - and
where the spec text and the browsers disagree, golden rule 2 decides: the
browsers win, unless they are only behind a newer spec.

**Stuck on HOW to implement something? Read an engine that already has.**
The specs say what; V8, WebKit, Blink and Gecko show how, and every problem
this engine meets - wrapper lifetime, handle ownership, teardown order, event
dispatch, parser state - was met and solved there first. Read them BEFORE
designing a mechanism, not after a theory has failed:

| Question | Where |
|----------|-------|
| V8's contract for an API (handles, weak callbacks, embedder roots, CHECKs) | `jsengines/v8/include/*.h` - V8 13.1 (the linked prebuilt), local; the doc comments ARE the contract. Source: `jsengines/v8/v8/` is a full checkout at a NEWER V8 (14.6 on 2026-10-19): read the linked version with `git -C jsengines/v8/v8 show 13.1.99:<path>` |
| How a browser binds the DOM to V8 | Blink: `third_party/blink/renderer/bindings/` and `platform/bindings/` (script_wrappable, dom_data_store, the GC controller) in https://github.com/chromium/chromium |
| The most readable DOM and bindings implementation | WebKit: `Source/WebCore/bindings/js/` (JSNodeCustom.cpp, JSDOMWrapper) and `Source/WebCore/dom/` in https://github.com/WebKit/WebKit |
| Implementations annotated with the spec's own step numbers | Gecko: `dom/base/`, `dom/bindings/`, `js/src/` via https://searchfox.org |

Fetch the file, read the function, cite it in the commit. Take the DESIGN,
never the code: the licences differ, and a copied function carries assumptions
about refcounting, tracing and threading that this engine does not share.

## Engine work

**Engine work** (V8 handle ownership, allocator lifetimes, teardown order, the
FFI boundary, build/codegen): there is no spec. Read the code, and prefer a
measurement over an assumption — `gc_bench`, `leaks --atExit`, the live-handle
counters. Guessing at ownership here has shipped use-after-frees twice.

**A change's cost is a pair, read by one command** (docs/performance.md, "A lane's
cost pair"): the tip against its base, both consoles built in the lane's own
mirror, in a timed window on chat.local - a default pass for time and
instructions, and a memory-only pass with `MallocLargeCache=0 MallocMaxMagazines=1` on both sides and
ALWAYS `--collected` (so that a memory row over the bar can be cleared by its
collected figure as well as by its levels), then `perf_bench cost --default=<D>
--memory=<M>`. Its verdict is AGENTS.md's 3% rule, and its table, with every
launch of every row above the bar, goes into the merge report.

## Doing a task: batching the gates

### Batch the expensive gates (the user, 2026-11-01)

Wall-clock time matters as much as tokens. A full `zig build test` is 30-45 minutes on a shared host, a
ReleaseSafe runner build about 12, and a sweep over an hour. Never pay those for a two-line change on its own.

- **Each change still gets its own cheap proof:** its targeted test fails first, then passes
  (`-Dtest-file=`, `--repeat`, a few WPT files).
- **Changes whose files and WPT directories don't overlap share ONE native gate, ONE runner build and ONE
  A/B** over the union of their directories. The directories keep the attribution, and each change is
  still its own commit.
- **Before starting any gate or run over 20 minutes,** look at what else is about to land, and batch it in
  instead of starting the next long job the moment this one ends.
- **WPT pass counts and timing come only from the production runner** (`wpt_runner`, the release
  console's build: the user, 2026-11-09). A batch that touches memory, lifetime, teardown, the engine
  adapter or the event loop also runs the bug-finding runner (`wpt_runner_bug_finding`) over the same files
  and reports its gate and its differences, never its pass counts (.claude/rules/wpt-workflow.md, "The two
  runs").
- **Merge current main into your branch before you report.** If your gated tip's tree is the tree the
  integrator would merge, your gates stand and the merge needs no re-run.

## Timed windows: the window queue (2026-11-20)

A timed window needs a quiet host, with no build and no other window running beside it. Timed windows are a
FULL A/B with its bug-finding, rerun and verify steps, a cost window, and a generation sweep. Do not ask the
integrator for a window any more: **send READY = enqueue your window**, then wait for it with ONE background
command.

```bash
tmp/remote/crane-pool.sh queue server1 maj1-l ab --est 90 \
  --note 'FULL A/B tip-b738e997e62 vs gen 233 + bug + rerun + verify' \
  'TIP=$HOME/crane-work/maj1-l-bins/tip-b738e997e62 G=$HOME/crane-frozen/main-ace97d9c1e bash .maj1/window.sh'
tmp/remote/crane-pool.sh queue-wait server1 maj1-l   # follows the log; exits with the window's rc
```

- **The keeper runs your window when its turn comes.** Each host runs a keeper (`~/crane-wq.sh`). It closes
  the host to new jobs and waits until the running builds and WPT runs have ended and the 1-minute load is
  under the host's gate (server1 6, chat.local 3). Then it closes the host for your mirror and runs your
  command in `~/crane-work/<mirror>` exactly as `crane-pool.sh wpt` does:
  - the command runs detached;
  - its log is `~/crane-work/<mirror>/tmp/crane-pool-run-<id>.log`, with the exit status in `<log>.rc`;
  - `CRANE_POOL_MIRROR` and the host's `CRANE_POOL_PAIR` are exported;
  - an `ab` or `sweep` window starts on a fresh wpt serve.

  When the window ends, the host opens, or the next window takes it.
- **Kinds:** `ab` is a FULL A/B and its steps (server1). `sweep` is a generation sweep. `cost` is a perf_bench
  pair and runs on macOS only (chat.local). `short` is anything else. Give `--est` in minutes. Give a `--note`:
  held-files.md shows it in place of the command.
- **The command runs in the foreground until its work is done**, so never use `&` without `wait`. The window
  ends when the command exits.
- **Builds are not starved between windows.** Before each drain, the keeper opens a BUILD GAP when build jobs
  were already waiting for that host (`crane-remote.sh` records which hosts each waiting job could take). The
  host stays open until those jobs have their slots, for at most 15 minutes (`WQ_BUILD_GAP_MAX_MIN`). Then the
  drain starts and waits for them to finish. A build you ask for after the gap began waits for the next
  handoff.
- **A window that is not moving is reported.** Ten minutes after the window starts, and every ten minutes after
  that, the keeper looks for CPU use in the window's process tree, or a changed file under your mirror's
  `tmp/`, `wpt-results/` or `-bins/`. If it finds neither, it writes `ALERT <time> <host> <mirror>: window
  not moving (<evidence>)` to held-files.md. A window that runs past twice its `--est` gets an ALERT too.
  Windows closed by hand get the same check.
- **The keeper writes the window lines itself:** QUEUED, DRAIN, WINDOW START, WINDOW END, HANDOFF and OPEN go to
  held-files.md. Your own END line carries the results.
- **To see or change your window:** `crane-pool.sh queue-list <host>` shows the queue, the window running now
  and its last movement check. `queue-drop <host> <mirror>` withdraws your window, and `--cancel` stops it while
  it runs. `--after <mirror>` holds your window until that mirror's window ends.
- **The integrator's controls:**
  - `queue-order` sets the order; the default is first come, first served.
  - `queue-pause` / `queue-resume` keep a host open for builds.
  - A `crane-pool.sh close` by hand always wins over the queue until `open`.
- **A window script started any other way (plain ssh) exports `CRANE_POOL_MIRROR=<its mirror>` before it
  sweeps.** Without it, `crane-measure.sh` takes the mirror from the runner's path, then from the working
  directory. The shared WPT tree's path names "main", so a FULL sweep there waits for its own window (lesson
  workflow-timed-windows-go-through-the-window-queue.md). `crane-measure.sh mirror <runner>` tells you which
  mirror a sweep will read as.

## Generated files go in `tmp/`

Everything you generate that isn't source or a committed doc goes in `tmp/`
(gitignored):

```
tmp/summaries/   session summaries, reports
tmp/analysis/    investigation notes
tmp/plans/       design docs, decision logs
tmp/debug/       test output, traces
tmp/scratch/     everything else
```

Project root is for committed docs only (README, CHANGELOG, CONTRIBUTING). Put
something there only if the user explicitly asks for it.

**Background jobs**: use `$CLAUDE_JOB_DIR/tmp` instead — parallel jobs clobber
each other in `/tmp`.

## Clean up as you go: the details

Applies to: build caches, `/tmp` clones and scratch directories, git worktrees
and their branches, crash dumps, throwaway databases, captured logs and profiler
output, and anything under `tmp/` you have finished reading.

Concretely, while working:

- **Finished with a measurement?** Delete the logs it produced. A `leaks` or
  `heap` dump is worth keeping until you have extracted the number, and worthless
  after.
- **Switched approach?** The artifacts of the abandoned one go now.
- **Spawned load generators, servers or background jobs?** Kill them in the same
  step that stops needing them, and verify with `pgrep` rather than assuming.
- **Long session?** Check disk periodically — `df -h /` and
  `du -sh /tmp/* 2>/dev/null | sort -h | tail -5`. Do not wait to be surprised.

Build caches are the big one. `~/Library/Caches/crane-z16-cache` reached **31 GB** in a
single session; deleting it returned 398 GB free to 429 GB. It is worth keeping
while you are still building and worth deleting the moment you are not — a cold
rebuild is ~10 minutes, since V8 itself is prebuilt.

Before reporting a task complete, verify rather than claim:

```bash
git worktree list          # only the checkout you expect
pgrep -fl 'gc_bench|wpt_runner|zig build'   # nothing of yours running
du -sh /tmp/* 2>/dev/null | sort -h | tail -5
```

## When in doubt

1. **Have you committed recently?** If you have working changes, commit them now.
2. **Creating files?** `tmp/`, unless asked otherwise.
3. **Which subsystem?** Check the file path and imports.
4. **Spec work?** Read the complete section from `specs/whatwg/<spec>.md` or `specs/w3c/<spec>.md` (fetch it there first if it is missing or six months old).
5. **Engine work?** Read the code and measure.
6. **Check dependencies** in `src/` before mocking anything.
7. **Look at existing tests** for patterns in similar subsystems.
8. **Inventing a mechanism?** Check how V8, WebKit, Blink or Gecko do it
   first - see "Stuck on HOW" above. If they have a name for it, use theirs.
