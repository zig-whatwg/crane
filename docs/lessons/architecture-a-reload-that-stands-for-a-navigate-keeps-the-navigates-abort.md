# Architecture: A reload that stands in for a navigate keeps the navigate's abort

**Date**: 2026-10-31
**Lesson**: Crane makes a declarative refresh to the document's own URL a reload (all three browsers report navigationType "reload"), but HTML's refresh is a navigate, and navigate step 24.3 aborts the active document once beforeunload lets it go on. The reload path kept no abort, so a fetch the refreshing document had started raced the reload's response.

**Why**: "Apply the reload history step" populates the entry and unloads the old document only when the new one commits; nothing aborts the old document when the reload begins. Navigate does (step 24.3), and so do Firefox and Safari for any cross-document load, reloads included: nsDocShell::InternalLoad calls StopInternal(STOP_NETWORK), FrameLoader::continueLoadAfterNavigationPolicy calls stopAllLoaders. Swapping one algorithm for another to match the browsers on one point (the navigation type) silently dropped a step the first one had.

**What Happened**: html/webappapis/dynamic-markup-insertion/opening-the-input-stream/abort-refresh-immediate.window.js's fetch() cases were flagged in seven generations (pass count 2-4 of 6): their fetch is rejected only when the reload commits before /common/blank.html answers. Firefox and Safari pass them in every wpt.fyi run. The Crane test fl3-refresh-reload-aborts-fetches.html forces the order (the fetch answered after 400 ms, the reload after 2 s): 5 of 5 fail before, 5 of 5 pass after.

**Fix**: Document.refreshComesDue reloads through dom.history_traversal.reloadForDeclarativeRefresh; History marks the apply item (ReloadCause.declarative_refresh), and apply_history_step aborts the reloaded navigable's active document and its descendants (abortForNavigation: fetches end, live XHRs are left to the unload, as navigate's own abort does) right after its "checking if unloading is canceled".

**Takeaway**: **When the engine replaces one spec algorithm with another to match the browsers, list the steps the replaced one had that the replacement lacks, and keep each one the browsers keep.**
