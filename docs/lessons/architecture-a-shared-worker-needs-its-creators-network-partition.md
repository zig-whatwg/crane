# Architecture: A shared worker needs its creator's network partition

**Date**: 2026-10-22
**Lesson**: Passing the Browser and storage partition to a worker does not also populate its network partition key.

**Why**: Fetch derives the HTTP cache partition from the client's top-level site. Missing that site deliberately bypasses the cache; it must never become a common unpartitioned cache.

**What Happened**: Classic SharedWorker WPT variants had been skipped. Enabling them exposed failed conditional requests, all fourteen only-if-cached assertions, and a resource timing cache-hit assertion. The worker already used its owner's Browser and storage key, but startup explicitly discarded the top-level site for shared workers. Every request therefore bypassed the Browser's HTTP cache.

**Fix**: Copy the creator's network site on the creator's thread for both dedicated and shared workers. Reuse the existing owned-copy transfer and cleanup chain. Keep unrelated Permissions origin policy separate. Test cache misses, hits, revalidation, and two top-level sites using the same worker URL and name: worker identity and cache entries must both stay partitioned. Chromium's `SharedWorkerHost::ComputeIsolationInfoForNetworkRequest` likewise derives isolation information from the worker's storage key.

**Takeaway**: **A worker needs every consumer's partition input; an absent key is not a shared key.**
