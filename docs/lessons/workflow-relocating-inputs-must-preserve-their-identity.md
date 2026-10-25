# Workflow: Relocating inputs must preserve their identity

**Date**: 2026-10-25
**Lesson**: When an operational file relocates immutable inputs, compare every non-location field with a separately pinned template.

**Why**: A file's hash proves nothing about its approved identity when the same editable configuration supplies both its path and its expected hash. A content check can pass while validating a different input.

**What Happened**: Row119's prepared d2 measurement guard allowed a local-to-chat binding to name the cost manifest and carry-forward fixture list. It verified each file against a hash from that binding but did not require those hashes to match the immutable template. An independent local review substituted an already-pinned font fixture for the cost stylesheet support input, and separately changed a carry-forward fixture. Both guard-only negative controls passed. No d2 measurement had run. The cost provenance path also needed its own immutable digest check.

**Fix**: Allow only the seven explicit absolute location fields to differ; require the exact key set and every other value to match the immutable template. Check relocated provenance against the pinned payload hash, then reconcile its rows with the frozen files. Exercise unchanged real inputs as the positive control and changed hash/provenance inputs as negative controls before issuing any runtime release. Keep the original packets and the review evidence.

**Takeaway**: **Paths may move; approved identities must come from immutable evidence, not from the file that supplies the new paths.**
