# Architecture: An element type the tree teardown does not list runs Element's deinit - and one alive at teardown runs none

**Date**: 2026-10-05
**Lesson**: A subtree's teardown (Node.deinit, its children through
`deinitNodeByType`) calls the element's own interface deinit only for the
types it names (script, SVG script, iframe - and now object, embed); every
other element gets Element's. And an element still alive when its page ends
is not deinit'd at all. State an element type keeps must survive both.

**Why**: `deinitNodeByType` dispatches by node type and, for elements, by a
short list. An impl's `deinit` - the one that hands back its own records -
runs for a collected wrapper (the vtable's) and for the listed types, nothing
else. The iframe gets away with it by keeping its InternalState and
IFrameIntegration in `runtime.ArenaAllocator`, which goes with the process,
and by freeing what an integration owns in `onRemovedFromDocument` (the
leaks lane, 2026-10-02).

**What Happened**: the objectembed lane's object and embed elements kept a
record per element (allocator.create) and a content navigable whose
navigations committed strings (recordCommit, commitResponse). With
`CRANE_LEAK_TRACES=1`, crane/obj-navigables.html leaked 5 DebugAllocator
blocks, obj-load-delay 23, obj-lifetime 7 - only for objects the collector
had not taken before the page ended. A debug print in the impl's deinit
showed it never ran for them; tests/html/object_embed_teardown_test.zig
showed a div's teardown leaving the object's state in place.

**Fix**: the records moved to `runtime.ArenaAllocator` (as the iframe's),
which removed the per-element leaks; `deinitNodeByType` dispatches
HTMLObjectElement and HTMLEmbedElement by vtable (as SVGScriptElement),
which removed the rest (3 -> 0, 15 -> 0, 3 -> 0). The generic fix - every
element's most-derived deinit - is queued for a leaks lane.

**Takeaway**: **A new element type with state of its own: keep its records
in the runtime arena, and check that a tree teardown reaches its deinit
(deinitNodeByType) - count `leaked:` lines for a page that ends with the
element still alive, not only for one whose element was collected.**
