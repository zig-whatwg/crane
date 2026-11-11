# Tests

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here.

## Tests come first

Write the failing test first, then satisfy it. This is not optional (see global
CLAUDE.md).

Where that is awkward, do it anyway but adapt the form:

- **WPT failures**: isolate the one failing test first, confirm it fails, fix,
  then uncomment and re-run all. That *is* the red-green loop.
- **Leaks**: the failing "test" is a measurement — record the B/cycle or leak
  count *before* the fix, so the after-number means something.
- **Comptime predicates**: pin the default in a test before relying on it.

WPT is the bar: `zig build wpt -- <path>`. Unit tests use
`std.testing.allocator` always, so leaks fail the test. Realistic inputs, spec
edge cases.
One exception: a churn test (100k+ allocations in a loop) checks memory on `@import("root").poisoning.ChurnAllocator` (the poisoning DebugAllocator, `stack_trace_frames = 0`, a leak naming its test): std.testing.allocator's 7-frame capture at every alloc and free was 95% of such a test's time on aarch64 macOS (`sample`, chat2, 2026-11-11: 148 s vs 27 s on server1; [lesson](../docs/lessons/testing-a-test-near-its-timeout-is-a-bug-profile-it-before-blaming-the-product.md)).

**A test directory is one executable, and the launcher runs it.** `zig build test`
compiles each `tests/<dir>/` as ONE test binary, from a root build.zig generates
(`tests/<dir>/.all_tests.zig`, gitignored) - a new `*_test.zig` joins it with
no list to edit. Every test executable - those, the `src/` module roots, the
tool and harness tests - runs through `tools/test_launcher` (`addSuiteRun` in
build.zig; the configuration fails if a step runs one directly). The launcher
runs a binary's tests in seeded, shuffled batches of child processes, several
at once, with a per-test timeout (300 s; a test listed as slow in build.zig's
`suite_configs` gets 4x), and re-runs every test that did not pass alone:
**FAIL** (fails alone), **ORDER-DEPENDENT** (passes alone, fails again after
the tests that ran before it in its process - a bug, named with its batch and
seed), **FLAKY** (the runs disagree). None of the three is a pass; each prints
as `error: '<test>' failed:` with the verdict. A test whose process the
launcher itself could not start (no slot, no spawn) is **LAUNCHER-ERROR**, never
charged to the test: it is not re-run, the suite's step fails, and each cause
prints once as `error: 'test <suite>' failed: LAUNCHER-ERROR, N tests not run
...: <step>, <path>: <error> (<errno>)`. The batch size is per suite
(`suite_configs`: 1, a process per test, for the suites that start V8 or a
Browser; 10 for the rest), so a test may share its process with any other
tests of its binary, in any order: never assume yours is the first to start
V8, initialise a per-thread manager, leave no isolate entered, or set a V8
flag (V8 freezes its flags when it starts; setting one after is a fatal
CHECK). A test may assume only what the process start makes, and leaves the
process as it found it: in tests/v8 every helper goes through
`tests/v8/test_process.zig` - `start()` starts the engine with the runtime's
flags, the hooks and the standalone runtime once, `OwnRuntime` gives a test a
standalone runtime of its own and the process's back, and a test that needs a
realm gets its own `TestAgent`, made by `engine.createAgent` and ended with the
test through `engine.destroyAgent` - no realm outlives its test
([lesson](../docs/lessons/testing-a-test-may-assume-only-what-the-process-start-makes.md)).
A helper never starts or ends the engine itself: `test_process.start()`, and
`startSnapshot(bytes)`/`endSnapshot()` for a test whose subject is the snapshot
(`test_process_test` checks every file). The standalone runtime is the process
start's only in tests-v8 (build.zig `SuiteConfig.standalone_runtime`); in every
other suite a test makes and ends its own, and one that leaves it fails by name
([lesson](../docs/lessons/testing-what-the-process-start-makes-is-a-fact-of-the-suite.md)).
The Crane test runner (`tests/test_runner/`) checks this after every test: a
test that leaves a Browser, agent, Global handle or standalone object alive, or
leaves the start unfinished, fails naming the field and its before and after
values. `CRANE_TEST_STATE=report|off` for a survey; a suite still in report
mode is listed in build.zig as TEMPORARY with its findings file.
A test that needs a fresh per-thread state runs its body on a `std.Thread` of
its own. A race test
between Browsers on different threads gives each Browser its own leak-checking
`@import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 })` instead of the shared
`std.testing.allocator`: the shared one's lock and per-allocation stack capture
make the threads take turns, so the race never happens - a liveclassic race
that crashed 7/7 with per-Browser allocators passed 6/6 with the shared one
([lesson](../docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md)).

**Every allocator a test checks memory with poisons what it frees** (lane
poison2, the user 2026-11-05; tests/test_runner/poisoning.zig). A read after a
free shows only if something changed the freed bytes:

- `std.testing.allocator` is Zig 0.17's `SafeAllocator`, which the Crane test
  runner makes per test with `check_write_after_free`: its free writes 0x55
  over every allocation in a bucket (under 12 KiB) and its bucket release
  panics "write after free" if anything wrote there since; a larger
  allocation is unmapped. A fault at 0x5555... is a read of freed memory.
- A test's own allocator is `@import("root").poisoning.DebugAllocator(config)`,
  a drop-in for `std.heap.DebugAllocator(config)` (`.init`, `allocator()`,
  `deinit()`) with 0xdd written over each block of 32 KiB or less before it is
  freed. Never a bare `std.heap.DebugAllocator`: it neither reuses nor writes a
  freed slot, so a struct read after its `destroy` has its old values and the
  test passes - two service-worker use-after-frees passed every gate that way
  and crashed on libc malloc (lane crashes8,
  [lesson](../docs/lessons/testing-the-debug-allocator-never-reuses-or-poisons-a-freed-slot.md)).
  tests/infra/test_allocators_test.zig fails a test file that makes one. A
  fault at 0xdddd... is a read of a block a test's DebugAllocator freed.
- libc's: the launcher runs every test child with `MallocScribble=1` (macOS;
  `MALLOC_PERTURB_=85` on glibc) for v8_wrapper.cpp's `new`/`delete` and
  `std.heap.c_allocator`. On the pool's macOS 27 malloc already zeroes a
  freed block of up to at least 4 KiB (past its free-list header); the
  scribble fills a freed block of 16 KiB or more with 0x55, which otherwise
  keeps its bytes, and every new block with 0xaa, so a read before a write
  reads 0xaa, not 0.

`CRANE_POISON_FREES=0` turns all three off for one run - to see whether a
failure depends on the poison, never to make a test pass. The launcher passes
it to its children; a cached run step does not rerun for it, so add
`-Dlaunch-seed=random` (or run the test executable or the launcher by hand).
tests/test_runner_fixture/poison_fixture.zig pins it: each of its reads after a
free fails by name under the poison and passes with it off.

What it costs (lane poison2, chat.local, alternating pairs, CPU = user + sys):
a warm `zig build test -Dlaunch-seed=random` with poisoning on against
`CRANE_POISON_FREES=0` ran wall x1.14 and x1.25, CPU x1.26 and x1.18; the html
suites alone ran wall x0.99 to x1.25 (median x1.11), CPU x1.02 to x1.20
(median x1.05); max RSS unchanged. Off also turns off SafeAllocator's check,
which Zig's own runner turns on, and nearly all of the difference is that
check (its free memsets 0x55 and its bucket release reads every freed byte
back, in Debug code): suites that link no V8 and swap no allocator pay the
same share as the rest. The drop-in and the scribble are memsets; from the
per-suite split they add about 0-3% over the check alone.
A test that needs this build's V8 snapshot imports `test_snapshot` (tests/v8),
never a path under `zig-out/`.

**Logs in a test executable.** The runner compiles `std.log` at .info and
prints at .warn while a test runs (`testing.log_level`, which a test may lower
to read info logs): a Debug build's default would analyse and emit every
`log.debug` site in every test executable, for output nobody prints (lane
compiletime1). To read debug logs in a local diagnosis, build with
`-Dtest-log-level=debug`, which compiles and prints them;
tests/infra/test_log_level_test.zig pins the defaults.

- **Seeds.** `zig build test` uses a seed hashed from each executable's bytes,
  printed in that suite's summary line, so an unchanged suite keeps its plan
  and Zig's cache skips it (the user, 2026-11-01). `-Dlaunch-seed=random`
  shuffles afresh every run (never cached); `-Dlaunch-seed=<value>` replays
  one. By hand: `test_launcher <exe> --seed=S --batch=B [--only-batch=K]`.
- **Shapes.** `-Dlaunch-batch=1` runs every test in a process of its own,
  `-Dlaunch-batch=0` each suite in one process, `-Dlaunch-shuffle=true`
  shuffles even the suites kept in index order; `zig build test-launch` runs
  the test executables alone, without the lints and checks `test` adds.
  Results: `tmp/test-launch/<suite>.jsonl` (+ `.log`, the output of each
  non-pass); they also order the next run, longest batches first.

One file alone, for a quick red/green:
`zig build test -Dspec=<dir> -Dtest-file=tests/<dir>/foo_test.zig -j2`.

**Some tests, from the cached binaries: `-Dtest-filter=PATTERN`** (lane
onebin2, 2026-11-04; the user: "rely on zig's own build cache ... then run
isolated tests by file name or test name"). Each pattern goes to every
suite's launcher (`--filter`, tools/test_launcher/filter.zig), which runs only
the tests it matches - selection at RUN time, so no executable changes: Zig's
cache rebuilds only what an edit touched, every unchanged suite stays cached,
and only the selected tests run. A pattern matches a test's WHOLE name; `*` is
any run of characters (none included), every other character is itself. Names
start with the file's path under its directory, so one pattern covers files and
tests:

```bash
zig build test -j2 -Dtest-filter='mutation_test*'                    # every test of tests/<dir>/mutation_test.zig
zig build test -j2 -Dtest-filter='mutation_test.test.removes*'       # some of them
zig build test -j2 -Dtest-filter='*removes a child*'                 # any test whose name holds that
zig build test -j2 -Dtest-filter='a_test*' -Dtest-filter='b_test*'   # repeatable: any pattern
zig build test -j2 -Dtest-filter='navigation.nav2_sync_*'            # tests/html/navigation/: "<subdir>.<stem>"
```

A suite with no matching test runs nothing and passes, and its launcher line
says so (`test_launcher: tests-css: filter mutation_test*: no test of 1674
matches, nothing run`); a suite with matches says how many (`test_launcher:
tests-dom: filter mutation_test*: 14 of 642 tests; seed ...`), and the Build
Summary counts only the selected tests (`14/14 tests passed`). Under `-Dtest-binaries=v8` a pattern also matches a name
without its directory prefix, so the same pattern selects the same tests in
both layouts. A filtered run's results go to `tmp/test-launch/<suite>.filtered.jsonl`,
never over the full run's timings. The run step is cached like any other:
the same filter on an unchanged tree runs nothing again (add
`-Dlaunch-seed=random` to rerun). `-Dspec=<dir>` still narrows what is built;
`-Dtest-file` still builds one file alone (a different binary - the filter
reuses the cached one).

What it saves, measured on chat2.local, `-Dtest-binaries=dirs`, `-j2`, warm cache
(lane onebin2, 2026-11-04, tmp/plans/lane-onebin2-handoff.md): the RUN, never the
compile. One tests/dom file changed: tests-dom recompiles either way (about 3.5
minutes: Sema and code generation 41%, LLVM Emit Object 58%), then its 642 tests
take 35-45 s, against 2 s for one file's 9 tests. In all: 258 s for the filtered
full run (every other suite's launcher also starts its executable once, to list
its tests, beside the compile), 239 s for a plain `-Dspec=dom` run, 245 s for a
plain full run (lane onebin1, an earlier tree). One src/dom leaf changed: every
executable that imports dom recompiles - 1,416 s plain, 1,387 s filtered (the
wall is the compile chain), but 1,884 s of CPU against 5,204 s, so the host is
free sooner.

Zig's own speed-ups for this loop, tried in the same window: `--watch` works over
a pool mirror (crane-remote's rsync renames each file into place, and the host's
file events see it), but saves only the restart - a tests/dom file 241 s, a
src/dom leaf 250 s, rebuild and run under `-Dspec=dom`. `-fincremental` cannot
build anything on aarch64-macos with the pinned Zig (0.17.1-dev+77c319a0f0): each
compile panics `TODO(MachO2): load archive` (a hello world too) - known and
expected upstream: `-fincremental` on macOS selects the new Mach-O linker, still
a stub, and the old one cannot do incremental either (ziglang/zig on Codeberg:
#37268, closed as expected; #32053 "-fincremental -fllvm crashes self-hosted
linkers", open). Retry when the pin moves. And it could
save at most the Sema and code generation share (about 40% of a test binary's
rebuild): LLVM Emit Object (about 58%) is redone whole either way.

**Test binaries: two layouts (`-Dtest-binaries`)** (lanes onebin1 and onebin2;
the user chose the hybrid, 2026-11-03):

- **`dirs`, the default:** one executable per tests/<dir>/ (`addTestFilesFromDir`).
  A change to one test file rebuilds only its directory's executable.
- **`v8`, for cold full gates** (main's gate, tmp/remote/gate-main.sh, and the
  final checks): the directories that link V8 join ONE executable, "tests",
  rooted at the generated tests/.all_tests.zig (`finishOneBinary`): each of their
  executables analyses and links the whole engine, so one does that work once;
  the rest keep their cheap executables. Test names carry the directory first
  ("html.editing2_join_test.test.joins"), and each member keeps its own
  `suite_configs` row, keyed by that prefix: its batch size (`--group`), its
  slow, alone and tsan_skip names, `--plain` for a member that links no V8, and
  test-verify per member. A member whose row the joined executable cannot honour
  - a process count of its own (`jobs`), index order, a state-check or variant
  mode other than `.fail` - keeps its own executable, as do tests/runtime (the
  engine-less tier), tests/codegen (its module root is imported as a file), the
  src/ module roots and the tool tests. A third layout, every directory in one
  (`one`), lost to `v8` on every row and was removed.

Measured on chat2.local (8 cores, 24 GB), fixed `-j2`, fresh local and global
cache per cold run, 18 skipped in each (lane onebin1, tmp/plans/lane-onebin1-handoff.md);
wall s / CPU s (user+sys) / peak RSS GB:

| `zig build test` | `dirs` | `one` (removed) | `v8` |
|---|---|---|---|
| cold | 2,176 / 7,074 / 15.6 | 1,860 / 6,424 / 14.7 | 1,560 / 7,008 / 14.5 |
| nothing changed | 60 | 58 | 59 |
| one src/dom leaf changed | 1,621 / 5,260 / 14.2 | 1,320 / 5,596 / 16.0 | 1,097 / 4,648 / 12.2 |
| one tests/dom file changed | 245 / 460 / 14.6 | 936 / 4,453 / 14.2 | 775 / 3,404 / 16.2 |
| one tests/v8 file changed | 313 / 638 / 15.3 | 936 | 746 / 3,482 / 15.9 |

Once per merge round the integrator runs the launcher in the two shapes that
show what sharing a process hides: every suite at batch 1 (`zig build
test-launch -Dlaunch-batch=1`, every test in a process of its own - a test that
passes only because an earlier one started V8 or installed a hook for it fails
there), and every suite as one shuffled process with fresh seeds (`zig build
test-launch -Dlaunch-batch=0 -Dlaunch-shuffle=true -Dlaunch-seed=random`, three
runs - a test that fails after another left state behind is ORDER-DEPENDENT
there). Both use the per-directory binaries; the per-file executables of
`-Dtest-isolation=file` (1,592 of them, about four times the CPU) are retired
(2026-11-01, lane v8order1, once tests-v8 passed both shapes).

**Two variants, run every night** (tmp/remote/nightly-tests.sh; results in
tmp/nightly/, `latest` and `index.tsv`), and by hand with `test` or
`test-launch` (lane tsan1, 2026-11-02):

- **`-Dsanitize-thread`**: every test executable built with ThreadSanitizer -
  Crane's own modules, v8_wrapper.cpp among them; the C libraries and the V8
  prebuilt stay uninstrumented - and run with `TSAN_OPTIONS=halt_on_error=1`,
  so a race crashes its process and is blamed on the test that was running,
  with line numbers (a dSYM beside each macOS executable). A race in Crane's
  code is a bug with an owner; `tools/test_launcher/tsan_suppressions.txt` takes
  only a proven false positive of the uninstrumented V8, with its proof.
- **`-Dmany-browsers`**: every test of a suite that links V8 runs beside a
  second, busy Browser on another thread of its process
  (tests/test_runner/busy_browser.zig: page loads, timers, DOM churn, a Browser
  per iteration) - V8's `--isolates` variant, WebKit's `--threaded`. The runner
  holds it between iterations while it takes each state digest, and a failure
  of the busy Browser fails the test it ran beside. A suite whose findings are
  not fixed yet runs it report-only (`suite_configs` `.many_browsers =
  .report`, TEMPORARY, naming its findings file): every verdict printed and
  recorded in tmp/test-launch/<suite>.many-browsers.jsonl, the step passes.

The two combine (`-Dsanitize-thread -Dmany-browsers`: races between two
instances). A variant's results go beside the suite's own:
tmp/test-launch/<suite>.tsan.jsonl, .many-browsers.jsonl.

Two kinds this codebase keeps needing:

1. **Memory.** `std.testing.allocator` does not see C++ allocations. For
   anything touching V8 handles or allocators, measure with `zig build gc-bench`
   and name leaks with `leaks --atExit -- <cmd>`. Run the WPT runner under it
   in-process: no `--parallel` (not even `=1`) and no `--supervise`, which make
   it a supervisor of child processes that `leaks` never inspects
   ([lesson](../docs/lessons/testing-leaks-at-exit-sees-only-the-supervisor-not-its-child-runners.md)).
2. **Comptime predicates** that gate handle ownership (`typeRetainsContext`,
   `argHandleIsCopied`) must have a test pinning their **default**, not just
   their known cases. See `tests/v8/retention_predicate_test.zig` — two
   use-after-frees shipped because the default was wrong.

### Regression protocol for handle-ownership changes

`zig build test` is **not** sufficient, and neither are DOM WPT files — they
missed two use-after-frees that shipped.

```bash
./zig-out/bin/wpt_runner html/webappapis/timers/ --parallel=3   # x3, count crashes
```

**A sweep-only crash is fixed only when counts say so.** A plausible mechanism with a green unit test is
not proof that it caused a crash seen only in sweeps. Claim it fixed with a same-list comparison: main's
runner crashing k of N single-process runs of the list that preceded the crash, yours 0 of N, N at least 6.
Otherwise it is unproven and stays open (2026-09-30: the WebSocket pump-token use-after-free was real, fixed,
and not the sweep crash - main 1/6, the fixed tip 4/6).

## Verify mode (part of "Before every commit")

**A branch that adds or changes tests also passes verify mode, and its merge
report quotes it** (the approved test plan, section 6: Gecko's test-verify runs
a changed test 10 times in one browser and 5 times fresh; Chromium 20x; WebKit
10x). A test that fails one run in fifteen is a flake on its first day: fix it
before it lands, not after it has an owner-less bug.

```bash
# The changed test files, computed in the checkout (a pool mirror has no .git):
files=$(git diff --name-only --diff-filter=AMR main...HEAD -- 'tests/*_test.zig' ':!tests/wpt' | paste -sd, -)
crane-remote.sh <mirror> "zig build test-verify -j2 -Dverify-files=$files"                    # 10 in one process, 5 alone
crane-remote.sh <mirror> "zig build test-verify -j2 -Dverify-files=$files -Dsanitize-thread"  # once under ThreadSanitizer
```

Every test of those files prints `VERIFY PASS <test>: batched 10/10 in one
process, alone 5/5`; any other run (fail, crash, timeout, leak, logged error, a
state check, a race) is `VERIFY FAIL` with its first bad run, and fails the step
(`-Dverify-base=main` computes the list itself where there is a git checkout).

The WPT side: every Crane test the branch adds or changes, and every file whose
result its A/B changed (newly passing, newly failing, newly blocking), repeated
10 times on the branch's ReleaseSafe runner, in one `crane-pool.sh wpt` job:

```bash
./zig-out/bin/wpt_runner --repeat=10 --verify --from-file=<list> --wpt-root=tests/wpt --output=<dir>
```

It exits 1, and its tally (`<dir>/repeat-tally.txt`) says `verify: UNSTABLE`,
naming each file, harness status and subtest with the statuses it had, when any
of them differed between the ten runs; a consistent failure is not a flake.
