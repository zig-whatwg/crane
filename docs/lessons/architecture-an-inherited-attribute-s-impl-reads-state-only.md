# Architecture: An inherited attribute's impl reads state only its own interface writes

**Date**: 2026-09-23
**Lesson**: `startContainer`/`startOffset`/`endContainer`/`endOffset`/`collapsed` are AbstractRange attributes, so the binding answers them through `AbstractRange.zig` for every range. That impl read AbstractRange's generated state, which neither Range nor StaticRange ever wrote - both keep their boundary points in their own `InternalState`. Every range read `startContainer` as `undefined`, and `Range-selectNode.html` passed 0 of 292.

**Fix**: `src/dom/range_boundaries.zig`: each subclass installs a provider, and AbstractRange's getters ask it - the `abort_algorithms.zig` shape, no impl-to-impl call and no mirrored copy to go stale. Range-selectNode 0 -> 280/292.

**Takeaway**: **When a parent interface declares an attribute, check who writes the state its impl reads. A subclass with its own `InternalState` usually does not.**
