# Architecture: `on*` content attributes had never been implemented

**Date**: 2026-09-22
**Lesson**: `HTMLElement.set_onerror` and `Document.set_onerror` were no-ops,
and no attribute-change code turned `on*="..."` attributes into handlers, so
`script.onerror = fn` was dropped and `<body onload>` never ran - 36 encoding
files hung on it. `OnErrorEventHandler` has its own typedef, which is how it
got stubbed separately from every other handler.

**Fix** (43a585d9a): compile content attributes in the attribute change steps
and assign them through the IDL attribute, forwarding `<body>`/`<frameset>`
window handlers to the Window. Deviation: the handler is compiled when the
attribute is SET, not on first use - every pointer-tag value in the handler
maps is taken, so there is nowhere yet to keep an uncompiled handler.

**Takeaway**: **When a directory hangs on an event, check that the handler is
stored before checking that the event fires.**
