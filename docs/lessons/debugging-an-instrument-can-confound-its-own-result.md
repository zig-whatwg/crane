# Debugging: An instrument can confound its own result

**Date**: 2026-09-21
**Lesson**: `gc_bench` forced a GC once per batch, and the batch *was* the sample interval.

**What Happened**: Asking for fewer report rows meant asking for fewer
collections. The same build doing the same work reported 756 B/element at
`300000 200000` and 476 at `300000 25000` — a 1.6x spread that was pure print
frequency. Two figures minutes apart looked like a regression and were an
artefact.

**Fix**: Batch pinned at 5,000 cycles, sampling independent of it. Verified by
two granularities agreeing to the byte.

**Takeaway**: **Keep the perturbation independent of the reporting cadence, and
prefer a slope between adjacent samples over any per-unit average.**
