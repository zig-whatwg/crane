# Testing: A test block in a module no test step roots never runs

**Date**: 2026-11-23
**Lesson**: `zig test` collects test blocks from the root module's files only, so a `test` block in a file of a module that no test step roots at - html_core's, under src/html/ - compiles nowhere and passes nothing, however wrong the code under it is.

**Why**: A file belongs to exactly one module of a compilation. src/html/root.zig is the html_core module's root and src/html/full.zig the html module's; the src-html step roots at full.zig, and everything that reaches html_core (full.zig, tests/html/, the impls) imports it as a module. Zig does not collect an imported module's tests (build.zig says so at "src-html": "a dep module's tests do not run"), and `refAllDecls` in another module's root does not change that. So the 318 test blocks (310 named) in 78 of html_core's 100 files have no step that runs them.

**What Happened**: Lane flk4's audit item replaced a SharedArrayBuffer stub in src/html/structured_clone/serialize.zig with a DataCloneError, and wrote its red test in tests/html/ (an engine-linked suite that does run). The green run crashed: "double free" at serialize.zig's allocation. Every throwing path of the walker destroyed its record and then the `errdefer` at the allocation destroyed it again - symbol, function, detached and shared buffers. serialize.zig's own inline tests ("symbol throws DataCloneError", "detached ArrayBuffer throws") pinned exactly those paths, and would have crashed the same way, but no step had ever run them.

**Fix**:
1. Put a test that must run where a step collects it: a `tests/<dir>/*_test.zig` file of a suite (`zig build test -Dspec=<dir> -Dtest-file=...` proves it runs: the launcher names it).
2. Before trusting an inline test as coverage, check that its file is reachable by relative `@import` from a test step's root module - not only from a module that root imports.
3. Wiring html_core's inline tests into a step is queued as its own item (main, 2026-11-23).

**Takeaway**: **An inline test proves something only if a step's root module reaches its file by relative import; in a module nothing roots a test at, it is dead weight that hides the bug it was written for.**
