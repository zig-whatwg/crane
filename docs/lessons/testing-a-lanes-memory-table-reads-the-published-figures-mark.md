# Testing: A lane's memory table reads the published figure's mark, or names its own

**Date**: 2026-11-13
**Lesson**: `/performance/` compares a workload's STEADY footprint (`footprint_settled`, read 500 ms after the workload; the plateau for `memory.page-growth`, the slope for `memory.instances`). A lane's pair summary that reads `footprint_end` measures a different moment, and between two engines whose collectors run at different times the two marks disagree by tens of percent on single rows.

**Why**: The end mark is taken the instant the workload returns; the steady mark after teardown and the settle time. A collection that runs inside that half second moves one reading and not the other. On two rows V8 13.1 ran one there and V8 15.7 did not (lane v8up's residual rows R4 and R5: 15.7 collects the old generation at its preconfigured limits and leaves an idle isolate uncollected for 30 s).

**What Happened**: Lane v8up b7's merge table (`.v8up/perfsum-b7.py`, `footprint_end`) gave the V8 15.7 port memory 1.0337 of main 253917157d7, with `streams.reader` at 1.020 and `fetch.loopback-small` at 1.028. Perf round 7 measured the same two binaries the published way: 1.028 over the suite, but `streams.reader` 1.409 (the 13.1 console drops from 506 MB at its end mark to 366 MB steady; the 15.7 console stays at 516 MB at both) and `fetch.loopback-small` 1.324 (the 13.1 console's end mark is bimodal, 71 or 91 MB, by whether its collection had run: 91 was its median in the lane's window, 71 in round 6's and round 7's). So the published page shows two rows over 1.3 that the merge report's table carried at 1.03 and below. The lane had named both rows under causes it found with idle-time readings, so no cause was missed - the size was.

**Fix**:
1. A pair summary that will be judged against the published page computes the page's figure: `footprint_settled` where the row has it, else `footprint_end`; the second-half median of `series` for `memory.page-growth`; the slope of `series` for `memory.instances` (`tools/perf_bench/report.zig`, `Cell.memoryFigure`). `perf_bench report` on the pair's own journals prints exactly that (`crane` against `crane_base`).
2. A table that reads another mark says so in its header ("memory at the end mark"), and the merge report carries that phrase with the number.
3. Before a round's report calls a row new, look for the same row in the lane's table at the other mark.

**Takeaway**: **A memory number is a mark as well as a value: compute the published figure's mark in every table that will be compared with the published page, and name the mark wherever another one is read.**
