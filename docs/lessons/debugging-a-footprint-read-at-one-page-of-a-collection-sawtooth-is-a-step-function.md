# Debugging: A footprint read at one page of a collection sawtooth is a step function

**Date**: 2026-11-13
**Lesson**: Where memory rises page by page until a threshold collects it, a reading taken at a fixed page moves by a whole tooth when anything shifts the crossing by one page; before calling such a row a regression, print the footprint at every step and the quantity the threshold tests at every crossing.

**Why**: A threshold collection makes a sawtooth (testing-a-footprint-condition-must-span-a-gc-epoch-of-the-workload.md is the same shape seen as a trend; this is the same shape seen as a single reading). Its period is the threshold divided by the growth per page, so a change of a few tens of kilobytes per page - lighter wrappers, one more string - moves the page on which the threshold is crossed, and the reading at "the tenth page" lands a tooth higher or lower. The row then reports +5% or -5% for a change that left the mechanism, its cost and its average exactly where they were. The same change can move two pages in opposite directions.

**What Happened**: After lane wr1 made node wrappers lighter, the perf suite's load.app read 1.051 of main at its steady mark and load.news 1.035, and the navigation collection (one critical memory-pressure notice when V8's used heap and ArrayBuffer stores reach 16 MB after a main frame's navigation) was named as the place to fix: "count the DOM memory too". Lane v8up b8 logged the test's own figures at every navigation that owed it. On load.app the sum was 15.82 MB at page 5 - 0.18 MB short - and 19.61 MB at page 6, where it fired; on load.docs 15.46 MB at page 5. The footprint per step was 29 34 41 47 54 39 43 46 47 48 MB: the row reads the last number. Counting the DOM at the same threshold fired four to five times in ten pages (a lower threshold under another name: memory 0.845, time 1.029); counting it at a threshold that kept one notice in ten pages read the same as before. Nothing was changed in the engine; the proposal went to the reading.

**Fix**:
1. Log, at every point the threshold is tested, the tested quantity, the threshold and whether it fired; print the footprint at every step beside it. One run per variant is enough to see the teeth.
2. Say how far the nearest miss was from the threshold. A miss by 1% of the threshold is the whole explanation of a one-page shift.
3. Compare variants by notices sent, by peak and by a reading over the cycle - the median of the second half of the steps, as memory.page-growth reads - never by the footprint at one fixed page alone.
4. A variant that fires more often is a different cost ruling, not a correction: bring its time beside its memory.

**Takeaway**: **A row read at one page of a sawtooth measures the phase of the teeth. Print every step and the tested quantity before blaming the mechanism, and judge a threshold by how often it fires, what it costs and what the cycle averages - a reading that a 1% change can move by a tooth belongs to the instrument.**
