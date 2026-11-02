# Debugging: An error line in a failing test's output may print in every run, passing ones too

**Date**: 2026-11-02
**Lesson**: The launcher keeps the output of tests that did not pass; an alarming line in it ("[v8_Context_NewFromSnapshot] ERROR: Context::FromSnapshot(0) failed") is evidence of a cause only once it is shown NOT to print when the test passes.

**Why**: Output from passing tests is discarded, so every line you read sits beside a failure. A noisy fallback that runs in every test looks like the cause of whichever ones fail.

**What Happened**: Lane tsan1's variant runs failed four tests that all printed the FromSnapshot error, in Browsers made without a snapshot - it was reported as the likely cause, and relayed to another lane. Reading the code: HTMLIFrameElement.attachRealm asks for a snapshot realm (`.from_snapshot = true`) in every Browser, v8_wrapper.cpp prints the error unguarded, and protocol_realms falls back to building the realm afresh - in every iframe of every snapshotless test, passing or not. The failures were timing: bfb_cache_test's 300 ms timer fired while the page was cached under a loaded host (3/3 in a full gate), and passed 5/5 alone and 14/14 in verify mode on the same binary at low load.

**Fix**: Before naming a line as the cause, find the code that prints it and when; run the test where it passes and look for the line (a `--verify` run by hand keeps every failure's output, and a passing run's stderr is the test's own when run alone). Report the line as noise with its own bug (the unconditional `from_snapshot`, the unguarded print) and the failure separately.

**Takeaway**: **A line that prints in every run is not a failure's cause. Show it is absent when the test passes before blaming it.**
