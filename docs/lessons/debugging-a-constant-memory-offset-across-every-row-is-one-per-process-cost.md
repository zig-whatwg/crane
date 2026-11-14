# Debugging: A constant memory offset across every row is one per-process cost

**Date**: 2026-11-13
**Lesson**: When two builds differ by a fraction of a megabyte on almost every row of a suite, there is one per-process cause; list the difference for every row to see it, build the base in your own mirror to split build from code, then revert one commit at a time.

**Why**: A table of ratios against a 3% bar shows the rows that cross it and hides a cost that is the same everywhere: half a megabyte is 2% of an idle page and 0.3% of a large one, so no row is flagged and the suite mean moves by a percent that looks like noise. Read as megabytes, row by row, the same number appears thirty times. And two consoles built in two places are not the same binary on macOS, so the base built elsewhere cannot tell whether your code or your build made the difference.

**What Happened**: Lane v8up b8's final pair read steady memory 1.018 of main with six rows over the bar, each with a cause of its own (a two-valued reading, a sawtooth). Listing my console minus main's for all 51 rows showed 34 of them between +0.2 and +0.9 MB: idle page 24.1 against 23.9 MB. A memory-map of both processes on the empty page put it in malloc's small zone (touched pages, +0.36 MB) with the same live blocks (9,733 against 9,732) and the same V8 heap. Main's commit built in my own mirror read 24.03 MB against 23.92 for the round's build of the same commit and 24.30 for my tip: 0.1 MB was the build, the rest my code. Two more builds, each with one fix reverted, named the commit: without the async-iterator fix 24.00 MB, without the Intl fix 24.24, with both 24.34. Thirty navigations in one tab showed the three consoles on the same curve, so the cost is paid once per process, not per realm.

**Fix**:
1. For a pair of builds, print `mine - base` in megabytes for every row, sorted. A cluster at one value is a fixed cost; a spread is per-object or per-row.
2. Take a region summary of both processes on a page that does nothing (`vmmap --summary`, `heap -s` on macOS): which region, and whether live blocks differ or only touched pages.
3. Build the base commit in YOUR mirror and read the same page: that reading minus the published base's is the build; yours minus that reading is your code.
4. Revert one commit at a time (a reverse patch applied for the build only) and read again. Seven runs of an empty page take a minute.
5. Decide once per process or per object with a page that repeats the unit (navigations for a realm, a loop for an object): the two curves diverge or they do not.
6. Give each reading its own output directory: a script that starts by deleting a fixed directory destroys the run before it when two are launched close together.

**Takeaway**: **Ratios against a bar cannot show a cost that is the same on every row. Subtract in megabytes across all rows, split build from code by building the base yourself, and bisect by reverting - before the report says "within noise".**
