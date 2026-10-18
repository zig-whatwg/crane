# Debugging: Check the delivered policy before CSP enforcement

**Date**: 2026-10-18

**Lesson**: Verify the actual response header before treating a CSP test failure as an enforcement defect.

**Why**: A test's name and nearby header file do not establish what policy the server delivered. WPT reads header sidecars by the full resource path.

**What Happened**: `content-security-policy/sandbox/sandbox-empty.sub.html` unexpectedly received a message from its child script. The checkout contained `sandboxed-post-message-to-parent.headers`, but the child resource was `sandboxed-post-message-to-parent.html`. WPT's handler looks for `path + '.headers'` or `.sub.headers`. A HEAD request to the shared server confirmed that the child received no Content-Security-Policy header. Running its script was therefore correct; the aligned browser results came from a different WPT revision and could not prove what this checkout served.

**Fix**: Record the served headers and the exact sidecar names. Keep upstream WPT unchanged in a restricted lane. Add a Crane control with a correctly named `.html.headers` file, and verify that an enforced empty sandbox prevents the same child script from running. Route the fixture issue to the owner of the WPT checkout.

**Takeaway**: **Test policy delivery separately from policy enforcement before changing either.**
