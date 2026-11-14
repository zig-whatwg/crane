# Architecture: A hold with no link on its node reads the slab's stamp - it must not outlive its node's Browser, and every free must mark the stamp

**Date**: 2026-11-09
**Lesson**: Once a counted hold has no link on its node (no per-node chain a teardown can empty), the only way it learns that a node was freed under it is the slab slot's stamp - the generation and the teardown-begun flag - so every path that releases a NodeBase must set that flag, and no hold may be read after its Browser's slab is gone.

**Why**: node_holds' chain (`NodeBase.holds`) let a teardown that frees a node whatever the counts say - a forced realm end, the Browser's final sweep - null every hold on it (`nodeReleased`), after which the holder read nothing of the node. The redesign's P6 deleted the chain (NodeBase 88 -> 80 bytes): a hold is now the node, its slab generation and its NodeBase, like `CountedRef`. Node.deinit marks the slot's teardown begun before it frees, but the final sweep released NodeBases (poisoned) with the slot's generation and flags unchanged; a hold released after it would have decremented a poisoned count. And tests kept a Holder past `browser.deinit()`, reading the slot of a freed slab.

**What Happened**: Rewriting node_holds without the chain, `Hold.stillHeld` became "same generation and teardown not begun". Node.releaseNodeBase - the one exit of a NodeBase, the sweep's included - now calls `instance_lifecycle.markCleanupStarted`. The two nodeholds_teardown tests that kept a Holder past the Browser's end changed: the realm-end case lets go after an iframe's realm ends inside a live Browser; the sweep case reads and releases its holds from a test sweep installed after the `.documents` phase (`teardown_sweeps.withSweepForTest`), between the node sweep and the slab's end, under poison. Holders were inventoried: every counted hold lives in a Browser's own instance states, tasks or parser objects; nodes never cross agents (structured clone of a node is a DataCloneError), and refcount_teardown.agentEnded reports any node still held at the agent's end.

**Fix**:
1. A chainless hold checks the slot's generation AND `isCleanupStarted`, and forgets (never releases) a node that fails either.
2. Every NodeBase release marks the slot's teardown begun - put it in the one exit, not in each caller.
3. A test that keeps a hold past a teardown reads it inside the Browser that owns the slab.

**Takeaway**: **A hold that cannot be told about a free must be able to see it: make every free mark the slot, and never let the hold outlive the allocator whose stamp it reads.**
