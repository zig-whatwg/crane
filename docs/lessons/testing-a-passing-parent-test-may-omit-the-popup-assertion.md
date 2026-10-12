# Testing: A passing parent test may omit the popup assertion

**Date**: 2026-10-12
**Lesson**: Before using a browser's passing WPT count as implementation evidence, check that its result includes the subtest that asserts the behavior.

**Why**: A test can delegate its meaningful assertions to another window. A passing parent can prove only setup if the remote results never enter its report.

**What Happened**: The aligned Chrome, Firefox and Safari results for `cookies/origin-bound-cookies/scheme-bound-cookies.https.html` all showed 1/1 passing. This initially looked like unanimous support for scheme-bound cookies. The per-file JSON contained only the parent, "Set a cookie on a secure origin and test it's not sent to an insecure origin." None contained the popup's "Check scheme bounding behavior is working." Crane collected both, and failed the popup's assertion that a non-Secure cookie set over HTTPS must not be sent over HTTP. Chromium's `kEnableSchemeBoundCookies` was disabled by default.

**Fix**:

1. Download each aligned run's per-test JSON, not just its aggregate status.
2. Compare the reported subtest names against the parent and child source files.
3. Read the engine's feature default and the code behind the relevant assertion.
4. Treat an absent assertion as missing evidence. Do not add an unshipped feature to match a misleading green count.

Evidence: aligned WPT revision `cc74d2669f5de548e808779877d1d33339ec5115`; run IDs Chrome `6218298311311360`, Firefox `4877098740350976`, Safari `5164107446878208`. See [WPT's per-file results](https://wpt.fyi/results/cookies/origin-bound-cookies/scheme-bound-cookies.https.html?run_id=6218298311311360&run_id=4877098740350976&run_id=5164107446878208), Chromium [net/base/features.cc](https://github.com/chromium/chromium/blob/main/net/base/features.cc) (`kEnableSchemeBoundCookies`) and [net/cookies/cookie_base.cc](https://github.com/chromium/chromium/blob/main/net/cookies/cookie_base.cc) (`IncludeForRequestURL`). The row's integrator corrected the initial interpretation in codex-cookies Q8.

**Takeaway**: **A browser result proves only the assertions it actually reports. Check the subtest before treating a green file as consensus.**
