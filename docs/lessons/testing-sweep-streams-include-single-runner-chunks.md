# Testing: Sweep streams include single-runner chunks

**Date**: 2026-10-20
**Lesson**: Collect both unsharded and sharded WPT report streams when a sweep's runner share changes between chunks.

**Why**: crane-measure gives each chunk a fresh share. A chunk with one runner writes journal.wptreport.jsonl; chunks with several write journal.shardN.wptreport.jsonl. A shard-only glob silently omits the first kind.

**What Happened**: Both row 97 sweeps completed 2,655 paths and reported 441,897 subtests. Collecting only journal.shard*.wptreport.jsonl yielded 3,170 BASE URLs against 3,525 TIP URLs. BASE's first chunk had one runner, and its 355 URLs were in the unsharded stream.

**Fix**: For each completed chunk, collect its unsharded report if present, otherwise its shard reports. Verify complete URL sets and reported subtest totals before comparing named subtests. Iterate JSONL by actual newline boundaries; str.splitlines also splits Unicode line separators inside test strings.

**Takeaway**: **Equal file counts do not prove equal subtest evidence; verify complete report streams after collecting every chunk.**
