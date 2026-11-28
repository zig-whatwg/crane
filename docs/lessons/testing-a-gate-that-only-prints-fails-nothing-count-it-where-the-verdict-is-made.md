# Testing: A gate that only prints fails nothing - count it where the verdict is made, and make "not run" a failure

**Date**: 2026-11-27
**Lesson**: A check whose result is a printed line, a log level, or a list some other tool might run is not a gate until the code that computes the verdict reads it, and it fails silently in a new way every time its producer and its reader drift apart: give the producer a summary of what it checked, and make the reader fail when that summary is missing or does not add up.

**Why**: Each of these was added as "the gate" and reported as one, and each was read by nothing that decides anything. A reader that finds no failure lines cannot tell "clean" from "never ran", so every way the check can stop running reads as a pass.

**What Happened** (lane gate2, audit of 97ab1aaf2..9d3f35085):
1. The bug-finding runner's per-file V8 handle check printed `warning(handle): handle leak: <path>: ...`; wpt_build_compare, wpt_ab and the sweeps never read it, and "0 unmarked handle leaks" in a merge message came from a hand grep of a crashtest run.
2. The allocator's unexpected-rungs gate counted `the Browser's heap got the <rung> rung` lines that Browser.init logged with `log.info`, under the runner's `.warn` level: the line was never written, and the unit test fed the counter hand-written lines (one of which Crane never logs).
3. tests/wpt_0_1_crashtests.txt (602 crashtests) was read only by the script that wrote it: generations 238 and 240 swept 0 crashtests, while README advertised "602/602".
4. wpt_ab ran the bug-finding runner with the WPT tree as its working directory, and the runner's handle baseline was a cwd-relative default (`tools/wpt_handle_leaks_baseline.txt`) that silently became "no baseline" there.

**Fix**:
1. Count the failure where the verdict is computed (wpt_build_compare's LogFindings: `handle leaks N` beside `heap leaks`, in the gate total).
2. Make the producer print what it checked - every runner process ends with `handle gate: checked N file(s), L handle leak(s) over the baseline, U OK file(s) unread (no counters); baseline <path> (E entries)` - and have the reader reconcile it with an independent count: no summary while the run has OK files is NOT RUN, fewer files checked than finished OK or a leak count the leak lines do not match is NOT RECONCILED, and each fails the gate.
3. Pin a producer's log level to its reader's threshold at compile time (Browser.heap_rung_log_level, asserted in tests/wpt_runner/main.zig), and feed a log counter the producer's own text.
4. Put a test type in the one list every reader runs (the crashtests are in tests/wpt_0_1_worklist.txt; the crashtest file is only the judge's type index), and pass a gate's inputs explicitly (`--handle-baseline=`, required in a frozen tip dir) instead of a default path that depends on where the tool runs.

**Takeaway**: **A gate exists only where the verdict reads it. Have the check report how much it checked, and treat a missing or unreconciled report as a failure - otherwise every way of not running it is a pass.**
