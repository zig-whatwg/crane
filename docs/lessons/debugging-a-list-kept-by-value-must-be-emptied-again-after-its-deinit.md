# Debugging: A list kept by value must be emptied again after its deinit

**Date**: 2026-11-08
**Lesson**: `std.ArrayList.deinit` sets the list to `undefined`; a list that lived behind a pointer freed right after its deinit can be moved into a struct by value only if every deinit that may be followed by another use writes `.empty` back.

**Why**: Zig's containers end their `deinit` with `self.* = undefined`, which a safe build fills with 0xaa. While the list was its own allocation (`?*AttrNodeList`, destroyed and nulled straight after its deinit), nothing ever read it again. Kept by value in a longer-lived block, the same "free the storage when the last entry goes" step leaves a list whose `items.len` and `capacity` are 0xaaaa..., and the next append or lookup walks it.

**What Happened**: Lane perf3 D2 moved an element's Attr node list from ElementData (`attr_nodes: ?*AttrNodeList`, freed with its last node) into the element's rare data by value (`attr_nodes: AttrNodeList`). `AttrNodeList.take` kept the old shape - `if (len == 0) entries.deinit(allocator)` - and eight tests-dom tests and one src-dom test panicked "reached unreachable code" on the next Attr node operation (getAttributeNode after a removeAttributeNode, the element's teardown walking the list). The size pins and the rare-data tests passed: only a second use after the list emptied showed it.

**Fix**: `AttrNodeList.deinit` frees the storage and writes `self.entries = .empty`; `take` calls it when the last node goes. Any by-value container whose deinit is not the end of its owner's life does the same.

**Takeaway**: **When a container moves from its own allocation into a struct by value, its deinit stops being the end of its life: write `.empty` back after every deinit that a later use can follow.**
