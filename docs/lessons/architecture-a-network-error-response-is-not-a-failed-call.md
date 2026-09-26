# Architecture: A network-error response is not a failed call

**Date**: 2026-09-21
**Lesson**: Fetch reports transport failure **in-band**, as a response object, not as an error return.

**Why**: `mainFetch` catches a transport error and *successfully returns*
`internal_response.networkError()` — type `error`, status 0, empty header list,
null body. Any caller written to expect `catch |err|` sees success.

**What Happened**: `src/browser/navigation.zig` read straight past it to
`getFirstValue("Content-Type") orelse "text/html"`. A network error has no
headers, so every failed navigation became an empty HTML document reported as a
successful page load, and the WPT runner then polled `window.__wpt_complete` for
the full 10-second ceiling. **Every transport failure was laundered into a
silent timeout** — DNS failure, refused connection, TLS error and a genuine hang
were indistinguishable in the journal. It hid an mbedTLS bug that broke all 192
`.https.` tests for a month.

**Fix**: Gate on `response_type == .@"error" or status == 0`, the same
predicate the fetch algorithms already apply. Do NOT test for an empty body or
missing content type — 204/205/304 legitimately have neither.

**Takeaway**: **When a subsystem signals failure in-band, every consumer must
check it explicitly; nothing will throw on their behalf.**
