# Testing: A measured number in a subtest name makes the test unverifiable

**Date**: 2026-11-17
**Lesson**: A subtest's name is its identity in every tally - put a measured time in the subtest's message, never in its name.

**Why**: `wpt_runner --repeat=10 --verify` holds a file to its subtests by name (tests/AGENTS.md, "Verify mode"); so do the A/B comparisons and the result site. A name that embeds `elapsed.toFixed(3) + ' ms'` is a new subtest every run.

**What Happened**: six Crane cost tests (dm2-click-dispatch-page, dm2-event-dispatch-page, dm2-filereader-progress-page, dm2-pi-parse-page, ev1-shadow-dispatch-cost, rc5-collection-timing) carried their timings in their subtest names so that a runner printing only the start of a subtest list still showed them. Lane vm1 (2026-11-17) found that `--verify` could never pass them: each of the ten runs had different subtest names.

**Fix**: a fixed name, and the time as the subtest's message - testharness.js sets a passing test's message to null in `Test.done`, so the page sets it afterwards in an `add_result_callback` (which runs before the completion callbacks, where the runner's report reads `t.message`), appending to a failure's own message rather than replacing it:

```js
const name = 'Dispatch 100000 events through 10 nodes';
add_result_callback(t => {
  if (t.name === name) t.message = (t.message ? t.message + '; ' : '') + elapsed.toFixed(3) + ' ms';
});
test(() => { assert_equals(count, 100000); }, name);
```

The runner prints a subtest's message and the result stream (journal.wptreport.jsonl) records it, so the number is still read where it was.

**Takeaway**: **Names are identities, messages are data: a cost page reports its measurement in the subtest's message (`add_result_callback`), and its name never changes between runs.**
