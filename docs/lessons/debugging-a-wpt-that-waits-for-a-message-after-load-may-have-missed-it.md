# Debugging: A WPT that waits for a frame's message after its load event may have missed it

**Date**: 2026-10-18
**Lesson**: When a test times out waiting for a postMessage from an iframe, log the order of "message arrived" and "frame loaded": in Crane (and Firefox) a message the frame posts while it parses is dispatched before the iframe's load event, and a listener added after `await with_iframe()` never hears it.

**Why**: HTML's "the end" and "completely finish loading" queue the window load and the iframe load event steps as DOM-manipulation tasks, after the posted-message task the frame's inline script queued; Crane runs them in that order. Blink (Document::CheckCompleted -> ImplicitClose, then the frame owner's DispatchLoad) and WebKit (FrameLoader::checkCompleted) fire the loads synchronously when a document with nothing pending finishes parsing, so in Chrome and Safari the load comes first.

**What Happened**: service-workers/service-worker/client-url-creation-url.https.html timed out at its first subtest. The suspect was the service worker's Client.url. A temporary Crane copy recording stages ("registered > activated > message "done" fromframe=true > frame loaded") showed the frame's 'done' arriving before the load; the same file with messages buffered until awaited passed 10/10, Client.url included. wpt.fyi: Chrome 10/10, Safari 10/10, Firefox 0/10 TIMEOUT - Firefox orders it as Crane does. The fix is iframe load timing, routed to the navigation lane.

**Fix**: For a message-wait hang: (1) copy the test to tests/wpt/crane/ with a window `message` listener installed before anything else, pushing each event into a stage list next to the other milestones; (2) fail the copy deliberately with the stage list as the message, so the runner prints it; (3) if the message comes before the listener, buffer messages in the copy and rerun - what still fails is the real defect. Delete the copies afterwards.

**Takeaway**: **A hang waiting for a frame's message is often an ordering bug, not a missing message: record when it arrived relative to the load, and buffer it to find what else fails.**
