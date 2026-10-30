# Testing: A test of teardown inside one script must make the engine collect inside it

**Date**: 2026-10-30
**Lesson**: A native test that claims "objects dropped inside one script are freed inside it" must make JS garbage in its loop, or no collection runs and the test passes or fails whatever the code does.

**Why**: V8 collects only when JS allocation asks it to, and Crane's deref of a collected wrapper runs in the wrapper's SECOND-pass callback. Outside a forced collection, V8 posts that callback as a foreground task, and the next collection's prologue runs whatever is still pending (V8 13.1 `src/heap/heap.cc`, "Ensure that all pending phantom callbacks are invoked"; `src/handles/global-handles.cc`, `PostGarbageCollectionProcessing`). A loop that makes DOM objects but allocates almost nothing on the JS heap triggers no collection. Every wrapper then lives until the script ends, and no teardown can run inside the script.

**What Happened**: Lane refcount9 was asked for a native test that pins the fix for the parser-write cost row: N documents dropped in one script stay bounded by the deferred teardown queue's high water. The first draft made 600 documents of ~710 nodes each in one script and asserted that the slab grew by fewer than 300,000 slots. It read 425,850 slots both with the fix and with the fix reverted (the detach item's weight forced to 0): every document of the script was alive at its end. The test would have pinned nothing. Adding `for (let k = 0; k < 64; k++) junk = new Array(1024).fill(k);` to each iteration made V8 scavenge inside the script. Then the test read RED 425,850 and GREEN 109,140.

**Fix**:
1. Put JS garbage in the loop, so the engine's own collections run inside the script, as they do in any real page's script.
2. Run the RED with the fix reverted, and check that the RED and GREEN numbers differ. When they are equal, the test is not reaching the mechanism.
3. Keep `TestUtils.gc()` out of a test like this. It is a binding, so the collection it asks for is owed to that binding's exit and drains the whole queue there. That proves the drain path, not the memory bound.

**Takeaway**: **A RED and a GREEN that read the same number are a test that never reached the code - make the engine do in the test what it does in the page (here, collect inside the script).**
