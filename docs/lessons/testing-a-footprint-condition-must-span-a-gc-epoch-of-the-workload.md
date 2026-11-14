# Testing: A footprint condition must span at least one GC epoch of its workload

**Date**: 2026-11-10
**Lesson**: A "flat" or "grows" verdict over a run shorter than the interval between the engine's own full collections measures one rising edge of a sawtooth, not a trend.

**Why**: Memory that only a full collection frees - V8's CppHeapPointerTable entries, 8 B per wrapper (V8 13.1.203 src/sandbox/cppheap-pointer-table.cc SweepAndCompact, called only from a mark-compact) - climbs between collections and drops at each. A window with no full collection in it sees only the climb.

**What Happened**: Lane wr1 batch 8's churn probe dropped 2.08M wrappers (8 rounds of 260,000) and read 102 -> 128 MB on the tip against 96 -> 101 on the base: "not flat", and the batch stopped. Batch 9 ran gc_bench at length (`--loop`): V8 runs a full collection about every 4.2M drops (17 over 72M; the base 13), and the tip plateaus at 151-170 MB max RSS, never crashing, far short of the table's 67.1M-entry capacity. The probe had stopped before its first full collection.

**Fix**: Size a footprint run to cover several of the workload's own GC intervals - count `full_gc_count` during it - and compare plateaus (max RSS over the run, tip against base), not one edge.

**Takeaway**: **Before reading growth as a leak, count the engine's full collections in the window: a window with none measures one tooth of the sawtooth.**

**Status (2026-11-13, lane wr1 batch 11)**: the condition this lesson restated was met on V8 15.7 by its one-interval formula and was still not acceptable - 137 MiB against main's 82 on the user's own workload - and the integrator said so. A bound that proves "memory is bounded by the collector" does not say the bound is a good one: report the PEAK beside the formula, against the base's peak, and the number of full collections each side ran. With the dropped wrappers' table entries reported to V8 the same run peaks at 75.8 MiB with 14 full collections.
