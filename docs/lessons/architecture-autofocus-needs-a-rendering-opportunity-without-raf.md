# Architecture: Autofocus needs a rendering opportunity without rAF

**Date**: 2026-10-20
**Lesson**: A place to flush autofocus inside an animation-frame callback does not provide a rendering opportunity for documents with no animation callbacks.

**Why**: HTML's update-the-rendering step 7 flushes a top-level document's autofocus candidates before resize, scroll, media-query and animation-frame callbacks. Autofocus can itself cause script to request the first animation frame. A scheduler that only wakes for pending script callbacks cannot start that sequence.

**What Happened**: Row 93 found `browser/Context.zig`'s existing rendering work in `animationFrameHandler`. However, `scheduleAnimationFrame` returns when its pending callback list is empty, and the handler also returns before collecting documents when that list is empty. The Browser event loop documents this dependency. The separate `html/event_loop/event_loop.zig` rendering implementation is not the Browser loop used by WPT.

The worklist test `html/webappapis/scripting/event-loops/update-the-rendering-resize-autofocus.html` requests its first animation frame from an autofocus handler. The frozen f85001892d runner times out before running that handler. A new single-test fixture, `crane/af1-autofocus-without-raf.html`, instead finishes with an explicit failure: zero focus events after load, with no animation callback requested by the test. `crane/af1-autofocus-reinsertion-order.html` supplies animation callbacks and still fails, separately demonstrating the missing candidate processing. Neither test needs geometry to expose its respective gap.

**Fix**: The feature remains pending the document and rendering owners; no production fix was made in row 93. The complete implementation needs:

1. Document-owned candidate state and the processed flag, reached through an installed hook, with the existing node-hold mechanism and teardown discipline.
2. A rendering opportunity scheduled for native pending work even without script animation callbacks. Preserve the rendering loop's document eligibility, reentrancy and lifetime checks.
3. Candidate flushing at step 7, plus dialog focusing steps 7–10 against the same state.
4. Separate tests for a page with no rAF and for candidate insertion order. Removing and reinserting the first element moves it behind another candidate even if its tree position stays first; scanning the tree cannot reconstruct the queue.

The spec algorithms are [HTML autofocus](https://html.spec.whatwg.org/multipage/interaction.html#the-autofocus-attribute) and [update the rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering). WebKit's [Document::appendAutofocusCandidate and flushAutofocusCandidates](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Document.cpp), read on 2026-10-20, show the remove-then-append queue design. Its weak storage is not a prescription for Crane's ownership model. The [reconnection test](https://wpt.fyi/results/html/interaction/focus/the-autofocus-attribute/first-reconnected.html?sha=0f26972422&label=stable) passes in Chrome, Firefox and Safari.

**Takeaway**: **Verify both the rendering step and the event that schedules it. A flush call alone cannot wake a document whose first callback depends on the flush.**
