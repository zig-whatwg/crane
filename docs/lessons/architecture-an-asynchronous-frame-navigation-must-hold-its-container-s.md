# Architecture: An asynchronous frame navigation must hold its container's load event

**Date**: 2026-09-26
**Lesson**: Once `iframe.src` stopped committing synchronously, the window's load event could fire before its frames had loaded. "The end" step 8 (delay the load event) now waits on `dom.content_navigables`.

**Fix**: clear a frame's delay before firing its load event and notify the document after, so a load handler that navigates the frame again delays the document further (HTML 4.8.5).

**Takeaway**: **Any engine work moved off the caller's stack that a document's load depends on must register as delaying the load event, or every `onload` test reads a half-built page.**
