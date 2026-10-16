# Spec Compliance: Response.redirect parses before validating status

**Date**: 2026-10-14
**Lesson**: Response.redirect needs the current settings object's API base URL and the parsed URL's serialization before it can construct an immutable response.

**Why**: Copying the supplied string into Location skips relative resolution, percent encoding and URL validation. Validating status first also throws the wrong exception when both inputs are invalid.

**What Happened**: Response.redirect accepted invalid URLs, preserved unparsed relative strings, and exposed mutable Headers. Response.error also exposed mutable Headers. The Response.url getter returned fragments even though Fetch requires serialization with the fragment excluded.

**Fix**: Follow Fetch §5.5's complete algorithms: parse in the current realm with its document base URL (or worker script URL), then validate the redirect status, create an immutable response and append the serialized URL. Keep fragments in Location; omit them from Response.url. Use the existing URL implementation and generated interfaces. Blink Response::redirect demonstrates the same parse-before-status ordering. Regression coverage includes a changed document base, cross-global URL resolution, Unicode, invalid URL/status combinations and percent-encoded hashes.

**Takeaway**: **The algorithm's input processing, ordering and object guard are observable API behavior.**

References: [Fetch Response](https://fetch.spec.whatwg.org/#response-class), [Blink response.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/fetch/response.cc). Regression tests: tests/v8/fa_response_test.zig and crane/fa-redirect-*.html.
