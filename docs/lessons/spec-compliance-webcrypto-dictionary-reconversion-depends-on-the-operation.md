# Spec Compliance: WebCrypto dictionary reconversion depends on the operation

**Date**: 2026-10-13
**Lesson**: Resolve normalization getter counts per registered dictionary, rather than treating every AlgorithmIdentifier alike.

**Why**: WebCrypto §18.4.4 first converts Algorithm to select a registration, then converts to that registration's dictionary. Repeating the name getter is observable when it transfers a buffer or throws. Browsers do not uniformly perform that second conversion.

**What Happened**: A result group of 548 transfer failures looked like one normalization bug. Aligned wpt.fyi runs 6218298311311360 (Chrome), 4877098740350976 (Firefox), and 5164107446878208 (Safari) showed different majorities: plain digest/HMAC Algorithm should read name once, but derived AES-GCM dictionaries still read it twice in Firefox and Safari. Removing every second read would have contradicted the majority for hundreds of cases.

**Fix**: Reuse the first conversion for the plain Algorithm registration. Preserve inherited-member conversion and ordering for derived dictionaries. WebKit's `Source/WebCore/crypto/SubtleCrypto.cpp:normalizeCryptoAlgorithmParameters` demonstrates this distinction; Blink's `normalize_algorithm.cc:ParseAlgorithmDictionary` demonstrates single-name normalization. Keep tests for both single-read transfers and derived dictionary getter ordering.

**Takeaway**: **A shared failure message does not imply one browser-compatible fix across every registered dictionary.**
