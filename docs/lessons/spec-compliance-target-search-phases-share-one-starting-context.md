# Spec Compliance: Target search phases share one starting context

**Date**: 2026-10-17
**Lesson**: A later search phase can skip an already-searched subtree only when every phase uses the same starting context.

**Why**: A callback across Windows can have different entry and receiver globals. HTML's named-target search first visits the current subtree and page, then visits other pages while excluding that current page.

**What Happened**: Crane searched the receiver's document first, then searched related pages from the entry Window. A popup's load or pageshow callback into its opener therefore searched the opener locally, but excluded the popup as the entry's current top. Both upstream tests timed out in three of three runs, while main passed all six. Traces showed that the matching popup was live and had a document and Window; it was skipped before familiarity was evaluated. A new two-case regression also returned a different WindowProxy.

**Fix**: Start both search phases from the receiver. HTML window-open step 13 instead names the entry global's document, but this is an existing browser/spec difference: Blink's LocalDOMWindow::open searches its receiver's frame tree, WebKit passes this->frame() into createWindow, and Gecko's OpenWindow2 resolves names relative to its receiver parent. The integrator approved following that agreement under golden rule 2. Keep the full familiarity algorithm and the entry-based source document, URL, referrer, creation and activation behavior unchanged. Pin both callback phases and the identity of the returned and navigated popup in a regression test.

**Takeaway**: **An exclusion justified by an earlier search is valid only when both searches share the same starting context. Trace cross-Window callbacks before changing origin or lifetime checks.**
