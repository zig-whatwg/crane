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
    const callback_ptr = context orelse return error.InvalidAlgorithm;
    const callback: callbacks.UnderlyingSourcePullCallback =
        @ptrCast(@alignCast(callback_ptr));

    // Call JavaScript callback
    _ = callback(@ptrCast(controller));
    // TODO: Handle promise returned by callback

    // Wrap result in promise (callback returns *const anyopaque which is a promise)
    // For now, create resolved promise
    const promise = try AsyncPromise(void).init(
        controller.allocator,
        controller.ctx.getEventLoop(),
    );
    promise.fulfill({});
    return promise;
}

fn jsCallbackInvokeWithArg(
    controller: *runtime.Instance,
    context: ?*anyopaque,
    arg: *const anyopaque,
) !*AsyncPromise(void) {
    // TODO: Pass arg to callback when cancel algorithm is implemented
    _ = arg;
    // Similar to jsCallbackInvoke but with argument
    return jsCallbackInvoke(controller, context);
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
    const promise = try AsyncPromise(void).init(
        controller.allocator,
        controller.ctx.getEventLoop(),
    );
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
