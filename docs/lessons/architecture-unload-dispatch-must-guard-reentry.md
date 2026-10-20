# Architecture: Unload dispatch must guard reentry

**Date**: 2026-10-20
**Lesson**: A document's dismissal event can remove its own frame indirectly; the original unload invocation must finish without dispatching a second unload.

**Why**: `document.open()` removes the target document's children. When a child unload handler opens its parent, removal reaches the child's unload steps again before that handler returns. Suppressing all parent opens would be wrong: a parent that is not itself unloading can still be opened.

**What Happened**: Commit `f6ce5c9e138` correctly began firing unload during iframe removal, matching browsers. It exposed an unguarded entry into `Document.unloadSteps`: the child-only case in `ignore-opens-during-unload.window.html` began failing. An isolated `nr1-document-open-reentrant-unload.html` counted two unload events on the frozen base, where one is required.

**Fix**: Check the document's existing unload counter before entering its unload steps. A nonzero counter means dismissal is already running; that invocation owns event dispatch and cleanup. Keep the parent's `document.open()` behavior and the ordinary iframe-removal events. The native regression also verifies that the opened parent's parser can continue writing afterward, using `std.testing.allocator` on a fresh thread.

[WebKit's `FrameLoader::dispatchUnloadEvents`](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/FrameLoader.cpp) similarly returns while a dismissal event is being dispatched. This guards an engine reentry around HTML's unload algorithm; it does not alter the algorithm's per-event counter increments or solve the separate question of ancestor counter scope during a whole-tree unload.

The counter reuse relies on its current writers: only this document's beforeunload and unload scopes raise it. A future ancestor-counter fix must distinguish suppression of `document.open()` from active dismissal dispatch, or otherwise preserve entry into the ancestor's own unload. Extending the counter's scope across descendants without accounting for this guard would skip that unload.

**Takeaway**: **Guard the reentered lifecycle operation, while preserving the script action that legitimately caused removal.**
