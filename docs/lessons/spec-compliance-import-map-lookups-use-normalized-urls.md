# Spec Compliance: Import Map Lookups Use Normalized URLs

**Date**: 2026-10-17
**Lesson**: Normalize URL-like import-map keys and import specifiers before exact lookup, including when an import receives the URL returned by import.meta.resolve().

**Why**: An import map contains normalized specifier keys. Relative spellings, dot segments and equivalent absolute URLs can name the same key; bare names remain names. Resolving a specifier does not exempt its returned URL from the next import's map lookup.

**What Happened**: Crane stored relative keys and looked up raw specifiers. A first import.meta.resolve() could map a name, but passing its absolute result to import() missed another relative key that normalized to that URL. The upstream import-meta-resolve-importmap test and sc2-import-map-isolated.html exposed the mismatch. Normalization also makes formerly different input strings collide, so an ordinary replacement can leak the old owned value or scope map.

**Fix**: Use the existing URL parser to normalize keys while parsing and normalize URL-like specifiers before calling the document's map lookup. Keep bare keys unchanged and ignore empty keys. On a normalized collision, preserve the stored key, free the incoming duplicate key and old value, and replace the value; recursively free an old scope map. Native tests use std.testing.allocator to check both lookup and collision cleanup. WebKit's JavaScriptCore ImportMap::normalizeSpecifierKey and resolve illustrate the same ordering.

**Takeaway**: **Canonicalize both sides of a lookup, and audit replacement ownership when canonicalization creates collisions.**
