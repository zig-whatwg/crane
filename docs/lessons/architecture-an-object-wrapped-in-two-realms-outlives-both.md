# Architecture: An object wrapped in two realms must outlive both wrappers

**Date**: 2026-09-26
**Lesson**: A node has one wrapper whatever realm reads it (its bound wrapper), but every other platform object gets a wrapper in the cache of each realm that reads it. The weak callback and cache teardown freed the instance on the first wrapper's death, leaving the other realm's wrapper - and any owner's `[SameObject]` cache - on freed memory.

**Why**: `wrapInstanceAsV8Object` caches in the CURRENT context's WrapperCache. A span's `dataset` DOMStringMap, read by its frame and by the frame's parent, is wrapped twice. Two more defects stacked on it:
- the lazy-interceptor getter path (`callLazyGetter`, which serves an element's `dataset`) never recorded the `[SameObject]` edge from owner to child at all, so the child's wrapper was tied to nothing;
- the accessor path's edge used one private key per property, so on an element's single wrapper each realm's read overwrote the edge to the other realm's child wrapper.

**What Happened**: once the navigation lane made markup `<iframe src>` load (increment 1), 25 `encoding/legacy-mb-*-decode-*.html` files - which read 13,000 spans across realms - went from TIMEOUT to CRASH: `dataset` returned null, then SEGV in `SetReturnValue`. `crane/crossrealm-sameobject-lifetime.html` (parent and frame read 300 spans' `dataset`, collections between rounds) failed 4/4 on main with no navigation change; a probe with no collection passed in every read order, which is what pointed at lifetime rather than conversion.

**Fix**: `wrapper_cache.zig` keeps `live_caches` (each cache joins on first insert, when its address is final, and leaves at teardown) and frees an instance only when no other live cache wraps it at the same generation (`wrappedElsewhere`) - in the weak callback, in `deinit` and in `clear`. `interface.zig`'s `recordSameObjectEdge` records the edge from both getter paths, keyed per realm.

**Takeaway**: **Ask how many wrappers an object can have before freeing it when one dies. Nodes have one; everything else has one per realm that touched it.**
