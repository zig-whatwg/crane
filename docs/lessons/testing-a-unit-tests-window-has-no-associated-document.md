# Testing: A unit test's Window has no associated Document

**Date**: 2026-10-18
**Lesson**: DOM inner invoke steps 2.6-2.8 skip a listener when targetGlobal or listenerGlobal is "a Window whose associated Document is not fully active". A Window that tests/v8 makes with createWindowRealm has no navigable and no Document, and dom.document_activity answers "not fully active" for it (Document's `isFullyActive`: `browsingContextOf(window) orelse return false`). Implemented literally, the check would skip every listener in every bare-realm test.

**Why**: In a browser every Window is created with a browsing context and a document, so "has no associated Document" never happens there. Crane's engine tests make bare Window realms. Document's fully-active hook (`isFullyActive`) returns false both for a Window that is no navigable's active window, which is correct for a navigated-away Window, and for a Window with no navigable at all.

**What Happened**: Lane events1 found this while writing its two-Browser test (tests/v8/ev1_shadow_dispatch_two_browsers_test.zig), whose listeners run in bare Window realms: reading the hook showed the literal check would count none of their calls. A removed frame's realm is a different case: it lives on while script holds its Window (dom.window_documents), so "the realm ended" does not tell you its document is gone either.

**Fix**: When inner invoke 2.6-2.8 lands, ask dom.document_activity first, and only on a "not fully active" answer check whether the Window has an associated Document at all (Window's `document` getter fails for a bare Window); treat a Window with none as fully active. Treat a retired realm (no engine, but an agent) as not fully active, and a context that never had an engine as giving no answer - the same line KeptInstance.get draws. Lane events1 wrote it this way and then took the check back out (EventTarget.zig, callListener): the full A/B showed it skipped listeners the browsers run, because of an IndexedDB request-realm defect and the order of a frame's detach.

**Takeaway**: **Before a spec check reads "the Window's associated Document", decide what it does with a Window that has none - every unit test's - or it turns into a silent no-op.**
