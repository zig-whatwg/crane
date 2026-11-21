# Workflow: A build-time tool writes nothing to stderr when it passes - and the build pins it

**Date**: 2026-11-21
**Lesson**: Zig 0.17's build runner prints a Run step's stderr, then a "failed command: <argv>" line, even when the step passes, so a tool that logs progress to stderr makes every passing build look failed; a build-time tool keeps its log off stderr unless it fails, and its Run step pins that with `expectStdErrEqual("")` and `expectExitCode(0)`.

**Why**: A Run step with an output file argument has no side effects, so the build runner discards its stdout and captures its stderr, and shows captured stderr with the step's command line whether or not the step failed (compiler/Maker.zig prints `failed command:` from the step's verbose context). Readers scan a build log for "failed command:" mid-build, before the Build Summary exists.

**What Happened**: The V8 snapshot generator's four `[v8_SnapshotCreator_*]` success lines were `fprintf(stderr, ...)` in v8_wrapper.cpp. Every freeze log on server1 carried the stderr block and "failed command: .../snapshot_generator .../whatwg_snapshot.bin" beside "Build Summary: N/N steps succeeded" (11 lanes' logs); lane nav2 (2026-11-14) stopped a passing build over it, and lane maj5 (2026-11-20) reported it as a flake. Meanwhile the generator's own progress log went to stdout, which the build discards - so a real failure showed nothing but the C++ lines.

**Fix**: (1) The success-path fprintfs are gone (AGENTS.md already forbids unguarded fprintf in v8_wrapper.cpp). (2) The generator keeps its log in memory (snapshot_generator_log.zig) and writes it to stdout when it succeeds - shown by a run by hand - and to stderr when it fails, where the failed step shows it. (3) engine_build.zig `expectQuietSuccess` puts `expectStdErrEqual("")` and `expectExitCode(0)` on both build-time runs: red with the old lines ("expected this stderr: ... but found: [v8_SnapshotCreator_SetDefaultContext] ..."), green after.

**Takeaway**: **Read a build log's verdict from "Build Summary" and "error:" lines, never from "failed command:" - and make every build-time tool quiet on success, with the Run step's expectStdErrEqual("") as the pin, so the noise cannot come back.**
