# Testing: WPT worklists name source files, not variant URLs

**Date**: 2026-10-23
**Lesson**: Give Crane's WPT runner source-file paths and let its metadata expansion create each test URL.

**Why**: The runner reads and parses a source file before iterating its declared globals and variants. A result URL such as `crane/example.html?case=0` is not a source-file path accepted by `--from-file`.

**What Happened**: A CSS resource regression list supplied literal query variants for four isolated URL cases and a fetch-once check. Each entry failed with `FileNotFound` before any assertion ran. The apparent test errors were invalid invocations, not additional product regressions.

**Fix**: Declare variants with `<meta name="variant" content="?case=0">` in a new Crane fixture and put its bare `.html` path in the worklist. Crane's `tests/wpt_runner/main.zig` expands `metadata.variantsOrDefault()` within each implemented global. Verify both the selected source count and the resulting variant labels: the repaired list produced four independent content-URL failures and one whitespace-URL failure. A separate declared variant exercised the fetch-once assertion successfully. Upstream WPT files remained unchanged.

**Crane fixtures have a separate reporting boundary**: `tests/wpt_runner/result_reporter.zig` intentionally excludes `crane/` fixtures from the WPT report and streamed result output. Their absence there does not mean they did not run. A verifier initially rejected a green URL regression run because it expected the Crane fixture's twelve assertions in that stream. The source journal and piped verbose log showed all twelve passed. Keep exact URL/name/occurrence comparisons for upstream WPT streams; use the source journal plus verbose assertion names and messages for Crane fixtures. Correcting the reader required neither a product change nor another test run.

**Validate fixture setup too**: A cache-lifetime test requested a nonexistent `dummy.svg` and failed before exercising the cache. A companion test passed because it checked only Resource Timing entries, which also record failed requests. Confirm the supporting file exists and require a successful load when success matters; the corrected SVG test failed on the old URL before passing with the valid resource. Also give cleanup callbacks block bodies when their operation returns a boolean: `() => { document.fonts.delete(face); }`. Returning the boolean violates testharness's cleanup contract and can turn a useful assertion failure into a harness error that prevents later cases from running.

**Takeaway**: **Source coverage and expanded test-URL coverage are different checks; verify both and use the result format that includes the test's namespace before treating a run as regression evidence.** See also [worklist validation](workflow-validate-the-worklist-before-acquiring-runner-tokens.md).
