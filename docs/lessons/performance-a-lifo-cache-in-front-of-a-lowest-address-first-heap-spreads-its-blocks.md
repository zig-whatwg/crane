# Performance: A LIFO cache in front of a lowest-address-first heap spreads its blocks - cache only from spans at or below the lowest with room

**Date**: 2026-11-24
**Lesson**: A per-bucket LIFO cache of released blocks (a magazine, Chromium's ThreadCache shape) in front of a lowest-address-first span heap reissues blocks wherever their spans are. Over a churning page, live and recently released blocks then spread across more spans than lowest-address-first keeps them in, and idle decommit has to keep those spans because they were touched recently. Cache a released block only when its span is at or below the bucket's lowest span with room. A block above that goes back to its span, which can then empty and age.

**Why**: Lowest-address-first is a compaction policy: each allocation fills the lowest hole, so high spans drain and become old enough for idle decommit. A LIFO cache bypasses the hole search, which is its whole speed gain, and with it the compaction. The cost is not the cached blocks (32 per bucket is kilobytes). It is where every later allocation lands.

**What Happened**: Lane hard1's span engine core cost 26 ns per State + slot pair against 8.5 for the old LIFO lists, and a sampling profile put the cost in span bookkeeping (tier flips, slot-map searches). A magazine of 32 released blocks per bucket cut a quarantined pair from 95 to 62 ns in long tasks. chat2's memory pass (9 launches, MallocLargeCache=0, tip vs magazine-0) then read about +1 MB steady and collected on events.dispatch, events.custom-event and page.events, and +1.2 MB collected on dom.build-tree.

The first hypothesis was aging: a drained span was dated by its bucket's latest push, not by its own last release. That got a red test (M5) and a fix that was correct in itself, but the re-run read the same +0.7 to +1.2 MB. It was disproved. The second hypothesis, spreading, was tested by caching only blocks from spans at or below the bucket's lowest span with room (M6). It brought custom-event and page.events to 0.0 and halved build-tree's cost (+0.7). The hot gain stayed (65.5 against 98.3 ns). events.dispatch kept +0.8 MB: there the bucket mostly has no span known to have room, and the magazine still takes every block.

**Fix**:
1. `Engine.release` caches a block only when `b.current == no_span` or `index <= b.current`; a block above goes back to its span (heap/root.zig, df02e6f7e).
2. Each span entry records its own last release (empty_since), so a drained span is aged as it would have been without the magazine (fa656974f). It did not fix this, but it is right.
3. Judge any cache in front of a compacting allocator on the memory rows of churn workloads, not on its microbenchmark. The microbench only shows the gain.

**Takeaway**: **A LIFO cache in front of a lowest-address-first heap trades compaction for speed. Cache only blocks from spans at or below the lowest span with room, and measure churn rows' steady and collected memory before believing the microbench.**
