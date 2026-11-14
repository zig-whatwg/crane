# Testing: A project runner's "passed" count may be its total

**Date**: 2026-11-14
**Lesson**: Before reading a number from a project's own test runner log, read the runner's source for what that number is: jquery-test-runner prints QUnit's total under the word "passed".

**Why**: A runner's summary line is written for a person who already knows the runner. jquery-test-runner 0.3.0's reporter.js (`reportEnd`) prints `${failed} failed. ${testCounts.total} passed. ${skipped} skipped.`: the middle number is every test QUnit counted, failures and skips included. Read at its word, the log of jQuery's Chrome run ("3 failed. 1147 passed. 0 skipped.") says Chrome passed 1,147 tests; it passed 1,144 of 1,147.

**What Happened**: Lane fw1 batch 6 replaced the hand-typed Chrome counts in tools/fw_matrix/frameworks.zon (`chrome_reference`) with journals read from the runners' own logs (`fw_matrix import`), so that every name and number on /frameworks/ comes from a run. Batch 4 had read the same line by hand and got 1,144 because it knew the run had 3 failures; a parser would not have known. The reader now computes passed = total - failed - skipped and refuses a log whose numbered failure list does not match the failed count. Bazel's web-test-runner summary (Angular's `bazel test <target>_chromium`) has the opposite gap: "N passed, M failed" with no names, so its failures are recorded as unnamed and the page says so.

**Fix**: For each runner a log reader supports, quote the runner's source for every number it reads (tools/fw_matrix/readers.zig, the comment above `LogPage`), test the reader on a fixture in the runner's real format, and cross-check the counts against what the log itself lists (the numbered failures).

**Takeaway**: **A label in a runner's summary is the runner's, not English: read the code that prints it before a parser trusts it, and check its count against the list the same log prints.**
