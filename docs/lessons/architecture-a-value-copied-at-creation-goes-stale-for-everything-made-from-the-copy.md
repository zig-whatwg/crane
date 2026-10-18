# Architecture: A value copied at creation goes stale for everything made from the copy

**Date**: 2026-10-18
**Lesson**: A Window kept the origin it was created with, and every later Window of the same navigable was created from the navigable's FIRST copy, so a frame that navigated to another origin made its children with its first container's origin.

**Why**: HTML gives the Window no origin of its own: the settings object's origin is the associated Document's, and a document's origin is decided once, by "determining the origin", and shared (dom.origin_record). Crane kept three copies besides: Window.InternalState.origin (the creation origin), IFrameIntegration.window_origin (kept "for the Windows later navigations make"), and the creator origin read from the container Window's copy when a child navigable was made. Each copy was right the moment it was taken.

**What Happened**: a cross-origin frame's Window was made by replaceRealm with `integration.window_origin` - the top-level page's origin, from the frame's initial about:blank. Its srcdoc child was then created from that Window's copy, and Window.effectiveOrigin answered an about: URL's origin from the copy: the srcdoc child read the TOP-LEVEL page's localStorage (webstorage/localstorage-share-data-unrelated-origins.html, all three browsers pass), and a popup's frame's about:blank children were cross-origin to their own parent (row 65's wh2-origin-open: SecurityError). The documents' origin records were right all along; only the copies were read.

**Fix**: f4daae9059e (lane nav1). Window.effectiveOrigin answers the document's origin record whenever it has a serialization; the copy answers only for a record not yet resolved and before the window has a document. createBrowsingContextAndDocument takes creatorOrigin from the container document's record (dom.document_origin.shareable), not its Window.

**Takeaway**: **A copy taken at creation is a snapshot; anything later made FROM the copy inherits its staleness. Read the owner (here the document's origin record) at the moment you need the value, and keep copies only as a fallback for before the owner exists.**
