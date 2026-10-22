# Testing: Fair-Share Sweeps Can Have Unsharded Result Streams

**Date**: 2026-10-21
**Lesson**: Collect both journal.wptreport.jsonl and journal.shard*.wptreport.jsonl from sweep chunks.

**Why**: crane-measure may reduce a requested four-runner chunk to one runner. That chunk writes an unsharded result stream, while other chunks in the same sweep write shard streams.

**What Happened**: Collecting only journal.shard*.wptreport.jsonl from a 9,950-file BASE sweep omitted 189 files' passing subtests. The aggregate journal reported 1,671,206 passes, but the collected detail stream had 1,665,335. A count audit traced every difference to unsharded chunks.

**Fix**: Collect chunks/*/journal*.wptreport.jsonl. Map each result URL through the WPT manifest to its source file, then compare summed passing subtests with every aggregate-journal record. The corrected stream had 13,425 unique URLs, no duplicates, and zero per-file count differences.

**Takeaway**: **A sweep's requested parallelism does not determine every chunk's result filename; verify detailed counts against the journal.**
