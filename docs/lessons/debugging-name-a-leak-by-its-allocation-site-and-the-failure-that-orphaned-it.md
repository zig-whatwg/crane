# Debugging: Name a leak by its allocation site and by the failure that orphaned it

**Date**: 2026-11-11
**Lesson**: A count of live blocks after teardown says that something leaked, not what. Record two stacks: one for every live block (where it was allocated, and in which round), and one for each round's induced failure. Then each leak names its owner and the failure that orphaned it, in one run.

**Why**: Out-of-memory sweeps fail a different allocation each round, and the leaked block is rarely made where the failure happens. Lane v8up b3g knew only "24 blocks (3,852 bytes) after Browser.deinit".

**What Happened**: Lane v8up b3h added a map to the test's CountingAllocator: block address -> 12-frame stack and round number. It lives in c_allocator behind a spin lock and is not counted. The test also kept each round's FailingAllocator.getStackTrace(). One run then split the 24 blocks into two causes:
- LocationImpl.init had no errdefer when its URL parse failed. This was 10 blocks, fixed in the same batch.
- engine.traceChild returns silently when the child's wrap fails (WrapperCache.set's CacheEntry allocation). Its callers had already handed the child to the edge, so 14 blocks of AbortController, NavigateEvent, NavigationDestination and Performance had no owner. The fix is queued: it is an engine ownership change.

Neither cause showed in the code that made the blocks. Both showed in the failing round's stack. The same report also answered "what does a round keep" (the in-flight navigation's record and policy clones), which had been open for two batches.

**Fix**: In the test allocator, keep `address -> {len, round, frames}` (captureCurrentStackTrace with `first_address = ret_addr`). Update the entry on resize and remap, and drop it on free. At the end, group the live blocks by stack and print each group with dumpStackTrace, followed by the stack of the failure of its first round. To ratchet a known leak while it waits for its fix, classify each group by the impl files its symbolized stack passes through (writeStackTrace into a fixed Writer). Fail on any other site, and on a count above the measured allowance.

**Takeaway**: **A leak count is a symptom. Record where each block was allocated and the stack of the failure in its round, and the leak names its cause. An infallible operation that takes ownership and can fail inside is a leak by construction.**
