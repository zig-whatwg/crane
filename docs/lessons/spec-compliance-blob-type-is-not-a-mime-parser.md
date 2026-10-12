# Spec Compliance: Blob type is not a MIME parser

**Date**: 2026-10-11
**Status**: The provenance advice below was superseded on 2026-10-11 by row 21: body presence selects Blob packaging behavior.
**Lesson**: A MIME parser's WPT result cannot decide a Blob constructor's normalization contract by itself.

**Why**: Blob/File accept a type by lowercasing printable ASCII and rejecting other characters. Fetch specifies extracting a MIME record from headers when packaging a Blob, but browser behavior also depends on the body being packaged.

**What Happened**: At aligned wpt.fyi revision cc74d2669f, all three browsers had identical statuses for all 955 Blob/File parsing cases (353 passed). Request/Response results split three ways: Chrome 358/942, Firefox 677/942, Safari 344/942. A duplicate charset survived in Chrome, kept its first occurrence in Firefox, and vanished with other parameters in Safari.

**Fix**: Keep the unanimous Blob/File normalization. The initial row 19 tie ruling used Fetch extraction for supplied headers and added provenance for generated types, based on the FormData-to-Blob assertion (Chrome/Safari 40/40 versus Firefox 39/40). Review found the narrower distinction was wrong: Blink uses the raw Content-Type, and WebKit FetchBodyConsumer uses it for every non-null body, including script-supplied headers. Row 21 follows that majority for every non-null body, including zero bytes, and removes the provenance flag. Null bodies keep Fetch extraction and serialization under the three-way tie ruling. Both paths finish with Blob normalization. Inspect individual subtest losses even in files with a net gain: the response file improved overall while hiding this failure. FileAPI issue226 concerns preserving type during structured serialization; it is not a constructor-normalization rule.

**Takeaway**: **Compare per-browser subtests and body state at each API boundary; generated-header provenance does not describe Blob packaging.**

Evidence: [aligned parsing results](https://wpt.fyi/results/mimesniff/mime-types/parsing.any.html?sha=cc74d2669f), [body consumption](https://wpt.fyi/results/fetch/api/response/response-consume.html?sha=cc74d2669f), [WebKit body packaging](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/fetch/FetchBodyConsumer.cpp), [FileAPI226](https://github.com/w3c/FileAPI/issues/226).
