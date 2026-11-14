# Debugging: Two medians of a bimodal row compare coin flips; list every run

**Date**: 2026-11-13
**Lesson**: A memory row whose runs fall in two groups has a median that says only which group had four of the seven; before comparing two such medians, print every run of both sides.

**Why**: Whether a collection lands before a mark can be decided by a few kilobytes of allocation, so a row reads one of two values 20 MB apart. Seven runs then split 3:4 or 4:3 by chance, and the ratio of two medians is 0.86 or 1.17 with nothing changed. A table of medians hides it completely, and "the ranges overlap" does not reveal it either: both sides have the same two values.

**What Happened**: Three times in one batch (lane v8up b8).
1. I told the integrator streams.reader read 509.7 MB on my driver against 366 on perf_bench's - one of two plain runs; the other was 366.0. The claim was corrected an hour later.
2. In a timed x7 of five arms of one console, parser.dom-parser read 122 or 143 MB and parser.document-write 126 or 145 MB in every arm but one: the low mode in 3 of 7 control runs, 2 of 7 with V8's page pool off, 4 of 7 with a 1 s pool timeout. The medians made the 1 s timeout look like a 14% saving on those rows that turning the pool off entirely did not give - impossible on its face, and explained only by the runs.
3. The baseline itself: main's seven runs of fetch.loopback-small were 70.6 70.8 71.1 71.6 72.1 90.1 92.4, so the ratio against it compared the candidate with main's low mode.

**Fix**: Keep a per-run lister beside the summary tool (the lane's `runs-b8.py <steady|time|instr> <rows> name=journal ...`) and run it for every row a message is about to cite. Where a row is bimodal, report both modes and the count in each, compare mode with mode, and say that the arm's median is not evidence. If the row matters, set the collection trace of a low run beside a high run to find what lands or not before the mark, or propose a reading that does not depend on it (one taken after a requested collection).

**Takeaway**: **Before a comparison leaves your hands, read every run behind both numbers. A row with two modes has no median worth comparing: report the modes and their counts, and never let a table's ratio for such a row argue for or against a change.**
