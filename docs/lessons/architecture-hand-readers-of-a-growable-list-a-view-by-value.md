# Architecture: Hand readers of a growable list a view by value, so a reallocation cannot dangle them

**Date**: 2026-11-07
**Lesson**: When a list that readers borrow from becomes out-of-line and exact-size (so it moves on every append or remove), change what its read API returns - a small view by value whose slices point into storage that does not move - instead of auditing every reader for pointers held across a mutation.

**Why**: An element's attribute list in Crane was four inline 96-byte slots plus a heap list: a pointer into the inline slots stayed valid while the element lived, so ~100 readers (the selector matcher, the style engine, reflection, getElementById) took `?*const AttributeEntry` from `findAttribute` / `attributeAt` / the iterator and some kept it across calls. Lane perf3 D1 moved the list out of line, exact-size, one allocation that `realloc` moves when an attribute is added or removed (Blink and WebKit hold attributes the same way). A pointer into it held across any step that can run script or change attributes - the attribute change steps, custom element reactions, mutation records, an Attr node's value setter - would read a freed block. Blink shipped exactly that: rare data reallocated during a set, a re-entrancy corruption.

**What Happened**: The integrator's approval made it a condition: no pointer into the list across a mutation, the ID and classes re-derived after every mutation or held as indices, and a test (set id, add 20 attributes, read id and className under a poisoning DebugAllocator). Auditing 100 readers, and keeping them right forever, was the expensive way. Instead the stored `Attribute` became 24 bytes - a pointer to its name record (static for a known name, else the attribute's own allocation) and its owned value - and every read returns an `AttributeEntry` BY VALUE, with the same field names the readers already used (`namespace_uri`, `prefix`, `local_name`, `value`). Its slices point into the name record and the value's buffer, neither of which moves with the list. Every reader compiled unchanged except three call sites that passed the entry to a `*const AttributeEntry` parameter (`&entry`). The ID and classes became views of their attributes' values, re-derived from the list by the attribute change steps; the old value's buffer is freed only after those steps ran, so the tree-ordered map's "out under the old ID" step still reads the old one.

**Fix**:
1. Store compactly (`Attribute { name: *const QualifiedName, value: []const u8 }`), keep the bytes a reader sees (names, values) in allocations the list does not own by position.
2. Return `?AttributeEntry` by value from every read; keep the field names, so readers' `entry.value` / `entry.local_name` compile unchanged.
3. Writers take the index afresh after anything that can change the list (`storedAt(index)`), never a `*Attribute` across a call.
4. Cached views of a value (the element's ID, its classes) are re-derived from the list inside the change steps; free the old value after the steps.
5. Pin it with the reallocation test under a poisoning allocator, and a view taken before the growth read after it.

**Takeaway**: **Make a reallocation rule structural: readers get a view by value whose bytes live outside the list, so no reader can hold a pointer into storage that moves - one API change instead of an audit of every reader.**
