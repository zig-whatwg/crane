# Codegen: An extended attribute the generator detects and never emits is silently ignored

**Date**: 2026-09-23
**Lesson**: `extattr.isLegacyNullToEmptyString` existed, with a test, and nothing called it - so every `[LegacyNullToEmptyString]` value (124 across the IDL: `innerHTML`, `CharacterData.data`, `createDocument`'s qualifiedName, the HTML colour attributes, CSSOM) turned `null` into `"null"`.

**What Happened**: `dom/common.js` builds its fixtures with `createDocument(null, null, doctype)`. That created an element named `null`, so the fixture's `xmlDoc.appendChild(element)` threw HierarchyRequestError inside `setup()`, and 23 `dom/ranges` files ERRORed with zero subtests and the message `[object DOMException]`. A probe that evaluated `setupRangeTests` one statement at a time named the line in one run. dom nodes/traversal/ranges: blocking 52 -> 32, passing subtests 3,237 -> 7,316.

**Fix**: codegen writes a `legacy_null_to_empty` table (Zig function name, bit per argument), and keeps the annotation on union member types, where `innerHTML` carries it. The binding swaps a JS `null` for `""` before conversion.

**Takeaway**: **Grep the generator for every `is<ExtAttr>` helper's callers. A detected-but-unused attribute is a whole class of values converted wrong, and the tests it breaks fail far from the conversion.**
