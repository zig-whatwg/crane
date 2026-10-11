# Spec Compliance: Blob type is not a MIME parser

**Date**: 2026-10-11
**Lesson**: A MIME parser's WPT result cannot decide a Blob constructor's normalization contract by itself.

**Why**: Blob/File accept a type by lowercasing printable ASCII and rejecting other characters. Fetch specifies extracting a MIME record from headers when packaging a Blob, but browser behavior also depends on the body being packaged.

**What Happened**: At aligned wpt.fyi revision cc74d2669f, all three browsers had identical statuses for all 955 Blob/File parsing cases (353 passed). Request/Response results split three ways: Chrome 358/942, Firefox 677/942, Safari 344/942. A duplicate charset survived in Chrome, kept its first occurrence in Firefox, and vanished with other parameters in Safari.

**Fix**: Keep the unanimous Blob/File normalization. Under the integrator's tie ruling, use Fetch extraction and serialization for script/network headers in Request/Response, then the existing Blob construction hook, which applies Blob normalization. Generated body types have a specific majority: response-consume.html's FormData-to-Blob assertion passes in Chrome and Safari (40/40), but fails in Firefox (39/40), which removes a parameter-space during serialization. Preserve generated formatting with explicit header provenance; mutations clear it and clones preserve it. Inspect individual subtest losses even in files with a net gain: the response file improved overall while hiding this failure. FileAPI issue226 concerns preserving type during structured serialization; it is not a constructor-normalization rule.

**Takeaway**: **Compare per-browser subtests at each API boundary before changing a shared parser or constructor.**

Evidence: [aligned parsing results](https://wpt.fyi/results/mimesniff/mime-types/parsing.any.html?sha=cc74d2669f), [body consumption](https://wpt.fyi/results/fetch/api/response/response-consume.html?sha=cc74d2669f), [WebKit body packaging](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/fetch/FetchBodyConsumer.cpp), [FileAPI226](https://github.com/w3c/FileAPI/issues/226).
