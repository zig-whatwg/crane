# Testing: -Dtest-file takes the path from the repository root - a bare file name builds nothing and reports green

**Date**: 2026-11-09
**Lesson**: `zig build test -Dspec=v8 -Dtest-file=node_anchor_test.zig` matches no test file, skips the suite, runs only the tools' tests and ends with a green Build Summary.

**Why**: build.zig compares `-Dtest-file` with each file's path as `addTestFilesFromDir` sees it (`tests/v8/foo_test.zig`, build.zig `TestSelection.file`). A name that matches no file is not an error: the selection simply excludes every file of the suite, and the steps that remain (the tools' own tests) pass.

**What Happened**: Lane wr1's batch 4 ran its new tests/v8 file and two existing ones with bare names. All three runs printed "Build Summary: 206/206 steps succeeded; 92/93 tests passed" - the same count for three different files - and none printed the facts the new test prints. The log showed no tests-v8 step at all and no compile of v8_wrapper.cpp. With `-Dtest-file=tests/v8/<file>` the new file ran and failed as expected.

**Fix**: Always pass the full path, `-Dtest-file=tests/<dir>/<file>_test.zig`. Read the launcher's own line (`test_launcher: <file>: seed ..., batch 1: PASS n ...`) before trusting a red/green run; a run without it tested nothing.

**Takeaway**: **A green build that never names the test you asked for tested nothing: check for the launcher's line for that file, and give -Dtest-file the repository path.**
