# Spec Compliance: TAO step 6 fails a redirect-tainted navigation in every browser

**Date**: 2026-10-18
**Lesson**: A navigation that went SO -> XO -> SO fails the TAO check at its last hop in Chromium (CorsURLLoader's `tainted_`), and all three browsers mask it. A `*` on the cross-origin hop does not save it.

**Why**: Fetch's TAO check returns success at step 4 for `Timing-Allow-Origin: *`, before step 6's navigation test. Step 6 compares the current URL with the request's origin, so a chain that comes back to the request's origin passes there as well. Chromium's PassesTimingAllowOriginCheck fails a navigate-mode request that is `tainted_` whatever its current URL.

**What Happened**: SO-XO-SO-redirect-chain-tao.https.html's partial-TAO iframe case went 4 -> 3 when lane sw1-b5 gave frame navigations their real origin. The suspected cause was a failure on the cross-origin hop that never reached the final hop. That was wrong. The cross-origin hop had `*` and passed. The case had passed before only because every navigation's origin read as "null". Chrome, Firefox and Safari all pass the case (wpt.fyi df642c4142).

**Fix**: http_fetch.taoCheckPasses step 6 also fails a navigate-mode request whose redirect-taint is not "same-origin" (tests/fetch/rt_tao_redirect_origin_test.zig).

**Takeaway**: **Before chasing a "lost" failure, check that the hop you suspect failed at all: read the test's headers hop by hop.**
