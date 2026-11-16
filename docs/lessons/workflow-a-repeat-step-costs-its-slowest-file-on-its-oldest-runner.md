# Workflow: A repeat step costs its slowest file on its oldest runner - read each side's journal for the file's status and duration before you multiply

**Date**: 2026-11-15
**Lesson**: A window step that repeats a few files on several runners takes `repeats x (the sum of the files' durations on that runner)` for each runner. A file that passes in half a second on the tip can be an ERROR at the harness limit on an older runner: 60 seconds for each of its variants, every repeat. The input checks of a dry run do not see this, because they check that the inputs exist, not how long they run.

**Why**: The files worth repeating in a crash window are the files the bug showed on, and those are often the files that recent merges changed most. On the tip they are fast and pass. On the base generation they may be the very files that were blocking: a harness ERROR or TIMEOUT that waits out the whole limit. A multi-variant file (`?1-2`, `?3-4`, ...) pays the limit once for each variant, and `--parallel` does not shorten one repeat when the variants of one file run one after another.

**What Happened**: Lane crash1's window repeated three files 20 times on four runners: generation 224, an older lane tip, main and the tip. The estimate for the step was a few minutes, taken from the tip. One of the three, html/cross-origin-opener-policy/iframe-popup-same-origin-allow-popups-to-same-origin-allow-popups.https.html, is ERROR on generation 224 (unblocked later by other lanes): five variants at 60 seconds each, 5 minutes a repeat, 100 minutes for that one side. The window had been granted for 80 minutes in all and other lanes waited on the host. The step was cancelled during its second repeat and run again on main's runner and the tip only, where the three files take 15 seconds a repeat; it then finished in 10 minutes. The generation's own journal already held the answer: the file's record reads `"status":"ERROR"` with `"duration_ms":299875`.

**Fix**:
1. Before a `--repeat=N` step, read each file's record in EACH side's journal (the generation's `full/journal.jsonl`, the lane's A/B journal): `status` and `duration_ms` (one record covers all of a file's variants). The step's time is N times that sum, for each side.
2. Drop a side on which a file is a known ERROR or TIMEOUT, or give that side its own shorter list. A side that cannot run the file to its end proves nothing about a crash in it anyway.
3. Put the measured per-side figure in the READY message, not the tip's figure times the number of sides.
4. Make the sides of such a step a parameter of the window script, so that one side can be dropped without editing the step.

**Takeaway**: **A repeat step's time is set by the slowest file on the oldest runner: read the file's status and duration in every side's journal before multiplying, and leave out a side on which the file only waits out the harness limit.**
