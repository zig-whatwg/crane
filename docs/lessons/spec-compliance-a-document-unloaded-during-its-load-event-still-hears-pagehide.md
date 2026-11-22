# Spec Compliance: A document unloaded during its own load event still hears pagehide and visibilitychange

**Date**: 2026-11-22
**Lesson**: HTML's "unload a document" step 10 fires pagehide and hides the document only when page showing is true, but page showing becomes true after the load listeners run; all three browsers fire both for a document unloaded from inside its own load event.

**Why**: "The end" step 9 fires load at the window (9.5) and only later sets page showing (9.10) and fires pageshow (9.11). A load listener that removes the document's frame (a common test pattern: the frame's `onload` calls `parent.startTest()`, which removes the iframe) unloads a document whose page showing is still false, so a literal reading fires neither pagehide nor visibilitychange. Blink's `Document::DispatchUnloadEvents` (core/dom/document.cc) skips them only while `load_event_progress_` is `kLoadEventNotRun`; WebKit's `FrameLoader::dispatchUnloadEvents` gates on `m_didCallImplicitClose`, set just before the load event.

**What Happened**: Lane tpw added page-visibility/ to the 0.1 worklist. onvisibilitychange.html and iframe-unload.html TIMED OUT in Crane and pass in Chrome 158, Firefox 160 and Safari 27.2. A probe showed that removing a fully loaded iframe already fired pagehide, visibilitychange and unload; only removal from inside the frame's own load event fired nothing. In the same batch, test_default_view.html showed the second half of the area's gap: Crane's Document started "visible", where HTML 6.2 says a Document's visibility state is "initially set to hidden" (a windowless document keeps it).

**Fix**: `Document.in_load_event`, set as "the end" fires load at the window and cleared at page showing or by the unload; unload step 10 runs when `page_showing or in_load_event` (24e40af31, golden rule 2). The initial visibility state became `hidden` (68027eca4); navigable documents still get theirs from "set the initial visibility state". A full A/B showed no other change.

**Takeaway**: **When an unload-time event is gated on page showing, ask what happens to a document unloaded inside its own load listeners - the browsers gate on "the load event has started", not on pageshow.**
