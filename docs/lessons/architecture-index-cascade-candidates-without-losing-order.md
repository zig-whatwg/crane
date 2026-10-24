# Architecture: Index a Cascade's Candidates Without Losing Their Order

**Date**: 2026-10-23
**Lesson**: A per-property fallback chain can reuse globally sorted candidate positions while preserving rollback and logical-property precedence.

**Why**: Scanning every matched declaration for every longhand makes work grow with the number of supported properties, even when a page declares only a few of them. Enlarging each candidate with provenance also enlarges those repeated reads.

**What Happened**: The CSS values lane added many longhands and had to preserve origin, importance, layer, shadow-tree scope, specificity and source order. Taking only each property's strongest declaration would break `revert` and `revert-layer`; indexing logical declarations before `writing-mode` and `direction` compute would choose the wrong physical property.

**Fix**: Keep the existing candidate sort and 32-byte candidate representation. Prepend candidate positions in reverse order into separate property chains, retaining every fallback. Compute the two mapping properties, then merge each logical chain into its physical chain using the original sorted positions. An empty chain selects the inherited or initial value without a candidate scan. Use a small stack link buffer with an allocator-backed fallback and test both paths, including allocation failures.

**Takeaway**: **Index the existing order, retain the fallback history, and delay mappings until their inputs have computed.**
