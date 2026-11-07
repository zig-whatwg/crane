# Architecture: A Window the next document reuses must not run its global's teardown

**Date**: 2026-11-07
**Lesson**: "This document is unloaded" and "this global is going away" are different events. They come apart when HTML "create and initialize a Document object" step 6 gives the next document the initial about:blank's Window. A cleanup step that ends what the global holds (its observers' registrations, its channels' keeps) must wait for the global's end, not for the about:blank's unload.

**Why**: Crane runs every unloading document cleanup step for a document's realm (dom.unloading_cleanup). The steps are of two kinds:
- HTML's own steps, which belong to the document and run at every unload, reuse or not: make WebSockets disappear, release Web Locks, remove blob URL entries.
- Engine teardown of the global. Reporting §4 keeps the registered observer list on the global, and Blink ends a ReportingObserver or a BroadcastChannel only at ContextDestroyed. A reused LocalDOMWindow (DocumentLoader ShouldReuseDOMWindow) never gets that call.

Running the second kind at the about:blank's unload ended the registrations of a global that lived on. Every observer the new document registered was then never kept.

**What Happened**: html/cross-origin-embedder-policy/reporting-navigation.https.html timed out on a different subtest from run to run, and credentialless/reporting-navigation did the same from time to time. A {buffered:true} observer showed that the missing reports had been made. Holding every observer from script made the file pass 30/30. A copy that collected garbage between observe() and the report failed every time for an iframe navigated to a same-origin page, and passed for an un-navigated about:blank frame. The "with empty frame: false" cases observe a navigated frame's window; their "true" twins observe an about:blank and passed. The registration lifetime of batch 2 was right; the step that ended it ran at the wrong moment.

**Fix**:
1. dom.unloading_cleanup has two kinds: `install` (document steps) and `installGlobalTeardown`. `runDocumentSteps` runs the first kind only.
2. commitAfterFinalize decides the reuse before it unloads, from keepsInitialWindow and the absence of a group switch. It passes the decision down as an argument to navigables.destroyWindowDocuments, which calls window_documents.documentReplaced for that window.
3. Context.clearWindowState then runs the document steps alone.
4. ReportingObserver and BroadcastChannel install their ends as global teardown.
5. MessagePort, EventTarget and custom elements have the same shape and are queued until browser evidence says what survives the reuse.

**Takeaway**: **Before hooking global teardown to a document's unload, ask whether the global can outlive that document. HTML's Window reuse means it can. Decide the reuse before the unload and pass it down, rather than repairing the consequences downstream.**
