# Testing: cppgc's used bytes cannot show an explicit free between collections - count the objects

**Date**: 2026-11-10
**Lesson**: `CppHeap::CollectStatistics(kBrief).used_size_bytes` (the adapter's `cpp_heap_used_bytes`) counts a linear allocation buffer whole from the moment it is taken and an explicit free only at the next allocation's safepoint, so between full collections it cannot show memory that `FreeUnreferencedObject` gave back.

**Why**: cppgc's StatsCollector (V8 13.1.203 src/heap/cppgc/stats-collector.cc) keeps `allocated_object_size() = marked_bytes + allocated_bytes_since_end_of_marking`. An allocation from the buffer changes nothing; a buffer refill adds the whole buffer (`NotifyAllocation` in ReplaceLinearAllocationBuffer); an explicit free into the free list adds to `explicitly_freed_bytes_since_safepoint_`, which joins the total only when an allocation's slow path reaches `NotifySafePointForConservativeCollection` with at least 1 KB of change; a free that ends at the buffer's start extends the buffer and is never counted at all (explicit-management.cc). Only a full collection makes the figure exact (marked bytes).

**What Happened**: Lane wr1 batch 8 freed each scavenge-dropped wrapper's NodeAnchor after the scavenge. Its red test asked that 50,000 dropped divs leave `cpp_heap_used_bytes` near its base. With the fix, 50,000 of 50,000 anchors were freed and none was held, yet the figure read +783,888 B (15.68 B/element): the last drain's frees were still waiting for a safepoint, and nothing allocated on the C++ heap after them.

**Fix**:
1. Prove a free by counting the objects: the anchors held (registry + dropped list) and the frees made (`node_anchors_freed`).
2. When bytes are needed, count them object by object: `v8_test_CppHeap_LiveBytes` (kDetailed: it finishes a running sweep and gives back the buffers first, so it changes the heap's state - tests only).
3. Read kBrief's figure only after a full collection, or as a slope over many readings (gc_bench), where one buffer and one pending safepoint are a constant.

**Takeaway**: **A heap's own running total is bookkeeping with lags of its own: before calling a free missing, count the objects - and read the total only where the heap makes it exact.**
