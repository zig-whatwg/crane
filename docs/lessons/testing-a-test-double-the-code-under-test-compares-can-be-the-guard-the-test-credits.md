# Testing: A test double that the code under test compares can itself be the guard the test credits

**Date**: 2026-11-14
**Lesson**: A test that replaces part of an object to observe it (a vtable copy that counts destructor runs) changes what the product sees of that object. If the product compares that part, the test passes because of its own double, and the branch it pins is unguarded in production.

**Why**: The wrapper cache's finalizer skipped an entry whose instance "is no longer the one it was made for", and until lane wrap1 batch 3 it decided that by comparing the instance's vtable and state pointers with the ones recorded at the wrap, as well as the slab generation. tests/v8/window_finalized_in_teardown_test.zig gives the realm's Window a COPY of its vtable that counts destructor runs, after the Window was wrapped. The finalizer saw a different vtable, took the slot for reissued and returned - so the test's own double kept the entry out of the branch under test.

**What Happened**: The test pins that a detached realm's Window, whose global the collector takes during another realm's coordinated teardown, is not torn down by its wrapper's death (its realm's end does that). Its header says "Measured, not reasoned: the entry reaches that branch no more". It did not reach it because of the swapped vtable. Batch 3 replaced the 88-byte entry with a 32-byte record that compares the slab generation alone; the test then failed with "vtable destructor runs after the collection: 1": the finalizer's "context tearing down" arm freed the Window through its vtable. In production, with no swapped vtable, that arm had been reachable all along. The fix excludes a realm's Window there by name, as the rule beside it already said (wrapper_cache.zig `finalizeEntry`).

**Fix**:
1. When a test passes "by measurement" through a path nobody can name, find the line that makes it pass before keeping it as a pin. Log the branch taken once.
2. Do not observe an object by replacing a field the product reads for identity (vtable, state pointer, generation). Count from inside a hook the product calls, or wrap the type at construction, before anything records it.
3. When a refactor removes a comparison, list what the comparison was catching by accident: run the tests that fail and read why they passed before.

**Takeaway**: **If the product compares what the test replaced, the test is measuring its own double. A guard nobody wrote is a guard nobody keeps.**
