# Testing: A cache's cost rows are its all-miss row and its smallest run, not its hit row

**Date**: 2026-11-11
**Lesson**: A cost suite for a new cache needs two rows the cache cannot win: every lookup missing, and the smallest unit of work that makes a cache at all. The hit row measures the saving; those two measure the price, and a cache that allocates its table per run can cost the smallest run more than it costs a large one.

**Why**: On a hit the cache's work (hash, probe, compare) is paid for by what it saves (an allocation and a free), so the row nets to zero and says nothing about either side. On a miss nothing is saved and the whole lookup shows. A cache owned by a short-lived run (a fragment parse) also pays a fixed cost per run - making and freeing its table - which a 300-element row divides by 300 and a one-element row does not.

**What Happened**: Lane nd2 batch 4 shares attribute blocks through a content-keyed cache per parser run. The brief asked for "a PARSE row"; a row of 100 repeated rows read 1.0005 against main, inside the noise. Two rows nobody asked for read otherwise: 300 elements with distinct sets 1.0100-1.0129 (+440 to +637 instructions an element), and `el.innerHTML = '<b class="x">hi</b>'` 1.0176, +1,246 instructions a parse - the cache's two table allocations and two frees for one element, on the commonest innerHTML there is. Scratch variants split the cost in a minute each: 25 parses of 12 distinct elements cost as much per element as one parse of 300 (so growth was not it), one attribute cost more than two and six cost less than main (so the cost was per element, not per attribute). The fix kept the run's first 16 slots inside the cache (no allocation under 13 distinct sets), grew x4, hashed the ids as integers, and declared the parser's conversion buffer without ReleaseSafe's fill: tiny fragment +302 (1.0043), all-miss 1.0023-1.0043.

Two reading traps on the way. perf_bench's instruction count is the whole process's, and V8 makes some runs of a 60,000-instruction row bimodal (+1,200 an op for a whole run, base and tip alike): a median of three can land on the high mode and invent a regression, so print the runs and compare low modes. And `sample` could not attribute a 1% difference spread over inlined code; the variants could.

**Fix**:
1. For a cache, add an all-miss row and a smallest-run row (one object, one lookup) beside the hit row, before the first measurement.
2. When a row rises, split it with variants that hold the total work fixed and change one dimension (objects per run, attributes per object, distinct fraction) - a minute each on two existing binaries.
3. A per-run cache starts with its table inline; the allocator is for the run that outgrows it.
4. Print each run of a row before trusting a median of three; compare like modes.

**Takeaway**: **Measure a cache where it cannot win - all misses, and a run of one - because the hit row hides its price; and give a per-run cache an inline first table so a run of one allocates nothing.**
