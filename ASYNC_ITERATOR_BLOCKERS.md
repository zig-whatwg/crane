# What's Blocking Async Iterator Support in Streams

## Current Status

Async iterator infrastructure **partially exists** in `/src/streams/internal/async_iterator.zig` (241 lines), but it's a **skeleton implementation** with placeholders.

## What Exists ✅

### Data Structures
- `IteratorRecord` - Holds iterator state (iterator object, next method, done flag)
- `IteratorResult` - Result of calling `next()` (value + done flag)
- `MockAsyncIterator` - Test helper for basic iteration

### API Stubs
- `getIterator()` - Get iterator from object (stub)
- `iteratorNext()` - Call next() method (stub)
- `iteratorComplete()` - Get "done" property (stub)
- `iteratorValue()` - Get "value" property (stub)
- `getMethod()` - Get method from object (stub)
- `call()` - Call function with this binding (stub)
- `iteratorClose()` - Close iterator (stub)

## What's Missing ❌

### 1. **V8 Property Access APIs**

Need to implement JavaScript property operations:

```zig
// Currently placeholders - need V8 FFI:
pub fn iteratorComplete(iter_result: JSValue) !bool {
    // BLOCKED: Needs V8 Object::Get(isolate, key) to read "done" property
    return false; // placeholder
}

pub fn iteratorValue(iter_result: JSValue) !JSValue {
    // BLOCKED: Needs V8 Object::Get(isolate, key) to read "value" property
    return JSValue.undefined_value(); // placeholder
}
```

**Required V8 FFI Functions**:
- `v8_Object_Get(isolate, context, object, key)` - Read property
- `v8_Object_Set(isolate, context, object, key, value)` - Write property
- `v8_Object_Has(isolate, context, object, key)` - Check property exists

### 2. **V8 Symbol Support**

Need to access well-known symbols:

```zig
pub fn getIterator(obj: JSValue, hint: enum { sync, async_hint }) !IteratorRecord {
    // BLOCKED: Needs Symbol.asyncIterator or Symbol.iterator
    // In V8: isolate->GetSymbol(v8::Symbol::GetAsyncIterator())
}
```

**Required V8 FFI Functions**:
- `v8_Symbol_GetIterator(isolate)` - Get Symbol.iterator
- `v8_Symbol_GetAsyncIterator(isolate)` - Get Symbol.asyncIterator
- `v8_Object_GetPropertyWithSymbol(isolate, object, symbol)` - Get property by symbol key

### 3. **V8 Function Invocation (Already Exists!)**

Function calling **is already implemented** in Phase 1:
- ✅ `v8_Function_Call()` exists in `v8_wrapper.cpp` 
- ✅ Zig binding exists in `ffi.zig`

But needs minor enhancement:
```zig
pub fn call(f: JSValue, v: JSValue, args: []const JSValue) !JSValue {
    // MOSTLY EXISTS: v8_Function_Call already works
    // NEEDS: Convert JSValue → V8 Value conversion
    // NEEDS: Handle 'this' binding (currently uses undefined)
}
```

### 4. **V8 Method Invocation**

Need to call methods on objects:

```zig
pub fn iteratorNext(record: *IteratorRecord) !Promise(JSValue) {
    // BLOCKED: Needs to call record.next_method.call(record.iterator)
    // Requires: Function::Call(receiver, argc, argv)
}
```

**What's Needed**:
- Extend `v8_Function_Call()` to support custom `this` binding
- Currently hardcoded to `undefined` as receiver

### 5. **Promise Integration (Already Exists!)**

Promise support **is already implemented** in Phase 2:
- ✅ `Promise(T)` wrapper exists
- ✅ `AsyncPromise(T)` for Streams exists
- ✅ Promise creation, resolution, rejection all work

But iterator methods return promises:
```zig
pub fn iteratorNext(record: *IteratorRecord) !Promise(JSValue) {
    // Returns promise that resolves to IteratorResult
    // Needs to wait for async operation to complete
}
```

## Summary: What Needs Implementation

### Critical (Blocking All Async Iterator Features)

1. **V8 Object Property Access** (Estimated: 4 hours)
   - Add `v8_Object_Get/Set/Has` to `v8_wrapper.cpp`
   - Add Zig FFI bindings to `ffi.zig`
   - Implement `iteratorComplete()` and `iteratorValue()`

2. **V8 Symbol Support** (Estimated: 3 hours)
   - Add `v8_Symbol_GetIterator/GetAsyncIterator` to `v8_wrapper.cpp`
   - Add `v8_Object_GetPropertyWithSymbol` for symbol-keyed property access
   - Implement `getIterator()` properly

3. **V8 Function Call with This Binding** (Estimated: 2 hours)
   - Extend `v8_Function_Call()` to accept optional receiver
   - Update Zig binding to support custom `this`
   - Implement `call()` and `iteratorNext()` properly

### Total Estimated Effort: **9 hours**

## Impact on Streams Features

Once async iterator support is complete, can implement:

| Feature | Status | Depends On |
|---------|--------|------------|
| `ReadableStream.from()` | ❌ Not implemented | Async iterator support |
| `ReadableStream.prototype[@@asyncIterator]` | ❌ Not implemented | Async iterator support |
| `ReadableStream.prototype.values()` | ❌ Not implemented | Async iterator support |
| `for await (const chunk of stream)` | ❌ Not implemented | Async iterator support |
| `ReadableStream.prototype.forEach()` | ❌ Not implemented | Async iterator support |
| `ReadableStream.prototype.tee()` | ❌ Not implemented | Internal algorithm only (no async iterator needed) |

**Note**: `tee()` doesn't actually require async iterators - it's a pure internal algorithm. It's marked as `NotImplemented` but could be implemented now.

## Comparison to Phase 1-4

### Phase 1: Function::Call ✅ COMPLETE
- Status: Fully implemented
- Effort: 2 hours
- Result: Can invoke JS callbacks from Zig

### Phase 2: Promise API ✅ COMPLETE  
- Status: Fully implemented
- Effort: 4 hours
- Result: Can create, resolve, reject, and chain promises

### Phase 3: Callback Utilities ✅ COMPLETE
- Status: Fully implemented
- Effort: 12 hours
- Result: High-level Zig wrappers for common callback patterns

### Phase 4: ArrayBuffer API ✅ COMPLETE
- Status: Fully implemented
- Effort: 6 hours
- Result: Full TypedArray/DataView introspection

### Phase 5: Async Iterator Support ❌ NOT STARTED
- Status: Skeleton with placeholders
- Estimated Effort: 9 hours
- Blockers: V8 property access, V8 symbol support, enhanced function call

## Recommended Next Steps

1. **Add V8 Object Property Access** (v8_wrapper.cpp)
   ```cpp
   Global<Value>* v8_Object_Get(Isolate* isolate, Global<Context>* ctx, 
                                 Global<Object>* obj, const char* key);
   bool v8_Object_Set(Isolate* isolate, Global<Context>* ctx,
                      Global<Object>* obj, const char* key, Global<Value>* value);
   bool v8_Object_Has(Isolate* isolate, Global<Context>* ctx,
                      Global<Object>* obj, const char* key);
   ```

2. **Add V8 Symbol Support** (v8_wrapper.cpp)
   ```cpp
   Global<Symbol>* v8_Symbol_GetIterator(Isolate* isolate);
   Global<Symbol>* v8_Symbol_GetAsyncIterator(Isolate* isolate);
   Global<Value>* v8_Object_GetPropertyWithSymbol(Isolate* isolate, 
                                                    Global<Context>* ctx,
                                                    Global<Object>* obj,
                                                    Global<Symbol>* symbol);
   ```

3. **Extend v8_Function_Call** (v8_wrapper.cpp)
   ```cpp
   // Add optional receiver parameter (defaults to undefined if null)
   Global<Value>* v8_Function_Call(Isolate* isolate, Global<Context>* ctx,
                                    Global<Function>* function,
                                    Global<Value>* receiver,  // NEW
                                    int argc, Global<Value>** argv);
   ```

4. **Implement Zig Wrappers** (async_iterator.zig)
   - Replace all placeholder functions with real V8 calls
   - Add comprehensive error handling
   - Write integration tests

5. **Implement Streams Methods** (ReadableStream.zig)
   - `call_from()` - Create stream from async iterable
   - `call_values()` - Get async iterator for stream
   - `call_forEach()` - Iterate over stream chunks
   - `call_tee()` - Split stream (doesn't need iterators, can implement now!)

## Conclusion

**Async iterator support is NOT fundamentally blocked** - it just needs ~9 hours of V8 FFI work to fill in the placeholders. The infrastructure is already designed, and most supporting APIs (Function::Call, Promise) are already implemented.

**The main blocker is**: Nobody has implemented the V8 property access and symbol APIs yet.

**Recommendation**: Implement Phase 5 (Async Iterators) as a focused sprint to unlock the remaining 5 Streams features.
