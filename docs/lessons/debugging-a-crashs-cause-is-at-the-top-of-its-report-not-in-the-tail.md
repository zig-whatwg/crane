# Debugging: A crash's cause is at the top of its report - a tail of the output can start below it

**Date**: 2026-11-03
**Lesson**: The test launcher's verdict block kept the last 40 lines of a test's output. A crash report starts with its panic or signal line and its nearest frames, so in any trace longer than the tail the cut fell below the frames that named the cause, and the first visible frame read as the crash's location.

**Why**: A Zig panic prints three lines per frame. A crash inside an engine teardown is 13-15 frames deep (44 lines for this one), so the last 40 lines start at the third frame. A ThreadSanitizer report prints two stacks and the threads' creation stacks, and its tail kept only the creation stacks and the SUMMARY line.

**What Happened**: workerteardown1_global_last_test's hook panicked on `current.?` (testing-a-tests-error-path-must-end-what-its-hooks-report-into.md). Its block began at `gc_integration.zig:105 in onObjectFreed`, so the panic message and the hook's own frame were cut off. It was reported, and briefed to a lane, as a crash in `WrapperCache.deinit:1822 -> runtime.gc.onObjectFreed` - a wrapper-cache use-after-free caused by state an earlier test left. The same day, the ThreadSanitizer runs of tests/html/page_retention_test.zig showed no `WARNING: ThreadSanitizer` line at all, only "Thread T2 ... created by main thread at" and the SUMMARY.

**Fix**: `report.writeVerdictBlock` (tools/test_launcher/report.zig) now prints two parts. First, when the last crash report starts above the tail, its first 20 lines: `thread N panic:`, `Segmentation fault at address`, `Bus error at address`, `Illegal instruction at address` or `WARNING: ThreadSanitizer:`. It takes the last such line, since earlier tests of a batch can print panics they expect, and prints `...` if lines are left out. Then the tail. The full output was always in `tmp/test-launch/<suite>.jsonl.log`, and a hand run keeps it with `--out=<file>.jsonl`.

**Takeaway**: **Before naming the component a crash is in, read its report from the first line - the panic or signal and the frame that raised it; a tail of the output starts wherever the cut fell.**
