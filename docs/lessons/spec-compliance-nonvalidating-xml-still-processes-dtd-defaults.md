# Spec Compliance: Nonvalidating XML Still Processes DTD Defaults

**Date**: 2026-10-21
**Lesson**: Nonvalidating XML processors still check declaration grammar and apply the attribute declarations they read.

**Why**: XML 1.0 §5.1 distinguishes validity constraints from required processing. Skipping ELEMENT, ATTLIST and NOTATION declarations loses both syntax errors and attribute defaults. Defaulted xmlns attributes affect namespace resolution itself.

**What Happened**: Crane accepted malformed declaration grammar, omitted default attributes, and failed to collapse spaces for declared non-CDATA attributes. A default namespace declaration was lost before the element's expanded name was resolved.

**Fix**: Parse the complete declaration grammar, preserving first-declaration precedence. Normalize defaults when declared and explicit values according to their declared types; collapse only U+0020 after reference expansion. Add defaults before namespace resolution. Keep validity constraints, such as required attributes and element-content validation, out of the nonvalidating parser. Use an explicit stack for nested content models and test allocator failure paths.

The design references are XML 1.0 §§3.2–3.3 and 5.1, libxml2's xmlParseElementDecl/xmlAddDefAttrs/xmlParseStartTag2, and Gecko's nsExpatDriver::HandleStartElement. Their implementations explain how defaults reach the DOM; no implementation code is copied.

**Takeaway**: **Nonvalidating does not mean declaration-blind: syntax, defaults and normalization remain observable XML behavior.**
