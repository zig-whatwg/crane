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
    .createEventLoop = v8CreateEventLoop,
    .destroyEventLoop = v8DestroyEventLoop,
    .createCallbackWrapper = v8CreateCallbackWrapper,
    .invokeCallback = v8InvokeCallback,
    .destroyCallbackWrapper = v8DestroyCallbackWrapper,
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
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(engine_ctx));
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse
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
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(engine_ctx));
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse
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

/// Create a V8 event loop
fn v8CreateEventLoop(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(engine_ctx));

    const v8_loop_ptr = allocator.create(event_loop_mod.V8EventLoop) catch
        return EngineError.OutOfMemory;

    v8_loop_ptr.* = event_loop_mod.V8EventLoop.init(isolate, allocator);

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
    const isolate = ffi.v8_Context_GetIsolate(context) orelse
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
