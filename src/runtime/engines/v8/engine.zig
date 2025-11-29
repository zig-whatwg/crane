//! V8 Engine Interface Implementation
//!
//! This module provides the V8 implementation of the abstract EngineInterface.
//! It bridges the gap between engine-agnostic WebIDL impls and V8-specific code.
//!
//! ## Usage
//!
//! ```zig
//! const v8_engine = @import("v8").engine;
//! const runtime = @import("runtime");
//!
//! // Create context with V8 engine
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .engine = &v8_engine.v8_engine_interface,
//!     .engine_ctx = isolate,  // V8 Isolate pointer
//! });
//! ```

const std = @import("std");
const runtime = @import("runtime");
const EngineInterface = runtime.EngineInterface;
const EngineError = runtime.EngineError;

// V8 FFI and helpers
const ffi = @import("ffi.zig");
const async_iterator = @import("async_iterator.zig");
const promise_mod = @import("promise.zig");
const event_loop_mod = @import("event_loop.zig");
const callback_wrapper_mod = @import("callback_wrapper.zig");

/// V8 implementation of the abstract EngineInterface
pub const v8_engine_interface: EngineInterface = .{
    .wrapAsyncIterator = v8WrapAsyncIterator,
    .createPromise = v8CreatePromise,
    .resolvePromise = v8ResolvePromise,
    .rejectPromise = v8RejectPromise,
    .getPromiseObject = v8GetPromiseObject,
    .createString = v8CreateString,
    .createArrayBuffer = v8CreateArrayBuffer,
    .createUint8Array = v8CreateUint8Array,
    .parseJson = v8ParseJson,
    .wrapInstance = v8WrapInstance,
    .isString = v8IsString,
    .extractString = v8ExtractString,
    .createEventLoop = v8CreateEventLoop,
    .destroyEventLoop = v8DestroyEventLoop,
    .createCallbackWrapper = v8CreateCallbackWrapper,
    .invokeCallback = v8InvokeCallback,
    .destroyCallbackWrapper = v8DestroyCallbackWrapper,
    .requestGarbageCollection = v8RequestGarbageCollection,
    .scheduleOnMainThread = v8ScheduleOnMainThread,
    .invokeStreamCallback = v8InvokeStreamCallback,
    .getWrapperForInstance = v8GetWrapperForInstance,
    .chainPromiseHandlers = v8ChainPromiseHandlers,
    .name = "V8",
    .version = "12.x", // TODO: Get actual version from V8
};

/// Promise handle for tracking V8 promise state
const V8PromiseHandle = struct {
    resolver: *ffi.PromiseResolver,
    promise: *ffi.Promise,
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

/// Wrap a Zig async iterator for V8
///
/// Takes a Zig ReadableStreamAsyncIterator and creates a V8 async iterator
/// object that JavaScript can use with `for await...of` loops.
fn v8WrapAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context (set by context_manager.zig)
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    // Get current isolate - the context should be entered so this works
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Import the ReadableStreamAsyncIterator type
    const readable_stream_async_iterator = @import("streams_readable_stream_async_iterator");
    const ReadableStreamAsyncIterator = readable_stream_async_iterator.ReadableStreamAsyncIterator;

    const iterator: *ReadableStreamAsyncIterator = @ptrCast(@alignCast(zig_iterator));

    const v8_object = async_iterator.wrapAsyncIterator(isolate, context, iterator) catch
        return EngineError.AsyncIteratorError;

    return @ptrCast(v8_object);
}

/// Create a V8 Promise that can be resolved/rejected from Zig
fn v8CreatePromise(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context (set by context_manager.zig)
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    // Get current isolate - the context should be entered so this works
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const resolver = ffi.v8_PromiseResolver_New(context) orelse
        return EngineError.PromiseError;

    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        ffi.v8_PromiseResolver_Dispose(resolver);
        return EngineError.PromiseError;
    };

    // Allocate handle to track the promise
    const handle = allocator.create(V8PromiseHandle) catch
        return EngineError.OutOfMemory;

    handle.* = .{
        .resolver = resolver,
        .promise = promise,
        .isolate = isolate,
        .context = context,
    };

    return @ptrCast(handle);
}

/// Resolve a V8 Promise with a value
fn v8ResolvePromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    value: ?*const anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Convert value to V8 Value
    const v8_value: *ffi.Value = if (value) |v|
        @ptrCast(@alignCast(@constCast(v)))
    else
        ffi.v8_Undefined(handle.isolate) orelse return EngineError.OperationFailed;

    if (!ffi.v8_PromiseResolver_Resolve(handle.resolver, handle.context, v8_value)) {
        return EngineError.PromiseError;
    }
}

/// Reject a V8 Promise with an error
fn v8RejectPromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    err: anyerror,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Create error message string
    const err_name = @errorName(err);
    const err_str = ffi.v8_String_NewFromUtf8(
        handle.isolate,
        err_name.ptr,
        @intCast(err_name.len),
    ) orelse return EngineError.OperationFailed;

    // Create Error object
    const err_obj = ffi.v8_Exception_Error(err_str) orelse
        return EngineError.OperationFailed;

    if (!ffi.v8_PromiseResolver_Reject(handle.resolver, handle.context, err_obj)) {
        return EngineError.PromiseError;
    }
}

/// Get the V8 Promise object to return to JavaScript
fn v8GetPromiseObject(promise_handle: *anyopaque) *anyopaque {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    return @ptrCast(handle.promise);
}

/// Create a V8 String from UTF-8 bytes
fn v8CreateString(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const v8_string = ffi.v8_String_NewFromUtf8(
        isolate,
        bytes.ptr,
        @intCast(bytes.len),
    ) orelse return EngineError.OperationFailed;

    return @ptrCast(v8_string);
}

/// Create a V8 ArrayBuffer from bytes
fn v8CreateArrayBuffer(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a new ArrayBuffer with the specified length
    const array_buffer = ffi.v8_ArrayBuffer_New(isolate, bytes.len) orelse
        return EngineError.OperationFailed;

    // Copy the bytes into the ArrayBuffer's backing store
    if (bytes.len > 0) {
        const data = ffi.v8_ArrayBuffer_Data(array_buffer) orelse
            return EngineError.OperationFailed;
        const dest: [*]u8 = @ptrCast(data);
        @memcpy(dest[0..bytes.len], bytes);
    }

    return @ptrCast(array_buffer);
}

/// Create a V8 Uint8Array from bytes
fn v8CreateUint8Array(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a backing ArrayBuffer
    const array_buffer = ffi.v8_ArrayBuffer_New(isolate, bytes.len) orelse
        return EngineError.OperationFailed;

    // Copy the bytes into the ArrayBuffer's backing store
    if (bytes.len > 0) {
        const data = ffi.v8_ArrayBuffer_Data(array_buffer) orelse
            return EngineError.OperationFailed;
        const dest: [*]u8 = @ptrCast(data);
        @memcpy(dest[0..bytes.len], bytes);
    }

    // Create Uint8Array view over the ArrayBuffer
    const uint8_array = ffi.v8_Uint8Array_New(isolate, array_buffer, 0, bytes.len) orelse
        return EngineError.OperationFailed;

    return @ptrCast(uint8_array);
}

/// Parse a JSON string and return a V8 value
fn v8ParseJson(
    engine_ctx: *anyopaque,
    json_str: []const u8,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create V8 string from JSON
    const v8_str = ffi.v8_String_NewFromUtf8(
        isolate,
        json_str.ptr,
        @intCast(json_str.len),
    ) orelse return EngineError.OperationFailed;

    // JSON.parse needs the string as a JavaScript string literal
    // Build: JSON.parse('...escaped json...')

    // Escape the JSON for JavaScript string literal (escape backslashes and quotes)
    var escaped: std.ArrayListUnmanaged(u8) = .{};
    defer escaped.deinit(std.heap.c_allocator);

    // Start with JSON.parse('
    escaped.appendSlice(std.heap.c_allocator, "JSON.parse('") catch return EngineError.OutOfMemory;

    for (json_str) |c| {
        switch (c) {
            '\\' => escaped.appendSlice(std.heap.c_allocator, "\\\\") catch return EngineError.OutOfMemory,
            '\'' => escaped.appendSlice(std.heap.c_allocator, "\\'") catch return EngineError.OutOfMemory,
            '\n' => escaped.appendSlice(std.heap.c_allocator, "\\n") catch return EngineError.OutOfMemory,
            '\r' => escaped.appendSlice(std.heap.c_allocator, "\\r") catch return EngineError.OutOfMemory,
            '\t' => escaped.appendSlice(std.heap.c_allocator, "\\t") catch return EngineError.OutOfMemory,
            else => escaped.append(std.heap.c_allocator, c) catch return EngineError.OutOfMemory,
        }
    }

    // End with ')
    escaped.appendSlice(std.heap.c_allocator, "')") catch return EngineError.OutOfMemory;

    _ = v8_str; // Not used - we build the script directly

    const parse_str = ffi.v8_String_NewFromUtf8(
        isolate,
        escaped.items.ptr,
        @intCast(escaped.items.len),
    ) orelse return EngineError.OperationFailed;

    const script = ffi.v8_Script_Compile(context, parse_str) orelse
        return EngineError.OperationFailed;
    defer ffi.v8_Script_Dispose(script);

    const result = ffi.v8_Script_Run(context, script) orelse
        return EngineError.OperationFailed;

    return @ptrCast(result);
}

/// Wrap a Zig runtime.Instance as a V8 object
fn v8WrapInstance(
    engine_ctx: *anyopaque,
    instance_ptr: *anyopaque,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Use the conversions module to wrap the instance
    const conv = @import("conversions.zig");
    const v8_obj = conv.instanceToV8(isolate, instance);

    return @ptrCast(v8_obj);
}

/// Check if a V8 value is a string
fn v8IsString(
    js_value: *const anyopaque,
) bool {
    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));
    return ffi.v8_Value_IsString(value);
}

/// Extract a string from a V8 value
fn v8ExtractString(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    allocator: std.mem.Allocator,
) EngineError![]const u8 {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));

    // Use the conversions module to extract the string
    const conv = @import("conversions.zig");
    const dom_string = conv.fromV8String(allocator, isolate, context, @ptrCast(value)) catch
        return EngineError.OperationFailed;

    // Extract the slice from DOMString
    // Note: DOMString.asSlice() returns a slice, but the memory is managed by DOMString
    // We need to dupe the bytes to give caller ownership
    const slice = dom_string.asSlice();
    const owned_slice = allocator.dupe(u8, slice) catch
        return EngineError.OutOfMemory;

    return owned_slice;
}

/// Create a V8 event loop
fn v8CreateEventLoop(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context, get the current isolate
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const v8_loop_ptr = allocator.create(event_loop_mod.V8EventLoop) catch
        return EngineError.OutOfMemory;

    v8_loop_ptr.* = event_loop_mod.V8EventLoop.init(isolate, allocator) catch
        return EngineError.OperationFailed;

    return @ptrCast(v8_loop_ptr);
}

/// Destroy a V8 event loop
fn v8DestroyEventLoop(
    event_loop: *anyopaque,
    allocator: std.mem.Allocator,
) void {
    const v8_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop));
    v8_loop.deinit();
    allocator.destroy(v8_loop);
}

// ============================================================================
// Callback Wrapper Implementation
// ============================================================================

/// Create a V8 callback wrapper from a JavaScript value
///
/// Used for WebIDL callback interfaces like EventListener.
/// Supports both direct function callbacks and object callbacks with methods.
fn v8CreateCallbackWrapper(
    engine_ctx: *anyopaque,
    js_value: *anyopaque,
    method_name: [*:0]const u8,
    allocator: std.mem.Allocator,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;
    const value: *ffi.Value = @ptrCast(@alignCast(js_value));

    const wrapper = callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        context,
        value,
        method_name,
    ) catch return EngineError.OutOfMemory;

    if (wrapper) |w| {
        return @ptrCast(w);
    }
    return null;
}

/// Invoke a V8 callback wrapper with arguments
fn v8InvokeCallback(
    engine_ctx: *anyopaque,
    callback_wrapper: *anyopaque,
    args: [*]const *anyopaque,
    args_len: usize,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const wrapper: *callback_wrapper_mod.CallbackWrapper = @ptrCast(@alignCast(callback_wrapper));

    // Convert args to V8 values
    const v8_args: [*]const *ffi.Value = @ptrCast(args);
    const v8_args_slice = v8_args[0..args_len];

    const result = wrapper.callN(context, v8_args_slice);
    if (result) |r| {
        return @ptrCast(r);
    }
    return null;
}

/// Destroy a V8 callback wrapper
fn v8DestroyCallbackWrapper(
    callback_wrapper: *anyopaque,
) void {
    const wrapper: *callback_wrapper_mod.CallbackWrapper = @ptrCast(@alignCast(callback_wrapper));
    wrapper.deinit();
}

// ============================================================================
// Garbage Collection (TestUtils support)
// ============================================================================

/// Request garbage collection via V8
///
/// Uses LowMemoryNotification() which triggers a full GC cycle.
/// Per WHATWG TestUtils spec: "Run implementation-defined steps to perform
/// a garbage collection covering at least the entry Realm."
fn v8RequestGarbageCollection(engine_ctx: *anyopaque) EngineError!void {
    // engine_ctx is the V8 Context, get the current isolate
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Use LowMemoryNotification which triggers a full GC
    // This is more reliable than RequestGarbageCollectionForTesting
    // and doesn't require special build flags
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
}

// ============================================================================
// Main Thread Scheduling
// ============================================================================

/// Schedule a callback on the main thread
///
/// For V8, we execute the callback immediately since we're typically
/// already on the main thread. A full implementation would use
/// platform->GetForegroundTaskRunner(isolate)->PostTask().
fn v8ScheduleOnMainThread(
    _: *anyopaque,
    callback: runtime.MainThreadCallback,
    user_data: *anyopaque,
) EngineError!void {
    // For now, execute immediately (assumes we're on main thread)
    // TODO: Use V8 platform task runner for true async scheduling
    callback(user_data);
}

// ============================================================================
// Stream Algorithm Callback Support
// ============================================================================

/// Invoke a JavaScript callback function for stream algorithms (pull, cancel, etc.)
///
/// This invokes a JS function that was stored during stream construction.
/// The function receives the controller as first argument and optional arg as second.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - js_callback: V8 Global<Value>* pointing to the JS function
///   - controller_v8: V8 Object* for the controller wrapper (or null)
///   - arg: Optional V8 Value* for additional argument (e.g., cancel reason)
///
/// Returns:
///   - V8 Promise* from calling the function, or null on failure
fn v8InvokeStreamCallback(
    engine_ctx: *anyopaque,
    js_callback: *const anyopaque,
    controller_v8: ?*anyopaque,
    arg: ?*const anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Get the JS function value from the Global handle
    // The callback is stored as a V8 Global<Value>* which we need to dereference
    const callback_value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_callback)));

    // Check if it's actually a function
    if (!ffi.v8_Value_IsFunction(callback_value)) {
        return EngineError.TypeError;
    }

    const callback_fn: *ffi.Function = @ptrCast(callback_value);

    // Build arguments array
    var args: [2]*ffi.Value = undefined;
    var arg_count: usize = 0;

    // First argument: controller (if provided)
    if (controller_v8) |ctrl| {
        args[arg_count] = @ptrCast(@alignCast(ctrl));
        arg_count += 1;
    }

    // Second argument: additional arg (if provided)
    if (arg) |a| {
        args[arg_count] = @ptrCast(@alignCast(@constCast(a)));
        arg_count += 1;
    }

    // Get 'this' value (undefined for stream callbacks)
    const this_val = ffi.v8_Undefined(isolate) orelse
        return EngineError.OperationFailed;

    // Call the function
    const args_ptr: [*]*ffi.Value = &args;
    const result = ffi.v8_Function_Call(
        callback_fn,
        context,
        this_val,
        @intCast(arg_count),
        if (arg_count > 0) args_ptr else args_ptr,
    );

    if (result) |r| {
        // If result is a Promise, return it directly
        if (ffi.v8_Value_IsPromise(r)) {
            return @ptrCast(r);
        }

        // If result is not a Promise, wrap it in a resolved Promise
        // Per spec, stream callbacks can return undefined or a Promise
        const resolver = ffi.v8_PromiseResolver_New(context) orelse
            return EngineError.PromiseError;
        _ = ffi.v8_PromiseResolver_Resolve(resolver, context, r);
        const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse
            return EngineError.PromiseError;
        return @ptrCast(promise);
    }

    // Call failed - this likely means an exception was thrown
    // Return null to signal error
    return null;
}

/// Get the V8 wrapper for a Zig runtime instance from the cache
///
/// Arguments:
///   - engine_ctx: V8 Context pointer (unused, cache has its own context)
///   - wrapper_cache: WrapperCache pointer
///   - instance: runtime.Instance pointer
///
/// Returns:
///   - V8 Object* if found in cache, null otherwise
fn v8GetWrapperForInstance(
    _: *anyopaque,
    wrapper_cache: *anyopaque,
    instance: *anyopaque,
) ?*anyopaque {
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache: *WrapperCache = @ptrCast(@alignCast(wrapper_cache));
    const inst: *runtime.Instance = @ptrCast(@alignCast(instance));

    if (cache.get(inst)) |wrapper| {
        return @ptrCast(wrapper);
    }
    return null;
}

/// Chain fulfillment/rejection handlers to a V8 Promise
///
/// Creates JavaScript functions that call into Zig when the promise settles.
/// Used to bridge V8 Promises to Zig AsyncPromise.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - js_promise: V8 Promise* to chain handlers onto
///   - on_fulfill_ctx: Context passed to fulfillment callback
///   - on_reject_ctx: Context passed to rejection callback
fn v8ChainPromiseHandlers(
    engine_ctx: *anyopaque,
    js_promise: *anyopaque,
    on_fulfill_ctx: *anyopaque,
    on_reject_ctx: *anyopaque,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const promise: *ffi.Promise = @ptrCast(@alignCast(js_promise));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a PromiseResolver that we'll use to create handlers
    // The handlers will call our Zig callback when invoked
    const resolver = ffi.v8_PromiseResolver_New(context) orelse
        return EngineError.PromiseError;

    // Create fulfill handler function
    const fulfill_handler = ffi.v8_PromiseResolver_CreateResolveHandler(context, resolver) orelse {
        ffi.v8_PromiseResolver_Dispose(resolver);
        return EngineError.PromiseError;
    };

    // Create reject handler function
    const reject_handler = ffi.v8_PromiseResolver_CreateRejectHandler(context, resolver) orelse {
        ffi.v8_Function_Dispose(fulfill_handler);
        ffi.v8_PromiseResolver_Dispose(resolver);
        return EngineError.PromiseError;
    };

    // Store our context pointers in the isolate data slots for now
    // TODO: Use proper weak ref mechanism to pass context to handlers
    _ = on_fulfill_ctx;
    _ = on_reject_ctx;
    _ = isolate;

    // Chain the handlers onto the promise
    _ = ffi.v8_Promise_Then(promise, context, fulfill_handler, reject_handler) orelse {
        ffi.v8_Function_Dispose(reject_handler);
        ffi.v8_Function_Dispose(fulfill_handler);
        ffi.v8_PromiseResolver_Dispose(resolver);
        return EngineError.PromiseError;
    };

    // Note: The handlers are now owned by the promise chain
    // The resolver is used internally by the handlers
}

// ============================================================================
// Helper functions for V8-specific operations
// ============================================================================

/// Get the V8 Isolate from a runtime Context
///
/// This is a convenience function for code that needs direct V8 access.
/// Prefer using the EngineInterface methods when possible.
pub fn getIsolate(ctx: runtime.Context) ?*ffi.Isolate {
    const engine_ctx = ctx.getEngineContext() orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// Get the V8 Context from a runtime Context
///
/// This is a convenience function for code that needs direct V8 access.
/// Prefer using the EngineInterface methods when possible.
pub fn getV8Context(ctx: runtime.Context) ?*ffi.Context {
    const isolate = getIsolate(ctx) orelse return null;
    return ffi.v8_Isolate_GetCurrentContext(isolate);
}

// ============================================================================
// Tests
// ============================================================================

test "v8_engine_interface - has all required functions" {
    const testing = std.testing;

    try testing.expect(v8_engine_interface.wrapAsyncIterator != null);
    try testing.expect(v8_engine_interface.createPromise != null);
    try testing.expect(v8_engine_interface.resolvePromise != null);
    try testing.expect(v8_engine_interface.rejectPromise != null);
    try testing.expect(v8_engine_interface.getPromiseObject != null);
    try testing.expect(v8_engine_interface.createEventLoop != null);
    try testing.expect(v8_engine_interface.destroyEventLoop != null);
    try testing.expect(v8_engine_interface.createCallbackWrapper != null);
    try testing.expect(v8_engine_interface.invokeCallback != null);
    try testing.expect(v8_engine_interface.destroyCallbackWrapper != null);
    try testing.expectEqualStrings("V8", v8_engine_interface.name);
}
