# Testing: A file's tests go wherever the file is imported

**Date**: 2026-11-11
**Lesson**: A Zig file imported by path into another module brings its `test` blocks into that module's test executable, with every import those tests name.

**Why**: `zig test` compiles the tests of every file in the root module, not only the root file's. A file reached with `@import("other_tool.zig")` is part of the importer's module.

**What Happened**: tools/thread_local_size.zig imported tools/ubsan_symbols.zig for its three reader types. Its own test executable then failed to compile: `tools/ubsan_symbols.zig:463: error: no module named 'ubsan_fixtures' available within module 'root'`, "referenced by: test.a C object compiled with the full sanitizer..." - the other tool's fixture-backed tests had come along (lane tls1, chat2.local). The same shape made six of the WPT runner's std-only unit-test executables fail when its helper files gained `@import("platform")`: each of those files is also built alone as a test root with only std-level imports (build.zig `harness_sources`).

**Fix**: Share code through a file that has no tests needing special imports, or repeat the few lines (thread_local_size.zig keeps its own readers and says why). For a file built under several roots, reach what only one root has through that root: tests/wpt_runner/signal_stack.zig asks `@hasDecl(@import("root"), "attachThreadSignalStack")`, which the runner's main.zig declares and a unit-test root does not.

**Takeaway**: **Before importing a file by path, look at its tests and at every root the importing file is built under: the imports must exist in all of them.**
