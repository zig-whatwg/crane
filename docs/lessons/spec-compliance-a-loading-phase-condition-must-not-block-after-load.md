# Spec Compliance: A condition meant for the loading phase must not hold a loaded page

**Date**: 2026-11-08
**Lesson**: HTML's "render-blocked" includes "allows adding render-blocking elements" (text/html, no body element) with no regard to readiness, so a loaded page whose script removed its body or root got no animation frames until Crane's 30 s timeout - 28 WPT crashtests timed out waiting for test-wait.js's frames; the browsers block on a missing body only while the document loads.

**Why**: The predicate was written for the parser's phase - no body yet means the head is still being parsed - but read as a state check it also matches a loaded document that script changed. Every browser passes those crashtests: Gecko says it in its code ("a missing body blocks rendering only while parsing, so that a document renders when script removes the body or the root element": `set non-empty || (AllowsAddingRenderBlockingElements() && mReadyState == READYSTATE_LOADING)`), Blink starts frames at WillInsertBody or FinishedParsing and never stops them, WebKit blocks on the set alone.

**What Happened**: Lane crash1's crashtest sweep had 15 files whose documentElement was removed or replaced and 13 whose body went (designMode editing, an inactive document's template, a self-navigation) all TIMEOUT: loaded, no test-wait class, but test-wait.js's two requestAnimationFrame callbacks never ran. The cause was not in update the rendering's document list but in `dom.document_rendering.isBlocked`. A browser probe (rAF requested in <head>, then a 1.5 s parser-blocking script) showed Chrome and Firefox give no frame before <body>, so the loading-phase rule is observable and kept.

**Fix**: `isBlocked` reads "allows adding" only while `document.readyState` is "loading" (Gecko's condition; golden rule 2, mechanism by mechanism, accepted by the integrator); adding to the set still follows "allows adding" alone. tests/html/crash1_render_blocking_test.zig: frames after body removal, root removal and root replacement; still blocked during document.open() until a body arrives.

**Takeaway**: **When a spec state predicate describes a phase ("no body yet"), check what the browsers do when script recreates that state after the phase is over - a timeout that never fires in a test is often a phase rule applied for the page's whole life.**
