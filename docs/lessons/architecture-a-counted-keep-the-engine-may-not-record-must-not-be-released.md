# Architecture: A counted keep the engine may fail to record must not be released

**Date**: 2026-10-29
**Lesson**: `engine.keepPlatformObjectAlive` cannot report failure - with no wrapper yet it records the keep in a side table, and under memory pressure it records nothing - so an owner that later calls `releasePlatformObject` releases a keep that does not exist, which the counted API reports as an unmatched release (an error log, fatal in unit tests).

**Why**: The counted keep (refcount design 2.3) is WebKit's ActiveDOMObject pending-activity count: each keep ended by exactly one release. Its V8 implementation increments the cache entry's `pending_activity` when the wrapper exists, else inserts into `pending_before_wrap` - and on OutOfMemory returns. The protocol call is `void`, so the owner believes it holds a keep it never got.

**What Happened**: Lane refcount8 gave the Window a counted keep of its document's wrapper (refcount step 5i), taken in `Document.setDefaultView` and ended in `clearDefaultView`. tests/html/iframe_policy_container_oom_test.zig, which injects allocation failures through a frame's navigation, then logged "releasePlatformObject on Document ... with no keepPlatformObjectAlive left to end": the keep had been taken on a document whose wrapper the failing allocations never made. The fix takes the keep only when `engine.hasWrapper(document)` - on the wrapper the window's traced edge just made, whose cache entry counts the keep and cannot fail to - and records that it did (`window_kept`); a document whose wrapper could not be made is kept by the wrapper cache's default-view rule meanwhile.

**Fix**: Take a counted keep only where the engine is sure to record it (an existing wrapper), keep your own flag that you took it, and release only what that flag says you hold. A side-table keep for an unwrapped object needs its owner to accept that it may silently not exist.

**Takeaway**: **A `void` acquire can fail silently: release only what you know you got - take counted keeps on an existing wrapper, and test the owner under allocation failure.**
