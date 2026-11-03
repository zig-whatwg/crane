# Debugging: A small shared cell that grows moves to a size class the hot path churns

**Date**: 2026-11-03
**Lesson**: Moving a promise capability into the one-byte cell every copy of a streams Deferred shares cost `Response.text()` 23% more instructions. The handle counts were right and every test passed. Only the gc_bench pairs showed it.

**Why**: gc_bench's allocator, Zig's DebugAllocator, serves small allocations from per-size-class buckets and gives a bucket's pages back once every slot in it is freed. A one-byte cell shared a size class with almost nothing else, so its buckets stayed mapped. A 40-byte cell landed in a class the streams code allocates and frees in bursts on every read. Each Deferred then paid for bucket set-up, and the bucket pages were mapped and unmapped again and again.

**What Happened**: Lane leakcheck1 made a settled Deferred release its capability (3 global handles to 1). Its first form kept the capability in the shared cell, so a settle could clear it once for every copy. The window's gc_bench pairs read:
- `response-text`: +23.35% instructions, RSS -1.2%. `arrayBuffer()`: +17%.
- The streams rows that had motivated the change: -0.8% to -3%.
- Reproduced 3x with and without `--loop`. Linear in calls (about 120k instructions a call at 10k, 20k, 40k and 80k cycles), so not a scan over live objects.
- Two equal 5-second `sample` profiles: `DebugAllocator.alloc` 629 vs 374 and `__munmap` 531 vs 305, tip vs base.

**Fix**: Shrink the cell back to the one-byte `settled` flag and keep the capability in each copy, as before. The flag's meaning grows instead of the cell: settled now also means "the capability is released". `settle` sets it, settles, then releases. `resolve`, `reject` and `deinit` read it before touching the capability, so no copy releases it twice. After the fix: `response-text` -0.48% instructions and -2.0% RSS; the streams rows -0.6% to -2.5% instructions and -3.1% to -5.0% RSS.

**Takeaway**: **A per-object heap cell's size is part of its cost: keep a cell that copies share minimal (put meaning in its bits, not more fields), and measure any size change on a hot path with gc_bench pairs - a green test suite and correct handle counts will not show it.**
