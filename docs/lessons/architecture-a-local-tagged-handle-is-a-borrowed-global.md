# Architecture: A `.local`-tagged JSValue handle is a borrowed Global, not a V8 Local

**Date**: 2026-09-26
**Lesson**: The binding hands an impl an object argument as `.handle = .{ .ptr, .handle_scope = .local }`, but `ptr` is the argument's `Global<Value>*` (`v8_FunctionCallbackInfo_GetArgument` makes a Global); `.local` only means "borrowed for the call".

**Why**: `JSValue.EngineHandle.handle_scope` names a V8 concept (Local vs Global handles) while carrying a lifetime fact (borrowed for the call vs owned until released). Code that believes the name reads the pointer as a Local slot.

**What Happened**: The engine-boundary lane's first `retainValue` read a `.local` handle with `v8_Value_ToGlobal` (a Local slot), and `isCallable` used `v8_Value_IsFunction_Local`: `AbortSignal.abort({...}).throwIfAborted()` threw a pointer-looking number, and `AbortSignal.any(new Set)` was a TypeError. Its tests had built only `.global`-tagged handles, so they were green.

**Fix**: In the adapter, a `.handle`'s `ptr` is a Global whichever way it is tagged (value_operations.handleOf). Tests build their arguments with `conversions.fromV8Value`, the way the binding does, so they see the tag the binding really uses. The planned rename (`handle_scope` -> `lifetime: .scoped/.persistent`, after the paused lanes merge) makes the name say what it means.

**Takeaway**: **Test an Engine operation with values made the way the binding makes them, not with hand-built ones - a flag named after an engine concept may mean something else entirely.**
