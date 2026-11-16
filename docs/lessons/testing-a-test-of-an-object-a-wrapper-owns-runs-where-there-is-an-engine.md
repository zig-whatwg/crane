# Testing: A test of an object a wrapper owns runs where there is an engine

**Date**: 2026-11-16
**Lesson**: A unit test that reads an object its wrapper owns (an element's classList, dataset, children) belongs in the test tier that has an engine realm; a fixture with no engine has no owner for it, and giving it one is a path production never takes.

**Why**: A [SameObject] child is owned by its wrapper: the generated getter traces it from its owner (dom.same_object_cache -> engine.traceChild), the trace makes the wrapper, and the wrapper's collection or the realm's end frees the child. tests/dom binds the V8 adapter but makes its ContextData with no realm, so traceChild returns at once and the child has no owner at all. The child's own allocations outside its Browser's pools (a DOMTokenList's copy of its attribute name) are then reported by std.testing.allocator, whether or not the element's document is torn down.

**What Happened**: Lane wb1 moved tests/dom onto real nodes, and 19 tests that read `classList` leaked; it ran them over an arena, as lane cg1's same-object tests already did, and two more tests freed the getters' objects by hand. Lane lk1 was asked to fix "the leak". Measured first: production has none (`leaks --atExit` on the production runner, 0 leaks over the token-list WPT files and over 1,000 elements of a removed iframe whose classList is first read after the removal) - no native code reads these attributes, and script always runs in a live realm. Two fixes were proposed and both refused by the integrator: an "the element owns the child when its realm has no engine" bit in the DOM, and a table of realm-less edges in the V8 adapter. Each is a branch only tests take, kept in step with the real owner by hand. The tests moved instead: 26 tests to tests/html, on a page of a real Browser (tests/html/native_read_page.zig), where the wrapper frees the object exactly as in production. The arena fixtures and the hand frees were deleted.

**Fix**:
1. Before fixing a leak a unit test reports, measure production (`leaks --atExit`, the bug-finding run): a leak only a fixture has is the fixture's.
2. When the fixture lacks the owner production has, move the test to the tier that has it (tests/html: a Browser page; tests/v8: an agent and a realm). Do not add the owner to the DOM or to the adapter for the fixture's sake.
3. Keep the moved test's assertions; where a hand free was the assertion ("the element leaves nothing behind"), assert what production does instead (the object's slab generation changes once its owner's edge ended and the collector ran).

**Takeaway**: **A leak that exists only where there is no engine is a test in the wrong tier: move the test to the production path, never the ownership to a path only tests take.**
