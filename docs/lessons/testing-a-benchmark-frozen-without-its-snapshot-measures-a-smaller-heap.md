# Testing: A benchmark frozen without its snapshot measures a smaller heap

**Date**: 2026-11-09
**Lesson**: gc_bench (like the runner and the console) finds Crane's V8 snapshot beside it by path, so a side frozen with gc_bench ALONE starts without one: a smaller JS heap, fewer instructions and shorter full collections. Comparing it with a side that has its snapshot measures the startup, not the code.

**Why**: src/browser/process.zig looks for `zig-out/bin/whatwg_snapshot.bin`, then `whatwg_snapshot.bin`, then `../whatwg_snapshot.bin`, all under the current directory, and quietly starts from nothing when none is there. The snapshot's context carries the bindings' instantiated templates and prototypes, about 2 MB of live JS heap that every full collection marks. Nothing in gc_bench's report says which startup it had, except the heap figures.

**What Happened**: Lane wr1's batch 5 froze P5's gc_bench with its gate's `MODE=gcb` (gc_bench alone, no snapshot copied) as tip-7652520f607. Batch 5 measured its R4c pause ratios against P2 with it, and batch 6 compared P6 with it. P6 then looked 0.3-0.55 ms slower in full-GC p95 on pause, div and text, benches with no holders in them, and ran 20% more instructions. The batch escalated with the cause unknown. Measured again, five rounds rotated, with every side's startup checked:
- P5 without the snapshot (tip-7652520f607): Engine heap 4.5 MB used, against 6.4 MB on P6. div used 6,156 M instructions, P6 7,388 M. Pause/div/text max/p95: 1951/1518, 3457/3018, 2906/2681 us.
- P5 WITH its snapshot (the same commit frozen with its runner, tip-m7652): 7,378 M instructions on div. 2278/1788, 3902/3649, 3298/3175 us.
- P6: 2344/1840, 4051/3697, 3554/3169 us. Equal to P5 with its snapshot.
So P6 had no pause cost to find. Batch 5's published R4c ratios had been flattered the same way: with the snapshot, P5's div p95 is 1.38x P2's, not 1.15x.

**Fix**:
1. Freeze every side of a gc_bench comparison with the snapshot its build made, beside the binary.
2. Make the measuring script check it and print it for each side: "check: tip-X has a snapshot" or "has NO snapshot" (tmp/plans/wr1-scripts/b6/gcbcmp.sh).
3. Read the instruction count first. A whole-process instruction gap of 20% between sides that differ by a few lines of tracing is a sign of a different process, not of the change.

**Takeaway**: **Before reading a benchmark gap as the change's cost, check that every side started the same way: a missing snapshot beside the binary is a smaller heap and a different measurement, and only the instruction count gives it away.**
