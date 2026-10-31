# Testing: Copy the upstream support page into crane/ to probe a WPT race

**Date**: 2026-10-31
**Lesson**: A WPT race inside an upstream support page (a popup, a frame) can be bisected without editing upstream: copy the page and its scripts into tests/wpt/crane/resources/, add postMessage probes to the opener at each step, and run a diagnostic Crane test that opens the copy.

**Why**: Upstream WPT is never edited, and the native log of the engine says what Crane did but not which of the page's own steps ran. The page's steps decide which hypothesis is alive.

**What Happened**: trusted-types-navigation's report-only case lost its violation 1 run in 6. The obvious hypothesis - beforeunload's listener not resolving the page's promise, leaving only requestIdleCallback - looked confirmed by the instrumented runner (the WebSocket's violation was queued only after the idle callbacks). The probes in a copy of navigation-support.js showed the opposite: "beforeunload", "continued" and "websocket" arrived in every run. The difference was the socket's deferred CSP check, not the page's promise.

**Fix**: tests/wpt/crane/resources/fl3-tt/ (a probe copy, a diagnostic test that rejects with the sequence it saw) - deleted after the diagnosis; the committed red test is the one-case copy fl3-tt-report-only-anchor-window.html.

**Takeaway**: **Before trusting a native log's story about a page's script, make the page tell you its own steps: a probed copy in crane/resources costs one run and can kill the leading hypothesis.**
