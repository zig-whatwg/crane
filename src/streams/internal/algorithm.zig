//! Algorithm abstraction for Streams
//!
//! Algorithms in WHATWG Streams represent operations that can be:
//! - JavaScript callbacks from underlyingSource (stored as V8 Global handles)
//! - Native Zig closures with captured state (for ReadableStream.from, etc.)
//! - No-op defaults (return undefined/resolved promise)
//!
//! This replaces the simple ?*const anyopaque function pointer approach
//! with a vtable-based system supporting context and proper lifecycle.
//!
//! ## V8 Handle Lifetime
//!
//! JavaScript callbacks are stored as V8 Global handles to survive HandleScope
//! destruction. When the JavaScript constructor returns, its HandleScope ends
//! and all Local handles become invalid. Global handles persist until explicitly
//! disposed.
//!
//! ## Reference Counting (RefCountedAlgorithm)
//!
//! The RefCountedAlgorithm wrapper provides safe sharing of Algorithm instances.
//! When an algorithm is copied (e.g., shared between stream and controller),
//! the reference count is incremented. Cleanup only happens when the last
//! reference is released.
//!
//! ```zig
//! const algo = try RefCountedAlgorithm.init(allocator, underlying_algorithm);
//! const copy = algo.clone(); // ref_count: 2
//! copy.deinit(); // ref_count: 1, no cleanup yet
//! algo.deinit(); // ref_count: 0, underlying algorithm destroyed
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const runtime = @import("runtime");
const callbacks = @import("callbacks");
const AsyncPromise = @import("async_promise").AsyncPromise;
const webidl = @import("webidl");
const v8_engine = @import("v8");

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

    /// Invoke with optional argument
    /// If arg is null, invokes without an argument (undefined in JS)
    pub fn invokeWithOptArg(
        self: *const Algorithm,
        controller: *runtime.Instance,
        arg: ?*anyopaque,
    ) !*AsyncPromise(void) {
        if (arg) |a| {
            return self.vtable.invoke_with_arg(controller, self.context, a);
        } else {
            // No argument - invoke without arg (will pass undefined to JS)
            return jsCallbackInvokeWithOptArg(controller, self.context, null);
        }
    }

    pub fn deinit(self: *Algorithm) void {
        self.vtable.destroy(self.context, self.allocator);
    }
};

// ============================================================================
// RefCountedAlgorithm - Safe sharing of Algorithm instances
// ============================================================================

/// Reference-counted wrapper for Algorithm instances.
///
/// This enables safe sharing of algorithms between streams and controllers
/// without memory leaks or double-frees. The underlying Algorithm is only
/// destroyed when the last reference is released.
///
/// ## Problem Solved
///
/// When an Algorithm is copied (e.g., stored in both stream and controller),
/// both copies point to the same context. Without reference counting:
/// - Both might try to call deinit → double-free
/// - One might not call deinit → memory leak
/// - Unclear ownership semantics
///
/// ## Thread Safety
///
/// Uses atomic operations for the reference count, making it safe to use
/// across threads (though V8 contexts are typically single-threaded).
///
/// ## Usage
///
/// ```zig
/// // Create a ref-counted algorithm
/// const algo = try RefCountedAlgorithm.init(allocator, try jsCallbackAlgorithmGlobal(...));
///
/// // Share with controller (increments ref count)
/// controller.algorithm = algo.clone();
///
/// // When stream is destroyed
/// stream.algorithm.deinit(); // ref_count decremented
///
/// // When controller is destroyed
/// controller.algorithm.deinit(); // ref_count hits 0, cleanup runs
/// ```
pub const RefCountedAlgorithm = struct {
    inner: *Inner,

    const Inner = struct {
        /// Reference count (atomic for thread safety)
        ref_count: std.atomic.Value(u32),

        /// The underlying Algorithm
        algorithm: *Algorithm,

        /// Allocator for freeing Inner struct
        allocator: Allocator,

        /// Increment reference count
        pub fn ref(self: *Inner) void {
            _ = self.ref_count.fetchAdd(1, .monotonic);
        }

        /// Decrement reference count, cleanup if zero
        pub fn unref(self: *Inner) void {
            // fetchSub returns the OLD value, so check if it was 1
            if (self.ref_count.fetchSub(1, .release) == 1) {
                // Ensure all writes are visible before cleanup
                std.atomic.fence(.acquire);

                // Destroy the underlying algorithm
                self.algorithm.deinit();
                self.allocator.destroy(self.algorithm);

                // Destroy Inner struct itself
                self.allocator.destroy(self);
            }
        }
    };

    /// Create a new reference-counted algorithm wrapper.
    ///
    /// Takes ownership of the provided Algorithm pointer.
    /// The Algorithm will be destroyed when the last RefCountedAlgorithm is deinit'd.
    pub fn init(allocator: Allocator, algorithm: *Algorithm) !RefCountedAlgorithm {
        const inner = try allocator.create(Inner);
        inner.* = .{
            .ref_count = std.atomic.Value(u32).init(1),
            .algorithm = algorithm,
            .allocator = allocator,
        };
        return .{ .inner = inner };
    }

    /// Clone the reference (increment ref count).
    ///
    /// Returns a new RefCountedAlgorithm that shares the same underlying Algorithm.
    /// Both the original and clone must be deinit'd.
    pub fn clone(self: RefCountedAlgorithm) RefCountedAlgorithm {
        self.inner.ref();
        return self;
    }

    /// Release this reference.
    ///
    /// Decrements the reference count. When the count reaches zero,
    /// the underlying Algorithm is destroyed.
    pub fn deinit(self: RefCountedAlgorithm) void {
        self.inner.unref();
    }

    /// Get the reference count (for debugging/testing).
    pub fn getRefCount(self: RefCountedAlgorithm) u32 {
        return self.inner.ref_count.load(.monotonic);
    }

    /// Invoke the algorithm (delegates to inner Algorithm).
    pub fn invoke(self: RefCountedAlgorithm, controller: *runtime.Instance) !*AsyncPromise(void) {
        return self.inner.algorithm.invoke(controller);
    }

    /// Invoke the algorithm with an argument.
    pub fn invokeWithArg(
        self: RefCountedAlgorithm,
        controller: *runtime.Instance,
        arg: *const anyopaque,
    ) !*AsyncPromise(void) {
        return self.inner.algorithm.invokeWithArg(controller, arg);
    }

    /// Invoke with optional argument.
    pub fn invokeWithOptArg(
        self: RefCountedAlgorithm,
        controller: *runtime.Instance,
        arg: ?*anyopaque,
    ) !*AsyncPromise(void) {
        return self.inner.algorithm.invokeWithOptArg(controller, arg);
    }

    /// Get the underlying Algorithm pointer (use with care).
    ///
    /// WARNING: Do not call deinit() on the returned Algorithm directly.
    /// Use RefCountedAlgorithm.deinit() instead.
    pub fn getAlgorithm(self: RefCountedAlgorithm) *Algorithm {
        return self.inner.algorithm;
    }
};

/// JavaScript Callback Algorithm (DEPRECATED - use jsCallbackAlgorithmGlobal)
/// Wraps a WebIDL callback function using raw pointer (unsafe after HandleScope ends)
///
/// WARNING: This stores a raw Local<Value> pointer which becomes invalid after
/// the constructor's HandleScope is destroyed. Use jsCallbackAlgorithmGlobal
/// for callbacks that need to survive HandleScope destruction.
///
/// Note: This function now handles tagged pointers from conversions.zig.
/// - `.runtime_instance` tagged pointers return error.NotAFunction
/// - Other tags are untagged and stored as-is (with lifetime risk)
pub fn jsCallbackAlgorithm(
    allocator: Allocator,
    callback: *const anyopaque,
) !*Algorithm {
    // Handle tagged pointers from conversions.zig
    const untagged = v8_engine.untagPointer(callback);

    switch (untagged.tag) {
        .runtime_instance => {
            // Interface objects cannot be called as functions
            return error.NotAFunction;
        },
        .global_handle, .local_value, .untagged => {
            // For deprecated API, just store the untagged pointer
            // (still unsafe after HandleScope ends!)
            const vtable = &js_callback_vtable;

            const algo = try allocator.create(Algorithm);
            algo.* = .{
                .context = untagged.ptr,
                .vtable = vtable,
                .allocator = allocator,
            };

            return algo;
        },
    }
}

const js_callback_vtable = Algorithm.VTable{
    .invoke = jsCallbackInvoke,
    .invoke_with_arg = jsCallbackInvokeWithArg,
    .destroy = jsCallbackDestroy,
};

/// Context for GlobalHandle-backed JavaScript callback algorithm
/// Stores the V8 Global handle and isolate needed for invocation and cleanup
const GlobalCallbackContext = struct {
    global_handle: v8_engine.GlobalHandle,
    isolate: *v8_engine.ffi.Isolate,
};

/// JavaScript Callback Algorithm with V8 Global Handle
///
/// Creates an algorithm that stores the JavaScript callback as a V8 Global handle,
/// which persists beyond HandleScope destruction. This is the correct way to store
/// callbacks from underlyingSource/underlyingSink that need to be invoked later.
///
/// ## Pointer Tagging Support
///
/// After the conversions.zig update, callback pointers may be TAGGED to indicate their type:
/// - `.global_handle`: Already a V8 Global handle (no conversion needed)
/// - `.runtime_instance`: A Zig runtime.Instance (cannot be called as function - error)
/// - `.local_value`: A V8 Local handle (needs Global conversion)
/// - `.untagged`: Legacy untagged pointer (treated as Local, needs Global conversion)
///
/// Parameters:
///   allocator: Memory allocator for the Algorithm struct
///   isolate: V8 isolate for creating the Global handle (if needed)
///   callback: Potentially tagged pointer from dictionary extraction
///
/// The Global handle is automatically disposed when the Algorithm is destroyed.
pub fn jsCallbackAlgorithmGlobal(
    allocator: Allocator,
    isolate: *v8_engine.ffi.Isolate,
    callback: *const anyopaque,
) !*Algorithm {
    // Check if the pointer is tagged and handle based on type
    const untagged = v8_engine.untagPointer(callback);

    switch (untagged.tag) {
        .runtime_instance => {
            // This is a runtime.Instance pointer, NOT a JS function!
            // Interface objects cannot be called as callbacks.
            // This indicates a type mismatch in the calling code.
            return error.NotAFunction;
        },

        .global_handle => {
            // Already a Global handle from conversions.zig
            // Wrap it directly without creating a new Global
            const global_ptr: *v8_engine.ffi.Value = @ptrCast(@alignCast(untagged.ptr));
            const global_handle = v8_engine.GlobalHandle{ .ptr = global_ptr };

            // Create context struct to hold Global handle and isolate
            const ctx = try allocator.create(GlobalCallbackContext);
            errdefer allocator.destroy(ctx);
            ctx.* = .{
                .global_handle = global_handle,
                .isolate = isolate,
            };

            const algo = try allocator.create(Algorithm);
            algo.* = .{
                .context = ctx,
                .vtable = &js_callback_global_vtable,
                .allocator = allocator,
            };

            return algo;
        },

        .local_value, .untagged => {
            // Local value or legacy untagged pointer - create Global handle from Local
            const global_handle = v8_engine.GlobalHandle.create(isolate, untagged.ptr) orelse {
                // Failed to create Global - callback is invalid or empty
                return error.InvalidCallback;
            };
            errdefer global_handle.dispose();

            // Create context struct to hold Global handle and isolate
            const ctx = try allocator.create(GlobalCallbackContext);
            errdefer allocator.destroy(ctx);
            ctx.* = .{
                .global_handle = global_handle,
                .isolate = isolate,
            };

            const algo = try allocator.create(Algorithm);
            algo.* = .{
                .context = ctx,
                .vtable = &js_callback_global_vtable,
                .allocator = allocator,
            };

            return algo;
        },
    }
}

const js_callback_global_vtable = Algorithm.VTable{
    .invoke = jsCallbackGlobalInvoke,
    .invoke_with_arg = jsCallbackGlobalInvokeWithArg,
    .destroy = jsCallbackGlobalDestroy,
};

fn jsCallbackGlobalInvoke(
    controller: *runtime.Instance,
    context: ?*anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();

    // Get the GlobalCallbackContext
    const ctx: *GlobalCallbackContext = @ptrCast(@alignCast(context orelse {
        // No callback stored - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    }));

    // Get Local from Global handle for this invocation
    const callback_local = ctx.global_handle.get(ctx.isolate) orelse {
        // Global handle is empty or invalid - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Now invoke using the Local handle (same as jsCallbackInvoke but with resolved handle)
    const engine = controller.ctx.getEngine() orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const invoke_fn = engine.invokeStreamCallback orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const engine_ctx = controller.ctx.getEngineContext() orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const controller_v8: ?*anyopaque = blk: {
        const get_wrapper_fn = engine.getWrapperForInstance orelse break :blk null;
        const cache_storage = controller.ctx.getV8WrapperCacheStorage() orelse break :blk null;
        break :blk get_wrapper_fn(engine_ctx, cache_storage, @ptrCast(controller));
    };

    const result = invoke_fn(
        engine_ctx,
        callback_local,
        controller_v8,
        null,
    ) catch {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream callback invocation failed",
        } });
        return promise;
    };

    if (result == null) {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream callback threw an exception",
        } });
        return promise;
    }

    const promise = try AsyncPromise(void).init(allocator, event_loop);
    try bridgeV8PromiseToAsync(engine, engine_ctx, result.?, promise, allocator);
    return promise;
}

fn jsCallbackGlobalInvokeWithArg(
    controller: *runtime.Instance,
    context: ?*anyopaque,
    arg: *const anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();

    // Get the GlobalCallbackContext
    const ctx: *GlobalCallbackContext = @ptrCast(@alignCast(context orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    }));

    // Get Local from Global handle for this invocation
    const callback_local = ctx.global_handle.get(ctx.isolate) orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const engine = controller.ctx.getEngine() orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const invoke_fn = engine.invokeStreamCallback orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const engine_ctx = controller.ctx.getEngineContext() orelse {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    const result = invoke_fn(
        engine_ctx,
        callback_local,
        null,
        arg,
    ) catch {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream cancel callback invocation failed",
        } });
        return promise;
    };

    if (result == null) {
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.reject(webidl.errors.Exception{ .simple = .{
            .type = .TypeError,
            .message = "Stream cancel callback threw an exception",
        } });
        return promise;
    }

    const promise = try AsyncPromise(void).init(allocator, event_loop);
    try bridgeV8PromiseToAsync(engine, engine_ctx, result.?, promise, allocator);
    return promise;
}

fn jsCallbackGlobalDestroy(context: ?*anyopaque, allocator: Allocator) void {
    const ctx: *GlobalCallbackContext = @ptrCast(@alignCast(context orelse return));

    // Dispose the V8 Global handle
    ctx.global_handle.dispose();

    // Free the context struct
    allocator.destroy(ctx);
}

/// Context structure for bridging V8 Promise to AsyncPromise
/// This is passed to the V8 promise handlers and freed after settlement
const PromiseBridgeContext = struct {
    promise: *AsyncPromise(void),
    allocator: Allocator,
};

/// Callback invoked when V8 Promise fulfills
/// Fulfills the corresponding AsyncPromise
fn v8PromiseFulfillCallback(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const bridge_ctx: *PromiseBridgeContext = @ptrCast(@alignCast(ctx orelse return));

    // Fulfill the AsyncPromise
    bridge_ctx.promise.fulfill({});

    // Clean up bridge context
    bridge_ctx.allocator.destroy(bridge_ctx);
}

/// Callback invoked when V8 Promise rejects
/// Rejects the corresponding AsyncPromise
fn v8PromiseRejectCallback(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const bridge_ctx: *PromiseBridgeContext = @ptrCast(@alignCast(ctx orelse return));

    // Reject the AsyncPromise with a generic error
    // Note: We could extract the error message from the V8 value if needed
    bridge_ctx.promise.reject(webidl.errors.Exception{ .simple = .{
        .type = .TypeError,
        .message = "Stream callback promise rejected",
    } });

    // Clean up bridge context
    bridge_ctx.allocator.destroy(bridge_ctx);
}

/// Bridge a V8 Promise result to an AsyncPromise
/// Creates handlers that fulfill/reject the AsyncPromise when the V8 Promise settles
fn bridgeV8PromiseToAsync(
    engine: *const runtime.EngineInterface,
    engine_ctx: *anyopaque,
    v8_promise: *anyopaque,
    async_promise: *AsyncPromise(void),
    allocator: Allocator,
) !void {
    const chain_fn = engine.chainPromiseHandlers orelse {
        // Engine doesn't support promise chaining - fulfill immediately
        async_promise.fulfill({});
        return;
    };

    // Create bridge context
    const bridge_ctx = try allocator.create(PromiseBridgeContext);
    bridge_ctx.* = .{
        .promise = async_promise,
        .allocator = allocator,
    };

    // Chain our handlers onto the V8 Promise
    chain_fn(
        engine_ctx,
        v8_promise,
        v8PromiseFulfillCallback,
        bridge_ctx,
        v8PromiseRejectCallback,
        bridge_ctx, // Same context for both - only one will be called
    ) catch {
        // Failed to chain - clean up and fulfill immediately
        allocator.destroy(bridge_ctx);
        async_promise.fulfill({});
    };
}

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

    // Create our AsyncPromise that will be settled when V8 Promise settles
    const promise = try AsyncPromise(void).init(allocator, event_loop);

    // Bridge the V8 Promise to our AsyncPromise
    try bridgeV8PromiseToAsync(engine, engine_ctx, result.?, promise, allocator);

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

    // Create our AsyncPromise that will be settled when V8 Promise settles
    const promise = try AsyncPromise(void).init(allocator, event_loop);

    // Bridge the V8 Promise to our AsyncPromise
    try bridgeV8PromiseToAsync(engine, engine_ctx, result.?, promise, allocator);

    return promise;
}

/// jsCallbackInvokeWithOptArg - Same as jsCallbackInvokeWithArg but arg is optional
/// If arg is null, the JS function is called without arguments (receives undefined)
fn jsCallbackInvokeWithOptArg(
    controller: *runtime.Instance,
    context: ?*anyopaque,
    arg: ?*const anyopaque,
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

    // Invoke the JavaScript callback through the engine
    const js_callback = context orelse {
        // No callback stored - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    };

    // Note: arg may be null here, which invoke_fn should handle by not passing the arg
    const result = invoke_fn(
        engine_ctx,
        js_callback,
        null, // Controller not needed for cancel
        arg, // Pass the optional cancel reason (may be null)
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

    // Create our AsyncPromise that will be settled when V8 Promise settles
    const promise = try AsyncPromise(void).init(allocator, event_loop);

    // Bridge the V8 Promise to our AsyncPromise
    try bridgeV8PromiseToAsync(engine, engine_ctx, result.?, promise, allocator);

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

// ============================================================================
// Zig Native Callback Algorithm
// ============================================================================

/// Context for Zig native callback algorithm
/// Stores the function pointers and user context
pub const ZigCallbackContext = struct {
    /// Pull callback function pointer
    pull_fn: ?*const fn (*runtime.Instance, ?*anyopaque) anyerror!void,
    /// Cancel callback function pointer
    cancel_fn: ?*const fn (?*const anyopaque, ?*anyopaque) anyerror!void,
    /// User context passed to callbacks
    user_context: ?*anyopaque,
};

/// Create an Algorithm from a Zig pull callback
///
/// This is for internal use when Zig code (e.g., Blob.stream()) needs to create
/// a ReadableStream with Zig function callbacks instead of JavaScript callbacks.
pub fn zigPullAlgorithm(
    allocator: Allocator,
    pull_fn: *const fn (*runtime.Instance, ?*anyopaque) anyerror!void,
    user_context: ?*anyopaque,
) !*Algorithm {
    const ctx = try allocator.create(ZigCallbackContext);
    errdefer allocator.destroy(ctx);
    ctx.* = .{
        .pull_fn = pull_fn,
        .cancel_fn = null,
        .user_context = user_context,
    };

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = ctx,
        .vtable = &zig_callback_vtable,
        .allocator = allocator,
    };

    return algo;
}

/// Create an Algorithm from a Zig cancel callback
///
/// This is for internal use when Zig code (e.g., Blob.stream()) needs to create
/// a ReadableStream with Zig function callbacks instead of JavaScript callbacks.
pub fn zigCancelAlgorithm(
    allocator: Allocator,
    cancel_fn: *const fn (?*const anyopaque, ?*anyopaque) anyerror!void,
    user_context: ?*anyopaque,
) !*Algorithm {
    const ctx = try allocator.create(ZigCallbackContext);
    errdefer allocator.destroy(ctx);
    ctx.* = .{
        .pull_fn = null,
        .cancel_fn = cancel_fn,
        .user_context = user_context,
    };

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = ctx,
        .vtable = &zig_callback_vtable,
        .allocator = allocator,
    };

    return algo;
}

const zig_callback_vtable = Algorithm.VTable{
    .invoke = zigCallbackInvoke,
    .invoke_with_arg = zigCallbackInvokeWithArg,
    .destroy = zigCallbackDestroy,
};

fn zigCallbackInvoke(
    controller: *runtime.Instance,
    context: ?*anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();

    const ctx: *ZigCallbackContext = @ptrCast(@alignCast(context orelse {
        // No context - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    }));

    if (ctx.pull_fn) |pull_fn| {
        // Invoke the Zig pull callback
        pull_fn(controller, ctx.user_context) catch |err| {
            // Callback returned error - reject promise
            const promise = try AsyncPromise(void).init(allocator, event_loop);
            promise.reject(webidl.errors.Exception{ .simple = .{
                .type = .TypeError,
                .message = @errorName(err),
            } });
            return promise;
        };
    }

    // Callback succeeded - return resolved promise
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    promise.fulfill({});
    return promise;
}

fn zigCallbackInvokeWithArg(
    controller: *runtime.Instance,
    context: ?*anyopaque,
    arg: *const anyopaque,
) !*AsyncPromise(void) {
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();

    const ctx: *ZigCallbackContext = @ptrCast(@alignCast(context orelse {
        // No context - return resolved promise
        const promise = try AsyncPromise(void).init(allocator, event_loop);
        promise.fulfill({});
        return promise;
    }));

    if (ctx.cancel_fn) |cancel_fn| {
        // Invoke the Zig cancel callback with reason
        cancel_fn(arg, ctx.user_context) catch |err| {
            // Callback returned error - reject promise
            const promise = try AsyncPromise(void).init(allocator, event_loop);
            promise.reject(webidl.errors.Exception{ .simple = .{
                .type = .TypeError,
                .message = @errorName(err),
            } });
            return promise;
        };
    }

    // Callback succeeded - return resolved promise
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    promise.fulfill({});
    return promise;
}

fn zigCallbackDestroy(context: ?*anyopaque, allocator: Allocator) void {
    if (context) |ctx| {
        const zig_ctx: *ZigCallbackContext = @ptrCast(@alignCast(ctx));
        allocator.destroy(zig_ctx);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "RefCountedAlgorithm: basic lifecycle" {
    const allocator = std.testing.allocator;

    // Create a noop algorithm for testing
    const algo = try noopAlgorithm(allocator);

    // Wrap in RefCountedAlgorithm
    const rc_algo = try RefCountedAlgorithm.init(allocator, algo);
    try std.testing.expectEqual(@as(u32, 1), rc_algo.getRefCount());

    // Deinit should clean up
    rc_algo.deinit();
    // No leak should be detected by testing allocator
}

test "RefCountedAlgorithm: clone increments ref count" {
    const allocator = std.testing.allocator;

    const algo = try noopAlgorithm(allocator);
    const rc_algo = try RefCountedAlgorithm.init(allocator, algo);

    try std.testing.expectEqual(@as(u32, 1), rc_algo.getRefCount());

    // Clone
    const clone1 = rc_algo.clone();
    try std.testing.expectEqual(@as(u32, 2), rc_algo.getRefCount());
    try std.testing.expectEqual(@as(u32, 2), clone1.getRefCount());

    // Clone again
    const clone2 = rc_algo.clone();
    try std.testing.expectEqual(@as(u32, 3), rc_algo.getRefCount());

    // Deinit clones
    clone1.deinit();
    try std.testing.expectEqual(@as(u32, 2), rc_algo.getRefCount());

    clone2.deinit();
    try std.testing.expectEqual(@as(u32, 1), rc_algo.getRefCount());

    // Deinit original - should cleanup
    rc_algo.deinit();
}

test "RefCountedAlgorithm: cleanup only on last unref" {
    const allocator = std.testing.allocator;

    // Use a tracking variable to verify cleanup
    var cleanup_count: u32 = 0;

    // Create a custom algorithm that tracks cleanup
    const TrackingContext = struct {
        count_ptr: *u32,
    };

    const tracking_ctx = try allocator.create(TrackingContext);
    tracking_ctx.* = .{ .count_ptr = &cleanup_count };

    const tracking_vtable = Algorithm.VTable{
        .invoke = struct {
            fn invoke(_: *runtime.Instance, _: ?*anyopaque) !*AsyncPromise(void) {
                unreachable; // Not called in this test
            }
        }.invoke,
        .invoke_with_arg = struct {
            fn invoke(_: *runtime.Instance, _: ?*anyopaque, _: *const anyopaque) !*AsyncPromise(void) {
                unreachable;
            }
        }.invoke,
        .destroy = struct {
            fn destroy(ctx: ?*anyopaque, alloc: Allocator) void {
                if (ctx) |c| {
                    const tc: *TrackingContext = @ptrCast(@alignCast(c));
                    tc.count_ptr.* += 1;
                    alloc.destroy(tc);
                }
            }
        }.destroy,
    };

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = tracking_ctx,
        .vtable = &tracking_vtable,
        .allocator = allocator,
    };

    const rc_algo = try RefCountedAlgorithm.init(allocator, algo);

    // Create clones
    const clone1 = rc_algo.clone();
    const clone2 = rc_algo.clone();

    // Verify no cleanup yet
    try std.testing.expectEqual(@as(u32, 0), cleanup_count);

    clone1.deinit();
    try std.testing.expectEqual(@as(u32, 0), cleanup_count); // Still 2 refs

    clone2.deinit();
    try std.testing.expectEqual(@as(u32, 0), cleanup_count); // Still 1 ref

    rc_algo.deinit();
    try std.testing.expectEqual(@as(u32, 1), cleanup_count); // Now cleanup ran!
}

test "RefCountedAlgorithm: getAlgorithm returns correct pointer" {
    const allocator = std.testing.allocator;

    const algo = try noopAlgorithm(allocator);
    const rc_algo = try RefCountedAlgorithm.init(allocator, algo);
    defer rc_algo.deinit();

    // getAlgorithm should return the same pointer
    try std.testing.expectEqual(algo, rc_algo.getAlgorithm());
}
