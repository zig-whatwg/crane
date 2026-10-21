# Testing: Match WPT revisions before changing browser behavior

**Date**: 2026-10-20
**Lesson**: A browser result can improve because its test changed, even when the browser algorithm did not.

**Why**: wpt.fyi's aligned runs align the browsers with each other. They do not align those runs with Crane's pinned WPT checkout. Matching paths and assertion names alone cannot establish matching inputs.

**What Happened**: Crane reported 488 WebCrypto failures in seven AES, RSA and ECDSA files. Earlier browser runs supported retaining the second inherited `name` read during algorithm normalization. New stable runs appeared to contradict that finding: Firefox and Safari now passed the AES-GCM transfer assertions. However, their WPT revision was `0f26972422b15f587e2afbd38dbb6ea2397fded0`; Crane's helper still came from the September 30 pin. [WPT PR #63475](https://github.com/web-platform-tests/wpt/pull/63475), merged October 13 as `37260931105fff57b17bbb80d15fd44b1eb3b930`, had made the getter transfer its buffer only while it was attached. The original helper transferred it on every read, so the second read threw before reaching the intended assertion.

**Fix**:

1. Read the local failure messages and the complete normalization algorithm before changing code.
2. Save the aligned run IDs, their full WPT revision, and per-subtest records. Compare the helper sources at that revision with the local pin.
3. Check implementation evidence as well: WebKit's `normalizeCryptoAlgorithmParameters` still converts a derived dictionary after the initial `Algorithm`; Gecko's `GetAlgorithmName` and `Coerce` also make both conversions. Current green results did not imply a single getter read.
4. Replay the corrected helper in new, separately named Crane fixtures while leaving the worklist tests intact. On the unchanged BASE runner, the same seven vector suites moved from 3,344 PASS / 488 FAIL to 3,832 PASS / 0 FAIL. Keep that result separate from production A/B totals.
5. If upstream WPT is outside the lane grant, hand the integrator an unapplied patch and the upstream commit. Preserve the spec algorithm and the original failures until the test owner updates the pin.

Evidence: WebCrypto §18.4.4 steps 2 and 6; [WebKit SubtleCrypto.cpp](https://github.com/WebKit/WebKit/blob/e427188d73fb165e49a4aade8c172b47ea6fbe02/Source/WebCore/crypto/SubtleCrypto.cpp); [Gecko WebCryptoTask.cpp](https://github.com/mozilla-firefox/firefox/blob/d8c6617dbc51c8793240662342dc055616d602c7/dom/crypto/WebCryptoTask.cpp). Aligned stable runs: Chrome `6244794098778112`, Firefox `5917475882663936`, Safari `5156841570172928` (October 19, 2026).

**Takeaway**: **Compare the test source revisions before treating changed browser pass counts as changed browser behavior.**
