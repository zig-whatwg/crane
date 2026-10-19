# Testing: Formatting expectations must not repeat the format expression

**Date**: 2026-10-18
**Lesson**: Pin serialized text with literal expected strings, and run the implementation-present branch of a new test before an expensive integration build.

**Why**: An expected-value helper that uses the implementation's formatting expression can reproduce its mistake. A capability guard in the initial failing test can also leave the rest of that test uncompiled until the capability exists.

**What Happened**: The new lastModified getter and its native expected-date helper both formatted an i32 year with `{d:0>4}`. Zig included a plus sign: year 7 became `00+7`. The getter test passed because both sides made the same mistake. A separate pure formatter test had literal expected strings, but its initial red stopped at an absent-helper guard. After implementation, its anonymous input records first failed to coerce to the platform's extern LocalDateTime struct. Explicitly typing those inputs let the literal assertion expose the actual formatting bug.

**Fix**: Type calendar inputs as LocalDateTime. Format the positive year as an unsigned integer, consistent with WallTime's representable local years, and keep literal examples for a short year, a pre-epoch date, a leap day and a year longer than four digits. Correct the getter's expected-date helper too. Run native checks before rebuilding the optimized runner so test compilation and pure formatting failures surface first.

**Takeaway**: **A formatting oracle must be independent of the expression it checks; a missing-capability red does not validate the test's later branch.**
