# Architecture: State keyed by a navigation lives as long as its request, not until its commit

**Date**: 2026-11-22
**Lesson**: A document commits at its response's head, so a navigation's request can still be streaming its body long after the commit. Anything that attributes that request's later events through the navigation must keep its record until the request ends.

**Why**: The devtools fetch observer finds a navigation request's frame through `state.navigations` (navigation id -> navigable). `onMilestone` removed the entry at `.committed`. A small document's body is whole at its handover, so its `loadingFinished` went out before the commit and the bug stayed hidden. A streamed document (React's SSR, Next.js dev, any chunked HTML) still arrives after the commit. Its `dataReceived` and `loadingFinished` then found no attribution and returned early: the Document request never ended over CDP.

**What Happened**: React's compiler playground suite (Playwright) timed out in every test's `page.goto(url, {waitUntil: 'networkidle'})`. Playwright counts the Document request as in flight until it ends. The protocol log showed the Document request with requestWillBeSent and responseReceived and nothing after. Every subresource ended normally, and no end event carried an unmatched id. htmx's and Vue's runners never showed it, because their documents arrive whole.

**Fix**: At the commit or abort, drop the navigation's entry only when no request with that id is in flight (`settleNavigation`). Otherwise `endRequest` drops it when the request finishes or fails. Test: tests/devtools/tpf_streamed_document_test.zig, a chunked page whose last chunk comes 300 ms after its head. It asserts the Document's `loadingFinished` comes after `Page.frameNavigated` and before the load event, with `dataReceived` after the commit.

**Takeaway**: **Commit is not the end of a navigation's request. Key the lifetime of per-navigation bookkeeping to the request's end, and test with a body that outlives the commit, because a whole-at-head document hides the bug.**
