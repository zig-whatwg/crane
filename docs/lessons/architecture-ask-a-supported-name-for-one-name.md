# Architecture: Ask "is P a supported property name?" for one P

**Date**: 2026-10-16
**Lesson**: The named property visibility algorithm asks about ONE name; answer it per name, and build the supported property names list only to enumerate.

**Why**: A [LegacyOverrideBuiltIns] interface's named interceptor masks the object's own properties and its prototype chain, so V8 runs it before EVERY property read - `form.submit`, `form.method`, `form.addEventListener`. Its first step is WebIDL 3.9.7 step 1, "is P a supported property name?". The binding answered it by building the whole list (`getSupportedPropertyNames` into an arena) and searching it. For a form, the list is a walk of the form's tree - the document, for a connected form.

**What Happened**: Codex row 23 implemented HTMLFormElement's named getter; every form property read went from under 1 us to 37-550 us (review-codex-lpo M1). Row 23's mitigation cached the list under the tree version, which left a per-read array allocation and a linear search (~420 ns a read), a per-read document walk whenever the tree held an undefined custom element (review S1), and a list whose strings borrowed the cache (S2). WebKit (`HTMLFormElement::isSupportedPropertyName`, `HTMLCollection::isSupportedPropertyName`) and Blink (`NamedPropertyQuery` -> `HasNamedElements`) answer per name from a cache the form or collection keeps; neither builds a list on a property read.

**Fix**: `webidl.SpecialOperations.supported_property_name` - a gated generated delegate `isSupportedPropertyName(instance, name)` beside `getSupportedPropertyNames`, its default null (pinned in tests/v8/special_operations_binding_test.zig), so an impl without one keeps the list. HTMLFormElement answers from a per-form map of each name's candidates kept under the tree version (and from its past names map); HTMLCollection answers `namedItem(name) != null`, which reads the same attributes as its list, so the two answers cannot differ. Enumeration still builds the list - and returns owned strings.

**Takeaway**: **A per-name question never builds the whole answer set: give the impl a per-name query whose default is the old list, and make the per-name answer agree with the list by construction.**
