# Architecture: A keep on an object with no wrapper yet can fail silently - take holds once the wrapper exists

**Date**: 2026-11-04
**Lesson**: `engine.keepPlatformObjectAlive` on an instance that has no wrapper yet records the keep in the wrapper cache's pending map, an insert that can fail. Under allocation failure it fails silently, the keep is lost, and the matching `releasePlatformObject` is an unmatched release. Take a hold after the object's wrapper exists. An object with no wrapper cannot be collected anyway.

**Why**: A keep on a wrapped instance is a counter bump on its cache entry, with no allocation. A keep on an unwrapped one goes to `pending_before_wrap` (`getOrPut ... catch return`), so the wrapper can take it over when it is made. The protocol call returns nothing, so the caller cannot know the keep was dropped.

**What Happened**: Lane streamslife1 replaced a per-object "turn" microtask with a scoped hold for the length of each streams setup. The first version took that hold on the new controller first thing, before the traced edges made its wrapper. tests/v8/sa_transform_setup_oom_test.zig fails each allocation of a TransformStream setup in turn. At one index the pending-map insert failed, and the setup's `defer give()` logged "releasePlatformObject on WritableStreamDefaultController ... with no keepPlatformObjectAlive left to end". Unit tests treat that log as fatal (decision D9).

**Fix**: `setUp*Controller` take the hold right after `js.traceBoth` has wrapped both stream and controller (and checked `engine.hasWrapper`), so the keep lands on the entry. Nothing before that point needs a hold: an instance with no wrapper is never collected. In the same family: `traceChild` swallows an out-of-memory wrap, so a setup checks `hasWrapper` after drawing its edges and fails with OutOfMemory, freeing what is still unwrapped (c47f7e52897).

**Takeaway**: **Hold an object once its wrapper exists. Before that, nothing can collect it, and a keep there costs an allocation that can fail without a word - the release that follows is then someone else's keep ended.**
