# Spec Compliance: A noopener popup's initial about:blank keeps its opener's origin

**Date**: 2026-11-21
**Lesson**: Give a noopener popup's initial about:blank a new policy container, as HTML's null creator does, but keep the opener's origin, or the popup loses window.name on its first navigation.

**Why**: HTML makes a noopener popup "given null" opener: "create a new browsing context and document" with a null creator gives the document a new opaque origin and a new policy container. Crane needed the new policy container for the opener policy enforcement. With an opener policy of "unsafe-none", a COOP + COEP response isolates the popup (noopener-popup-cross-origin-isolation.https.html). But "finalize a cross-document navigation" step 4 clears the target name of a top-level navigable with no opener whose new document is not same origin with the old one. With an opaque about:blank, every first navigation is cross-origin. All three browsers keep the name (clear-window-name.https.html "not reset at the first navigation away from initial about:blank with noopener": C157, F160, S27.2 PASS).

**What Happened**: Lane blk6's first FULL A/B lost 53 subtests: window-open-popup-behavior.html (49), named-lookup-noopener.html (2) and clear-window-name.https.html (2). The popups' pages read window.name to find their BroadcastChannel and executor, and it was "". A targeted run of the COOP directory had shown +5/-0 and missed them, because none of those tests reads window.name.

**Fix**: In createAuxiliaryNavigable, a noopener popup keeps the opener document's origin (a stated deviation from step 7), and its creator for steps 19.1-19.3 (referrer, policy container, opener policy) is null (commit 7dab04f47).

**Takeaway**: **Every observable of a document's origin moves when you change it: before changing an initial about:blank's origin, run the window-name, named-lookup and popup-behavior tests, not just the directory of the feature you fixed.**
