# Testing: Compare WPT results through the manifest

**Date**: 2026-10-21
**Lesson**: Join browser results by the manifest's generated test URLs before comparing source files or directories.

**Why**: Crane's selection and journal count source paths. Browser and Lightpanda results count executed URLs, including window/worker variants and query parameters. Those counts measure different things, and suffix replacement does not recover the manifest's mapping.

**What Happened**: Row 114's frozen-main discovery selected 31,429 runnable sources from a manifest containing 31,977 sources and 39,096 URLs. The latest Lightpanda result contained 38,674 unique URLs. Exactly 38,660 mapped to the pinned manifest; 14 belonged to a different snapshot. The remaining 548 manifest sources were formats the frozen runner could not execute, not Crane test failures.

**Fix**: Keep the raw result downloads, timestamps and revision identities. Expand each manifest source to its actual URL entries, treating a null URL as the source URL. Join result records through that map, preserving query parameters and worker variants. Report missing and unsupported URLs separately. Within common URLs, compare exact subtest names and preserve repeated-name occurrences; a harness that stops early has not executed the same population. Retain per-engine denominators and coverage alongside directory totals. Check discovery against the sweep journal for missing and duplicate sources.

**Takeaway**: **A shared directory name is not a shared test population. Preserve source identity, URL identity and coverage before interpreting a pass-count difference.**
