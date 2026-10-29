# Workflow: A tip-only A/B runs in the environment of the sweep it is compared with

**Date**: 2026-10-29
**Lesson**: When one side of an A/B is a generation sweep, the tip side has to copy that sweep's launch environment exactly. A diagnostic flag is not neutral just because it "only adds reporting".

**Why**: A tip-only A/B compares a tip run with journals a generation sweep has already written. Any
difference in environment variables, runner count or chunk size becomes part of the "tip" result.
`CRANE_LEAK_FILES=1` puts the `Attributing` allocator in front of the runner's DebugAllocator
(tests/wpt_runner/runner_allocator.zig). That changes timing and, on some files, whether the process
survives.

**What Happened**: Lane leaks1's full A/B began with both sides its own and `CRANE_LEAK_FILES=1` on
both, so that comparison was fair. When the base side was dropped for generation 193's journals, the
22 tip chunks already done were kept. Generation 193 had run without the variable:
`tmp/remote/gate-main.sh` sets none, even though runner_allocator.zig's doc comment says main's sweep
sets it. Comparing per-file wall times of those chunks with generation 193 found:

- **SIGABRT on 4 files.** `content-security-policy/embedded-enforcement/` required-csp-header-cascade,
  subsumption_algorithm-general, -strict_dynamic and -unsafe_inline crashed. Under the variable this
  happened in 3/3 runs on the tip AND 3/3 on frozen main's runner; with it unset, 0 and 0. Against
  generation 193 they read as 4 new crashes.
- **Slow for the rest of the process.** The median per-file ratio was 1.05, but 32 files ran 3x to
  550x slower. Examples: join-different-white-space-style-paragraphs 3.9 s -> 2,172 s; WebCrypto
  failures_AES-CBC 0.2 s -> 38 s; join-pre-and-other-block OK -> TIMEOUT. Each file that follows a
  heavy one in the same process stays slow. The same files take 1-2 s in a fresh process even with
  the variable on.
  - The likely mechanism: `Attributing.live` is a `std.AutoHashMapUnmanaged`. A remove leaves a
    tombstone and gives `available` back, so the map never grows or rehashes, and probing stops only
    at a never-used slot (zig 0.16 std/hash_map.zig :1155, :1226-1231). Steady alloc/free churn uses
    up the free slots, and from then on every insert and lookup scans toward the whole table.

The chunks were rerun without the variable. Both defects were queued against runner_allocator.zig.

**Fix**:
1. Before a tip-only run, read the generation's launch line (gate-main.sh, the first lines of its
   sweep.log) and copy its environment. Give the tip run the same variables, and unset any you do not
   want (`env -u CRANE_LEAK_FILES`). A comment in the code saying what the sweep sets is not
   evidence; the launch line is.
2. Once the first chunks finish, compare per-file `wall_ms` with the baseline journal. Read the
   pattern:
   - A median near 1 with a handful of 100x outliers comes from the environment or the process
     shape, not from a code change.
   - Outliers that begin at one heavy file and stay for the rest of that chunk's process point at
     state that accumulates in the process.
3. Check a crash new to the tip on BOTH runners in the tip run's environment before suspecting the
   tip. Four ABRTs that looked like a regression in this lane's own handle-ownership change were
   main's, under a flag main does not run.

**Takeaway**: **Copy the baseline's environment from its launch line, not from a comment, and check
per-file wall times against the baseline early: a run with a different environment measures that
environment.**
