# Testing: A slope over a series that levels off reads a later knee as more growth

**Date**: 2026-11-08
**Lesson**: A least-squares slope over a footprint series that rises and then levels off measures when the series levels off as much as how much it grows, so a build that is lower at every step but levels off later reads as growing faster.

**Why**: perf_bench compared `memory.page-growth` (30 documents in one tab) by the slope of the footprint over all 30 steps. The footprint rises while no collection runs, then levels off once the collector frees the pages left behind. A least-squares line through a step-shaped series is steeper the later the step: the flat points before and after weigh against each other only when they are balanced. A tip that keeps less per page is collected later (V8 schedules DOM-driven collections by the reported native bytes, so it sees the pressure later), rises more gently and reaches its level a few pages later - a steeper line.

**What Happened**: Lane perf2 batch 6's Crane-only perf pair read page-growth "steady" 1.175 against its base, and batch 3's 1.128 before it; batch 7 was asked to find which allocations stayed. None did. Per run (7 each), the tip's footprint was below the base's at every one of the 30 steps (median series 0.4 to 5.7 MB lower; end 64.4 against 65.9 MB; peak lower in every run). Both levelled off - the base by step 9, the tip by step 11 - and their slopes over steps 15-29 were 12 and 13 KB per page, flat. The first nine steps showed the cause: the tip rose about 1.08 MB less per page, which is what its smaller nodes save on a page of ~2,000 elements and ~1,400 text nodes, until the first collection.

**Fix**: Read the series before the ratio. Per run: the footprint at a few steps, where it levels off (the knee), the level (median of the second half) and the slope of the second half. perf_bench now compares page-growth by the level, every round recomputed the same way from its journals' series (a record without one is not measured), and shows the second half's slope beside it as what each further page keeps.

**Takeaway**: **A slope over a series that levels off is not a growth rate: look at the series, compare the level, and take the slope only over the part that is still climbing - or over the part after the knee, to see what is kept.**
