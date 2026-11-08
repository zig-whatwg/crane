# Testing: A deep tree fixture costs nodes x depth to build - size the test by what crashed

**Date**: 2026-11-08
**Lesson**: Building a 100,000-deep tree by DOM insertion took over 4.5 minutes per test in the Debug unit tests, whatever the build order: each inserted node's insertion steps walk to the root, so a depth test must use the smallest depth that proves the point (one that crashed before the fix, on a pinned thread stack) and leave the extreme depth to a release-runner probe.

**Why**: The insert steps walk the new node's ancestors (mutation.isConnectedThroughShadow, shadow_dom_algorithms.rootOf, isHostIncludingInclusiveAncestor, hasInterestedObservers), and the "for each inclusive descendant" insertion steps do it per descendant - so inserting a chunk of s nodes at depth D costs about s x D. Chunking a build (500-level chunks appended to the previous chunk's leaf) only moves the cost: the total stays nodes x depth / 2. A sample of the stuck tests showed nearly all non-idle time in isConnectedThroughShadow.

**What Happened**: Lane crash1 batch 2's brief asked for teardown tests at 100,000 levels. The chunked build seemed to avoid the per-append ancestor walk, but each chunk's 500 descendants each walked 100,000 ancestors when linked; the tests ran past the launcher's 300 s per-test timeout and the job was killed. At 10,000 levels the seven tests take about 10 s of wall time, and the old recursive teardown crashed at that depth on the tests' pinned 8 MiB thread (3 to 4 KiB a level in Debug).

**Fix**: tests/html/crash1_deep_teardown_test.zig at 10,000 levels on a thread spawned with `.stack_size = 8 * 1024 * 1024`, so the red does not depend on the default thread stack; the 100,000-level checks run as release-runner probe pages. The insert cost is queued with its sample (feature-queue, the deep-construction perf item).

**Takeaway**: **Size a depth test by the depth that failed and pin the stack it failed on; a fixture whose build is quadratic in depth belongs in a release-runner probe, not in the unit suite.**
