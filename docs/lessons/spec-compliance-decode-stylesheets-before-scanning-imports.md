# Spec Compliance: Decode Stylesheets Before Scanning Imports

**Date**: 2026-10-27
**Lesson**: Decode a fetched stylesheet once, before either parsing its rules or discovering its imports, and retain its resulting encoding for child sheets.

**Why**: CSS Syntax selects an encoding from response metadata, an exact byte-level `@charset` signature, and the environment, with a BOM overriding that selection. Import discovery also consumes CSS text. Scanning raw bytes misses imports in UTF-16 and can send a differently decoded URL to the fetcher.

**What Happened**: Crane's loader passed raw bytes to both consumers, while the CSSOM delivery path independently assumed UTF-8. Charset WPT files failed, and a stylesheet's actual encoding was unavailable when an imported sheet needed its environment encoding.

**Fix**: Use the existing Encoding decoder at response consumption, before both consumers. Retain the selected encoding on the existing load's Sheet and as immutable metadata on SheetRecord, so an import inserted after parsing or detachment still has its parent's encoding. Imports inherit that encoding; root sheets use a valid link charset or XML stylesheet charset pseudo-attribute, then the document encoding. Remove the second decoder from delivery so a second U+FEFF remains content. Keep `@charset` sniffing separate from token grammar: its exact signature and first-1024-byte limit matter. WebKit's [TextResourceDecoder](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/TextResourceDecoder.cpp), particularly `checkForBOM`, `checkForCSSCharset`, and `decode`, supplies the design precedent for selecting the encoding before codec consumption.

**Takeaway**: **Every consumer of a fetched stylesheet must see the same decoded text; the resulting encoding is part of the stylesheet's import environment.**
