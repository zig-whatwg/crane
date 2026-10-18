# Testing: A handle ledger is kept by handle, not by entry point

**Date**: 2026-10-17
**Lesson**: `live_object_globals` was counted at six of the twenty entry points that make a Global<Object> and uncounted in `v8_Object_Dispose`, so it drifted both ways at once: negative for every uncounted handle the typed dispose released, positive for every counted one the binding released as a Value. Mark the handle when it is made, and read the mark at every delete site.

**Why**: A counter incremented where a handle is made and decremented where it is released is right only if every creation site counts and every handle goes back through the one dispose that uncounts. Neither held: `v8_Object_New` and its siblings, `Holder`, `Function::NewInstance` and `Proxy::New` never counted; the binding releases every result through `v8_Global_Dispose`, which never uncounted; and `v8_GetGlobalPrototype` counted before its early `return nullptr`s (the expected miss for an interface not on the global, once per wrapped element).

**What Happened**: Lane worklets saw the ledger fall below zero on main. tests/v8/object_global_ledger_test.zig on main: 64 `v8_Object_New` read +0 while held and -64 after `v8_Object_Dispose`; 64 `v8_Context_Global` released by `v8_Global_Dispose` left +64; 128 `toJSON()` calls through the binding moved the ledger -10 -> 118. V8's global handle bytes returned to their start in every case: nothing leaked, the ledger lied.

**Fix**: As `live_string_globals` already was (lane callleak): `trackHandle`, which every `new Global<Object>` goes through, sets a wrapper class id on the handle's node and counts it; `forgetCountedHandle`, called from every delete site a handle can reach - the typed disposes (Object, Array, Function, Promise, Resolver), the generic ones (Value, Global), the snapshot's bulk reset and the weak callback's Reset - reads the id back and uncounts. One inline store and one inline load; no registry, no lock. The six entry-point increments went.

**Takeaway**: **Count a handle by a mark on the handle, read at every delete site - never by the entry point that made it or the type it is released as. A weak handle V8 resets is uncounted when its callback resets it.**
