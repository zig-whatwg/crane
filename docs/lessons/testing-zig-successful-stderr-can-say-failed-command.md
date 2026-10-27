# Testing: Zig can print failed command for successful stderr

**Date**: 2026-10-27
**Lesson**: In Zig 0.16, a `failed command:` line alone does not establish a failed build step or test.

**Why**: The build runner displays captured stderr even for successful steps. Its verbose diagnostic printer then emits the command under the label `failed command:` because the command was saved before the child process ran.

**What Happened**: Crane's codegen suite printed its intentional negative-fixture diagnostics under `run test tests-codegen w`, followed by `failed command: .../tests-codegen ...`. There was no named failed codegen test. Reading the pinned Zig sources explained that output before any rerun or unrelated code change was attempted. Later, the HTML test process restarted without an immediate diagnostic: its final result reported a real iframe out-of-memory crash. These were distinct results and required different treatment.

**Fix**: Read the literal `Build Summary` and named test result lines. In the pinned Zig 0.16 distribution, `lib/compiler/build_runner.zig`'s `printStepFailure` emits `w` only when test results are successful, no error messages exist, and stderr was captured. Its `printErrorMessages` prints `result_failed_command` whenever present. `lib/std/Build/Step/Run.zig` assigns that command before spawning and retains successful test stderr. The same Run.zig continues after a crashed or timed-out test by starting a fresh child, and the build prints the accumulated diagnostic when that step finishes. Quiet output or a new PID is not evidence of success. An actual failed assertion produces an `error: '<test name>' failed` line; process failures, leaks, logged errors and compile errors have their own diagnostics and still require investigation.

**Takeaway**: **Use results and the final summary, not the command label alone.** Keep complete logs; expected negative-test diagnostics are evidence of exercised error paths, not permission to ignore a real failure.
