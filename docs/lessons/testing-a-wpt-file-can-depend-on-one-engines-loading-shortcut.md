# Testing: A WPT file can depend on one engine's loading shortcut

**Date**: 2026-10-19
**Lesson**: Before fixing the mechanism a failing assertion names, check why the browsers that also fail it fail: dom/nodes/insertion-removing-steps/Node-appendChild-script-and-default-style-meta-from-fragment.html fails in Firefox and Safari not over the default-style pragma it tests but because its data: alternate style sheet is not loaded yet when its inline script runs - only Chrome, which loads data: URLs synchronously, has it.

**Why**: The test reads the `<link rel="alternate stylesheet" href="data:...">` it depends on from an inline script right after it. An alternate sheet is not script-blocking (HTML: its sheet is not enabled when the parser makes it), and Fetch delivers even a data: URL in a later task. Blink's ResourceFetcher answers data: URLs synchronously (ResourceForStaticData); Gecko and WebKit do not, and neither does Crane.

**What Happened**: wpt.fyi (aligned stable 23b0b89b1a) shows Chrome passing and Firefox and Safari failing with the same message as Crane ("expected none but got block" for the later script). Lane style4 measured each browser: at inline-script time the alternate sheet is null in Firefox 144, Safari 27.0.1 and Crane (main 880b839eb4's runner), loaded in Chrome 151. After the load event, the same fragment scenario gives Chrome and Safari the test's answer (earlier script block, later script none); Firefox runs the pragma at insertion. So the pragma's phase (post-connection, Chrome + Safari) was implemented and pinned in crane/style4-default-style.html, which waits for load; the WPT file stays blocking, as it is in two of the three browsers.

**Fix**: Measure the precondition (is the resource there when the assertion runs?) separately from the mechanism, in each browser. Pin the mechanism in a Crane test that removes the precondition's timing, and report the WPT file as Chrome-only with the measurement - do not make loading synchronous to satisfy it (Fetch, Firefox and Safari agree).

**Takeaway**: **When two browsers fail an assertion with your message, find out why they fail before you change the mechanism the test is named after - the test may encode one engine's shortcut.**
