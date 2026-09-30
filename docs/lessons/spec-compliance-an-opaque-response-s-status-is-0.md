# Spec Compliance: An opaque response's status is 0

**Date**: 2026-09-29
**Lesson**: HTML's link fetch fails a resource whose "response's status is not an ok status", and the response it is handed is the filtered one; every cross-origin no-cors style sheet's is opaque, with status 0 and no headers.

**Why**: Fetch hands processResponseConsumeBody the filtered response, and an opaque filtered response has status 0, an empty header list and a null body; the body bytes come from the internal response. Read to the letter, 4.2.4.3 step 7.2 fires `error` at every `<link rel=stylesheet>` from another origin. Browsers check the real status (Blink fails a subresource at 400 or above), and link-style-error-01's cross-origin cases expect `load`.

**What Happened**: Caught while writing the check, before it ran: Crane's AsyncFetch delivers the internal response with its `response_type`, so the check reads the internal status and headers and uses the type only for "CORS-same-origin" (the quirks-mode Content-Type exception). The 12 cross-origin subtests of link-style-error-01 and its quirks variants pass.

**Fix**: a93d2b413, `style_sheet_loading.processResponse`, with the deviation stated in the file.

**Takeaway**: **Before checking a response's status or headers, ask whether it can be no-cors cross-origin: an opaque response says 0 and nothing, and the check has to read the internal response.**
