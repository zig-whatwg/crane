# Testing: Subtree cleanup must return native storage

**Date**: 2026-10-07
**Lesson**: A passing allocator test and an empty node registry do not prove that discarded nodes returned their slab slots and outer state blocks.

**Why**: An interface's deinit releases owned resources. Runtime finalization separately returns the Instance slot and FullState block. Native descendants without wrappers have no finalizer to perform that second half; bulk arena teardown still makes std.testing.allocator report no leak.

**What Happened**: A template parse/clone/import loop left 13,008 live instances after 1,000 forced-GC cycles, while its wrapper cache returned to five and its NodeBase registry to one. Native tests likewise retained 19 slots after a single cycle. The emptied innerHTML fragment and recursively cleaned, unwrapped descendants had only run interface deinit.

**Fix**: Route discarded parser fragments through Node's destruction hook. After a tree-owned node's cleanup completes, return storage when no wrapper owns it, checking its saved slab generation. Leave wrapped storage to the existing finalizer and avoid wrapper-cache queries during coordinated realm teardown. Assert both live slab slots and arena bytes before bulk teardown, then measure a repeated forced-GC loop.

The fixed probe returns to eight live instances and its starting live-state bytes. Over four 5,000-cycle GC batches with malloc, allocator-held bytes plateau after the first batch; 1,160,006 of 1,520,020 state allocations are recycled. The first batch's high-water allocation alone cannot establish a leak, so read subsequent batches as well.

**Takeaway**: **Count live storage separately from resource cleanup, and prove that repeated operations reach a plateau.**
