# Architecture: A missing partition key is not a shared cache partition

**Date**: 2026-10-16
**Lesson**: When the caller has not captured a network partition key, bypass partitioned state instead of substituting the requesting origin or an empty key.

**Why**: The same frame origin can run under different top-level sites. Its origin cannot reconstruct the top-level site's partition. An empty placeholder would combine unrelated clients into one partition.

**What Happened**: Crane already carried each Browser's NetworkContext into Fetch, but requests had no captured top-level site. Adding preflight and authentication stores without that value would have enabled cross-partition reuse. The stores and copied request field could be implemented in this lane; capturing settings belonged to another owner.

**Fix**: Own both locked stores on the existing NetworkContext. Copy a supplied top-level site into each request and clone. Bypass lookup and insertion when the key is null. Verify ownership, explicit-key hits, distinct partitions and distinct NetworkContexts natively; keep browser reuse tests blocked on the settings capture instead of claiming a stand-in key is correct.

**Takeaway**: **An absent partition is missing information, not permission to share.**
