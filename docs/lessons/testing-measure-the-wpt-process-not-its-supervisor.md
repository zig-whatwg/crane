# Testing: Measure the WPT process, not its supervisor

**Date**: 2026-10-08
**Lesson**: A process-scoped profiler must wrap the runner that executes the tests; even `--parallel=1` selects a supervisor.

**Why**: `Options.wantsSupervisor` in `tests/wpt_runner/options.zig` treats any explicit parallel count as a supervisor request. The supervisor launches the test process and does not own its engine allocations. Apple `leaks --atExit` measures the wrapped process, so a clean supervisor says nothing about leaks in its child.

**What Happened**: During document.write integration, a corrected-side command added `--parallel=1` to a 36-file leak comparison. It reported zero leaks, while the earlier direct-process baseline and integrated runner reported 43 and 35 blocks. Source inspection showed that the new command measured a different process role. Its test results remained useful, but its leak number was discarded and both sides were rerun with the original direct-process form. The baseline again reported 43 blocks / 2,736,832 bytes and the corrected candidate 35 / 2,736,704; the supervisor zero was not a leak fix.

**Fix**: Reserve one token through `crane-measure.sh run <label> 1`, then run `leaks --atExit -- <runner> --from-file=<list> --wpt-root=tests/wpt --output=<dir>` without `--parallel` or `--supervise`. Keep the same ordered list and process shape on both sides. Pipe combined output through `cat` so the runner's positional writes cannot erase earlier profiler output. Verify the profiler's target command before interpreting its total. Record its nonzero findings exit separately from test status: the paired command returned 1 when leaks were present. Child-emitted heap snapshots and ownership counters have their own measurement scope; assess them separately.

**Takeaway**: **A profiler result is comparable only when both commands measure the process that owns the allocations.**
