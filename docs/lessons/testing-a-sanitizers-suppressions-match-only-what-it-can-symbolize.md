# Testing: A sanitizer's suppressions match only what it can symbolize - a test child with no PATH halts on every suppressed report

**Date**: 2026-11-13
**Lesson**: ThreadSanitizer's suppression file names functions, and the sanitizer learns a frame's function from a symbolizer it finds on PATH; a process started with an empty or minimal environment prints `<null>` frames, matches no suppression, and with `halt_on_error=1` dies on the first report the file was written to hide.

**Why**: tools/test_launcher/tsan_suppressions.txt holds lines such as `race:v8::` and `race:std::__Cr::`: proven false positives of the uninstrumented V8, matched against the function names of a report's frames. The names are not in the report until the runtime symbolizes it, and on Linux the runtime does that by running an external program it looks up on the process's PATH (compiler-rt's sanitizer_common tries `llvm-symbolizer`, then `addr2line`; server1 has both in /usr/bin). Measured here: the same executable, the same report - with a PATH its frames read `v8::platform::DefaultWorkerThreadsTaskRunner::...`; without one, every frame is `#0 <null> <null> (exe+0x9c2008f)`. A suppression cannot match a name that is not there, so the report counts as a real one.

**What Happened**: Lane build3 gave the launcher's own many-Browsers fixture test the options every real test child of a sanitizer build runs with (`halt_on_error=1`, the suppression file), because without them the fixture's V8 printed 6,999 to 16,044 unsuppressed reports per run. With them the test failed differently: `expected .fail, found .crash`, "test process exited with code 66", and one report whose every frame was `<null>` - between two `V8 DefaultWorke` threads, the worker-start report that the file's `race:v8::` line covers in every real test child of the same build. The difference was the environment: the launcher's real children get a copy of the launcher's whole environment (`child.testEnvironment(gpa, init.environ_map, ...)`), and the launcher's own tests build theirs from an EMPTY map, so the fixture's children had no PATH. Given the test process's PATH, the frames were symbolized (`v8::platform::DefaultWorkerThreadsTaskRunner::...`), the suppressions matched, and the test passed.

Measured afterwards on the one sanitized fixture, run by hand under the suppression file with nothing to halt it, so that every report that got through is counted (server1; `llvm-symbolizer` and `addr2line` both in /usr/bin):

| the fixture's environment | reports | frames reading `<null> <null>` | exit |
|---|---:|---:|---:|
| the engine started at process start, no PATH | 4 | 76 | 66 |
| the same, with PATH | 0 | 0 | 0 |
| the many-Browsers variant (a busy Browser's V8 on its own thread), no PATH | 19,017 | 1,121,444 | 66 |
| the same, with PATH | 0 | 0 | 1 (its one test that must fail there) |

By the same mechanism (not measured: every pool host has one) a host with no symbolizer installed would crash every sanitizer run on V8's first suppressed report, and it would read like a product race.

**Fix**:
1. A process that runs under a suppression file gets a PATH on which the symbolizer is found. In the launcher's own tests: `base.put("PATH", testing.environ.getPosix("PATH"))` for a sanitized child (tools/test_launcher/child.zig, `manyBrowsersFixture`).
2. Reading a sanitizer failure, look at the frames first: `<null> <null> (exe+0x...)` on every line means the runtime could not symbolize, and then the question is the environment or the host, not the code.
3. A new pool host is checked for a symbolizer before its first sanitizer run (`command -v llvm-symbolizer addr2line`).

**Takeaway**: **Suppressions are matched on names the sanitizer gets from an external symbolizer found on PATH. A sanitized process with no PATH, or a host with no symbolizer, suppresses nothing: frames that read `<null>` mean "look at the environment" before "look at the race".**
