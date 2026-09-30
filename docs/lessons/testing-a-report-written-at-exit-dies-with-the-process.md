# Testing: A report written at exit dies with the process, and shards that share a name overwrite each other

**Date**: 2026-09-30
**Lesson**: A supervised sweep's wptreports held a fraction of what it ran: a child writes its report only when it finishes, so a crash or a stall kill erases every file it had finished, and the three shards of a chunk all wrote `wptreport-0.json` over each other.

**Why**: `runTests` builds the report in memory and writes it after the last file. The journal survives a crash because it is written per file; the report was not. Separately, `Options.reportPath` named a child's report after its start index, and every shard's worklist starts at index 0.

**What Happened**: packaging a sweep for wpt.fyi needs every result with its subtest names; the journal has only counts. Reading the frozen main-045122ef3 sweep for that: 30 chunks x 3 shards, and 17 wptreport files in total. Nothing had noticed, because every consumer until then (the progress page, the A/B) read the journal. An upload built from those reports would have silently omitted most of the corpus.

**Fix**: each file's results are appended, as JSON lines in one write, to `<journal stem>.wptreport.jsonl` as the file finishes - before its journal record, so a crash between the two leaves real results under the supervisor's CRASH record (result_reporter.ResultStream, Options.resultsStreamPath). A journalled child names its report after its journal (`wptreport-journal.shard1-0.json`). tools/wpt_upload_package.zig builds the upload from reports and streams, and gives the file a crash took wptrunner's CRASH/TIMEOUT result.

**Takeaway**: **An artifact written at exit is only as durable as the process. Anything a crash-surviving run must deliver is written per unit of work, like the journal - and before trusting any per-process output, count the files against the processes that should have written them.**
