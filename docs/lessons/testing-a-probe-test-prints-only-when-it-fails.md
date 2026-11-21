# Testing: A probe test prints only when it fails

**Date**: 2026-11-21
**Lesson**: tools/test_launcher shows a test's stderr only for a test that does not pass, so a throwaway probe that prints Crane's results must end with an error.

**Why**: The launcher runs each test in a child process and reports output only for FAIL, ORDER-DEPENDENT or FLAKY tests; a passing test's std.debug.print lines are discarded.

**What Happened**: Lane edit4 wrote tests/html/edit4_probe_test.zig to print Crane's output for 21 candidate editing cases. The first run passed and printed nothing, which cost a ~10-minute remote build. Adding `return error.ProbeDone;` at the end made the launcher print every PROBE line.

**Fix**: End a probe with `return error.ProbeDone;` and grep its lines from the run's output (`grep -a PROBE`). Never commit a probe, and delete it before any gate.

**Takeaway**: **A probe must fail to be heard: end it with an error, read its prints from the failure report, and delete it before the gate.**
