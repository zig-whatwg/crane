# Testing: Drive the storage path in a lifetime regression

**Date**: 2026-10-23
**Lesson**: A lifetime test must make its intervening calls reach the allocation or serialization path whose storage it intends to reuse.

**Why**: An invalid input may return before that path. Repeating such a call can exercise validation and leave the temporary buffer untouched, so a dangling reference can retain convincing contents until the final assertion.

**What Happened**: An image cache-hit regression queued a task, dropped the image's script reference, made 32 other image calls, forced garbage collection and checked the target URL and completion. The intervening calls used malformed URLs. Those inputs could fail in parsing before the successful URL serializer reused the stack-fallback storage. The test's storage-reuse claim was stronger than its stimulus. Both frozen binaries pass the strengthened three-case fixture.

**Fix**: Prime a different cached URL with the same serialized length as the target, then use it in the intervening calls and assert that each call completes synchronously. This exercises successful parsing, serialization and cache-hit handling while avoiding additional network requests. Cover both a short URL and a URL long enough to require allocator fallback. Keep the target identity, URL, completion, task and resource-timing assertions and both garbage collections. Keep the separate base-URL mutation case unchanged. Hash the strengthened fixture and run it on both the previous and changed binaries; a receipt for the earlier fixture does not cover the new stimulus.

**Takeaway**: **Drive the same storage path before checking retained data.**
