# Workflow: A test executable per file re-analyses the engine every time

**Date**: 2026-10-04
**Lesson**: `zig build test` built one executable per `tests/**/*_test.zig` file, and each one that reaches the engine is a full root-module analysis of most of the ~1M-line tree plus its own V8 link; one executable per test directory did the same work in a fifth of the time.

**Why**: Zig shares no semantic analysis between compilations. A named module (`impls`, `html`, `v8`) imported by 53 test executables is analysed 53 times, and every change to a core file invalidates all of them. Each lane that follows "tests first" adds files, so every batch made every later gate slower.

**What Happened**: Main's gate went from 35-62 minutes (2026-10-02/03) to 47-113 minutes (2026-10-04) while the test step count grew 542 -> 632 in two days; 276 test files meant 276 compiles (tests/v8 alone 53). Measured cold on chat, same tree (eddc5e7248), same load:

| `zig build test` | per file | per directory |
|---|---|---|
| steps | 636 | 174 |
| wall | 6,432 s | 1,239 s |
| CPU (user+sys) | 6,923 s | 1,505 s |
| peak RSS | 10.0 GB | 10.1 GB |
| local cache after | 21 GB | 4.0 GB |

Sharing one process exposed three tests that assumed they were first: one needed a per-thread context manager of its own (`AlreadyInitialized`), one asserted no isolate was entered while earlier files' isolates sat beneath its own, and one set a V8 flag after V8 had started (a fatal `!IsFrozen()` CHECK).

**Fix**:
1. `addTestFilesFromDir` (build.zig) writes `tests/<dir>/.all_tests.zig` - `test { _ = @import("<file>"); ... }` over every `*_test.zig` under the directory, sorted - and builds that as the directory's one executable. The root must sit in the directory (a module cannot import files outside its root's directory), so it is generated into the source tree, gitignored, and rewritten through a temporary and a rename only when the list changes.
2. `-Dtest-file=tests/<dir>/foo_test.zig` builds one file alone, for red/green.
3. The three tests: run the body on a `std.Thread` (fresh per-thread state); exit every entered isolate, not just your own; set V8 flags only `if (!v8_Platform_IsInitialized())`.

**Takeaway**: **Count compiles, not files: in Zig every test executable re-analyses everything it imports, so tests that reach the engine share one executable per directory - and a test must never assume it is the first in its process.**
