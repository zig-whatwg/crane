# Spec Compliance: a load moved into the parser's task exposes every step done after the parse

**Date**: 2026-11-14
**Lesson**: When "the end" completes the load inside the parser's task (the browsers' order, the user's ruling 2026-11-12), every step the commit path ran AFTER the parse callback returned now runs after the load listeners. Audit the commit path for those steps before the A/B, and move each before the parse as the spec orders it.

**Why**: While load was always a later task, a step done right after the parse (setting a text document's content type and mode, handing a traversal's saved form states to the new document, a script run queued without a load delay) was still done before any load listener ran, so nothing observed the order. The spec puts them before the parse ("load a text document" steps 1-3, "restore persisted state" via the new document, "prepare the script element" step 35.2's set that "the end" step 7 waits on).

**What Happened**: Lane nav2's first attempt (batch 11, edffbee5a4e) lost 17 files and was reverted. Batch 12 found three classes of setup-after-parse among them: iframe_integration commitTextDocument/commitMediaDocument (type-argument-plaintext 8 -> 0, contentType 4 -> 3), restorePersistedState after commitResponse (range-restore 2 -> 0), and the queued SVG script run (execution-timing/135). A fourth class was navigations queued during the parse that must still run first (WebKit's implicitClose waits on a pending location change; replace-before-load/form-submit*, 014, 028), and a fifth a browser rule the old order had hidden (Blink/WebKit ignore history.back() while the document unloads: traverse-during-beforeunload).

**Fix**: DocumentSetup passed to the parse callback; next_persisted_state taken when the document is made; the queued SVG run delays the load; dom.navigables.navigationPlanned keeps the load queued while a navigation waits; History.go ignored while unloading.

**Takeaway**: **Before moving an event earlier, list what the old order did between the new point and the old one, and give each its spec position; a probe of the widest test set finds the rest by name.**
