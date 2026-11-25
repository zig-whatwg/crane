# Workflow: A window's verdict reads its record count, not its exit status

**Date**: 2026-11-24
**Lesson**: A cost window prints a verdict only after it has counted each pass's records against runs x workloads x consoles. An exit status of 0 and a cost table do not mean the pass is whole, and a check that lives in one lane's copy of a script protects that lane alone.

**Why**:
- `perf_bench run` exited 0 when a STOP file ended it early, so a pass cut short looked like a pass that ran to the end.
- `perf_bench cost` reads whatever records are in the journal. It prints a full table over a fraction of a pass, with no warning.
- The window scripts were copied from lane to lane (vm1, then edit4, tpc, mem1, hard1, cs1). A fix went into one copy and stopped there. The copies also kept writing UTC times, against the 12-hour Eastern rule.

**What Happened**:
- Lane hard1 cancelled a cost window (queue-drop --cancel) and queued it again under the same OUTNAME.
- The new window's D pass ended in the same second it started, with rc=0. The journal held the cancelled run's 52 records: 1 or 2 launches per console out of 7.
- The window printed a verdict table as if the pass were complete. Nobody found out whether perf_bench had resumed the old journal or a stop file had survived the cancel.
- On 2026-11-23 a broken console timed out every workload for 7 hours. That failure came the same way: nothing in the chain said "this pass holds nothing".

**Fix** (lane tool1):
- One committed window runner, `perf_bench window` (tools/perf_bench/window.zig), replaces the copies. It:
  - refuses an existing `--out`, or moves it aside with a stamp;
  - counts each pass's journal records, one per (engine, workload, run), and leaves out the `page.*` rows, because a timed-out launch writes none;
  - prints that count on the pass's END line and gives no verdict when the count is short or the run ended early;
  - checks each console against its SHA256SUMS and the mirror's tree.head against the tip;
  - stamps every line in 12-hour US Eastern.
- `perf_bench run` now exits 3 when a STOP file ends it, and 4 when `--max-timeouts` launches of one engine in a row timed out or crashed.
- `perf_bench check` launches a page in every engine.

**Takeaway**: **Count what a pass wrote before you read it: the expected records are runs x workloads x consoles, and a window that cannot say "6 of 28" will print a verdict over a cancelled run. A check belongs in the one committed tool, not in the lane copy that happened to need it.**
