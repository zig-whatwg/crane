# Spec Compliance: User Timing converts legacy epoch values

**Date**: 2026-10-18

**Lesson**: A legacy navigation name in a measure uses PerformanceTiming's integer epoch values, including its unavailable-value rule.

**Why**: PerformanceTiming and PerformanceNavigationTiming describe the same navigation using different representations. Subtracting a fractional relative timestamp is not equivalent to subtracting two integer epoch timestamps. Zero in the legacy interface means unavailable; a nonzero epoch value equal to navigationStart is available and converts to zero.

**What Happened**: PerformanceTiming had acquired recorded values, but Performance's convertNameToTimestamp still rejected every legacy name except navigationStart. The new rt3-user-timing-navigation.html regression passed seven cases and failed fifteen; two upstream User Timing files ended with InvalidAccessError. Safari's aligned stable result failed only the two duration checks ending at responseEnd, while Chrome and Firefox passed all seventeen cases.

Fixing that conversion exposed a second sentinel error: EntryData treated an end time of zero as unfinished even for a completed measure ending at navigationStart. The associated-navigation-timing WPT finished with six of eight passing; its two negative-duration checks read zero instead. All three browsers pass those checks.

**Fix**: Follow User Timing §3.2 through the existing generated PerformanceTiming getters. Keep the non-Window TypeError and navigationStart special case. Reject only an unavailable zero value, subtract the integer navigationStart, then convert the signed difference to a high-resolution timestamp. Exercise every legacy name, zero/unavailable values, and worker rejection through WPT.

For a measure, User Timing §2.1.3 step 8 always subtracts start from end, including an end of zero. Use its existing entry type to distinguish that completed value from another entry type's unfinished-end sentinel.

**Takeaway**: **Preserve an API's representation and sentinel rules at a conversion boundary; nearby APIs are not interchangeable.**
