# Architecture: Cancelled reaction queues need stable element identities

**Date**: 2026-10-05

**Lesson**: A queued element identity must outlive cancellation, even when cancellation releases the element itself.

**Why**: HTML custom element reactions have both per-element reaction queues and element queues containing references to those queues. Nested callbacks can unload a realm while an outer queue still contains its elements. Crane's slab allocator can then reuse an element's address.

**What Happened**: The agent-owned queue design initially used the element pointer as its identity. Removing its pending reactions at realm teardown would leave an outer element-queue entry with that pointer. If another realm reused the address and enqueued work, the old entry could invoke the new element's reactions in the wrong position.

**Fix**: The agent allocates a stable record for each queued element. Queue entries reference the record. Realm cleanup cancels it, drops pending payloads, releases its root, and removes the element-to-record mapping. A reused address receives a different record. Cancelled records remain until all frames and backup invocations have finished. The allocator-backed test cancels a realm during invocation and immediately reuses the identity in another realm.

**Takeaway**: **Cancel ownership and identity separately: release dead objects promptly, but retire their queued identities only after every queue that can name them has finished.**
