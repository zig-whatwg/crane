# Architecture: A Local made from a slot's value is not the slot

**Date**: 2026-11-07
**Lesson**: In V8 13.1 as Crane builds it (no V8_ENABLE_DIRECT_HANDLE), a `Local<T>` is the ADDRESS of a slot that holds the tagged pointer. To view a raw slot as a Local, reinterpret the slot's address (`*reinterpret_cast<Local<T>*>(&slot_ptr)`, what V8's own `Local::FromSlot` does), never the value read out of it.

**Why**: `*reinterpret_cast<Local<Value>*>(&addr)` reads the 8 bytes at `&addr` as the Local, so the Local's "slot" is `addr` itself, the tagged pointer. Every question then asked of it (`IsFunction`, `GetCreationContext`) reads the object's first word (its compressed map and hash) as if it were the object. The answer is garbage that usually looks harmless. The code reads like the right thing: "a Local is an Address*, so point at our address slot".

**What Happened**: `v8_FunctionCallbackInfo_GetFunctionCreationContext` read the callback's target from `implicit_args[kTargetIndex]` this way, on every binding path that throws or makes an object in "the function's realm". The garbage was nearly always "not a function", so the function fell back to the current context. Inside an API callback that is the called function's own realm, because calling a function enters its realm, so every test passed for months.

perf3's phase 1b moved the read later, after the impl had run script (the function's realm is made only when a step asks for it). Then it bus-errored in tests/v8/context_counter_test.zig (WritableStream.getWriter). A first fix tried to copy the target into a handle with `Local<Value>::New(isolate, view)`. The Debug build's UBSan then named the double dereference, because the header's `ValueAsAddress` is compiled into v8_wrapper.cpp: "load of misaligned address ...c75 for type 'const Address'" in 398 tests.

**Fix**:
1. `functionCallbackTarget(info)` takes `&layout->implicit_args[4]` and reinterprets THAT pointer's storage as the Local, as `FunctionCallbackInfo::Data()` does with `Local<Data>::FromSlot(&implicit_args_[kTargetIndex])`. The slot is part of the API callback's frame, so the Local is good for the whole call.
2. tests/v8/perf3_function_creation_context_test.zig (red before) asks `v8_Debug_FunctionCallbackTargetKind` what the read finds: a FunctionTemplateInfo or the function, never anything else. The probe is made in one realm and called from another, interpreted and hot.
3. When a crash comes from adapter code that reads V8's internals, run the Debug build first: UBSan instruments the V8 header functions inlined into v8_wrapper.cpp, and V8's own library code is not instrumented.

**Takeaway**: **A Local is the address of a slot: reinterpret the slot's address, never its value. Code that is wrong in this way can pass every test for months when its fallback happens to give the right answer.**
