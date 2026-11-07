# Architecture: A navigation ends the load of the document it aborts - look for the mechanism, not the task order

**Date**: 2026-11-07
**Lesson**: When two files seem to need contradictory task orders, find the shipping browser that passes both and read how it does it. Firefox passes the replace-before-load files and promise-rejection-event-during-parse.html. It does so with a load-completion rule, not with task scheduling: a document that a navigation aborts never fires its load event.

**Why**: In Crane, a frame's document that submits a form while it is parsed fired load at the frame before the replacement committed. That happened because Crane parses a fully received body, EOF included, in one task, so the planned navigation's task finds the parser stopped. Two models explain the browsers:
- Chrome's: the body's end is a separate task, so the parser is still active when the planned navigation runs.
- Gecko's: the parse ends in the same flush. The load event belongs to the load group (nsDocumentViewer::LoadComplete fires load and pageshow only for a successful status), and the new load's Stop() completes the old load as NS_BINDING_ABORTED.

Only Gecko's model keeps "interactive" ahead of an unhandledrejection task queued by an inline script.

**What Happened**: Lane nav2 batch 7 first took Chrome's model as "the root", with no special case in "abort a document". DocumentParser.readArrived and createComplete queued the EOF as its own networking task. All five replace-before-load files passed (+9 in a 4,413-file pair). The FULL A/B then lost promise-rejection-event-during-parse.html, which Firefox passes and Chrome and Safari fail. The user ruled "investigate, then decide". Gecko's code showed that:
- its form submission is queued too (nsDocShell::OnFormSubmit dispatches an OnLinkClickEvent; dom.forms.submit_async_navigation is true);
- its unhandledrejection is a plain runnable (CycleCollectedJSContext::AfterProcessMicrotasks);
- what makes form-submit pass is LoadComplete's aStatus check.

**Fix**: The deferred-EOF commits were reverted. Document.load_aborted is set by abortDocument(for_navigation) while the readiness is not "complete". completeLoading then only completes the readiness: no load, no pageshow, no container load. This is a stated deviation from "the end" step 9, golden rule 2's Firefox + Safari majority (a-user-click.html, location-assign-user-click.html). Result: +22 with no loss on the same 4,424 files; the four files pass together.

**Takeaway**: **Before moving an event boundary to fix one file, list every file that orders events on that boundary - readystatechange, unhandledrejection, load - and measure them too. When files seem to need contradictory orders, read the code of a browser that passes all of them: the order may come from another mechanism (here, an aborted load never fires load), and one rule can satisfy them all.**
