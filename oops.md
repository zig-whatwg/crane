# V8 Callback Invocation Bug: Deep Dive

## The Problem

JavaScript event listener callbacks fail to execute in WPT tests, causing timeouts. When `addEventListener` registers a callback and an event fires, the callback is never invoked.

## Root Cause

**V8 Local handles cannot be reconstructed from raw pointers passed through FFI.**

When we receive a JavaScript function from V8 (e.g., the callback passed to `addEventListener`), we get a `Local<Function>` which internally is a handle pointing to a slot in V8's HandleScope. We need to persist this as a `Global<Function>` to call it later.

The problem is in how we pass the Local handle through the Zig/C++ FFI boundary:

```
Zig side: func: *v8.Function (raw pointer)
     ↓
C++ side: Function* local_func (raw pointer)
     ↓
Reconstruct: Local<Function> local = *reinterpret_cast<Local<Function>*>(&local_func)
     ↓
Result: GARBAGE - the handle is corrupted
```

## What We Tried

### Attempt 1: Create `v8_Function_ToGlobal()` with HandleScope

```cpp
Global<Function>* v8_Function_ToGlobal(Isolate* isolate, Function* local_func) {
    HandleScope handle_scope(isolate);  // <-- Problem: invalidates incoming handle
    
    Function* func_ptr = local_func;
    Local<Function> local = *reinterpret_cast<Local<Function>*>(&func_ptr);
    
    return new Global<Function>(isolate, local);
}
```

**Result**: `IsFunction()` returned false immediately after reconstruction. The HandleScope was destroying the incoming handle before we could use it.

### Attempt 2: Remove HandleScope

```cpp
Global<Function>* v8_Function_ToGlobal(Isolate* isolate, Function* local_func) {
    // No HandleScope - trust caller's scope
    Function* func_ptr = local_func;
    Local<Function> local = *reinterpret_cast<Local<Function>*>(&func_ptr);
    
    return new Global<Function>(isolate, local);
}
```

**Result**: Global creation succeeded, but when later calling `.Get(isolate)` to retrieve the Local<Function>, `IsFunction()` still returned false. The Global contained garbage.

### Attempt 3: Use Global<Value>* and Cast at Call Time

Changed `v8_Function_Call_Safe` signature from:
```cpp
V8FunctionCallResult* v8_Function_Call_Safe(Global<Function>* function, ...)
```
to:
```cpp
V8FunctionCallResult* v8_Function_Call_Safe(Global<Value>* function, ...)
```

Then cast to Function after retrieval:
```cpp
Local<Value> fn_value = function->Get(isolate);
if (!fn_value->IsFunction()) { /* error */ }
Local<Function> fn = fn_value.As<Function>();
```

**Result**: Same problem - `IsFunction()` returns false. The Global<Value> created by `v8_Value_ToGlobal` also contains garbage when the original value was a function.

## Debug Output Analysis

```
[CallbackWrapper.initFunction] func=ffi.Function@7f206db20, IsFunction=true
[CallbackWrapper.initFunction] Global<Value> created: ffi.Value@7f206db40
...
[v8_Function_Call_Safe] function=0x7f206db40, context=..., recv=..., argc=1
[v8_Function_Call_Safe] fn_value.IsEmpty()=0, IsFunction()=0  <-- BUG HERE
```

Key observation:
- At creation time: `IsFunction=true` (the Local handle is valid)
- At call time: `IsFunction()=0` (the Global handle contains garbage)

The Global handle pointer `0x7f206db40` is slightly different from the original `0x7f206db20`, which is expected (it's a new Global allocation). But the VALUE inside that Global is corrupted.

## The Fundamental Issue

V8's `Local<T>` is NOT just a `T*` pointer. It's a handle that points to a slot in an active HandleScope. The internal structure is something like:

```cpp
template <class T>
class Local {
    T** val_;  // Points to a slot in HandleScope, which contains T*
};
```

When we pass `Function*` through FFI, we're passing the **internal V8 heap pointer**, not the **handle's slot address**. When we try to reconstruct a Local from this:

```cpp
Local<Function> local = *reinterpret_cast<Local<Function>*>(&func_ptr);
```

We're creating a Local that thinks `&func_ptr` (a stack address!) is a HandleScope slot. This is completely wrong.

## How Chromium Does It

Chromium/Blink uses `TraceWrapperV8Reference<v8::Function>` which:
1. Takes a `v8::Local<T>` directly (not a raw pointer)
2. Stores it in a `v8::TracedReference<T>` (similar to Global but GC-traced)
3. Never passes raw V8 internal pointers through any boundary

They can do this because their C++ code directly receives the Local handle from V8 callbacks. We're trying to pass it through a Zig FFI layer, which only supports primitive types and pointers.

## Potential Solutions

### Option A: Create Global in Zig Before FFI

Instead of passing the Local through FFI and creating Global in C++, create the Global immediately in the V8 callback (on C++ side) and return that:

```cpp
// In the callback dispatch code
void SomeCallback(const FunctionCallbackInfo<Value>& args) {
    Local<Function> callback = args[0].As<Function>();
    Global<Function>* global = new Global<Function>(isolate, callback);
    // Pass global* to Zig, not the Local
}
```

### Option B: Store Functions in a V8-Managed Registry

Create a C++ side registry that stores Global<Function> handles keyed by integer IDs:

```cpp
std::unordered_map<uint64_t, Global<Function>> function_registry;

uint64_t RegisterFunction(Isolate* isolate, Local<Function> func) {
    uint64_t id = next_id++;
    function_registry[id].Reset(isolate, func);
    return id;
}

Global<Function>* GetFunction(uint64_t id) {
    return &function_registry[id];
}
```

Zig stores the ID instead of trying to hold a handle.

### Option C: Use V8's PersistentBase API Differently

V8 has `Persistent<T>` which is similar to `Global<T>` but with different move semantics. It might have properties that make FFI easier.

### Option D: Keep Everything in C++

Move all callback handling to C++ and only call into Zig for non-V8 operations. This is a significant architectural change but would eliminate the FFI handle problem entirely.

## Current State

The codebase is in a partially working state:
- Event listeners ARE registered successfully
- Events DO fire and reach the callback dispatch code
- The callback wrapper IS created with a seemingly valid function
- But when we try to CALL the function, the Global contains garbage

## Files Modified

1. `src/runtime/engines/v8/v8_wrapper.cpp` (lines ~454-500, ~6362-6400)
   - Added `v8_Function_ToGlobal()` (doesn't work)
   - Modified `v8_Function_Call_Safe()` to accept `Global<Value>*`

2. `src/runtime/engines/v8/ffi.zig` (line ~989)
   - Changed FFI declaration to use `*Value` instead of `*Function`

3. `src/runtime/engines/v8/callback_wrapper.zig` (lines ~76-120, ~258-282)
   - Modified `initFunction()` to use different Global creation approaches
   - Modified `callN()` to work with new types

4. `src/runtime/engines/v8/engine.zig` (line ~823)
   - Cast callback function pointer for FFI compatibility

## Next Steps

1. Investigate where the Local<Function> is first received from V8 (likely in some callback handler)
2. Create the Global<Function> at that point, BEFORE any FFI crossing
3. Pass the Global* pointer to Zig (Global pointers ARE safe to pass through FFI)
4. Ensure the Global is stored somewhere that won't be garbage collected

The key insight is: **Create Global handles in C++ before crossing to Zig, not after.**
