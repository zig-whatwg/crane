# Architecture: An adapter that stops freeing on its own needs a drain path in every agent configuration

**Date**: 2026-11-09
**Lesson**: When a free moves from the collector to the counts' queue, every configuration the engine can be made in - test-only ones included - needs that queue; and a repro made in a test-only configuration proves nothing about production until you know which path the configuration takes.

**Why**: Since refcount step 7 a node is freed only when its tree's counts reach zero, through its agent's deferred teardown queue (dom.refcount_teardown.settle). The V8 adapter kept one count-blind free for an agent made WITHOUT a queue - wrapper_cache.finalizeEntry's queue-less second pass, plus the realm end's sweep of its cache - because such an agent had nowhere else to free a tree. Production agents always pass a queue (Browser.zig, html/worker_host.zig); only tests make queue-less ones.

**What Happened**:
1. Lane wr1 batch 1 reproduced "a node held only by dom.refcount.holderRef is FREED when its wrapper is collected" (generation 3 -> 0, 0xdd poison) in a tests/v8 Page made with `engine.createAgent` and no `deferred_teardown`. It was recorded as a SAFETY item: use-after-free, or shadow mode? The comments disagreed: finalizeEntry said "counts decide since step 7", while holderRef's and CountedRef's still said "SHADOW MODE: frees are still the collector's".
2. Batch 2 ran the same case in an agent WITH a queue: the node survived (count 2 -> 1, slot empty), and the holder's release queued and freed it (tests/v8/wr1_counted_hold_test.zig, 3/3). The free came from the queue-less test agent's count-blind fallback. It was no production use-after-free, and the "shadow mode" comments were stale.
3. The wrapper redesign's P2 moved node wrappers out of the wrapper cache, so neither count-blind path saw a node any more. Every queue-less test agent then leaked its garbage trees: the Crane test runner's state check failed each such test ("runtime.standalone_objects: (absent) -> N: the test left it changed").

**Fix**:
1. createAgent makes the agent's OWN DeferredTeardown when the host gives none (protocol_agents.AgentRecord.own_deferred_teardown). `deferredTeardownOf` answers it, never the host pointer, so test agents take production's path: a requested collection, each realm's end and the agent's end drain it.
2. endAgent drains and frees that queue before the isolate is disposed and its CppHeap freed (tests/v8/wr1_own_teardown_queue_test.zig).
3. The SAFETY repro became P2's red test (tests/v8/node_wrapper_inline_test.zig): a holder's count keeps the node past its wrapper in a queue-less agent too.
4. The stale "shadow mode" comments now name the one free still made whatever the counts say: a forced realm end's coordinated teardown.

**Takeaway**: **Before calling a free a use-after-free, rerun the repro in the configuration production uses. A test agent's fallback path is not production's. And when you remove a fallback free, give every configuration, test-only ones included, the drain path production has, rather than a second model kept for tests.**
