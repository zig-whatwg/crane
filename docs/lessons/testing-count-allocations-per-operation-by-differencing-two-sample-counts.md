# Testing: Count allocations per operation by differencing two sample counts, with a counting allocator that walks frame pointers

**Date**: 2026-11-22
**Lesson**: To know what one DOM operation allocates, run the same perf_bench workload in two console launches that differ only in their sample count (10 and 30 samples, warmup 3), each under a counting `std.mem.Allocator` wrapper; the difference divided by 20 x ops is the per-operation count with page load, setup and teardown cancelled out.

**Why**: A single run's totals mix the page load, the workload's setup (a 3,000-element document for the query rows) and the samples, and a per-workload page still loads the harness. Subtracting a baseline page does not cancel setup; subtracting two runs of the same page does.

**What Happened**: Lane alloc1 (allocator-hardening design) needed allocations per operation, by size class, alignment and thread, for the state arena, the slab and the host allocator, to turn a prototype's ns-per-allocation into an expected cost per workload. The scratch census (.claude/worktrees/alloc1 tools/repl.zig `AllocCensus`, never merged; copy in tmp/plans/alloc1-evidence/) wraps the console's allocator, hooks the arena's createRaw/destroyRaw and the slab, keys each allocation site by `ret_addr` plus three return addresses read up the frame-pointer chain (aarch64 Darwin keeps frame records), and writes counts to a file named by pid. One page per workload was generated from each suite page (`self.__censusOnly` filters `perf.add`; the other `perf.add('<name>'` calls are rewritten to a no-op `perf.skip(` because perf_bench rejects a page that declares a workload its suite does not list, and rejects a workload listed twice). 99 launches took 4 minutes on chat.local. Result: dom.create-element = 3.00 host allocations + 1 arena block + 1 slab slot per call, exactly.

**Fix**:
1. A counting wrapper over the console's allocator (alloc/resize/remap/free forwarded with `rawAlloc` etc.), a mutex, per-class and per-thread counters, an open-addressing table of call stacks.
2. Stack keys: `ret_addr` and the return addresses above its frame, by reading `[fp, lr]` records from `@frameAddress()`, bounded (fp increasing, 16-aligned, under 8 MiB apart).
3. Symbolize offline: store addresses minus the image base (`_dyld_get_image_header(0)`), feed `atos -o repl -l 0x100000000`.
4. Two launches per workload at 10 and 30 samples; per-op = (it30 - it10) / (20 x ops), ops from the journal.
5. Read the census dir from a file in the console's working directory as well as the environment: perf_bench runs the console in its own directory.

**Takeaway**: **Per-operation allocation counts come from differencing two sample counts of the same page, not from one run or a baseline page; a frame-pointer walk names the call site for free.**
