# Spec Compliance: A global task follows its Window, and engine code asks the navigable

**Date**: 2026-10-04
**Lesson**: Giving Window.postMessage's task a document made the full A/B lose 137 files in two waves, and both were "the right document, asked the wrong way".

**Why**: HTML's "queue a global task" takes the global's associated Document when the task is queued, and "a task is runnable if its document is ... fully active". Read literally, that drops a message posted to a frame whose initial about:blank is then replaced in the same Window (a javascript: URL, a navigation that reuses the Window) - but browsers deliver it: Blink posts a window's messages to the frame's task runner, not to a document, and webmessaging/{with,without}-ports/018.html expects delivery. And "is this document fully active" is the event loop's question, asked with no script running: `interfaces.Window.get_document` - script's getter - runs its cross-origin check against whatever realm is current (the page's, at the loop), so every cross-origin or opaque-origin frame's document read as not fully active.

**What Happened**: First sweep: 137 newly blocking, nearly all postMessage to cross-origin, sandboxed or data: frames (webmessaging *xorigin*, origin-keyed agent clusters, cookies/samesite, cors/remote-origin, mixed-content iframe-data-inherit). Fixed by reading the navigable's own record (`BrowsingContext.active_document`, via `ofWindow`). The rerun then showed webmessaging 018 x2 TIMEOUT: the message's document was the replaced about:blank.

**Fix**: A global task on a Window names the Window (`runtime.EventLoopTask.document` may hold one); `dom.document_activity` answers for the document that Window's navigable shows when the task runs. Stated as a deviation on the Task field. A removed frame's window is no navigable's active window, so its messages still drop.

**Takeaway**: **When engine code asks a question about a frame, read the engine's record (the navigable), never the getter script uses; and before converting a task to carry a document, check what browsers key it on - for a global task it is the window, not the document of the moment it was queued.**
