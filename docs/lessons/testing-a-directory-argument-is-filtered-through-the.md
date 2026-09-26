# Testing: A directory argument is filtered through the runner's allowlist, and three 0.1 areas were not on it

**Date**: 2026-09-22
**Lesson**: `wpt_runner custom-elements/` printed "No tests found. Check your
filter paths." and exited 0. The 0.1 worklist had 167 custom-elements files.

**Why**: a directory argument is intersected with `in_scope_categories` in
`tests/wpt_runner/config.zig`, which listed url, urlpattern, encoding, console,
mimesniff, streams, fetch, xhr, dom, html, cookiestore and webidl - and not
`custom-elements` (167 files), `websockets` (200) or `navigation-api` (414).
781 worklist files, 18% of the corpus, were invisible to every directory run.
An explicit file path works, and `--from-file` bypasses the filter entirely,
which is the only reason the sweep ever measured them.

**What Happened**: "No tests found" reads as an empty area, not as a filter, and
the exit code is 0. An agent told to work `websockets/` by directory would have
baselined nothing and reported a clean run. `tools/wpt_subset.py` is the
authority on scope; the runner's list had drifted from it without anything
noticing, because nothing compares the two.

**Fix**: the three areas are on the list now. When adding an area to the
worklist's INCLUDE table, add it here too - or run the area with
`--from-file=<list>`, which is what the sweep does.

**Takeaway**: **"No tests found" with exit 0 is a filter, not a fact.** Any
runner answer that involves zero of something - zero tests, zero subtests, zero
crashes - deserves one question before it is believed: what would this look like
if the input had simply been dropped? This is the sixth distinct way this harness
manufactures a result; the other five are among the Testing lessons in the AGENTS.md index.
