# Architecture: A browser's strong hold comes with the step that ends it - copy both or neither

**Date**: 2026-10-27
**Lesson**: Before copying a browser's strong hold into Crane, find the step that ends it in that browser and check that Crane has the same step. A hold Crane cannot end in the same place is a leak, even when the browser's hold is correct.

**Why**: A strong reference is only as safe as its release. A browser's design pairs each hold with the event that drops it. That event can come from a different algorithm, or from a step Crane does not implement yet. Copy the hold without its release and the held object lives until some unrelated event happens.

**What Happened**: Refcount step 5c (lane refcount5) was to convert a MutationObserver's transient registrations. The design said to make them `GCReachableRef`, following WebKit's `MutationObserverRegistration::m_transientRegistrationNodes`, a `HashSet<GCReachableRef<Node>>`.
- WebKit ends those holds at the next microtask whether or not the observer has records. `observedSubtreeNodeWillDetach` calls `setHasTransientRegistration`, which adds the observer to the active set and queues the microtask. `deliver` then takes the transient registrations. Blink does the same with `SetHasTransientRegistration`.
- Crane removes transient registered observers only in "notify mutation observers" step 6.3. That step runs only for observers that have queued records. Crane implemented the older DOM text, which had no activation step.
- So a strong hold would have kept every subtree removed under an `{attributes: true, subtree: true}` observer until that observer's next record. On a quiet page that could be never.
- The current DOM text settles it. It gives the observer's "transient node set" as "a set of weak references to nodes". It also adds the activation step: "add transient registered observers", step 7, appends the observer to the pending mutation observers. Under Crane's decision D1, a removed node lives while anything in its tree is held, so the weak set loses nothing observable.

The integrator ruled for the weak set (ruling D-T (A)). The spec's activation step and its creation-index notify order became a separate spec item. The same batch's pending targets did copy WebKit's strong hold (`m_pendingTargets`), because Crane does have its release: notify, takeRecords() and disconnect() each empty the record queue, the same three places where WebKit drops the set.

**Fix**:
1. For every browser hold you mirror, write down three things: what takes the hold, what releases it, and the algorithm step where the release happens.
2. Find that same step in Crane. If it is missing, either implement it in the same change or keep the hold weak, and say which you chose.
3. Read the current spec text for the holder before choosing the hold's strength. "Weak reference" in a spec is a statement about lifetime.
4. Pin the choice with a count test. For example, tests/html/refcount_observer_holds_test.zig checks that "the node list and transient node set hold no reference".

**Takeaway**: **A strong hold is only as safe as the step that ends it: when you copy a browser's hold, copy its release, or keep the hold weak.**
