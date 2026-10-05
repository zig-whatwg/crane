# Architecture: A reused Window outlives its first document's end steps

**Date**: 2026-10-05
**Lesson**: An unloading-cleanup step that is keyed on the realm, and that marks the Window's state "ended", also ends that state for the next document. HTML reuses the initial about:blank document's Window for a navigable's first same-origin document.

**Why**: HTML "create and initialize a Document object" step 6 gives the new document the initial about:blank document's Window, and with it the same realm. Crane runs its unloading document cleanup steps (dom.unloading_cleanup) for a realm, not a document. Window's idle-callbacks step set `idle.ended = true` when about:blank unloaded, and nothing cleared the flag when setDocument gave the reused Window its new document. From then on, call_requestIdleCallback returned at once, and neither an idle period nor a `{timeout}` ever ran that callback. That covers every iframe navigated from its initial about:blank (srcdoc frames included) and every window.open(url) popup.

**What Happened**: The csp2 lane's javascript: URL checks were correct, yet trusted-types-navigation.html (8 variants, each a long timeout), navigate-to-javascript-url-005.html and navigate-to-javascript-url-csp-headers.html still timed out. A debug frame showed the frame's script ran, its javascript: URL ran, and its `requestIdleCallback(cb, {timeout: 2000})` never called back. `iframe.contentWindow === initialWindow` after load was true. The top-level page has no initial about:blank to reuse, so its rIC worked, and the four top-level TT files passed. That made it look like a frame-only CSP problem.

**Fix**: setDocument, the reuse point, clears `ended`. The end step stays the old document's whatever the order. Crane unloads the old document, running its cleanup, before setDocument. If the cleanup ever ran after setDocument, setDocument's `replaced_pending_end` would make that step end nothing of the new document's.

**Takeaway**: **State a cleanup step ends "for the realm" outlives the document it was meant for when HTML reuses the Window. Key it to the document, or reset it where the Window gets its new document, and test rIC, timers and listeners in a frame navigated from about:blank, not only on the top-level page.**
