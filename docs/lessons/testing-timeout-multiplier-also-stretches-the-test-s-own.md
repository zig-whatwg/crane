# Testing: `timeout_multiplier` also stretches the test's own waits

**Date**: 2026-09-24
**Lesson**: testharness.js multiplies `step_timeout` by `timeout_multiplier`,
so the runner's `setup({timeout_multiplier: 6})` for `long` files made every
deliberate wait in them six times longer.

**Why**: the multiplier was a stand-in for the `<meta name="timeout">` that
testharness.js cannot see (it is installed before the page is fetched). It
did lift the harness timer to 60s - and scaled `step_timeout(2000)` to 12s
with it.

**What Happened**: `the-script-element/moving-between-documents/` (52 files)
waits 2s and 4s after loading two slow frames. At 6x that is 36s of waiting;
it fit the 60s ceiling while frames loaded instantly, and stopped fitting
once b207665d7 made frames fetch their blocking stylesheet and scripts. The
directory went from 29 OK to none, and the commit that exposed it was not
the one at fault. With an explicit timeout, all 50 of its worklist files and
two more under the-script-element/ pass: 53 TIMEOUT -> OK across the 393
`long` files outside legacy-mb.

**Fix**: a budget beyond the harness default takes
`setup({explicit_timeout: true})`, as WPT's own runner does for every file,
and `waitForCompletion` calls the harness's `timeout()` at the runner's
ceiling - the harness then reports every subtest that ran.
`config.Timeout.explicitTimeout` holds the rule, pinned by tests.

**Takeaway**: **A knob that scales one clock usually scales others with
it.** When a test's own timing matters, check what else a harness setting
touches before using it to fix a timeout.
