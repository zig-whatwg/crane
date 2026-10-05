# Architecture: Reaction scopes capture the agent before script

**Date**: 2026-10-05

**Lesson**: A native scope that spans author script captures its agent before the call and never rediscovers it from the receiver when the call ends.

**Why**: Script can remove the receiver's iframe. Explicit realm teardown can free native Instances even while a JavaScript wrapper is held, and the slab can reuse their addresses before a generated defer runs. The function's current realm can be the ended realm too.

**What Happened**: Wiring CEReactions as begin(instance)/end(instance) would have read instance.ctx after constructors or reactions could retire that instance's realm. Replacing that read with currentRealm was also insufficient: in a binding callback it identifies the member function's realm, which can itself end during the member.

**Fix**: Begin returns a value containing the engine agent and its custom-element state. End uses only that value. The engine suspends and restores any pending exception through an agent-scoped operation while reactions run in their callbacks' associated realms. If the engine cannot suspend the exception, pop the scope without script and transfer its elements to the backup queue. Empty scopes still balance when their first definition is installed during the member, but make no exception operation.

**Takeaway**: **Capture the lifetime that outlives reentrancy; a receiver pointer or freshly queried realm does not prove that lifetime.**
