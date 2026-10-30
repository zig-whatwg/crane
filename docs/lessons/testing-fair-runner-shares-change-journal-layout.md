# Testing: Fair Runner Shares Change Journal Layout

**Date**: 2026-10-28
**Lesson**: Reconcile the journal streams that the runner actually produced, because its assigned parallelism may differ from the requested count.

**Why**: The shared runner pool can reduce a request for two runners to one. A supervised one-runner invocation writes `journal.wptreport.jsonl`; multiple runners write `journal.shard<N>.wptreport.jsonl`. Both contain the same kind of named-subtest records.

**What Happened**: The page-rule comparison requested two tokens for both endpoints. BASE received two and TIP received one. All fourteen files completed in both arms, but a local reconciler that selected only `journal.shard*.wptreport.jsonl` reported missing TIP subtests. The original logs showed the actual token shares; the plain journal stream was present and complete.

**Fix**: Read `journal*.wptreport.jsonl`, then enforce unique file records, reconcile every subtest status count with the file journal, and compare name multisets so duplicate names remain visible. Keep the original observations and logs. Fixing this reader required no new measurement or invented result. Crane-only cases still came from their actual per-case verbose logs because these public streams omit them.

**Takeaway**: **Requested parallelism is not evidence of journal layout. Discover the actual streams and verify their contents.**
