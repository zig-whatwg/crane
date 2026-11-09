# Architecture: A cached flag is a shortcut only once every writer keeps it exact

**Date**: 2026-11-08
**Lesson**: A flag that is right "except in one case" forces every reader to keep the slow computation as a fallback; find the one writer that leaves it wrong, fix it there, prove exactness against the definition on random mutations, and only then delete the fallback from the hot path.

**Why**: NodeBase.is_connected was maintained by insert and remove for every node, shadow trees included - except a shadow root attached to a host already in a document, which kept `false`. So insert, remove, move and the post-connection steps each asked `is_connected or isConnectedThroughShadow(parent)`, and the second half walked to the root and through the shadow hosts on every insert into a detached tree: O(depth) per insert, O(nodes x depth) to build a tree.

**What Happened**: Lane crash1 batch 3 traced the gap to the attach step and set the new root's flag from its host in `dom.shadow_hosts.attached`, the hook every attach - scripted or declarative - goes through (Blink's ShadowRoot::InsertedInto sets kIsConnectedFlag from the host the same way). `tests/dom/crash1_connected_flag_test.zig` then compares every node's flag with the definition (the shadow-including root is a document) after each of 3,000 seeded mutations - elements, text, fragments, shadow roots attached to connected and disconnected hosts, inserts and removals - and pins the attach-then-move cases. With that, the four `isConnectedThroughShadow` walks went.

A second shortcut in the same batch had the opposite trade: the agent's mutation observer counter answers "no observer anywhere" in O(1), but reaching the agent takes the engine's agent-registry lock, so `hasInterestedObservers` asks it only after walking 64 ancestors - a shallow tree pays nothing, a deep one pays one lookup.

**Fix**: (1) find the writer that breaks the invariant; (2) fix it at the one step every path goes through; (3) a randomized differential test of flag against definition; (4) delete the fallback walks. For an O(1) answer that is not free (a lock, a hash lookup), ask it only where the walk it replaces is long.

**Takeaway**: **A flag with an exception is a walk with extra steps: make the flag exact at its writers and prove it, then let the readers trust it.**
