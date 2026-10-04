# Architecture: A handle is not a JavaScript type

**Date**: 2026-10-04
**Lesson**: Use the engine's Type operation to classify a JSValue that may hold an engine handle.

**Why**: JSValue's tags describe its representation. Inline undefined has the undefined tag; an engine handle can also refer to undefined, null, a number, or any other JavaScript value. Checking only the tag cannot classify every representation.

**What Happened**: IndexedDB's get-all options parser read count, direction and query with engine.getProperty. That operation returned owned handles, including for missing properties. The parser used JSValue.isUndefined, which tests only the inline tag. It therefore tried to convert a missing count to a finite integer and a missing direction to an enum, throwing TypeError for ordinary empty or partial options. The key-range helper similarly failed to recognize a null or undefined query reached through a property read. Options with every member supplied concealed the bug.

**Fix**: Keep getProperty's Owned values and their releases; classify their borrowed values with engine.typeOf. Apply the same semantic null/undefined check in key-range conversion. Pin empty dictionaries, explicit undefined members, null queries, and each single supplied option through store/index getAll and getAllKeys. Keep the existing dictionary member order and error propagation.

**Takeaway**: **An opaque handle says how a value is held, not what JavaScript type it has.**
