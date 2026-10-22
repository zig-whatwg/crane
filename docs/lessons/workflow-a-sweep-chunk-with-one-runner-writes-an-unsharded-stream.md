# Workflow: A sweep chunk with one runner writes an unsharded stream

**Date**: 2026-10-21
**Lesson**: Collect both serial and parallel result streams when a sweep can receive a different runner share for each chunk.

**Why**: `crane-measure.sh sweep` asks for a share of the runner pool at each chunk. Even a sweep requesting four runners can receive one. The parallel runner writes `journal.shard<N>.wptreport.jsonl`; the serial runner writes `journal.wptreport.jsonl`.

**What Happened**: Row 105's BASE sweep journal recorded 2,626 files and 387,358 passing subtests. Concatenating only `chunks/*/journal.shard*.wptreport.jsonl` recovered 387,232 named passes. The missing 126 passes belonged to the final XHR chunk, which had received one runner token. Its file counts were present, but its 35 generated test variants were absent from the collected stream.

**Fix**: Include both filenames, as `chunks/*/journal*.wptreport.jsonl` does for the current runner. The complete stream then contained 3,655 variants and exactly 387,358 passing subtests, with no duplicate test variants. Keep the original chunk streams, and check their aggregate against the file journal before using it for a subtest-loss audit or publishing file detail pages.

**Takeaway**: **A complete file journal does not prove the accompanying subtest stream is complete. Reconcile the passing counts, and check duplicate variants.**
