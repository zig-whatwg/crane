# Testing: A median of seven runs picks one of two levels by one run, and a page's rows flip together

**Date**: 2026-11-13
**Lesson**: When a workload's memory reads one of two levels from run to run, the median of seven runs is whichever level four of them hit. Rows of the same page share the level, so the suite's geometric mean moves by a percent between two windows of the same two binaries.

**Why**: `/performance/` compares each row's median over the runs. A row with two levels has no middle: 4 runs high and 3 low publishes the high level, 3 and 4 the low one. A page's later workloads start from what its earlier ones left, so every row after the first one that split reads the same level in the same run, and each counts once in the geometric mean.

**What Happened**: Lane wr1's merge report gave the wrapper redesign steady memory 0.925 of main e7024f71f0b (perf pair x7, chat.local). Perf round 8 measured the same source against the same frozen binary in its own window, x7, and read 0.937. The whole difference is four rows of one page (`workloads/attributes.html`: `dom.event-ctor`, `dom.event-ctor-dict`, `dom.set-get-attribute`, `dom.class-list`). The new build read 130 and 150 MB on them in runs 0, 2 and 3, and 149 and 170 MB in runs 1, 4, 5 and 6; round 7's binary read 155 and 175 MB in all seven. So the medians were the high level, 0.96-0.97 of the control. Lane wr1's window had read the low level (`dom.event-ctor` 130.2 MB, 0.84), which one more low run here would have published too: four rows x ln(0.84 / 0.965) / 47 rows = -1.2%, which is 0.937 against 0.926. The two levels are 20 MB apart and have a cause (lane wrap1's measurement the same day): the two Event workloads each make and drop 650,000 Events, a dropped wrapper of an object that is not a node leaves 32 B until the next full collection, and 650,000 x 32 B = 20.8 MB. The level is whether a full collection lands inside the page. The same check answered a second question: a neighbouring lane's two-second `du` ran on the host inside the window, the run it touched read the low level, and two other runs nowhere near it read the same level, so the `du` was not the cause.

**Fix**:
1. When a row's ratio differs between two windows of the same binaries, print the row's value per run before explaining it. Seven values in two tight groups is two levels, not noise and not a build difference.
2. Report such a row as its two levels and their counts ("0.84-0.86 in 3 runs of 7, 0.96-0.98 in 4"), and say which one the median shows.
3. Count how many rows of the page share the split before sizing its effect on a suite mean: they move together.
4. A level that is a whole number of megabytes apart has a count behind it. Divide the gap by the workload's operations: 20.8 MB / 650,000 = 32 B named the object.

**Takeaway**: **A median over an odd number of runs turns a two-level row into one level by a single run: print the runs, report both levels with their counts, and treat a page's rows as one vote.**
