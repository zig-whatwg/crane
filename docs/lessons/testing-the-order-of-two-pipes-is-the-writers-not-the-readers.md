# Testing: The order of a process's two pipes is the writer's, not the reader's

**Date**: 2026-11-03
**Lesson**: A test process prints a failing test's text on stderr and then sends its result on stdout, but a launcher that polls both pipes can read the result first: when the result arrives, read what the stderr pipe holds before taking the test's output.

**Why**: tools/test_launcher reads a child's stdout (the test-runner protocol) and stderr (what the test printed) through one `std.Io.File.MultiReader`, which polls both pipes and reads those the poll found ready. Its `fill` returns once any read completes. If the poll finds only stdout ready - the `test_started` message - and the launcher's thread is preempted before the read, the child can print its text and send `test_results` meanwhile; the read then takes both messages, and the text is still in the stderr pipe, unread. The launcher took the test's output from what stderr had buffered: nothing. Zig's own build runner takes it the same way (compiler/Maker/Step/Run.zig, `stderr.buffered()` at `test_results`).

**What Happened**: The launcher's own fixture test "real processes: the Crane test runner fails a test that leaves process state behind, by the field's name" failed once under v8state1's gate load (2026-11-02): the log_err child's status was right, its output empty; seven reruns passed. The same race has a second face: a passing test's text, still in the pipe when its result is read, was buffered with the NEXT test's output and blamed on it. Two deterministic tests in tools/test_launcher/child.zig drive `Executor.run` over three pipes, writing the child's side in the state the race leaves (the result already read, the text written after): both were red with the old code and green with the fix.

**Fix**: At every `test_results`, `readReady` fills the multi-reader with a zero timeout until nothing is ready (bounded): everything the child wrote to stderr before the result is in the pipe by then, so a poll that does not wait finds it. Then the output is taken (a failure) or tossed (a pass).

**Takeaway**: **Order between two pipes is the writer's, not the reader's: when the later message arrives, read what the earlier pipe already holds before you use it.**
