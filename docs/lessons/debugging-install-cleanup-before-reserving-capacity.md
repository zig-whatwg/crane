# Debugging: Install cleanup before reserving capacity

**Date**: 2026-10-23
**Lesson**: Install a collection's cleanup immediately after initialization, before its first fallible reserve.

**Why**: A reserve can allocate before it fails. `infra.List.ensureCapacity` first moves an inline list to a small heap allocation, then grows that allocation to the requested capacity. If the second allocation fails, the list still owns its first heap block. An `errdefer` placed after the reserve has not been registered yet.

**What Happened**: The image URL allocator test exercised every failure while parsing and serializing a document-relative URL. In the unchanged URL serializer, failure 15 of 21 left 8 bytes allocated: 1,195 bytes allocated versus 1,187 freed. The allocation trace named the small block installed by `ensureHeap`; the failing allocation was the subsequent growth in the same `ensureCapacity` call. Successful serialization and the other allocator tests passed.

**Fix**: Register cleanup before reserving capacity, retaining the existing successful ownership transfer:

```zig
var output = infra.List(u8).init(allocator);
errdefer output.deinit();
try output.ensureCapacity(capacity);
// Append the serialized components.
return try output.toOwnedSlice();
```

The unchanged allocation-failure tests then passed at every failure position; the targeted native run finished with all 905 tests passing. Keep these tests unchanged when checking the fix. The caller must clean up its initialized collection; it must not assume a failed reserve left the collection unallocated.

**Takeaway**: **A failed allocation operation may follow a successful allocation inside the same call.**
