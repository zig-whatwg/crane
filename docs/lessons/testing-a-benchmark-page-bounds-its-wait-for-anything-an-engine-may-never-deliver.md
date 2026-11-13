# Testing: A benchmark page bounds its wait for anything an engine may never deliver

**Date**: 2026-11-13
**Lesson**: A workload that waits for an event - a worker's message, a load, a callback - must first prove, in its setup and against a clock of seconds, that the engine delivers that event at all; an engine that has the constructor and never fires the event otherwise costs the page's whole timeout in every run.

**Why**: Feature detection by `typeof X === 'function'` says the name exists, not that the feature works. An engine can ship the constructor and skip the work behind it by configuration, and then neither the success event nor the error event ever comes: there is nothing to catch. The benchmark runner's only defence is the page's timeout, which is sized for the slowest honest engine (minutes), and it is paid per run, per round.

**What Happened**: Lane v8up b8 added `tests/perf/workloads/workers.html` (workers started and stopped) to the published suite. The self-check ran it once in each engine through perf_bench's drivers: Crane, Chrome, Firefox and Safari finished in seconds; Lightpanda's nightly sat for the page's whole 600 seconds and three rows read `timeout`. Its log had the cause in one line: `resource skipped ... resource=worker hint="enable via --load-resources worker"` - `Worker` is defined, the worker's script is never loaded, so no message and no `error`. In a seven-run round that is seventy minutes of a closed timing window spent waiting.

**Fix**:
1. In the workload's `setup` (untimed, before the warm-up), do the smallest instance of the thing once - one worker, one message each way - with a timer of a few seconds beside it. Share that one probe between the page's workloads.
2. If the answer does not come, throw the harness's `Unsupported` with the reason in words (`'Worker: a worker did not answer in 5 s'`): the row reads `unsupported` and says why, and the page moves on.
3. Keep the timed loop free of the timer: the probe is the guard, the workload measures only the work.
4. Run a new page once in EVERY engine the suite launches before committing it, the ones that are not the comparison's headline included, and read each engine's own log when a row is not `ok`.
5. Whether that engine should be launched with the feature on is its launcher's owner's decision; say it, do not decide it in the page.

**Takeaway**: **`typeof` proves a name, not a behaviour. A page that waits on an engine proves the behaviour once, in seconds, in its setup - and a new page is run in every engine the suite has before it is committed, because the one nobody thought of is the one that waits out the timeout.**
