# Architecture: An activity bit cannot own two independent holds

**Date**: 2026-10-05

**Lesson**: An idempotent keep/release API cannot represent two independent reasons to keep the same object alive.

**Why**: A boolean pending-activity hold has no ownership count. Either caller's release clears the bit, even if the other caller still needs it. A platform Instance pointer also does not root its JavaScript wrapper.

**What Happened**: Custom-element creation returns a native Instance after constructing a JavaScript wrapper. The generated CEReactions bracket can run script before return conversion. A proposed temporary keepPlatformObjectAlive/releasePlatformObject handoff would have reused the same pending_activity bit that details toggle tasks and media activity use. Returning a customized details element could then clear the details task's hold. This was found while reviewing the ownership contract, before that proposal was activated.

**Fix**: Transfer the constructor result's independent Owned value to an agent-owned pending-return list. Release it at the next microtask, on realm cleanup, or before destroying the agent. Each Owned is released exactly once, including after its realm retires. The separate handle never changes a built-in element's activity bit. Cover both the return-conversion collection window and a dropped customized details element with a pending toggle task.

The native return-window fixture queues a different collector element, so its reaction queue cannot accidentally root the result. With the pending return root present, the result preserves its class and expando; temporarily releasing it before end changes its slab generation from 5 to 0. Separate parser cases exercise collection inside an attribute callback and from its cleanup microtask checkpoint, before insertion.

**Takeaway**: **Keep independent ownership independent; use a counted or separately owned root when an existing keep/release API is only a bit.**
