# Testing: A shared suite can hide missing hook setup

**Date**: 2026-10-07

**Lesson**: A test that constructs platform objects must initialize the hooks it uses, even when the directory-wide suite already passes.

**Why**: Crane's normal `zig build test` runs all files in a directory in one executable. An earlier file can install process-wide Node hooks, making a later file pass without its own setup. File isolation removes that accidental order dependency.

**What Happened**: The merge-round isolated suite found two failures in `tree_owns_predicate_test.zig`. `DocumentFragment.init` reached `node_creation.setType` with `node_steps.node` unset and returned `InvalidStateError`. The ordinary V8 directory suite had passed because another file installed the hooks first.

**Fix**: Call `interfaces.process_hooks.startHooksForTest()` in that file's one-time setup before creating any Node. Verify the file alone, then repeat `zig build test -Dtest-isolation=file` for the full merge round.

**Takeaway**: **Each test file owns its process-wide prerequisites.**
