# Spec Compliance: "UTF-8 decode" never fails

**Date**: 2026-09-29
**Lesson**: When a spec says "UTF-8 decode" or "UTF-8 decode without BOM", it means the Encoding Standard's UTF-8 decoder in replacement mode: each maximal subpart of a bad sequence becomes U+FFFD and the algorithm carries on. Only "UTF-8 decode without BOM or fail" may fail.

**Why**: `std.unicode.utf8ValidateSlice` is the obvious Zig call, and it turns a lossy decode into an error. The error then escapes from every algorithm built on the one that decodes, far from the byte that caused it.

**What Happened**: The application/x-www-form-urlencoded parser (`src/url/form_urlencoded/parser.zig`) validated the percent-decoded name and value and returned `error.InvalidUtf8`. URL's constructor initializes its `searchParams` with that parser, so `new URL("http://h/?a=%ff")`, `URL.parse` and `new URLSearchParams("a=%ff")` all threw. `HTMLIFrameElement.resolveSrc` treats a URL that does not parse as about:blank, as the spec says for a failure, so an iframe whose `src` query held `%ff` never navigated. In `mimesniff/mime-types/charset-parameter.window.js`, the `text/html;test=ÿ;charset=gbk` subtest waited for a load event that only ever came from about:blank, and the whole file read TIMEOUT. `url/urlencoded-parser.any.js` had been failing 30 subtests on the same line.

The probe that found it took one run: `new URL(u, location.href).href` in a test page answered "InvalidUtf8", while `a.href` and `iframe.src` quietly returned the unresolved string.

**Fix**: `utf8DecodeWithoutBom` in the parser, the Encoding Standard's decoder step by step (lower and upper boundaries, "restore byte to ioQueue"), with valid input returned as is (56e465399). `url/urlencoded-parser.any.js` 180 -> 210 of 210; `tests/url/form_urlencoded_utf8_decode_test.zig` pins the maximal-subpart cases.

**Takeaway**: **Where the spec decodes, decode; validation is a different algorithm with a different name.** Before writing `utf8ValidateSlice` in spec code, check which of the two the spec calls for.
