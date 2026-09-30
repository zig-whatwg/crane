# Testing: A stash poll hangs on a request nothing sends

**Date**: 2026-09-29
**Lesson**: All 18 html/semantics/links/downloading-resources/ files timed out with no subtest run because each polls the server for a header a ping request would have stashed, and Crane sent no pings.

**Why**: WPT's server-side stash pattern (`inspect-header.py?cmd=put` from the request under test, `cmd=get` from a polling `fetch()`) never fails: the poll just retries until the harness times out. The file reads as a hang in whatever it polls with, while the missing piece is the request that fills the stash - here hyperlink auditing, the POST `a.click()` sends for a `ping` attribute.

**What Happened**: The brief named the files "header-origin and header-referrer" and pointed at referrer policies; reading one test showed the poll loop and the `ping` attribute. With hyperlink auditing (2f89c234e), 17 of the 18 pass; header-origin-no-referrer needs `<meta name=referrer>` in the policy container.

**Fix**: 2f89c234e (HTML 4.6.6).

**Takeaway**: **When a file polls the server for a stashed value, find what should send the request that fills the stash - a ping, a beacon, a report - before looking at what reads it.**
