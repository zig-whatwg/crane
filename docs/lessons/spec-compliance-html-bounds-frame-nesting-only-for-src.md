# Spec Compliance: HTML bounds frame nesting only for src; browsers bound script navigations too

**Date**: 2026-09-29
**Lesson**: A frame that script navigates to its own page's URL nests without end in the spec, and nothing above it ever fires load. Every browser bounds this, and the engine has to as well.

**Why**: HTML stops an iframe from loading a URL an ancestor already shows only in the iframe's attribute processing: "shared attribute processing steps for iframe and frame elements", step 3. A navigation that script starts - `location.href`, `navigation.navigate()`, a link - has no such step.

navigate-initial-about-blank.html calls `navigation.navigate("#1")` in an initial about:blank frame. That resolves against the creator's base URL, so the frame loads the test page itself, which makes a frame and does the same again. Each level delays its parent's load event, so the top page never loads and the file times out.

**What Happened**: The file's single subtest passed, and the file still read TIMEOUT. That is the signature of a load event that never fires. The two engines bound this differently:
- Chromium cancels a subframe navigation as its request starts, when the URL, fragments excluded, equals the last committed URL of two or more ancestors (`NavigationRequest::IsSelfReferentialURL`, checked in `WillStartRequest` and `WillRedirectRequest`). It allows one level of self-reference and exempts about: URLs, browser-initiated navigations and POST.
- Gecko caps content-frame depth at 10 when a frame loads (`nsFrameLoader::CheckForRecursiveLoad`).

**Fix**: b835a4221 takes Chromium's rule, in `HTMLIFrameElement.startFetch`. The canceled navigation ends like a 204: the frame keeps its document, and the delay it put on its container's load event ends. The deviation is stated in the code. Test: `tests/wpt/crane/nav-self-referential-frames-stop.html`, whose depths are exactly [1, 2].

**Takeaway**: **A file whose subtests all pass while the file times out is waiting for a load event. When the spec has no bound on a recursion, take a shipping engine's and say so.**
