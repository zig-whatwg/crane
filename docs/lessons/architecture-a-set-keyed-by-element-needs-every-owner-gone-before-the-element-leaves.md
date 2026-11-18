# Architecture: a set keyed by element needs every owner gone before the element leaves it

**Date**: 2026-11-18
**Lesson**: When several loads (or tasks) of one element each "add the element to a set" - HTML's render-blocking element set, a document's delay list - the end of one of them must not take the element out while another still needs it.

**Why**: HTML's "block rendering on el" is idempotent: the set holds the element, not the fetch. A link whose href changes starts a new fetch that blocks again (a no-op on the set) and the old fetch is cancelled; if the cancelled load's cleanup removes the element, nothing blocks rendering while the new sheet is still loading.

**What Happened**: html/dom/render-blocking/stylesheet-link-href-change-keeps-blocking.html (Chrome and Safari pass) failed in Crane: the first rendering update ran before the new stylesheet arrived and read the unstyled color. style_sheet_loading's `unblockRenderingFor` removed the element whenever a load that had blocked ended - including the superseded one, cancelled right after its replacement started.

**Fix**: `unblockRenderingFor` removes the element only when no other live load of the same element is still render-blocking (a walk of the realm's style sheet loads). Lane blk2, b53037ae6d2.

**Takeaway**: **A membership keyed by the element is shared by all of the element's owners: remove it only when the last owner that added it ends.**
