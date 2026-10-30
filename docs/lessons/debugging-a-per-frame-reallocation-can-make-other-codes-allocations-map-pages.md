# Debugging: A per-frame free and re-allocation can make OTHER code's allocations map pages

**Date**: 2026-10-30
**Lesson**: Under the WPT runner's DebugAllocator, a change that frees and re-allocates a small buffer once per frame can make unrelated, unchanged code's short-lived allocations of the same size class map and unmap a bucket page on every call. The cost shows up in the unchanged code, so a profile points away from the change. Count page reclaims per operation to see it.

**Why**: `std.heap.DebugAllocator` (tests/wpt_runner/runner_allocator.zig, `never_unmap = false`) bump-allocates inside 128 KiB bucket pages, never reuses a freed slot, and unmaps a bucket as soon as its last live slot is freed. Whether a call-lifetime allocation is nearly free or costs an mmap, a munmap and a zero-fill fault depends on whether some longer-lived allocation keeps its size class's current bucket occupied. That depends on every other allocation of the class in the process, so new code can change it without allocating anything per call itself.

**What Happened**: Lane rendering3's effect-stack target index was rebuilt each time the values revision moved, which is every frame while an animation runs. Each rebuild freed every target's `ArrayListUnmanaged(Link)` and allocated it again: one 128-byte list for one spinner. crane/r3-cost-one-spinner.html (one running animation, 50 `getComputedStyle(e).opacity` reads of unanimated elements per frame) read 31% slower.
- The first agent counted style resolutions, index rebuilds and settles per frame. All were as designed: 0 resolutions during the reads and 1 rebuild per frame. It escalated with the cause unknown.
- `sample` of base and tip showed `computedStyle`'s own allocator time going from 2 to 60 samples, almost all `mmap`/`munmap`. The extra was also in `serializeValue`'s output buffer (10 to 62). Both are 128-byte call-lifetime buffers (the lineage list and the serialization `ArrayList(u8)`) that the change never touched.
- `/usr/bin/time -l` over split pages (300 frames, 15,000 reads) settled it. `getComputedStyle()` alone and other DOM calls were equal. A fresh declaration's read made 197,8xx page reclaims against base's 182,2xx: about one extra fault per read. Instructions rose by about 15,000 per read, which is kernel work.
- A tip whose `component()` returned 0 at once matched base exactly (182,2xx reclaims), which ruled the effect-stack path in. Keeping the index's storage across rebuilds (below) matched base too: 182,261 and 182,231 reclaims, 652.6 and 683.9 ms against base's 653.5 and 666.5 ms, with tip at 813 ms.

**Fix**:
1. Retained storage: `TargetIndex.begin` empties each target's list with `clearRetainingCapacity`, and `finish` removes only the targets no effect applies to any more, under a TombstoneGuard. A steady-state frame then allocates nothing. tests/dom/r3_target_index_test.zig pins this with a FailingAllocator that fails every later allocation.
2. Diagnosis: run the probe split into parts (the call alone, the read on a reused object, the read on a fresh one), each part under `/usr/bin/time -l`, base against tip. Then a tip with the new path cut off (`component()` returning 0) to rule the change in or out as a whole.

**Allocator-dependent**: the cost exists only under an allocator that never reuses a freed slot and returns an emptied page at once. A reusing allocator (smp_allocator, a host's malloc) would not show it. Zig 0.17's SafeAllocator, which the port moves the runner to, never reuses slots either (the integrator, 2026-10-30): re-run crane/r3-cost-one-spinner.html and the page-reclaim split after the port.

**Takeaway**: **When a per-call cost moves but nothing per call changed, count page reclaims per call before theorising: under DebugAllocator your per-frame churn can make someone else's call-lifetime allocations map pages. Keep per-frame storage, do not free and re-allocate it.**
