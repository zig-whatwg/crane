# Testing: A test's error path must end what its hooks report into - or its failure becomes a crash that names someone else

**Date**: 2026-11-03
**Lesson**: A test that installs a hook reading its own state (`current.?`) and lets a failed step return before it ends the realm the hooked objects live in turns its failure into a crash: the defers clear the state first, the agent's end tears the realm down after, and the hook panics inside engine teardown.

**Why**: Zig runs defers in reverse order. `defer protocol.destroyAgent(agent)` is declared first, so it runs last. `defer Readers.current = null` is declared later, so it runs first. The test's success path ended the realm explicitly in between. An error path skipped that call, so the realm ended in `destroyAgent` - `endAgent` -> `cleanupAll` -> `WrapperCache.deinit` -> `gc.onObjectFreed` -> the hooked deinit, with `current` already null. The panic is in the test's own hook, but every frame under it is the engine's.

**What Happened**: Lane leakcheck1 saw tests/v8/workerteardown1_global_last_test crash once in 8 shuffled batch-0 runs of tests-v8, "in wrapper_cache.deinit:1822 -> runtime.gc.onObjectFreed, during a worker realm's end through destroyAgent". Alone it passed twice, and a replay of the same prefix passed. Lane crashes7 got its brief as a use-after-free that some earlier test's leftover state caused. It was neither. The test made readers until two came after the realm's global in the cache map's hash order, and gave up at 256 with `return error.WalkOrderNeverPutAReaderAfterTheGlobal` - before `destroyWorkerRealm`. A probe measured the give-up at 3 of 3,000 and 8 of 4,000 arrangements (about 0.2%, the same in any batch shape). Forcing the error path gave the reported stack exactly: `panic: attempt to use null value` at `hookedDeinit` <- `onObjectFreed` <- `WrapperCache.deinit:1822` <- ... <- `destroyAgent`. Three more tests in tests/v8 had the same shape (exitleak1_teardown_wrap, cleanup_coordinator_nested, gs3_frame_window_operations); they had not yet failed another way.

**Fix**:
1. End the realm on every path while the hook's state lives: a defer declared AFTER the one that clears `current`, so it runs before it.
   ```zig
   Readers.current = readers;
   defer Readers.current = null;
   var ended = false;
   defer if (!ended) protocol.destroyWorkerRealm(made.realm, null, null);
   ...
   protocol.destroyWorkerRealm(made.realm, null, null);
   ended = true;
   ```
2. Let the hook fall through when the state is gone (`current orelse return interfaces.TextEncoder.vtable.deinit.?(instance)`), so a broken structure fails by its counts instead of crashing.
3. Remove the chance: when the hash order is unlucky, redraw it (`map.rehash()`, a new seed) instead of waiting for more entries to fix it. 4,000 of 4,000 arrangements then succeed.
4. RED for the path itself: a case that fails once its readers exist and expects the error AND every reader torn down in scope. On the old structure it printed "expected 3, found 0" and then crashed.

**Takeaway**: **A test's hooks may only run while the state they read lives: end every hooked realm in a defer declared after the one that clears that state, and make an arrangement that can fail by chance either retry with a fresh draw or fail cleanly - never return past its own teardown.**
