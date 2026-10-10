# Debugging: A node's slab generation can outlive its NodeBase - a generation check does not prove a node's storage is there

**Date**: 2026-10-09
**Lesson**: Node.deinit frees the node's NodeBase but releases its slab slot (the generation going dead) only outside coordinated teardown and when no wrapper is cached (`deinitNodeByType`'s deferred `releaseStorage`). During a realm's teardown, and in the browser's final registry sweep, a node's NodeBase is gone while `SlabAllocator.generationOf` still reads live. Anything that keeps a pointer INTO a node (not just to its Instance) needs to be told when the node goes.

**Why**: The generation is the Instance slot's identity, and the slot outlives the node's own storage on those paths by design (a cached wrapper still names the slot). A holder's record linked into `NodeBase.holds` unlinks by writing the node's chain head - into freed memory, if the node went first.

**What Happened**: Lane nodeholds' first build checked only the generation before unlinking a hold. The cost tests (10,000-element pages) ABRTed at Browser.deinit: the realm's teardown freed nodes and lists in no order, and a list freed after its nodes wrote into their freed NodeBases. A lifecycle-flag check (`isCleanupStarted`) would have cost a global hash lookup per hold and still missed the final sweep, which sets no flag.

**Fix**: `node_holds.nodeReleased(node_base)`, called by Node.deinit and the final sweep beside `observer_registrations.releaseList` - just before the NodeBase is freed - nulls every hold on the node: native records only, no engine call, no allocation, safe in any teardown. The holder then reads null (a teardown net) and skips the hold. Pinned by tests/html/nodeholds_teardown_test.zig (a holder outliving its node through the realm's teardown and through the final sweep); with nodeReleased a no-op both crash.

**Takeaway**: **A live generation says the Instance slot is still that object's, not that its node storage exists: anything linked into a NodeBase must be unlinked by the node's own teardown, the way registered observers are.**
