# Testing: Check benchmark noise with identical binaries

**Date**: 2026-10-13
**Lesson**: Before attributing a noisy timing difference to code, measure the same binary against itself and aggregate fresh processes.

**Why**: More work in one process reduces startup cost but can expose nonlinear runtime behavior. A long sample is not automatically a more reliable sample. A same-binary comparison separates measurement variation from a source change without guessing at the allocator, GC or scheduler responsible.

**What Happened**: Row 29's original seven paired createElement samples had separate medians 0.75 and 0.80 seconds, but a paired-ratio median of zero. Tenfold workloads brought createElement within 3%, yet innerHTML's separate medians moved 10.23 to 15.24 seconds. Seven long innerHTML A/A pairs using the exact frozen BASE then differed by 8.8%; one pair was 10.06 versus 16.30 seconds. That result established large benchmark variation, not that the candidate was safe. gc_bench already forces GC at a fixed 5,000-cycle cadence; changing the printed sample interval did not change it.

**Fix**: Preserve all original samples and hashes. Use the row-23 Q11 control protocol: ten fresh processes for each side of each of seven alternating rounds, take each round's median, and compare both the separate medians and the median paired ratio. Keep the workload, executable mode, snapshot and working directory matched. A candidate still needs to meet its cost bar; an A/A failure alone does not waive it. If a stable difference persists, bisect and profile within the diagnosis time limit.

**Takeaway**: **Measure the benchmark's variation before explaining a slowdown, and never discard the data that triggered the investigation.**
