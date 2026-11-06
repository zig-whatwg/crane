# Debugging: Attribute retained DOM memory with a forced GC and the allocator's view

**Date**: 2026-11-06
**Lesson**: "The page keeps all its memory" covered three separate mechanisms. Four readings per workload tell them apart:
- live instances against live wrappers;
- the same run with a forced full collection;
- vmmap's malloc regions after that collection;
- the allocation sites of what is still live.

**Why**: A footprint that stays at its peak looks like a leak whatever its cause. Each cause leaves a different signature. Garbage the engine has not collected disappears under `--gc`. Garbage the host queued but has not freed has instances but no wrappers. Memory freed to Crane's own allocators stays in the footprint even after a collection, so the allocators themselves have to be read.

**What Happened**: Perf round 0's DOM pages kept their peak as their steady footprint: innerhtml 3.6 GB, parser 1.9 GB, tree 1.6 GB. Lane perf1 ran gc_bench (release build, `--c-alloc`) with each workload's statement at the page's op count, plain, `--gc` and `--loop`. It also ran the real pages in the release console behind a scratch server that ran vmmap at each `settled` mark, then `TestUtils.gc()` twice from the console's stdin. The readings separated three things:
- **Not collected.** Clone, build-tree, createElement and the parser workloads kept hundreds of thousands of instances with live wrappers, and dropped to about 10 under `--gc`. V8's heap stayed at 5-7 MB, so V8 never collected.
- **Queued, not freed.** innerHTML-set kept 1,392,020 instances with 9 wrappers. That is the deferred teardown queue under a bound that weighed each tree as 64 nodes.
- **Freed, but not returned.** After the forced collection the tree page's Malloc Small fell 327 -> 198 MB. Its Malloc Large, the state arena's 27 chunks, stayed at 1.3 GB, because std.heap.ArenaAllocator never returns a chunk. `gc_bench --profile` plus atos named it: arena createRaw held 1.47 GB, and NodeBase allocations were 472 B each.

**Fix**: For this kind of question, use the scratch tools in tmp/plans/perf0-scripts and the perf1 handoff:
- gc_bench bodies per workload, run plain, `--gc` and `--loop`, with `--profile` for allocation sites (resolve the addresses with `atos -o gc_bench`);
- for the real page, the console behind a server that measures before it answers each mark.
Start that server and wait until its port answers before launching the console. A cold Python start took more than a second on the pool host, and the console's first navigation then failed with a curl 28 timeout and never ran the page.

**Takeaway**: **Compare instances with wrappers, then repeat with a forced collection, then read the allocator. Each pair of readings rules out one cause, and a footprint that does not fall when its objects die means an allocator is holding the peak.**
