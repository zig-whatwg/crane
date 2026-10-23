# Performance: A general sort reserves scratch before small-input branches

**Date**: 2026-10-22

**Lesson**: Profile a general sort's stack setup when a larger element type slows a hot path, even if nearly every input is tiny.

**Why**: Zig's `std.mem.sort` uses block sort, which reserves a 512-element scratch array. In Debug-owned modules its stack initialization occurs before the small-input return paths. A larger candidate record can therefore add work to every element's cascade without increasing the number of comparisons.

**What Happened**: CSS's required declaration-order tie-break grew Candidate from 32 to 48 bytes. The stylesheet cost page regressed by 6.23% (ratio of medians) and 6.78% (median paired change) on seven isolated pairs. BASE/TIP samples showed parseSheet almost unchanged (2849/2863 samples), while resolveOne grew (886/1152) and its sort grew (339/520). The sort prologue reserved and initialized 24 KiB instead of 16 KiB. The comparator already used the unique candidate index to break every ordering tie, so stable sorting added no semantic guarantee.

**Fix**: Use `std.mem.sortUnstable` with the same total comparator. Pure CSS tests, including cascade ordering, passed. The next frozen runner's seven isolated pairs on the stylesheet page measured -3.11% and -3.89%; all eight required cost metrics passed. Preserve the failed series and profiles alongside that result. A separate selector-only slowdown passed in the new series but had no demonstrated CSS mechanism; do not attribute it to this fix.

**Takeaway**: **Check scratch setup and element size before optimizing comparison logic. Change sort stability only after proving the comparator gives every record a distinct position.**
