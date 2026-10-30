# Workflow: A sweep chunk names its result stream by its runner count

**Date**: 2026-10-30
**Lesson**: crane-measure's sweep writes `journal.shard<k>.wptreport.jsonl` for a chunk that ran several runners but `journal.wptreport.jsonl` for a chunk that got one; a name comparison that reads only the shard files silently drops whole chunks.

**Why**: Each chunk takes a fresh fair share of the runner pool. Under load a chunk can get a single runner, and the single-runner runner writes the unsharded file name.

**What Happened**: Lane rendering3's formal A/B (3,652 files) read the tip's streams with `chunks/*/journal.shard*.wptreport.jsonl`. Ten tip chunks had run with one runner, so 1,974 of 4,687 records were read and the comparison reported 41,458 "lost" PASS names, while the journals (which carry counts only) showed +1,342 passed. The base side, with a different share pattern, lost other chunks.

**Fix**: Concatenate `chunks/*/journal*.wptreport.jsonl` (both names) on the host, fetch the one file, and check its record count against the journal before comparing names.

**Takeaway**: **Before trusting a name-level A/B, check that each side's stream has as many records as its journal - a missing chunk looks exactly like a mass regression, or, worse, hides one.**
