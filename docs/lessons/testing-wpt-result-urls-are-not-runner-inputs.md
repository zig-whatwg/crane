# Testing: WPT Result URLs Are Not Runner Input Paths

**Date**: 2026-10-17
**Lesson**: Build a targeted runner list from WPT source paths, not by copying generated test URLs from a wptreport stream.

**Why**: A single `.any.js` source generates Window, worker and other test URLs. The report names those generated URLs, while Crane's command-line file loader needs the source file and expands its metadata itself.

**What Happened**: The scripting row copied eight `.any*.html` result URLs into a diagnostic list. They produced FileNotFound harness errors, although the corresponding `.any.js` sources existed. Treating those records as browser-engine failures would have inflated the baseline blocker count and made a corrected input list look like an engine improvement.

**Fix**: Map generated URLs back to their source, deduplicate the source list, and verify every path exists under the WPT root before running it. Preserve the initial log with an explicit input-error label, exclude those records from diagnosis, and rerun the same corrected source list on both frozen builds. Keep per-variant failure messages from the wptreport stream alongside source-file journal counts.

**Takeaway**: **Match the runner's input contract before comparing results; changing the test list is not a conformance gain.**
