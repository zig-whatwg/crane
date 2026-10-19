# Spec Compliance: Normalize XML input after Trusted Types

**Date**: 2026-10-18
**Lesson**: DOMParser's XML path must replace isolated UTF-16 surrogates in its owned parser input without changing DOMString conversion for other APIs.

**Why**: A WebIDL DOMString preserves UTF-16 code units, including isolated surrogates. Crane represents them as WTF-8; its XML parser expects scalar UTF-8. Feeding WTF-8 directly to that parser turns otherwise valid XML containing a surrogate into an error document.

**What Happened**: `domparsing/DOMParser-parseFromString-xml-parsererror.html` failed “A lone surrogate is replaced with U+FFFD”. Chrome and Firefox replace the surrogate; Safari fails this assertion (aligned wpt.fyi revision `23b0b89b1a472cac446e3c6e75fc7d6254913ef0`). There is no newer spec change behind this split. Gecko's `DOMParser::ParseFromStringInternal` converts the input to UTF-8 before `ParseFromStream`: https://searchfox.org/mozilla-central/source/dom/base/DOMParser.cpp.

**Fix**: Apply `infra.string.replaceLoneSurrogatesWtf8` to the already-owned Trusted Types compliant string, immediately before the XML branch parses it. This preserves the policy's input and result ownership, valid supplementary characters, and the HTML branch. It does not rewrite XML numeric character references: `&#xD800;` remains an XML well-formedness error. The Crane regressions cover text, attributes, CDATA, valid pairs and invalid numeric references across all four XML MIME types.

**Takeaway**: **Put a parser's scalar conversion at its input boundary; do not make DOMString lose code units globally.**
