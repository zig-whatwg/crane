# Testing: Equal browser pass counts can hide opposite behaviour

**Date**: 2026-10-18
**Lesson**: Compare the same subtest in each browser before applying a browser majority.

**Why**: A file's passing total does not identify which behavior a browser implements. Equal totals can come from different failures.

**What Happened**: `workers/interfaces/WorkerUtils/importScripts/blob-url.worker.html` passed 2/3 in Chrome, 2/3 in Firefox and 3/3 in Safari in the aligned stable WPT run `23b0b89b1a`. The totals suggested Chrome and Firefox both rejected a blob URL revoked by an earlier imported script. The actual results showed Firefox and Safari both preserved that URL's previously captured blob entry. Firefox's separate failure concerned the exception type for a URL revoked before `importScripts()` began.

**Fix**: Retrieve the aligned run IDs, then inspect each browser's per-subtest result and failure message. For this case, preserve the URL record's blob entry according to the Firefox/Safari majority; treat Firefox's SyntaxError versus NetworkError discrepancy separately. Record the engine source or standards discussion that explains each split.

**Takeaway**: **A browser majority is about the same observable behavior, never matching file totals.**
