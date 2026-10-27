# Testing: A connectedCallback is a deterministic collection point

**Date**: 2026-10-26
**Lesson**: To prove a use-after-free between a native snapshot of weakly held objects and its write-back, make the mutation in that window insert a custom element whose connectedCallback calls `TestUtils.gc()`: the callback runs at the end of the native insertBefore's [CEReactions] scope, inside the window, every time.

**Why**: A document's live ranges are held weakly (src/dom/live_range_list.zig). Native code that copies them out of the list, mutates the tree, and writes back through the copies reads freed memory if a collection tears a dropped range down in between. A collection there is rare under random churn, so a churn-only test passes on the broken code and proves nothing. The generated interfaces end a [CEReactions] scope when a native caller's insertBefore returns, and the custom element reactions queued by the insertion - connectedCallback - run right there, synchronously, as script.

**What Happened**: Lane editing4's native probe of editing/run/delete.html crashed once in Range.setStartBoundary <- common.zig movePreservingRanges, which copied every live range's pointer, called insertBefore, then set the points through the copies. A stress test (40 rounds x 4,000 dropped `document.createRange()`, then commands that move nodes, then `TestUtils.gc()`) passed on that code. Adding one child `<gc-on-connect>` whose connectedCallback calls `TestUtils.gc()` to the moved content made it fail on the first round: SIGABRT, "Segmentation fault at address 0x1317c0000" in Instance.stateAs <- Range.getInternal <- Range.setStartBoundary <- movePreservingRanges <- split_parent.splitParent <- delete.deleteAction. The fix (3c8c7aae795) records values by address and slab generation, never dereferences the copies, and writes inside a second walk of the live list under engine.holdTeardowns; the same test is green.

**Fix**:
1. `customElements.define('gc-on-connect', class extends HTMLElement { connectedCallback() { if (globalThis.collectOnConnect) TestUtils.gc(); } })`.
2. Put the element in the content the native step moves; create the dropped objects (thousands of Ranges) just before; set the flag; run the command; clear the flag.
3. Run the test body on its own thread (helpers.onFreshThread) so the page is fresh.
4. For a window with no DOM mutation (writes only), this does not apply: the collection has to come from the writes themselves.

**Takeaway**: **A connectedCallback inside a native call's [CEReactions] scope is a deterministic collection point between a snapshot and its write-back - use it to make a weak-list use-after-free go red on the first run.**
