# Testing: A srcdoc document's relative URLs resolve against its parent's

**Date**: 2026-10-28
**Lesson**: `frames[0].history.pushState(null, '', '#p1')` from a page whose frame is an `<iframe srcdoc>` threw SecurityError. The srcdoc document's base URL is its container document's (HTML "fallback base URL"), so `#p1` parsed to `http://example.test/top#p1`, which `about:srcdoc` cannot be rewritten to.

**Why**: The shared history push/replace state steps parse the URL relative to the relevant settings object, whose API base URL is the document's base URL. An about:srcdoc document has no base URL of its own: it takes its parent's.

**What Happened**: Lane nav2's same-document delta case failed with "a host script threw: SecurityError" before any traversal ran, and it looked like a pushState regression.

**Fix**: Pass absolute URLs (`'about:srcdoc#p1'`) in tests that push from a srcdoc frame, or make the frame an about:blank document first.

**Takeaway**: **In a test that changes a srcdoc frame's URL, write the URL absolute: a relative one resolves against the parent document.**
