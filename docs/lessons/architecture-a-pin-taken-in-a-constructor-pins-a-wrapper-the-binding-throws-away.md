# Architecture: A Pin taken in a constructor pins a wrapper the binding throws away

**Date**: 2026-09-26
**Lesson**: `same_object.Pin.hold(instance)` inside `call_constructor` makes a wrapper for an instance the binding is about to wrap itself; the binding's `cache.set(instance, this_obj)` then replaces the Pin's entry, so the Pin holds an object script never sees and the real wrapper stays weak.

**Why**: A Pin creates the wrapper when none exists, and in a constructor none exists yet: the binding stores V8's `new` object in the wrapper cache only after the constructor returns, replacing whatever entry is there.

**What Happened**: WebSocket held itself alive with a Pin taken in its constructor. Once V8 collected in worker isolates, the sockets of websockets/Create-blocked-port.any.js's worker variant were freed with their connections pending; the first ~20 never fired `error` (440 of 502 subtests).

**Fix**: For "alive while I have work pending", take the Engine table's pending-activity hold (`keepPlatformObjectAlive`). A hold placed before the wrapper exists is recorded against the instance (`WrapperCache.pending_before_wrap`, by slab generation) and taken by the wrapper the binding makes; `releasePlatformObject` ends it (2016d4f6c). A Pin stays right for a [SameObject] CHILD handed out by an owner that already has its wrapper (`xhr.upload`, `channel.port1`).

**Takeaway**: **Never pin the object under construction; take a pending-activity hold, which survives the binding's wrap.**
