# Architecture: A native [SameObject] read is traced like a script read

**Date**: 2026-10-16
**Lesson**: A generated [SameObject] getter caches the child it makes as a bare pointer in its owner's state. A script read wraps the child, and its wrapper owns it from then on; a native read (`interfaces.SVGAElement.get_href` from an extract-an-origin step) made a child that nothing wrapped and nothing ever freed.

**Why**: Crane frees a platform object either through its wrapper (the wrapper cache's finalizer) or through an owner that keeps it. The generated cache is neither: it keeps a pointer, never a reference. Blink keeps the same object as a traced `Member<>` of its owner, so a C++ read and a script read leave one state.

**What Happened**: Codex row 45 Q14: origin-from-hyperlinkelementutils.window.js went 0 -> 75 `leaked:` markers once SVGAElement's origin extraction read `href` natively - an SVGAnimatedString's state, attribute name and namespace for each of 25 xlink-only cases. tests/html/same_object_native_read_test.zig reproduced it: 24 leaked allocations for 8 links, whether the owners were collected or lived until the page ended.

Two designs were weighed:
- **Free an unwrapped cached child at the owner's teardown** (an opt-in table, or `releaseIfUnwrapped` for every cache): rejected. 402 generated caches; some hold objects the owner does not own (a GATT server's `device`, an event's `data`, a back reference), and impls keep and sever others themselves (Document's KeptChild children, Element's NamedNodeMap). A free there can be a second free, and a table that grows by hand is a list that goes stale.
- **Trace the child from its owner when the getter makes it** (`dom.same_object_cache.made` -> `engine.traceChild`): chosen. The child's wrapper, made in its relevant realm, owns it, and lives as long as the owner's wrapper - or is held until the owner gets one. The owner's destruction chain ends an edge still waiting (`dom.same_object_cache.end` -> `engine.forgetTracedChild`), as the protocol asks of an owner that can be freed unwrapped. AbortController's impl already traced its signal this way on every `get_signal`.

**Fix**: codegen emits `made` after the cache is filled (for a `*runtime.Instance` cache, nullable or not) and `end` first in `deinitChain` for an interface whose State caches a [SameObject] attribute. One regeneration: 198 interfaces, 412 getters. Two tests that had used a native read to get an UNWRAPPED object changed premise, keeping their point: refcount_node_list_roots_test frees the list by ending the owner's edge and collecting; native_wrap_checkpoint_test asserts the getter's own wrap runs no microtask checkpoint.

**Takeaway**: **A native read must leave what a script read leaves. When an object needs an owner, give it a traced edge, never a table of who may free what.**
