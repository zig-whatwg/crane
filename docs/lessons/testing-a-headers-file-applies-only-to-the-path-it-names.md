# Testing: A headers file applies only to the path it names

**Date**: 2026-10-16
**Lesson**: wptserve sends the headers in `<path>.sub.headers` or `<path>.headers` for exactly `<path>`; a file named after the resource without its extension, or a `.headers` file holding a `{{...}}` template, changes nothing - silently.

**Why**: `load_headers` (tests/wpt/tools/wptserve/wptserve/handlers.py) appends ".sub.headers", then ".headers", to the requested file's path. Only the `.sub.headers` form is a template.

**What Happened**: Two traps in the sandbox lane. Its own Crane resource `sbx-frame-csp.sub.html.headers` held `Content-Security-Policy: sandbox {{GET[sandbox]}}`; without `.sub` the header was sent literally, so every CSP variant was fully sandboxed and the allow-scripts controls failed - which looked like the CSP parser dropping tokens until a native test with the real parser passed. And upstream content-security-policy/sandbox/sandbox-empty.sub.html embeds `support/sandboxed-post-message-to-parent.html`, whose headers file is `sandboxed-post-message-to-parent.headers`: no engine ever sandboxes that frame (`curl -I` shows no CSP). Chrome, Firefox and Safari pass the file only because their iframe load event (PASS2) comes before the frame's posted message, after which logTest ignores the "unexpected" log; it is an event-ordering test, not a sandbox one.

**Fix**: Name a headers file `<file>.headers`, or `<file>.sub.headers` when it substitutes, and check what the server sends (`curl -sI`) before reading a header-dependent failure as an engine defect.

**Takeaway**: **Before diagnosing a header-driven failure, confirm the header is sent: `curl -sI` the resource. A misnamed headers file fails silently, in your tests and in upstream ones.**
