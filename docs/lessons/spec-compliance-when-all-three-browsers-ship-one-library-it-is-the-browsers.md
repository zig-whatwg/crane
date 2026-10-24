# Spec Compliance: When all three browsers ship one library, the library is the browsers

**Date**: 2026-10-23
**Lesson**: Where Blink, Gecko and WebKit all decode a format with the same library, that library's deviations from the spec are the browsers' behaviour (golden rule 2), and its source is the evidence.

**Why**: Golden rule 2 asks what the browsers do where they and the spec differ. When all three embed one implementation, there is no majority to count. The answer is in that implementation, and reading it settles cases that wpt.fyi's tests never touch.

**What Happened**: WOFF2 decoding in all three browsers is Google's woff2 library (Blink's web_font_decoder.cc, Gecko through OTS's ProcessWOFF2, WebKit's WOFFFileFormat.cpp). The WOFF2 Recommendation says an unknown transform version MUST be rejected. woff2 reads glyf and loca versions 1 and 2 as the null transform, and hmtx versions 2 and 3 as version 1. No conformance test covers either. The one place the embedders do differ is the declared totalSfntSize:
- Blink and OTS refuse 0 and anything below the file's size;
- Gecko's OTS also caps the decoded size at it;
- WebKit ignores it.
Mechanism by mechanism, the majority is Blink's behaviour. wpt.fyi agrees: css/WOFF2/header-totalsfntsize-001.xht, which expects a too-small value to load, fails in Chrome and Firefox.

**Fix**: kit/sfnt's woff2.zig follows woff2_dec.cc (ReadWOFF2Header, ReadTableDirectory, ReconstructGlyf, ReconstructTransformedHmtx) and names each place it departs from the Recommendation and why. The W3C conformance suite's fonts in WPT (css/WOFF2/support/) are native fixtures: 24 that load, 35 that are rejected, and 240 metadata fonts.

**Takeaway**: **Before ruling between spec and browsers, check whether the browsers share an implementation. If they do, read it: the shared library is the behaviour to match.**
