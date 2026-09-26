# Testing: testharness.js reads its own timeout out of a document that does not exist yet

**Date**: 2026-09-22
**Lesson**: `<meta name="timeout" content="long">` was invisible, so every `long` file ran on a sixth of its budget.

**Why**: `WindowTestEnvironment.test_timeout()` walks
`document.getElementsByTagName("meta")` for `name=timeout`. In a browser that
runs as part of the document, so the meta above the `<script>` is there. The
runner installs testharness.js *before* the page is fetched -
`loadTestHarness(ctx)` then `loadPageWithOptions` - so the walk has always run
over an empty document and always returned
`settings.harness_timeout.normal` (10s).

**What Happened**: Two clocks disagreed on every `long` file: 60s from the
runner, which parses the same meta out of the source and has a test proving
it, and 10s from the harness. The harness always won, because it fires first
and calls `complete()`. The file was recorded TIMEOUT with whatever had run,
usually nothing. Measured on
`back-forward-cache/eligibility/inflight-fetch-1.html`: 9,925ms of a 60,000ms
ceiling. 68 of the 664 sources under `html/browsers` declare `long`.

The parser test passed the whole time. The bug was not in what the runner
parsed but in what it never told the harness.

**Fix**: inject `setup({timeout_multiplier: N})` after testharness.js loads -
testharness's own knob for a slow host, applied to exactly the value the meta
lookup should have produced. `config.Timeout.harnessMultiplier` keeps the two
in step, with a test that walks the enum so a third budget cannot drift.

**Takeaway**: **When a library derives a setting from state the host supplies
out of order, the host has to hand it over explicitly. Two components each
reading the same input is not the same as them agreeing.**
