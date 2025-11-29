//! Algorithm abstraction for Streams
//!
//! Algorithms in WHATWG Streams represent operations that can be:
//! - JavaScript callbacks from underlyingSource
//! - Native Zig closures with captured state (for ReadableStream.from, etc.)
//! - No-op defaults (return undefined/resolved promise)
//!
//! This replaces the simple ?*const anyopaque function pointer approach
//! with a vtable-based system supporting context and proper lifecycle.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const callbacks = @import("callbacks");
const AsyncPromise = @import("async_promise").AsyncPromise;
const webidl = @import("webidl");

/// Algorithm - Represents a stream operation (start/pull/cancel/etc.)
///
/// Design: Uses vtable pattern for type erasure + context storage
/// Supports both JavaScript callbacks and native closures
pub const Algorithm = struct {
    /// Type-erased context pointer
    /// - For JS callbacks: NULL (callback is the context)
    /// - For native closures: Pointer to captured state struct
    context: ?*anyopaque,

    /// Vtable for algorithm operations
    vtable: *const VTable,

    /// Allocator for cleanup
    allocator: Allocator,

    pub const VTable = struct {
        /// Invoke the algorithm
        /// - controller: ReadableStreamDefaultController instance
        /// - context: Type-erased algorithm context
        /// Returns promise that resolves on completion
        invoke: *const fn (
            controller: *runtime.Instance,
            context: ?*anyopaque,
        ) anyerror!*AsyncPromise(void),

        /// Invoke with argument (for cancel algorithm with reason)
        invoke_with_arg: *const fn (
            controller: *runtime.Instance,
            context: ?*anyopaque,
            arg: *const anyopaque,
        ) anyerror!*AsyncPromise(void),

        /// Destroy algorithm and free context
        destroy: *const fn (
            context: ?*anyopaque,
            allocator: Allocator,
        ) void,
    };

    pub fn invoke(self: *const Algorithm, controller: *runtime.Instance) !*AsyncPromise(void) {
        return self.vtable.invoke(controller, self.context);
    }

    pub fn invokeWithArg(
        self: *const Algorithm,
        controller: *runtime.Instance,
        arg: *const anyopaque,
    ) !*AsyncPromise(void) {
        return self.vtable.invoke_with_arg(controller, self.context, arg);
    }

    pub fn deinit(self: *Algorithm) void {
        self.vtable.destroy(self.context, self.allocator);
    }
};

/// JavaScript Callback Algorithm
/// Wraps a WebIDL callback function
pub fn jsCallbackAlgorithm(
    allocator: Allocator,
    callback: *const anyopaque,
) !*Algorithm {
    const vtable = &js_callback_vtable;

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = @constCast(callback),
        .vtable = vtable,
        .allocator = allocator,
    };

    return algo;
}

const js_callback_vtable = Algorithm.VTable{
    .invoke = jsCallbackInvoke,
    .invoke_with_arg = jsCallbackInvokeWithArg,
    .destroy = jsCallbackDestroy,
};

fn jsCallbackInvoke(
    controller: *runtime.Instance,
    context: ?*anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();

    // Get engine interface for invoking JavaScript callbacks
    const engine = controller.ctx.getEngine() orelse {
        // No engine - return resolved promise (fallback for testing)
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Check if engine supports stream callback invocation
    const invoke_fn = engine.invokeStreamCallback orelse {
        // Engine doesn't support stream callbacks - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Get the engine context (V8 Context)
    const engine_ctx = controller.ctx.getEngineContext() orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Get the controller's V8 wrapper from cache using engine interface
    const controller_v8: ?*anyopaque = blk: {
        const get_wrapper_fn = engine.getWrapperForInstance orelse break :blk null;
        const cache_storage = controller.ctx.getV8WrapperCacheStorage() orelse break :blk null;
        break :blk get_wrapper_fn(engine_ctx, cache_storage, @ptrCast(controller));
    };

    // Invoke the JavaScript callback through the engine
    const js_callback = context orelse {
        // No callback stored - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const result = invoke_fn(
        engine_ctx,
        js_callback,
        controller_v8,
        null, // No additional argument for pull
    ) catch {
        // Invocation failed - return rejected promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream callback invocation failed",
        } });
        return promise;
    };

    // If invocation returned null, callback threw - return rejected promise
    if (result == null) {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream callback threw an exception",
        } });
        return promise;
    }

    // The result is a V8 Promise - we need to wrap it in an AsyncPromise
    // For now, return a resolved promise since we can't chain V8 promises easily
    // TODO: Bridge V8 Promise to AsyncPromise via then() callbacks
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    promise.fulfill({});
    return promise;
}

fn jsCallbackInvokeWithArg(
    controller: *runtime.Instance,
    context: ?*anyopaque,
    arg: *const anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();

    // Get engine interface for invoking JavaScript callbacks
    const engine = controller.ctx.getEngine() orelse {
        // No engine - return resolved promise (fallback for testing)
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Check if engine supports stream callback invocation
    const invoke_fn = engine.invokeStreamCallback orelse {
        // Engine doesn't support stream callbacks - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Get the engine context (V8 Context)
    const engine_ctx = controller.ctx.getEngineContext() orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Invoke the JavaScript callback through the engine with argument
    const js_callback = context orelse {
        // No callback stored - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const result = invoke_fn(
        engine_ctx,
        js_callback,
        null, // Controller not needed for cancel
        arg, // Pass the cancel reason
    ) catch {
        // Invocation failed - return rejected promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream cancel callback invocation failed",
        } });
        return promise;
    };

    // If invocation returned null, callback threw - return rejected promise
    if (result == null) {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream cancel callback threw an exception",
        } });
        return promise;
    }

    // The result is a V8 Promise - we need to wrap it in an AsyncPromise
    // For now, return a resolved promise since we can't chain V8 promises easily
    // TODO: Bridge V8 Promise to AsyncPromise via then() callbacks
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    promise.fulfill({});
    return promise;
}

fn jsCallbackDestroy(context: ?*anyopaque, allocator: Allocator) void {
    _ = context;
    _ = allocator;
    // JavaScript callbacks are managed by V8 GC, nothing to free
}

/// No-op Algorithm
/// Returns immediately resolved promise
pub fn noopAlgorithm(allocator: Allocator) !*Algorithm {
    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = null,
        .vtable = &noop_vtable,
        .allocator = allocator,
    };
    return algo;
}

const noop_vtable = Algorithm.VTable{
    .invoke = noopInvoke,
    .invoke_with_arg = noopInvokeWithArg,
    .destroy = noopDestroy,
};

fn noopInvoke(
    controller: *runtime.Instance,
    _: ?*anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    promise.fulfill({});
    return promise;
}

fn noopInvokeWithArg(
    controller: *runtime.Instance,
    _: ?*anyopaque,
    _: *const anyopaque,
) !*AsyncPromise(void) {
    return noopInvoke(controller, null);
}

fn noopDestroy(_: ?*anyopaque, _: Allocator) void {
    // Nothing to clean up
}
