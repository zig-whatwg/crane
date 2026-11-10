# Workflow: An engine upgrade's breakage is three lists - a compile against the new headers finds one

**Date**: 2026-11-10
**Lesson**: Compiling the adapter against the target version's headers lists the removed and re-signed APIs, and nothing else. A name that survives the upgrade with new semantics, and a cast over the engine's private layout, compile cleanly and break at run time.

**Why**: V8 retires an API in three steps: it adds `FooV2` beside `Foo`, deprecates `Foo`, then removes `Foo` and renames `FooV2` back to `Foo`. After the last step, every call that still says `Foo` compiles - against the V2 semantics. And a `reinterpret_cast` over a class's private members (here `FunctionCallbackInfo`'s `implicit_args_`) is invisible to any compiler.

**What Happened**: Lane v8up batch 1 compiled `v8_wrapper.cpp` (`zig c++ -fsyntax-only`, the exact build flags) against V8 15.7.112.23's include/ and got 87 errors on main. None of them was:
- `global_proxy->GetPrototype()` in `v8_Context_GetRealGlobal`: at 13.1.203 it returned the hidden JSGlobalObject; at 15.7 `GetPrototype()` is `Object.getPrototypeOf` (21963a7493e renamed `GetPrototypeV2` back), so it returns `Window.prototype`, and the Streams size functions would be cached on the wrong object.
- the two `SetPrototype()` and two `PropertyCallbackInfo::Holder()` calls, which changed the same way;
- the two `FCILayout` casts that read `implicit_args_[4]` - the class became a flat frame view (b9c4e374820).

A second compile against the LINKED 13.1.203 headers with `-DV8_DEPRECATION_WARNINGS -DV8_IMMINENT_DEPRECATION_WARNINGS` named exactly the silent sites: every `GetPrototype`, `SetPrototype` and `Holder` that 13.1 already called deprecated. The casts needed a grep for `reinterpret_cast` over V8 types.

A fourth kind surfaced in batch 3 (2026-11-10), in the first tests/v8 run on 15.7.112.43: `v8_String_WriteUtf8` called `WriteUtf8(isolate, buffer, length)`. 13.1's old WriteUtf8 took `(isolate, char*, int capacity, int* nchars = nullptr, int options = NO_OPTIONS)`; 15.7 deleted it (11e71ca38ef) and gave the name to the former WriteUtf8V2, `(isolate, char*, size_t capacity, int flags = kNone, size_t* processed = nullptr)`. A call using only the leading arguments compiles against either. The five calls that passed `nchars` or `NO_NULL_TERMINATION` were in list (1); the two three-argument calls were in no list - 13.1 had not deprecated the old form - and they lost the NUL that 13.1 wrote and counted, so every caller that dropped "the NUL" cut a byte ("gregory" read "gregor", `new Intl.Locale('en')` threw).

**Fix**: For an engine upgrade, make three lists before estimating: (1) the errors of a syntax-only compile against the target's headers; (2) the deprecation warnings of a compile against the CURRENT headers with the engine's deprecation macros on - each is a call whose name may survive with other semantics; (3) every cast over the engine's types (`grep -n 'reinterpret_cast' | grep -i -E 'Info|Layout|internal::'`). Keep the deprecation warnings at zero between upgrades, so list (2) stays empty. Then (4): for every API the version history says was removed and RENAMED BACK (the V2 pattern), grep every call of the name - not only the lines that failed to compile - and check the defaulted arguments: a call that passes only the leading ones binds to the new semantics silently.

**Takeaway**: **A clean compile against the new headers proves only that the names still exist: compile the old headers with the deprecation warnings on to find the names that survived with new meanings.**
