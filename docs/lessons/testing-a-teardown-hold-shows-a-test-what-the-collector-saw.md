# Testing: A teardown hold shows a test what the collector saw - run ONE collection inside engine.holdTeardowns and assert before the hold ends

**Date**: 2026-11-15
**Lesson**: Code that runs inside a collection's pause decides from a state no test can normally observe: wrappers dead, their references not yet released, no finalizer run. A teardown hold keeps that state still. Take the hold, force one collection, read and assert, then release the hold and assert again on what the releases did.

**Why**: Lane dm2's batch B decides, at the end of a full collection's marking, which trees die with the wrappers found dead (dom.dying_trees), and the engine is told inside the pause. By the time `TestUtils.gc()` returns to a test, the agent's safe point has released every reference and queued every tree: the figure reads the same whether the bytes left it inside the collection (the fix) or at the release (the bug). The design's own red for this batch was a V8 limit read from `--trace-gc-nvp` on a perf page, which no unit test can assert.

**What Happened**: engine.holdTeardowns exists for native walks (WebKit's DeferGC, Blink's GCForbiddenScope): while a hold lasts the adapter runs no finalizer and no node wrapper's release (node_wrappers.zig `Registry.drain` returns, wrapper_cache.zig lists the finalizers for the last resume). A collection requested inside a hold therefore stops exactly where the pause left the DOM. tests/html/dm2_dying_trees_test.zig drops what it made, enters the realm (engine.runInRealm), takes a hold, calls engine.requestGarbageCollection once and reads: every node's slot empty, every count still held, nothing queued - and, with the fix, the figure and V8's external count already lower by the dead trees' bytes. The same held state is the exact input of the rule, so the test also calls the rule's pure core (`predict`) there with a visited set of its own and records its picks. With the pass disabled the first test printed "the figure fell 0 B ... predicted 0 B"; with it, the figure fell by all 3,520,000 B before any release.

**Fix**:
1. Drop the objects from script first, then enter the realm natively: no script may run inside a hold (the adapter panics in Debug), and `runInRealm` itself refuses to start inside one, so the hold is taken and released INSIDE the callback.
2. `const hold = engine.holdTeardowns(realm); defer hold.release();` then one `engine.requestGarbageCollection(agent)`.
3. Read the state into a struct and assert on it after the callback returns (an error inside the callback is carried out in the struct).
4. Read again after the hold's release: the difference is what the releases did.
5. Keep raw node pointers taken before the drop: the nodes stay alive through the hold, because no reference was released.

**Takeaway**: **To test what happens inside a collection, do not race the safe point - stop it. A teardown hold around one forced collection turns "between the pause and the releases" into a state a test can read at leisure, and gives a pass's pure rule its real input.**
