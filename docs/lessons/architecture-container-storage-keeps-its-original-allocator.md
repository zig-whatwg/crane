# Architecture: Container storage keeps its original allocator

**Date**: 2026-10-08
**Lesson**: An output allocator does not own temporary container storage returned by another owner.

**Why**: CookieJar.retrieve clones cookies and allocates its unmanaged result list using the jar's allocator. Header generation and CookieStore queries accept an independent output allocator. Their result uses that allocator; the intermediate list still belongs to the jar allocator.

**What Happened**: Both callers deinitialized the intermediate list with the output allocator. Earlier request paths happened to use the same allocator. Asynchronous module fetching used c_allocator while the Browser jar used DebugAllocator, exposing aborts in cookie-bearing module tests. A regression test using a testing.allocator jar and an arena output allocator reports one leaked list in each caller, without depending on a platform-specific wrong-free crash.

**Fix**: Deinitialize the retrieved list with jar.allocator. Keep each copied Cookie's own deinit and allocate the final header/query result using its requested output allocator. Test the two allocators independently, then replay the same original process prefix on baseline, faulty and corrected runners before attributing an observed abort.

**Takeaway**: **Track the allocator of every container separately from the allocator of the result it helps construct.**
