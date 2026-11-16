# Debugging: A memory excess on one host with equal collection counts is the allocator's - run the same binary with the allocator's own switches before changing the engine

**Date**: 2026-11-15
**Status** (2026-11-16, lane mem2): which glibc mechanism it is, is now measured - both, together: the moving thresholds leave free space at the top of every heap and the per-thread arenas multiply it (attributes page: 20.2 MB of free tops against a 19.0 MB resident gap). And the setting that removes it is NOT a fix: fixed low thresholds cost `fetch.loopback-stream` x1.47, because that free top is what serves large requests. No threshold pair passed; nothing landed. Lesson architecture-a-low-glibc-trim-threshold-returns-the-heaps-top-and-maps-every-large-buffer-afresh.md.
**Lesson**: When a make-and-drop row is over the bar on Linux and at or under it on macOS, and the collector ran the same collections on both, the bytes are free memory the C library has not given back. Prove it with the same frozen binary and an environment variable, not with an engine change.

**Why**: Crane's production build uses libc malloc. glibc keeps freed memory resident by rules of its own (per-thread arenas, a trim threshold and an mmap threshold that it raises by itself while the process runs); macOS's allocator follows other rules. A change that makes the engine free memory in different batches - here, 6 full collections instead of 1 - changes what glibc keeps without changing what the engine holds.

**What Happened**: Lane wrap1's batch 3, 650,000 dropped Events (2026-11-15): chat.local the lane 88.5 MB against main 87.3 (+1.4%); server1 99.1 against 87.5 (+13%), back to back. Zig-side bytes at the end were equal on both sides (59.8 against 60.4 MB) and V8's committed heap was equal; the excess was in neither. The same frozen binaries on server1 with `MALLOC_TRIM_THRESHOLD_=131072 MALLOC_MMAP_THRESHOLD_=131072`: main 87.1, the lane 87.8 (+0.8%). With `MALLOC_ARENA_MAX=1`: 86.0 and 91.2. So a glibc setting alone removes most or all of it. WHICH glibc mechanism it is was not established, and the report said so after first naming one too confidently. The row had been open for a day as an engine question.

**Fix**:
1. Split the row first: resident growth, Zig-side bytes (gc_bench prints them), V8 used and committed, C++ heap used, collection counts - for both sides on both hosts (lane wrap1's `.wrap1/split.sh` reads them from gc_bench's log).
2. If the engine's own numbers are equal and one host is over: run the SAME binaries with the allocator's switches (glibc: `MALLOC_TRIM_THRESHOLD_`, `MALLOC_MMAP_THRESHOLD_`, `MALLOC_ARENA_MAX`). It takes minutes and no build.
3. Report what was measured (a setting removes the excess) apart from what is inferred (which mechanism). The fix belongs to the platform's allocator setup, not to the lane that tripped over it.

**Takeaway**: **Equal engine bytes and equal collection counts with unequal resident memory means the allocator is holding free memory. Change one environment variable before you change a line of the engine.**
