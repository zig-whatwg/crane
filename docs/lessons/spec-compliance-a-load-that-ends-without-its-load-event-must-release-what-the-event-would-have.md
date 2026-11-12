# Spec Compliance: A load that ends without its load event must release what the event would have released

**Date**: 2026-11-12
**Lesson**: Crane ends a frame's delay on its parent's load in the iframe load event steps. So any path that ends a document's load WITHOUT that event (window.stop(), an abort) must end the navigable's delay itself, or the parent's load waits forever.

**Why**: HTML clears a navigable's "is delaying load events" at the commit ("finalize a cross-document navigation" step 2). Crane holds `IFrameIntegration.delaying_load` until the iframe load event steps run (HTMLIFrameElement `endLoadDelay`). For a normal load the two give the same answer. A load that is suppressed never runs those steps, and nothing else clears the flag. HTML 4.8.5's first delay predicate has the same trap in the spec: an aborted parser never reaches "the end" step 11 (ready for post-load tasks).

**What Happened**: Lane nav2 batch 10 made window.stop() end a still-loading document's load the way Blink's Document::CancelParsing does: readiness complete, no load event, ready for post-load tasks (Document's `lifecycleStopLoad`). abort-document-load.html's one subtest then passed, but the file still TIMED OUT, because the top window's load (which testharness waits for) never fired. The frame's `delaying_load` was still true. The first probe showed "TIMEOUT 0 -> TIMEOUT 1". The fix (content_navigables `load_stopped`, which HTMLIFrameElement installs and which calls `endLoadDelay`) made it "OK 1". Blink does the same through DocumentLoader::StopLoading -> LoadFailed -> DidFinishNavigation, which runs the parent's CheckCompleted without the owner's load event.

**Fix**: When a change suppresses an event, list everything that event's handler released (container delays, readiness, ready-for-post-load, pageshow, the container's load event), and end each one on the new path. Check the file's harness status, not only its subtest count: a TIMEOUT with every subtest passing is a load that never ended.

**Takeaway**: **Suppressing an event also suppresses its side effects. A load that ends without its load event must release the parent's delay itself. A file that times out after all its subtests pass is waiting for a load that never ended.**
