# Testing: A test block in src/ that reaches an engine operation cannot link

**Date**: 2026-10-22
**Lesson**: A `test` block inside a src/dom (or other module) file is compiled into a module test executable that links no V8. Once its code reaches an engine protocol operation, through any call chain, that binary fails to link, with `undefined symbol: _v8_...`.

**Why**: Zig analyses lazily. A src/ module that imports `engine` builds fine in its test executable as long as no test reaches an operation, because the V8 adapter's functions are never referenced. A test block that calls code which might call `engine.releasePlatformObject` pulls in the adapter's wrapper cache (`syncEntry`, `armWeak`), and with it the C++ wrapper's symbols, which only the executables that link V8 provide.

**What Happened**: Lane closewatch1 pinned the close watcher manager's group rules with a test block in src/dom/close_watcher_manager.zig. Its watchers had empty owner holds, but `CloseWatcher.release` calls `TaskHold.release`, which calls `engine.releasePlatformObject`. Both lane gates then failed one step, "compile test Debug native 5 errors" (`_v8_Global_ClearWeak`, `_v8_Global_SetWeakFinalizer`). The step was easy to read past: every test passed, and the build summary said 217/220 steps.

**Fix**: Move the behaviour into a tests/<dir>/ native test that runs a real Browser (here tests/html/cw1_close_watcher_test.zig), and delete the in-file block. Keep in-file test blocks for pure data and algorithms that reach no engine operation.

**Takeaway**: **Read the step count, not only the test count: a src/ test block that reaches the engine fails to LINK, while every test still passes.**
