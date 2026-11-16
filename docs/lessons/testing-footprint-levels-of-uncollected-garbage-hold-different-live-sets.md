# Testing: The footprint levels of a row that ends on uncollected garbage hold different live sets - log the allocations before calling one level true

**Date**: 2026-11-16
**Lesson**: When a row's memory at its mark is garbage the collector has not freed yet, how much of it is still live differs from launch to launch, so two footprint levels can differ in what is held as well as in what is counted.

**Why**: V8 frees ArrayBuffer backing stores from its sweeper, some of them on another thread and some time after the collection that found them dead. A mark half a second after a row's end catches the sweeper wherever it is. `vmmap`'s dirty totals of two launches can be within a few megabytes of each other and still hold different blocks.

**What Happened**: Lane mem2 found `fetch.loopback-gzip`'s two levels (78 and 115 MB with the ring off) to have 119-121 MB dirty in both and named the high one the true figure (lesson testing-two-footprint-levels-with-equal-dirty-bytes-are-one-level-undercounted.md). Lane ab1's allocator ended the under-count and the row still read from 115 to 125 MB. A diagnosis console that logged every in-sandbox allocation and free, four launches a side, showed why: at the mark 36 to 39 of the row's 1 MiB bodies were live, and 0 to 41 of the row before's 176 KiB pieces - 36.0 to 46.3 MiB in all, on both allocators. Main's high-level launches were the ones where everything earlier had been freed in time (its allocator had unmapped its area, so the bodies lay on fresh pages and were counted): 36 bodies, 114.0 MB. Main's low-level launches held MORE - 40.3 to 44.4 MiB live, 121-126 MB dirty - and read 80. With dirty pages minus live bytes as the measure the two allocators were equal: 79.9-82.8 MiB on the tip, 79.3-81.7 on main.

**Fix**:
1. For a row whose memory is uncollected garbage, do not expect one true level: expect a spread as wide as what the sweeper may have left.
2. Compare two builds on such a row by dirty pages minus live bytes, launch by launch, with the allocations logged (a diagnosis build: one line per allocation and free, the line count taken at the mark) - never by the medians of two spreads alone.
3. Say in the report which state each level is ("everything before freed: 36 bodies" / "39 bodies and the stream's last pieces").

**Takeaway**: **Equal dirty totals are not equal live sets: on a row that ends on garbage, log the allocations and compare dirty minus live.**
