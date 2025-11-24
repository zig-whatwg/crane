# Promise Integration Architecture for Streams

## Overview

This document describes the promise integration architecture for WHATWG Streams, specifically focusing on BYOB (Bring Your Own Buffer) operations.

## Current State

### Implemented

1. **AsyncPromise Infrastructure** (`internal/async_promise.zig`)
   - Complete ECMAScript-compliant promise implementation
   - Integrates with event loop for true async behavior
   - Supports then/catch/finally chaining
   - Memory-safe with proper ownership model

2. **ReadIntoRequestWithPromise** (`internal/read_into_request_promise.zig`)
   - Promise-based BYOB read request structure
   - Implements chunk_steps, close_steps, error_steps callbacks
   - Returns AsyncPromise<ReadIntoResult> to caller
   - Test coverage for basic operations

3. **ArrayBufferView Introspection** (`runtime/arraybuffer_view.zig`)
   - Runtime introspection of TypedArray and DataView objects
   - Provides element size, byte offset, byte length queries
   - Detachment detection
   - Type identification (Uint8Array, Int16Array, etc.)

### Partially Implemented

1. **ReadableStreamBYOBReader** (`webidl/impls/ReadableStreamBYOBReader.zig`)
   - Core structure complete
   - read() method structure in place
   - **Missing**: Promise creation and fulfillment in read()
   - **Missing**: closed promise management
   - **Missing**: Error promise rejection

2. **ReadableByteStreamController** (`webidl/impls/ReadableByteStreamController.zig`)
   - All BYOB algorithms implemented
   - ArrayBufferView helpers integrated
   - **Missing**: Promise fulfillment in pullInto operations
   - **Missing**: Error handling with JSValue conversion

## Integration Points

### 1. ReadableStreamBYOBReader.read()

**Current State**: Returns `error.NotImplemented`

**Required Implementation**:
```zig
pub fn call_read(
    instance: *runtime.Instance,
    view: typedefs.ArrayBufferView,
    options: ?*dictionaries.ReadableStreamBYOBReaderReadOptions,
) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Create ReadIntoRequestWithPromise
    const request = try ReadIntoRequestWithPromise.init(
        internal.allocator,
        internal.event_loop,
    );
    
    // Step 2: Add to controller's pending queue
    const ReadIntoRequest = ReadIntoRequest.init(
        internal.allocator,
        chunkStepsFn,
        closeStepsFn,
        errorStepsFn,
        @ptrCast(request), // Pass request as context
    );
    
    // Step 3: Call controller.pullInto(view, min, readIntoRequest)
    // ...
    
    // Step 4: Return promise to caller
    return @ptrCast(request.getPromise());
}
```

**Dependencies**:
- AsyncPromise (✅ available)
- Event loop integration (✅ available)
- ReadIntoRequestWithPromise (✅ available)
- Controller pullInto method (✅ available)

**Blockers**: None - ready for implementation

### 2. ReadableStreamBYOBReader closed promise

**Current State**: Returns `error.NotImplemented`

**Required Implementation**:
```zig
pub fn get_closed(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Return the existing closed promise
    return @ptrCast(internal.closed_promise);
}
```

**Dependencies**:
- AsyncPromise (✅ available)
- InternalState.closed_promise field (✅ available)

**Blockers**: None - ready for implementation

### 3. Error Handling with JSValue

**Current State**: Error rejection incomplete

**Required Implementation**:

When a stream errors, we need to:
1. Convert Zig error to JSValue
2. Reject promises with that JSValue
3. Store error in stream.[[storedError]]

**Example**:
```zig
fn errorInternal(internal: *InternalState, e: JSValue) void {
    // Reject all pending read-into requests
    for (internal.read_into_requests.items) |request| {
        request.errorSteps(e);
    }
    
    // Reject closed promise
    internal.closed_promise.reject(e);
}
```

**Dependencies**:
- JSValue type definition
- Error to JSValue conversion
- Promise reject() method accepting JSValue

**Blockers**:
- ⚠️ AsyncPromise.reject() currently doesn't exist or doesn't accept JSValue
- ⚠️ JSValue type needs proper definition
- ⚠️ Error conversion strategy undefined

## V8 Integration Points

The following require V8 API integration:

### 1. ArrayBufferView Introspection

**Location**: `runtime/arraybuffer_view.zig`

**Required V8 APIs**:
```cpp
// Type detection
bool v8::Value::IsTypedArray()
bool v8::Value::IsUint8Array()
bool v8::Value::IsDataView()
// etc.

// Property access
v8::Local<v8::ArrayBuffer> TypedArray::Buffer()
size_t TypedArray::ByteOffset()
size_t TypedArray::ByteLength()
size_t TypedArray::Length()

// Detachment check
bool ArrayBuffer::IsDetached() // Called WasDetached() in some versions
```

**Implementation Location**: `runtime/engines/v8/` (new file recommended: `arraybuffer_introspection.zig`)

### 2. Promise Creation and Conversion

**Required V8 APIs**:
```cpp
// Create promise
v8::Local<v8::Promise::Resolver> Promise::Resolver::New(context)

// Settle promise
resolver->Resolve(context, value)
resolver->Reject(context, reason)

// Get promise from resolver
resolver->GetPromise()
```

**Implementation Location**: `runtime/engines/v8/promise.zig` (already exists, may need extensions)

### 3. JSValue Conversion

**Required V8 APIs**:
```cpp
// Error to JSValue
v8::Local<v8::Value> v8::Exception::TypeError(message)
v8::Local<v8::Value> v8::Exception::RangeError(message)

// Value creation
v8::Local<v8::Value> v8::Undefined(isolate)
v8::Local<v8::Value> v8::Null(isolate)
v8::Local<v8::Number> v8::Number::New(isolate, value)
```

## Implementation Roadmap

### Phase 1: Pure Zig (COMPLETED)
- ✅ AsyncPromise infrastructure
- ✅ ReadIntoRequestWithPromise
- ✅ ArrayBufferView introspection API
- ✅ All BYOB algorithms in ReadableByteStreamController
- ✅ Integration points clearly defined

### Phase 2: Promise Integration (READY)
**Estimated**: 2-3 hours

**Tasks**:
1. Implement ReadableStreamBYOBReader.call_read() with promise return
2. Implement ReadableStreamBYOBReader.get_closed() promise getter
3. Update read_into_requests to use ReadIntoRequestWithPromise
4. Add promise fulfillment in chunkSteps/closeSteps callbacks

**Blockers**: None (can use stub error handling for now)

### Phase 3: Error Handling (BLOCKED)
**Estimated**: 1-2 hours (after JSValue work)

**Tasks**:
1. Define JSValue type properly
2. Implement error to JSValue conversion
3. Add AsyncPromise.reject(JSValue) if needed
4. Update errorSteps to reject promises with JSValue

**Blockers**:
- ⚠️ Requires JSValue type definition
- ⚠️ Requires error conversion strategy

### Phase 4: V8 Integration (REQUIRES V8 KNOWLEDGE)
**Estimated**: 3-5 hours

**Tasks**:
1. Implement V8 ArrayBufferView introspection in `runtime/engines/v8/`
2. Create V8 promise wrappers that integrate with AsyncPromise
3. Implement JSValue <-> V8 value conversion
4. Test with actual V8 runtime

**Blockers**:
- ⚠️ Requires V8 API expertise
- ⚠️ Requires V8 build environment

## Testing Strategy

### Current Tests
- ✅ ArrayBufferView.ViewType element sizes
- ✅ ReadIntoRequestWithPromise basic fulfillment
- ✅ ReadIntoRequestWithPromise close steps

### Needed Tests (Phase 2)
- [ ] ReadableStreamBYOBReader.read() returns promise
- [ ] Promise fulfills on successful read
- [ ] Promise fulfills with done=true on close
- [ ] Multiple pending reads handled correctly
- [ ] closed promise resolves when stream closes

### Needed Tests (Phase 3)
- [ ] Promise rejects on error
- [ ] Error propagates to all pending reads
- [ ] closed promise rejects on error

### Needed Tests (Phase 4)
- [ ] V8 TypedArray introspection works correctly
- [ ] V8 promises integrate with AsyncPromise
- [ ] End-to-end BYOB read with real V8 runtime

## API Compatibility

### For Spec-Level Code

Code in `src/webidl/impls/` should use clean, high-level APIs:

```zig
// ✅ GOOD - High-level API
const element_size = ArrayBufferViewModule.getViewElementSize(view);

// ❌ BAD - Don't call V8 directly from spec code
const element_size = v8.TypedArray_ElementSize(view);
```

### For Runtime Code

Code in `src/runtime/` provides the abstraction layer:

```zig
// In runtime/arraybuffer_view.zig
pub fn getViewElementSize(view: *const anyopaque) u64 {
    if (V8_AVAILABLE) {
        return V8ViewIntrospection.getElementSize(view);
    } else {
        // Fallback for testing
        return 1;
    }
}
```

## Summary

**Current Status**:
- Phase 1: ✅ COMPLETE
- Phase 2: 🟡 READY (no blockers, can be implemented immediately)
- Phase 3: 🔴 BLOCKED (needs JSValue work)
- Phase 4: 🔴 BLOCKED (needs V8 expertise)

**Immediate Next Steps**:
1. Implement Phase 2 (Promise Integration) - fully unblocked
2. Add comprehensive tests for Phase 2
3. Document JSValue requirements for Phase 3
4. Create V8 integration plan for Phase 4

**Estimated Completion**:
- Phase 2: 2-3 hours of focused work
- Phase 3: 1-2 hours (after JSValue available)
- Phase 4: 3-5 hours (requires V8 knowledge)
- **Total remaining**: ~6-10 hours

At that point, Streams API will be 100% complete! 🎉
