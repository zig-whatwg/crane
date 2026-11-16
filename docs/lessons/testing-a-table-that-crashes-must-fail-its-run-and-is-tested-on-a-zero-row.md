# Testing: A table that crashes must fail its run - and is tested on a row whose base is zero before the window

**Date**: 2026-11-16
**Lesson**: A measurement script that prints its summary table and then "rc=0" tells nothing about the table: a summary step that crashed halfway left a run that looked complete.

**Why**: A window script runs the measurement and then a summary program. Its last line reports the script's status, and the script does not look at the summary's. A reader sees rows, a traceback further up, and `rc=0`.

**What Happened**: Lane mem2's timed window on server1 (2026-11-16, 345 launches, 26 minutes of an emptied host) ended `rc=0`. Its cost table had stopped after 27 of 51 rows with `ZeroDivisionError`: `overhead.empty` has a median sample of 0 ms, and the table divided by the base's median. The table had been tested earlier that night, on two pages that have no such row. The missing rows included the streams rows and the suite's geometric means. The launches were intact, so the table was rebuilt from them; a window whose launches are not kept would have been lost.

**Fix**:
1. The script checks the summary's status and ends non-zero with a line that says the table is incomplete; test that path once with an input that makes the summary fail.
2. Test a ratio table on a row whose base is 0 and on a row that is missing in one arm, not only on ordinary rows.
3. Keep every launch's record, so that a summary can be run again without the host.
4. Compare the number of rows printed with the number expected before reading any of them.

**Takeaway**: **A run's status must include its summary's: make a failed table fail the script, test the table on a zero and on a missing row, and keep the raw records so the table can be rebuilt.**
