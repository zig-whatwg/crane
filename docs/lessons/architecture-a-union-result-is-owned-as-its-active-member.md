# Architecture: A union result is owned as its active member is

**Date**: 2026-10-11
**Lesson**: Whether the handle a result converts to is the binding's to release depends on the converted value, so for a union it is decided by the active member at run time, never by the union type at comptime.

**Why**: `convertReturnValue` (interface.zig) sets `owned` per type: a string, number, boolean or enum result is a Global made for the call and released once set; a platform object is its wrapper, the wrapper cache's. A union is neither - FormDataEntryValue is (File or USVString) - and the branch for unions left `owned` false for all of them, the conservative answer for the File arm, a leak for the string arm.

**What Happened**: Every `FormData.get()` that returned a string kept its String Global: 32 B of V8 global handles per call (2048 B over tests/v8/per_call_handle_test.zig's 64 calls), found by Codex row 19 (Q13). Lane callleak's per-call fixes had covered each type family but not a union that mixes them.

**Fix**: `conversions.unionValueIsOwned(T, value)` switches on the active member and applies the rule a dictionary member's value follows (`dictionaryMemberValueIsOwned`: strings, numbers, booleans, enums, dictionaries, sequences - fresh), a nested union by its own active member; an interface, `any`, `object` or `*anyopaque` member stays kept. The default is KEPT, pinned in tests/v8/retention_predicate_test.zig. Attribute getters returning unions (CSSNumberish, VTTCue.line, AnimationPlaybackEvent.currentTime) go through PropertyGetterCallback's comptime `getterValueIsOwned`, which answers false for every union: the same leak, left for that path's owner.

**Takeaway**: **An ownership rule keyed on a type is wrong for a union: ask the value which member it holds, and keep the safe default for every member you cannot prove fresh.**
