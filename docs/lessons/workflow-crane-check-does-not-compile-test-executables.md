# Workflow: crane-check does not compile test executables - build them with a check step

**Date**: 2026-11-21
**Lesson**: `zig build crane-check` compiles only what the crane graph reaches, so a change of error unions or signatures that test files call (here: IndexedDB's native API, 32 tests/storage files plus in-file tests) compiles "green" while the tests do not; `zig build check-storage-tests` (and check-devtools) compile the test executables without running them.

**Why**: Zig analyses lazily: a test file no step builds is never analysed. A compile-only phase (no test runs allowed) makes this the only way to find a broken test before the test pass.

**What Happened**: Lane prof1's IndexedDB move to the backing store passed crane-check twice; the integrator asked for the test binaries to be compiled too. The new step found two errors in a new test (JavaScript helpers with braces passed inside a `std.fmt` format string) and one in another lane's test (`std.Thread.sleep`, gone in Zig 0.17) - none visible to crane-check.

**Fix**: build.zig's `check-storage-tests` depends on the module test compiles (src/storage, src/cookiestore, src/platform) and on the directory executables `addTestFilesFromDirCompile` answers (tests/storage, tests/platform, tests/browser) - their Compile steps, not their Runs. Add a directory or module the same way when your change reaches its tests.

**Takeaway**: **A compile check that builds no test executable proves nothing about the tests: compile them with a check-* step (no run) whenever a change alters what tests call.**
