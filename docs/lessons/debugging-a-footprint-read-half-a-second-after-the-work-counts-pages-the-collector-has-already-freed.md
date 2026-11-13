# Debugging: A footprint read half a second after the work counts pages the collector has already freed

**Date**: 2026-11-13
**Lesson**: V8 15.7 keeps the pages its collections free in a process-wide pool for 8 to 16 seconds, so a process footprint read sooner than that includes memory the heap no longer counts as committed; set the heap's committed size beside the footprint before calling the difference a collection that did not run.

**Why**: The collector's statistics (committed, used) say what the heap holds. The OS's footprint says what the process has not given back. Between the two sit allocators that keep freed memory for reuse. V8 15.7's is `MemoryPool` (`src/heap/memory-pool.cc`): heap pages, large pages up to 32 MB and the compiler's zone reservations, shared by every isolate of the process, released by a heartbeat task every `memory_pool_timeout` seconds (8 by default, so a page waits 8 to 16 s), at once on a memory-pressure notice, and never by an ordinary collection. V8 13.1 pooled only semispace pages and released them at every full collection. A benchmark whose mark is 0.5 s after the workload therefore reads the pool on 15.7 and not on 13.1.

**What Happened**: After the V8 13.1 -> 15.7 port the perf suite's steady memory (read 500 ms after each workload) was 1.455 of main on fetch.loopback-stream, about 1.3 on two more fetch rows and 1.04 on four streams rows. The brief named the cause as "the end mark falls before V8 15.7's collection". The trace showed the collections DID run: at those marks V8's heap was 23-37 MB committed while the footprint was about 100 MB, and 15-25 MB on the fetch page and about 170 MB on the streams page were pooled pages. Timed x7 with `--no-memory-pool`: steady memory 0.912 of the control (fetch.loopback-stream 1.484 -> 1.004 of main, the streams rows 1.04 -> 0.55), time 0.9996, instructions 1.0007. `--memory-pool-timeout=1` closed only the rows whose workloads outlast the heartbeat. A run with ten idle seconds after each workload showed V8 returning the same memory by itself.

**Fix**:
1. At the mark, read the heap's own statistics beside the footprint (the lane's measurement console dumps `HeapStatistics` and the per-space sizes on a signal). A footprint far above the committed size is an allocator's reserve, not uncollected garbage.
2. Name the reserve from the engine's source (the flags `memory_pool`, `memory_pool_timeout`, `max_large_page_pool_size`) and prove it with ONE arm that turns it off.
3. Read the row again after the reserve's own timeout before deciding anything. If the memory falls by itself, the question is where the mark is, not what the collector does.
4. Chrome ships the pool on at 8 s. A default no browser ships is the user's ruling: bring the timed table, with what the suite does not measure (worker churn, the other OS).

**Takeaway**: **A footprint is the heap plus every allocator's reserve. When a row's memory rises across an engine update, set the engine's committed size beside the footprint at the same mark first: a gap between them is a pool with a timeout, and no amount of collection scheduling moves it.**
