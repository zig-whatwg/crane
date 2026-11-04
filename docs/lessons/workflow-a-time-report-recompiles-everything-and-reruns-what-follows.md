# Workflow: A time report recompiles everything, and reruns what follows

**Date**: 2026-11-04
**Lesson**: `zig build --time-report` (Zig 0.17) ignores every cache hit and rewrites each compile's output, so the time report costs a cold build of its whole step graph - and the next plain build reruns every Run step that takes a rewritten binary.

**Why**: The 0.17 compiler, given `--time-report`, checks the cache but does the work anyway ("Under `--time-report`, ignore cache hits; do the work anyway for those juicy numbers", src/Compilation.zig at 77c319a0f00a). The build runner's Run step caches on the content of its inputs, and a recompiled executable is a new file: tools/test_launcher is an input of every suite's run step, so rewriting it reruns every suite. The flag also implies `--webui`: the build does not exit when it is done, and the report is not printed - it is sent to the web UI over a WebSocket (std/Build/abi.zig `time_report.CompileResult`; its per-declaration records are name, file, analysis count and three nanosecond counts, build-web/time_report.zig).

**What Happened**: Lane onebin2's window on chat2 checked its report reader with `zig build test-launcher --time-report` (76 s), then measured "one tests/dom file changed" with a plain `zig build test`: 1,969 s and 12,926 tests, against about 250 s and 642 tests expected - the self-test had rewritten test_launcher, so all 80 suites ran again. That measurement was void. The reports themselves worked: tests-dom's rebuild is 261.8 s, of which Sema and code generation are 108.5 s (41%), LLVM Emit Object 151.2 s (58%), parse and AstGen 0.5 s, link 1.3 s.

**Fix**:
1. Run a time report on a narrow selection (`-Dspec=<dir>`, or a single step), in a timed window: it is a cold build of that graph.
2. Read it headlessly: `--webui=127.0.0.1:<port>`, connect a WebSocket client once the build has its configuration (the server accepts connections earlier, but serves `configured.?`), take the Hello (step names) and every `time_report_compile_result`, stop when the build is idle and quiet, then kill the build. The lane's reader: tmp/onebin2-results/timereport.py.
3. After a time report, run one plain build to settle the cache (it reruns every suite) before any timed plain build - or time-report last.

**Takeaway**: **A `--time-report` build is a cold build that never exits: put it last in a measurement series, or settle the cache with one plain build after it.**
