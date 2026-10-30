# Testing: OOM Matrices Replay Unrelated Rows

**Date**: 2026-10-27
**Lesson**: Inject allocation failures separately for independent matrix rows, while keeping each row's complete operation and assertions together.

**Why**: `checkAllAllocationFailures` counts the allocations in its callback, then replays that callback with each allocation made to fail. When the callback loops over independent cases, a failure in a later case repeatedly pays for all earlier cases. The extra work grows with the square of the aggregate allocation count.

**What Happened**: The counter-style math test put 77 browser-probe rows inside one callback. A sample of the long-running test found every main-thread sample in the failure-index loop, repeatedly parsing rules, setting descriptors and capturing allocator stack traces. The run was stopped at its authorized 20-minute bound.

A separate measurement found 6,719 allocations and a 622 ms unlimited baseline. At failure indices 0, 1,679, 3,359, 5,039 and 6,718, median iterations took 0.028, 158.990, 314.807, 473.141 and 636.073 ms. Summing piecewise-linear interpolation over all indices projected 35.414 minutes for the failure loop alone.

After moving the matrix loop outside the allocation-failure callback, all 77 rows completed their exhaustive checks. The entire 50-case selection, including compilation, finished in 76.042 seconds with no crash or leak markers. One unrelated page-test expectation failed, so that selection was not wholly green. The measurement establishes test cost, not an engine performance improvement or a delivery gate.

**Fix**: Preserve the original input and measure before restructuring it. Pass one independent row to a concrete callback and run `checkAllAllocationFailures` for each row. Keep the row's parse-time and setter checks together, keep every assertion and use the same leak-checking allocator. The callback needs a concrete parameter type: the testing helper reflects its parameters and rejects `anytype`. Rerun the complete original selection, confirm every named case executes, and distinguish command time from per-case time.

**Takeaway**: **Keep allocation-failure coverage complete without replaying unrelated cases for every injected failure.**

Related: [allocation-failure sweep complexity](testing-an-allocation-per-element-makes-the-failure-sweep-quadratic.md), [test allocator cost](testing-the-test-allocator-costs-more-than-a-fast-native-operation.md), and [propagating injected errors](testing-allocator-walks-propagate-injected-errors.md).
