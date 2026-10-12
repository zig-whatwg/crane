# Spec Compliance: A frame navigation sees only the response headers its fetch copied

**Date**: 2026-10-11
**Lesson**: `NavigationFetchResult.headers` - what a frame's or popup's commit reads response headers from - holds only the names `fetch_integration.zig` lists in `security_headers`; any other header reads as absent.

**Why**: The navigation fetch copies a fixed allowlist of headers out of the response's header list (COOP, COEP, CORP, CSP, X-Frame-Options, Referrer-Policy, Refresh, ...) into a small map, and frees the rest with the response. `headers.get("x")` for a name not on the list returns null - exactly what a response without that header gives - so nothing fails, warns or crashes: the feature just behaves as if no server ever sent it.

**What Happened**: Lane serial's unfinished Origin-Agent-Cluster work (5e9e708c84) read `response.headers.get("origin-agent-cluster")` in HTMLIFrameElement's runCommit, but never added the name to the allowlist. Every frame and popup would have been site-keyed whatever its server sent, while the top-level page - which reads the full header list in src/browser/navigation.zig - was not. The oac lane caught it reading the code before porting, not from a failing test.

**Fix**: Add the header name to `security_headers` in `src/html/navigation/fetch_integration.zig` (lowercase; the value stored is the header list's combined value, Fetch "get"), in the same change that reads it. Lane oac added `origin-agent-cluster`.

**Takeaway**: **A header a frame or popup navigation reads must be on fetch_integration's copy list - a missing one reads as "not sent", silently.**
