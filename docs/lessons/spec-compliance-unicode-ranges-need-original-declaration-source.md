# Spec Compliance: Re-tokenize Unicode Ranges From Original Source

**Date**: 2026-10-24
**Lesson**: A descriptor with a special tokenization mode must receive the original source before a generic token serializer changes its spelling.

**Why**: In ordinary CSS tokenization, `U+41` is an identifier followed by a signed number. The generic serializer preserves those token boundaries by writing `U/**/+41`. Unicode-range tokenization instead requires adjacent `U`, `+` and a hexadecimal digit or question mark, so the serialized spelling is not an equivalent input to that mode.

**What Happened**: An integration of the correct generic boundary table made a font-face declaration lose its unicode-range descriptor. Direct descriptor-parser tests and the FontFace constructor/setters still passed because they bypassed generic declaration serialization. A declaration-list regression exposed the changed source spelling.

**Fix**: CSS Syntax 3 §5.5.6 step8 consumes unicode-range from the original source. After decoding and matching the descriptor name, preserve that value span through the existing importance and whitespace handling, then let the descriptor consumer re-tokenize in §4.3.14's mode. Keep comments intact: comments between ranges are valid, while `U/**/+41` remains invalid. Pin declaration lists, stylesheet rules, direct API paths and allocation failure cleanup.

**Takeaway**: **Test the complete declaration pipeline when a grammar changes tokenization mode; a correct generic serializer can still be the wrong input to the next parser.**
