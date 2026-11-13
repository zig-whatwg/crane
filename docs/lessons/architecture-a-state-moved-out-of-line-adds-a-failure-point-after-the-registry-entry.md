# Architecture: A state moved out of line adds a failure point after its registry entry

**Date**: 2026-11-10
**Lesson**: Moving part of an impl's state into an allocation of its own (to shrink the common case) adds a step that can fail AFTER `Registry.createIn` registered the state; the construction chain frees the instance without its deinit, so the next object at that address inherits the entry. Give `initOwn` an `errdefer` that ends the state and removes the entry.

**Why**: CSSStyleDeclaration's InternalState was 192 bytes for every object, element.style's included, because it held what only a computed declaration (a MemberHold, a pseudo-element copy) or a detached one (its own DeclarationBlock) reads. Lane rare1 moved those into an `Extra` block made only for those kinds: 56 bytes for an inline or rule declaration. But `makeExtra` allocates, and initOwn ran it after `Registry.createIn`. An initChain error frees the slab slot and never runs deinitOwn.

**What Happened**: tests/dom/bx1_transform_alias_test.zig reads computed declarations under `testing.checkAllAllocationFailures`. Each failing index after the new allocation left an entry behind, and the next declaration at that address logged "stale CSSStyleDeclaration.InternalState at a reissued address: a teardown missed it" (the registry's own check, docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md). Before the change the only allocation after createIn was the pseudo-element copy, which that test never passed, so the gap was there but never reached. Isolated by running the test with the old CSSStyleDeclaration over the new tree (it passed), then fixed with `errdefer { internal.deinit(instance); Registry.remove(instance); }` right after the state is initialised, and pinned with a construction under every allocation failure.

**Fix**:
1. In an `initOwn` that registers state, put the errdefer that deinits it and removes the entry directly after the state is initialised - before any step that can fail.
2. Make the state's deinit safe on a half-made state (a hold never taken, an optional block never made).
3. Test the construction with `checkAllAllocationFailures`; the registry's stale check turns a missed exit into a failure.

**Takeaway**: **Every allocation added after `Registry.createIn` is a new exit the construction chain does not clean: an errdefer that removes the entry belongs right after the state exists.**
