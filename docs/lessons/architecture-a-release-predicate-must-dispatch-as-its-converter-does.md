# Architecture: A release predicate must dispatch as its converter does

**Date**: 2026-10-16
**Lesson**: A rule deciding whether a converted value's Global is released must take the converter's own branches, in the converter's order, for every value it answers. A generic arm the converter never reaches for a type will misclassify that type.

**Why**: `conversions.toV8Value` converts runtime.JSValue, DOMString and ArrayBufferView by branches of their own, before its generic union branch. Their tagged-union arms are representations, not IDL member types. `unionValueIsOwned` read any tagged union by its arms, and its member rule called a plain struct a dictionary made for the call. runtime.JSValue's `.handle` arm is `EngineHandle { ptr }`, a plain struct, so the rule answered "owned" for the impl's own handle.

**What Happened**: Lane regexop (8a73cd6881) made toV8Sequence release a union element when `unionValueIsOwned` said so, and it checked `@typeInfo(T) == .union` to decide. runtime.JSValue is a union, so a sequence<any> element holding `.handle` was disposed after `v8_Array_Set`. That disposed the impl's handle: a use-after-free on the next use. No implemented API on main returned such a sequence yet, so nothing crashed. Lane dictleak found it while extending the same rule to dictionary members (Codex row 41 Q21: union, webidl.Opt and `any` members kept a Global each, 5,687 on sanitizer-config.html). Its red test pinned `unionValueIsOwned(runtime.JSValue, .handle)`, and that answered true.

**Fix**: `memberValueIsOwned(T, value)` is now the one rule for every value toV8Value puts into an object or array (dictionary members, sequence elements, record keys and values). It is an allowlist that follows the converter's order:
1. The adapter's own JSValue types are kept.
2. runtime.JSValue is decided by its arm (`jsValueConversionIsFresh`), and runtime.OptionalJSValue the same way.
3. A type whose every value converts fresh is released.
4. A webidl.Opt is released when not passed (a fresh undefined); when passed, its inner value decides.
5. An optional is released when null (a fresh Null); otherwise its child decides.
6. Only a union the generic branch converts (`convertsByActiveMember`) is decided by its active member, through `unionValueIsOwned`.

`unionValueIsOwned` answers a representation union as the value it is. tests/v8/dictionary_member_ownership_test.zig pins each arm, the default, and the handle that stays alive.

**Takeaway**: **Write a release predicate as a mirror of the converter's dispatch. A type the converter handles specially must be handled specially, and first, in the predicate too.**
