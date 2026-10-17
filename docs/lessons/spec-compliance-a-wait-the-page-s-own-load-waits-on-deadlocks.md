# Spec Compliance: A wait that the page's own load waits on deadlocks

**Date**: 2026-10-17
**Lesson**: Service Workers' clients.get() of a reserved client (a navigation's resultingClientId) waits for the client's execution ready flag, and the navigation waits on the fetch event that called it. A fetch handler that awaits get() before its respondWith() settles deadlocks: the document cannot load until the handler answers, and the handler waits for the document.

**Why**: The spec's steps are each correct, but they meet in a cycle once the fetch event's response gates the navigation that would set execution ready. The browsers split on how to break it. Firefox and Safari resolve get() at once and hold Client.postMessage() to the reserved client until its realm adopts it. Chrome parks get() and fails the tests that await it: on wpt.fyi, controlled-iframe-postMessage is Chrome 2/5, Firefox 5/5 and Safari 5/5.

**What Happened**: Lane sw1-b3's first service-workers/ run with frames controlled. controlled-iframe-postMessage, controlled-dedicatedworker-postMessage and clients-get-resultingClientId timed out. Their workers do `clients.get(event.resultingClientId)` inside the fetch event, then postMessage the client. The first fix broke the cycle for blocking callers only; the files still hung on the async path. The browser majority's answer fixed all three: get() resolves at once with the reserved client (undefined if it was discarded), and messages to it are buffered and delivered when the realm adopts the environment.

**Fix**: 8188ac0947b (manager.zig `getClient`, `postToClient`, `deliverReservedMessages`), with the deviation and the wpt.fyi numbers stated in realm.zig and manager.zig.

**Takeaway**: **Before implementing a spec wait, check whether what it waits for waits on the caller; if it does, follow the browser majority's break of the cycle and state it, rather than adding a special case per caller.**
