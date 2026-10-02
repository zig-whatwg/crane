# Architecture: traceChild must never make the owner's wrapper - an edge from an owner script has not seen waits for its wrapper

**Date**: 2026-10-01
**Lesson**: An edge drawn from an owner that has no wrapper yet must wait - held strongly in the owner's realm's wrapper cache - until the binding makes the owner's wrapper, and be drawn on that wrapper then. Making the owner's wrapper inside `traceChild` is wrong in both places owners have none.

**Why**: Two kinds of owner have no wrapper when they first keep a child: an object a constructor is building (WebIDL `new X(dict)` - the binding caches `this` only after `call_constructor` returns, and `WrapperCache.set` replaces an existing entry: a wrapper made earlier is dropped with its edges), and an object Zig made for later (a navigate event before its dispatch - a wrapper made now is weak and unreachable, so the collector frees the owner before script ever sees it). WebSocket.zig had already recorded the constructor half for a `same_object.Pin`.

**What Happened**: Converting the event Pins (StorageEvent.storageArea, FormDataEvent.formData, NavigateEvent's destination and signal...) to edges meant tracing from `call_constructor` and from Zig-made events. The first batch's `traceChild` made the owner's wrapper (`relevantWrapper`) when it had none.

**Fix**: `protocol_tracing.holderOf` never makes a wrapper; an unwrapped owner's edge goes to `WrapperCache.deferEdge` (by slab generation), which `WrapperCache.set` draws on the wrapper when it is made. An owner freed unwrapped ends its waiting edges from its teardown (`forgetTracedChild` touches no engine object for an unwrapped owner, so it is safe even while the collector runs - the cache removes a collected owner's entry before freeing it); a dead owner's edges are pruned by generation as a backstop. tests/v8 pin both directions.

**Takeaway**: **An operation that keeps something "for as long as the owner's wrapper lives" must not create that wrapper itself: defer to the wrapper the binding makes, and release the deferral when the owner dies unwrapped.**
