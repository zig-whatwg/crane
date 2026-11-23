# Architecture: A handle-holding struct is named before the dictionary rule

**Date**: 2026-11-23
**Lesson**: A new value type that IS the binding's argument handle must be named in every structural ownership predicate before the rule that walks structs as dictionaries, or the walk calls it copied and the handle is released under the impl.

**Why**: The V8 binding decides who frees an argument's Global with allowlist predicates (`argHandleIsCopied`, `memberHandleIsSafe`, `typeRetainsContext`, `needsArgCleanup`, `freeConvertedArg`). Each has a structural rule for dictionaries: a struct is copied when every field's handle is safe, because a dictionary reads each member through a Get of its own. A JSValue field counts as safe there - a member's JSValue aliases only its own Get handle. A struct whose single JSValue field IS the argument's Global passes that rule.

**What Happened**: Lane bind1 replaced the callback carrier - a fake function pointer holding the binding's Global in its bits - with `runtime.BorrowedCallbackFunction { function: JSValue }` and `runtime.BorrowedCallbackInterface { object: JSValue }`. The function-pointer shape had been unknown to the struct rules (a pointer, so "not copied": keep the handle). The new types are structs, and `argHandleIsCopied` would have walked them as dictionaries, found one safe JSValue field and answered "copied" - so `convertArgReleasingWith` would dispose the argument's Global right after conversion, and the impl's `keep()` (a v8_Global_TakeOver of that Global) would read a freed box. Every addEventListener, MutationObserver constructor and event handler setter would have been a use-after-free. Read while generalizing the predicates, before the first build.

**Fix**: In each predicate, name the types before the structural rules: `if (isCallbackValueType(T)) break :blk false;` ahead of `argHandleIsCopied`'s dictionary walk, and likewise ahead of the context-retention walk and the free paths. A test pins it (`retention_predicate_test`: "argHandleIsCopied - a callback value IS its argument's handle, never copied").

**Takeaway**: **When a new type carries a handle, list it in every ownership predicate ahead of the structural (dictionary, union, optional) rules - a struct of one JSValue looks exactly like a safe dictionary.**
