# Testing: A check that reads a list filtered for another reader cannot see what the filter dropped - hold it to an independent count

**Date**: 2026-11-17
**Lesson**: When one list feeds two readers and a filter is written for one of them, the other reader loses the filtered entries without an error; a check built on that reader then passes for exactly the things it never saw.

**Why**: The WPT runner keeps each file's results in one list (`WptReport.results`). Two things are written from it: the report for upload to wpt.fyi, and the result stream (`journal*.wptreport.jsonl`) that Crane's own tools read. Crane's own tests (`tests/wpt/crane/`) must not be uploaded, so `addResultWithExpected` returned early for them - before the list, not at the upload. The stream therefore had no line for any Crane test. Verify mode (`wpt_runner --repeat=10 --verify`) reads subtests from the stream only, so for a Crane test it compared nothing, found nothing that differed, and said STABLE.

**What Happened**: Lane flk2 ran verify mode on its new Crane test and the tally printed "0 subtests passed in every run" beside "OK 10": the test's one subtest had passed ten times and the tally had not seen it once. A subtest of a Crane test that passed nine times and failed the tenth would have read the same. The journal, written by another path, had the truth all along: each run's record carries the file's passed, failed, timed-out and not-run counts. Lane tl2 fixed both ends: the list keeps a Crane test's result and marks it (`TestResultJson.own`), and only the upload report and its summary leave marked results out; and the tally now holds every file to its journal counts as well, so counts that differ between runs are UNSTABLE whether or not a stream line names the subtest, and results the journals counted but the stream did not name are reported as such. The second net also covers a frozen runner from before the fix (`--repeat-with`).

**Fix**:
1. Put a filter where its reason is: at the reader it is for (the upload), not where the shared list is filled.
2. A check that says "nothing differed" must also say how much it compared. "0 subtests passed in every run" beside ten passing runs was the visible sign, and it was printed for weeks.
3. Where a second record of the same facts exists (here the journal's counts), hold the check to it: the two can only disagree when one of them is blind.
4. When adding a new kind of test, run the verifier on one that is made to flake, and see it fail.

**Takeaway**: **A verifier is only as wide as the list it reads: filter at the consumer, print what was compared, and cross-check against a count that took another path.**
