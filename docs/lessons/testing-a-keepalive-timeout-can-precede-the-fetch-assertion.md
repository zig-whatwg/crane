# Testing: A keepalive timeout can precede the Fetch assertion

**Date**: 2026-10-18
**Lesson**: Isolate a WPT test's setup handshake before changing the feature named by its directory.

**Why**: `fetch/api/resources/keepalive-helper.js` waits for an iframe's load event before installing the listener for the child's setup message. The child posts that message from its window load handler. Delivering the message before the container load event loses the handshake, so the test never reaches its Fetch assertion.

**What Happened**: Frozen main `ae02a55dc8` timed out in `redirect-keepalive.https.any.js`'s "setting up" subtest even though the mixed-content redirect reached the correct block. The upstream file passes 2/2 in Chrome, Firefox and Safari at [aligned stable revision 23b0b89b1a](https://wpt.fyi/results/fetch/api/redirect/redirect-keepalive.https.any.html?sha=23b0b89b1a&label=stable). `crane/nm1-keepalive-setup.https.html`, with both listeners registered before inserting the iframe, expected `["load", "message"]` but observed `["message"]`. Its first draft put the script before the body and failed at appendChild; moving the body before the script was necessary to measure the intended ordering.

**Fix**: Keep the regression with the Document load-order owner. `Document.completeLoading` dispatches the child's window load before queuing a separate container-load task; nav1 owns the change that brings container load into that dispatch. The integrator routed this dependency in row 70 Q12. No Fetch keepalive change was made. The existing [parent-loading lesson](architecture-a-parent-completes-loading-in-its-last-child-s-task.md) records the related browser ordering and engine implementations.

**Takeaway**: **A timeout during setup can belong to navigation or messaging even when the test lives under Fetch. Prove which handshake was lost before editing the feature algorithm.**
