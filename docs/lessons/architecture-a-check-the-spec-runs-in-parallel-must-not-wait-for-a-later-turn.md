# Architecture: A check the spec runs "in parallel" must not wait for a later turn when its document can go first

**Date**: 2026-10-31
**Lesson**: Crane ran a WebSocket's connect-src check on the socket's first pump turn, a 1 ms timer after the constructor. When the page navigated in that millisecond, the socket disappeared unchecked and its violation was never reported.

**Why**: The WebSockets constructor's step 12 establishes the connection "in parallel", and the CSP check is inside the fetch that step makes, so the spec's text puts the check after the constructor returns. "In parallel" allows it to start at once, and all three browsers check in the constructor: Blink's WebSocket::Connect asks AllowConnectToSource before it returns (the error event follows asynchronously), WebKit's WebSocket::connect asks allowConnectToSource (and throws, webkit.org/b/286744), and Gecko's WebSocket::Init runs the content policy check. Deferring the check to a timer makes its effect - the violation event - depend on whether anything that ends the document runs first.

**What Happened**: trusted-types/trusted-types-navigation.html's report-only cases navigate their window with a javascript: URL, then force a connect-src violation with `new WebSocket(...)` and post the violations they saw from that event's task. One case alone (tests/wpt/crane/fl3-tt-report-only-anchor-window.html) failed 1 in 6 isolated (ReleaseSafe), 11 in 20 in Debug. An instrumented copy of the upstream support page (tests/wpt/crane/resources/fl3-tt/, postMessage probes) showed beforeunload, the promise continuation and the WebSocket constructor in every run; the runner's logs showed the connect-src violation queued only in the runs where the 1 ms pump turn beat the next document's response.

**Fix**: The constructor runs prepareHandshakeRequest (main fetch steps 4-7: CSP report and block, the upgrades, Mixed Content) and keeps its answer; the first pump turn only fails or starts the connection. Violations are queued as events, as before - only earlier. No exception (Chrome and the spec).

**Takeaway**: **When a spec step runs "in parallel", the engine may run it now - and should, when its effect is observable and something can end the document before a later turn. Check what all three browsers do: a check they run synchronously is one script relies on.**
