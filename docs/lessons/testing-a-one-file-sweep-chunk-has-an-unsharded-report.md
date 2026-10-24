# Testing: A one-file sweep chunk has an unsharded report

**Date**: 2026-10-23
**Lesson**: Assemble sweep subtest evidence from both sharded and unsharded chunk streams.

**Why**: The runner can use a single process for a small final chunk even when the sweep requested parallel execution. Its report filename then lacks the shard component.

**What Happened**: A 6,081-source sweep used 96 batches of at most 64 sources. The final batch contained one source with three variants. The source journal and raw log recorded all three passing subtests, but an aggregate built with `journal.shard*.wptreport.jsonl` omitted the chunk's `journal.wptreport.jsonl`. A name-and-occurrence comparison incorrectly reported three missing prior passes.

**Fix**: Read every raw chunk stream matching `journal*.wptreport.jsonl`, including both filename forms, and reject duplicate test URLs. Check the source journals and variant reports separately. Preserve the earlier aggregate and raw data; rebuild the analysis from those original streams. Include the actual emitted plain source URL when an encoded document's variant metadata produces a different manifest URL inventory. Reject unmapped fresh reports rather than silently omitting them.

**Takeaway**: **A complete source journal does not prove a complete subtest stream.**
