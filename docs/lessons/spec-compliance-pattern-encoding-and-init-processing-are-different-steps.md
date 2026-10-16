# Spec Compliance: Pattern encoding and init processing are different steps

**Date**: 2026-10-12
**Lesson**: A URLPattern encoding callback receives a fragment, not a whole URL component supplied by the caller.

**Why**: Pattern parsing calls the callback separately for fixed text, prefixes and suffixes. Removing syntax delimiters there, swallowing URL-parser errors, or treating every fragment as an opaque string changes both validation and the exposed canonical pattern.

**What Happened**: URLPattern used percent-encoding shortcuts, handwritten URL splitting and ad hoc base inheritance. It retained dot segments and hexadecimal IPv4, accepted invalid ports, removed query/hash delimiters in callbacks, and treated absent paths as roots. Existing native tests repeated some of those assumptions. Protocol classification compared literal strings, missing patterns such as `http*`.

**Fix**: Implement the complete init-processing algorithm once with distinct pattern and URL modes. Strip one delimiter at that boundary, escape inherited base values in pattern mode, and apply the URL parser's exact states inside the encoding callbacks. Parse matching URL strings with the URL parser. Ask the compiled protocol component whether it matches a special scheme. Keep temporary URL storage local to one call and test every allocation failure.

**Takeaway**: **Keep input preprocessing, fragment encoding and matching separate; test each boundary with both missing and explicitly empty values.**
