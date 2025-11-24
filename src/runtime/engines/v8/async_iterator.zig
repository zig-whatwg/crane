//! V8 Async Iterator Wrapper
//!
//! Provides conversion between Zig ReadableStreamAsyncIterator and V8 async iterator objects.
//!
//! ## Architecture
//!
//! ```
//! JavaScript                V8 C++                    Zig
//! ----------               ---------                 -----
//! iterator.next()  →  NextCallback()  →  nextShim()  →  ReadableStreamAsyncIterator.next()
//!       ↓                     ↓                ↓                      ↓
//! Promise<{value,done}>  V8 Promise      V8 Promise           AsyncPromise<IteratorResult>
//! ```
//!
//! ## Usage
//!
//! ```zig
//! // In ReadableStream.call_values():
//! const zig_iterator = try create_readable_stream_async_iterator(...);
//! const v8_object = try wrapAsyncIterator(isolate, context, zig_iterator);
//! return @ptrCast(v8_object);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const conversions = @import("conversions.zig");
const V8Promise = @import("promise.zig").Promise;

// Import streams async iterator
const readable_stream_async_iterator = @import("streams_readable_stream_async_iterator");
const ReadableStreamAsyncIterator = readable_stream_async_iterator.ReadableStreamAsyncIterator;
const IteratorResult = readable_stream_async_iterator.IteratorResult;
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

/// Wrap a Zig ReadableStreamAsyncIterator in a V8 async iterator object
///
/// Creates a V8 object with next() and return() methods that call the
/// Zig iterator and return V8 Promises.
///
/// Arguments:
///   isolate: V8 isolate
///   context: V8 context
///   zig_iterator: Zig async iterator pointer
///
/// Returns:
///   V8 Object with async iterator interface
pub fn wrapAsyncIterator(
    isolate: *v8.Isolate,
    context: *v8.Context,
    zig_iterator: *ReadableStreamAsyncIterator,
) !*v8.Object {
    // Create V8 async iterator object with Zig callbacks
    const v8_object = v8.v8_AsyncIterator_New(
        isolate,
        context,
        @ptrCast(zig_iterator),
        nextShim,
        returnShim,
    ) orelse return error.AsyncIteratorCreationFailed;

    return v8_object;
}

/// Shim for async iterator next() callback
///
/// Called by V8 when JavaScript code calls iterator.next().
/// Calls Zig iterator's next() method and converts the result to V8 Promise.
fn nextShim(
    isolate: *v8.Isolate,
    context: *v8.Context,
    iterator_ptr: ?*anyopaque,
) callconv(.c) ?*v8.Promise {
    // Cast to Zig iterator type
    const iterator: *ReadableStreamAsyncIterator = @ptrCast(@alignCast(iterator_ptr orelse return null));

    // Call module-level next() function with iterator as argument
    const zig_promise = readable_stream_async_iterator.next(iterator) catch |err| {
        // On error, return a rejected V8 promise
        return createRejectedPromise(isolate, context, err);
    };

    // Convert Zig AsyncPromise to V8 Promise
    return convertAsyncPromiseToV8(isolate, context, zig_promise) catch null;
}

/// Shim for async iterator return() callback
///
/// Called by V8 when JavaScript code calls iterator.return().
/// Calls Zig iterator's returnEarly() method and converts to V8 Promise.
fn returnShim(
    isolate: *v8.Isolate,
    context: *v8.Context,
    iterator_ptr: ?*anyopaque,
) callconv(.c) ?*v8.Promise {
    // Cast to Zig iterator type
    const iterator: *ReadableStreamAsyncIterator = @ptrCast(@alignCast(iterator_ptr orelse return null));

    // Call module-level returnEarly() function with iterator as argument
    const zig_promise = readable_stream_async_iterator.returnEarly(iterator, null) catch |err| {
        // On error, return a rejected V8 promise
        return createRejectedPromise(isolate, context, err);
    };

    // Convert Zig AsyncPromise to V8 Promise (returns { value: undefined, done: true })
    return convertVoidPromiseToV8(isolate, context, zig_promise) catch null;
}

// Import webidl for Exception type
const webidl = @import("webidl");

/// Context for bridging Zig AsyncPromise to V8 Promise
const PromiseBridge = struct {
    v8_promise: V8Promise(IteratorResult),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context) !*PromiseBridge {
        const bridge = try allocator.create(PromiseBridge);
        errdefer allocator.destroy(bridge);

        bridge.* = .{
            .v8_promise = try V8Promise(IteratorResult).init(isolate, context),
            .allocator = allocator,
        };

        return bridge;
    }

    fn deinit(self: *PromiseBridge) void {
        self.v8_promise.deinit();
        self.allocator.destroy(self);
    }

    fn onFulfilled(ctx: *anyopaque, value: IteratorResult) anyerror!void {
        const self: *PromiseBridge = @ptrCast(@alignCast(ctx));
        self.v8_promise.resolve(value) catch {};
        self.deinit();
    }

    fn onRejected(ctx: *anyopaque, err_value: webidl.errors.Exception) anyerror!void {
        const self: *PromiseBridge = @ptrCast(@alignCast(ctx));
        self.v8_promise.reject(err_value) catch {};
        self.deinit();
    }
};

/// Convert Zig AsyncPromise(IteratorResult) to V8 Promise
///
/// Creates a V8 Promise and registers callbacks on the Zig promise.
/// When the Zig promise settles, the V8 promise is resolved/rejected.
fn convertAsyncPromiseToV8(
    isolate: *v8.Isolate,
    context: *v8.Context,
    zig_promise: *AsyncPromise(IteratorResult),
) !*v8.Promise {
    // Get allocator from somewhere - for now use a global/thread-local
    // TODO: Pass allocator through context or make it available
    const allocator = std.heap.c_allocator; // Temporary - should come from context

    // Create bridge that will resolve V8 promise when Zig promise settles
    const bridge = try PromiseBridge.init(allocator, isolate, context);
    errdefer bridge.deinit();

    // Register callback on Zig promise
    // When it resolves, bridge will resolve the V8 promise
    try zig_promise.onSettleCtx(
        PromiseBridge.onFulfilled,
        PromiseBridge.onRejected,
        bridge,
    );

    // Return the V8 promise (bridge will be cleaned up when promise settles)
    return bridge.v8_promise.getPromise();
}

/// Context for bridging void AsyncPromise to V8 Promise
const VoidPromiseBridge = struct {
    v8_promise: V8Promise(void),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context) !*VoidPromiseBridge {
        const bridge = try allocator.create(VoidPromiseBridge);
        errdefer allocator.destroy(bridge);

        bridge.* = .{
            .v8_promise = try V8Promise(void).init(isolate, context),
            .allocator = allocator,
        };

        return bridge;
    }

    fn deinit(self: *VoidPromiseBridge) void {
        self.v8_promise.deinit();
        self.allocator.destroy(self);
    }

    fn onFulfilled(ctx: *anyopaque, _: void) anyerror!void {
        const self: *VoidPromiseBridge = @ptrCast(@alignCast(ctx));
        self.v8_promise.resolve({}) catch {};
        self.deinit();
    }

    fn onRejected(ctx: *anyopaque, err_value: webidl.errors.Exception) anyerror!void {
        const self: *VoidPromiseBridge = @ptrCast(@alignCast(ctx));
        self.v8_promise.reject(err_value) catch {};
        self.deinit();
    }
};

/// Convert Zig AsyncPromise(void) to V8 Promise
///
/// Creates a V8 Promise that resolves to undefined when Zig promise settles.
fn convertVoidPromiseToV8(
    isolate: *v8.Isolate,
    context: *v8.Context,
    zig_promise: *AsyncPromise(void),
) !*v8.Promise {
    const allocator = std.heap.c_allocator; // Temporary - should come from context

    // Create bridge
    const bridge = try VoidPromiseBridge.init(allocator, isolate, context);
    errdefer bridge.deinit();

    // Register callback
    try zig_promise.onSettleCtx(
        VoidPromiseBridge.onFulfilled,
        VoidPromiseBridge.onRejected,
        bridge,
    );

    // Return V8 promise
    return bridge.v8_promise.getPromise();
}

/// Create a rejected V8 Promise with error message
fn createRejectedPromise(
    isolate: *v8.Isolate,
    context: *v8.Context,
    err: anyerror,
) ?*v8.Promise {
    _ = context;

    // Create error message string
    const err_name = @errorName(err);
    const err_str = v8.v8_String_NewFromUtf8(
        isolate,
        err_name.ptr,
        @intCast(err_name.len),
    ) orelse return null;

    // Create Error object
    const err_obj = v8.v8_Exception_Error(err_str) orelse return null;

    // Create rejected promise
    // TODO: Implement v8_Promise_Reject in v8_wrapper.cpp
    // For now, just return null
    _ = err_obj;
    return null;
}
