# Testing: A matching hash does not prove the algorithm was recognized

**Date**: 2026-10-16
**Lesson**: When a parser ignores unsupported input, choose a regression whose result differs between recognition and ignoring.

**Why**: An SRI token with a matching digest loads a resource whether the algorithm is recognized and verified or ignored as unsupported. A positive test cannot distinguish those paths.

**What Happened**: Row 48 initially followed WebKit's case-insensitive hash-algorithm parser. Its uppercase matching-hash test passed. Blink's `SubresourceIntegrity::ParseAttributeAlgorithm` uses case-sensitive `starts_with`, and Gecko's `SRIMetadata` uses `EqualsLiteral`; the browser majority ignores uppercase algorithm names, contrary to the draft and WebKit. Existing WPT cases do not distinguish that split.

**Fix**: Native regressions use a mismatching uppercase digest, mixed case, and an uppercase stronger token beside a matching lowercase digest. They also check that uppercase-only metadata does not satisfy Integrity-Policy, and that Blink-only `sha-256` spelling stays unsupported. The parser follows the exact lowercase names. The native red run rejected the mismatching uppercase token as a network error and allowed uppercase metadata through the policy precheck; both expectations failed before the parser correction.

**Takeaway**: **Before trusting a passing parser test, ask whether ignoring its input would pass it too.** Use a case with different observable outcomes, and keep source-derived browser-majority expectations in native tests when the liaison has not approved them as WPT-runner tests.
