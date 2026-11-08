# Testing: Account a kept object's bytes live, at two counts

**Date**: 2026-11-08
**Lesson**: A per-object memory breakdown by allocation site needs the process read LIVE, at two object counts, by three readers: `malloc_history -allBySize` (every live block by stack), `vmmap -summary` (resident bytes per region) and the engine's heap snapshot. gc_bench's own `bytes per element` (total RSS growth / cycles) is not a per-object figure.

**Why**: gc_bench frees everything before it exits, so nothing that runs at exit (`leaks --atExit`, a final memgraph) sees the kept objects. Its `bytes per element` divides the whole RSS growth by the cycle count. That includes one-off growth: V8's heap reaching its working size, the first arena and slab chunks, the first malloc regions and the wrapper-cache map's doublings. Without `--gc` it also includes uncollected garbage. And `malloc_history`'s allocated bytes count the arena's chunk tails, which nothing has touched and so are not resident.

**What Happened**: Lane perf2 batch 8 had to account for the "~600+ B outside the arena block" of a kept div, the input for the wrapper redesign. The brief's ~1,080 B was gc_bench's total/cycles: 1,063 B measured without `--gc` and 1,002 B with it. The per-object figure, taken live at 10,000 and 50,000 divs, is 865 B: the 464-B block plus 409 B outside it. Grouping malloc_history's stacks by their innermost three non-allocator frames put every row at exactly 1.000 block per div: the wrapper cache entry 96 B, WeakCallbackData 48, the armed-map node 48, the Global box 16. V8's NodeBlocks and the hash tables came out as fractional blocks per div. The arena showed 538 B allocated per div but 456 resident. The heap snapshot separated the V8 heap's share: the wrapper is 32 B, the tree-edge PropertyArray 20 B and a parent's children-Set entry 12.3 B.

**Fix** (scripts: tmp/plans/perf2-scripts/batch8/):
1. A TEMPORARY gc_bench build, never committed. `--snapshot=<path>` writes `engine.writeHeapSnapshot` with every kept object live; `--hold=<s>` then sleeps (libc `sleep`, after the report).
2. Per body and N in {10,000, 50,000}: run `MallocStackLogging=lite ./gc_bench N 10000 --c-alloc --gc --profile --snapshot=... --hold=900`. Wait for its `HOLD pid=` line, run `vmmap -summary`, `heap -s` and `malloc_history <pid> -allBySize`, then kill it and delete `/private/tmp/stack-logs.<pid>.*`.
3. Run the same N's again with no stack logging, for vmmap's resident split (stack logging wraps the malloc zone and skews its fragmentation).
4. Diff the two counts and divide by 40,000 (mh.py, vm.py, hs.py). Drop the rows the readers make themselves: HeapObjectsMap (the snapshot's own map) and gc_bench's `CountingAllocator.track` (`--profile`'s map).
5. Use a control body (`{}` in an array) and an unwrapped one (`insertAdjacentHTML`) to split the JS slot from the wrapper from the node.

**Takeaway**: **A kept object's bytes are a difference between two live readings, not total growth over cycles: hold the process, read malloc_history, vmmap and the heap snapshot at two counts, and take resident bytes over allocated ones.**
