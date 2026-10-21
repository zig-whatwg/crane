# Testing: Missing browser results may mean a test was replaced

**Date**: 2026-10-21
**Lesson**: Pin the browser run and exact test identity before classifying an absent result or a shared failure; renamed tests can also change the assertion.

**Why**: A gate-exemption audit needs evidence about the behavior the worklist actually tests. No result is not a failure, a setup pass is not a feature pass, and a passing successor is not a passing original test.

**What Happened**: Row 106 audited generation 171's 338 blockers against aligned stable Chrome, Firefox and Safari runs at WPT revision `0f26972422b15f587e2afbd38dbb6ea2397fded0`. Two WebAssembly URLs were absent. [WPT PR 63102](https://github.com/web-platform-tests/wpt/pull/63102), merged on 2026-10-09, explained both:

- `cross-origin-module-sharing-fails.html` became `window-cross-site-failure.html`, with corrected origins and an extra sandbox case.
- `share-module-cross-origin-fails.sub.html` was replaced by `window-same-site-success.sub.html`. The replacement expects sharing to succeed within the same agent cluster, reversing the old assertion.

Older aligned stable runs at `cc74d2669f5de548e808779877d1d33339ec5115` still contained the original files: Chrome passed them, while Firefox and Safari timed out. Neither absence from the newer run nor the successors' results established three-browser rejection of a newer specification. The original Crane files stayed blocking pending an owner-reviewed WPT update.

The same audit found two files whose only browser pass was setup: CSP sandbox autoplay and service-worker request-body cancellation. Their tested behavior failed in every browser, for different reasons. An aggregate nonzero pass count would have hidden that distinction.

**Fix**:

1. Record aligned run IDs, revision, browser versions and dates. Query those IDs explicitly.
2. Match source files to the exact generated URLs and query variants actually run by Crane. In object-storage report URLs, encode `?` as `%3F` because the variant is part of the object name.
3. Read individual statuses and failure messages. Require a pass of the failed assertion, or a complete relevant test pass; label setup-only passes separately.
4. For an absent path, read test history. Keep older exact-path evidence dated separately from current successor evidence. Never silently substitute a replacement with different assertions.
5. Evaluate intent independently. A timeout, obsolete expectation, missing capability or test typo cannot supply the three explicit browser decisions the exemption rule requires.

**Takeaway**: **Test identity, observed behavior and implementer intent are three separate pieces of evidence. Keep all three explicit.**
