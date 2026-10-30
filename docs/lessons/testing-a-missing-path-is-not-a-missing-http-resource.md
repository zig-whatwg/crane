# Testing: A Missing Path Is Not a Missing HTTP Resource

**Date**: 2026-10-28
**Lesson**: Trace a requested resource through the server before diagnosing a missing dependency from the checkout.

**Why**: An HTTP URL need not name a file. Rewrites can serve another pinned source, and an obsolete script tag can be redundant with a present helper.

**What Happened**: The Typed OM focus requested `/resources/WebIDLParser.js`, which was absent from the pinned WPT tree. WPT's `tools/serve/serve.py` rewrites that URL to `resources/webidl2/lib/webidl2.js`. Three transform tests also requested an absent `comparisons.js`; their comparison functions were already supplied by `testhelper.js`, and the recorded shipping-browser runs passed. Neither filesystem observation alone established a test failure.

**Fix**: Follow the existing route and pin its implementation, target, headers and downstream inputs. Record a genuinely absent requested path separately and verify continued absence around the observations. Preserve the original source and report the actual HTTP, harness and named-subtest results. Do not restore a file, synthesize an error, or infer causation from a missing tag.

**Takeaway**: **A URL is a serving contract, and a missing path is evidence to investigate rather than a test verdict.**
