# Testing: An exclusion pattern is a substring rule over the whole path

**Date**: 2026-09-22
**Lesson**: `config.isExcluded` matches with `indexOf`, so a short pattern silently deletes whole directories from the corpus.

**Why**: `exclusion_patterns` entries are tested with
`std.mem.indexOf(u8, path, pattern) != null`. There is no anchoring, no path
segmentation, and nothing that distinguishes "a directory named X" from "any
path containing X".

**What Happened**: The entry `"browsers/"` was written to drop WPT's own
`infrastructure/browsers/` browser-driver test - exactly one source. That
substring also occurs in all **701** `html/browsers/` sources, so the entire
browsing-contexts corpus was out of scope: `wpt_runner html/browsers/windows/`
answered `Found 0 test files ... Scope: 0 of 36594 testharness URLs (0.0%)`.
Nothing in that area could be run except by naming each file on the command
line, and `isInScope` looked correct the whole time because the `html`
category matched.

Note that `isInScope` has a careful whole-segment matcher, with tests, so the
category side of the same decision cannot make this mistake. The exclusion
side has no such guard.

**Fix**: Anchor the pattern - `"infrastructure/browsers/"`. Tests pin both
directions: the 701 sources are in scope, the 1 source is not.

**Takeaway**: **Anchor every exclusion pattern at a directory that can only
mean what you meant.** Before adding one, grep the manifest for it and count
what it takes with it.
