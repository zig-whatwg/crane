//! Abstract JavaScript Engine Interface
//!
//! This module defines the interface that all JavaScript engine implementations
//! must satisfy. It provides engine-agnostic operations for WebIDL bindings.
//!
//! ## Design Goals
//!
//! 1. **Engine Independence**: WebIDL impl files should not import engine-specific code
//! 2. **Runtime Dispatch**: Engine operations dispatched through vtable at runtime
//! 3. **Zero Cost When Unused**: No overhead when engine operations aren't called
//! 4. **Type Safety**: Zig's type system ensures correct usage
//!
//! ## Supported Engines
//!
//! - V8 (implemented in src/runtime/engines/v8/)
//! - JSC (future)
//! - SpiderMonkey (future)
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! pub fn call_values(instance: *runtime.Instance, options: Options) !*const anyopaque {
//!     const ctx = instance.ctx;
//!
//!     // Create Zig-side iterator (engine-agnostic)
//!     const zig_iterator = try createAsyncIterator(ctx, instance, options);
//!
//!     // Wrap for JS engine (engine-specific, but abstracted)
//!     const engine = ctx.getEngine() orelse return error.NoEngine;
//!     return try engine.wrapAsyncIterator(ctx, zig_iterator);
//! }
//! ```

const std = @import("std");

/// Callback signature for main thread scheduling
///
/// This is the function that will be called on the main thread.
/// The user_data pointer is passed through from scheduleOnMainThread.
pub const MainThreadCallback = *const fn (user_data: *anyopaque) void;

/// Error set for engine operations
pub const EngineError = error{
    /// No engine is configured in the context
    NoEngine,
    /// Engine operation failed
    OperationFailed,
    /// Memory allocation failed
    OutOfMemory,
    /// Type conversion failed
    TypeError,
    /// Promise creation/resolution failed
    PromiseError,
    /// Async iterator wrapping failed
    AsyncIteratorError,
    /// Interface registration failed
    RegistrationFailed,
};

/// Abstract interface for JavaScript engine operations
///
/// All engine implementations (V8, JSC, etc.) must provide these operations.
/// The interface uses function pointers for runtime dispatch, allowing
/// engine selection without recompilation of WebIDL code.
pub const EngineInterface = struct {
    /// Wrap a Zig async iterator for the JS engine
    ///
    /// Takes a Zig async iterator (e.g., ReadableStreamAsyncIterator) and
    /// returns an engine-specific async iterator object that JavaScript
    /// can use with `for await...of` loops.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Isolate, JSC VM, etc.)
    ///   - zig_iterator: Pointer to Zig async iterator
    ///
    /// Returns:
    ///   - Opaque pointer to engine's async iterator object
    wrapAsyncIterator: *const fn (
        engine_ctx: *anyopaque,
        zig_iterator: *anyopaque,
    ) EngineError!*anyopaque,

    /// Create a Promise that can be resolved/rejected from Zig
    ///
    /// Returns a handle that can be used with resolvePromise/rejectPromise.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - allocator: Allocator for any needed storage
    ///
    /// Returns:
    ///   - Opaque pointer to promise handle
    createPromise: *const fn (
        engine_ctx: *anyopaque,
        allocator: std.mem.Allocator,
    ) EngineError!*anyopaque,

    /// Resolve a Promise with a value
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - promise_handle: Handle from createPromise
    ///   - value: Opaque pointer to value (engine will convert)
    resolvePromise: *const fn (
        engine_ctx: *anyopaque,
        promise_handle: *anyopaque,
        value: ?*const anyopaque,
    ) EngineError!void,

    /// Reject a Promise with an error
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - promise_handle: Handle from createPromise
    ///   - err: Error to reject with
    rejectPromise: *const fn (
        engine_ctx: *anyopaque,
        promise_handle: *anyopaque,
        err: anyerror,
    ) EngineError!void,

    /// Get the Promise object to return to JavaScript
    ///
    /// Arguments:
    ///   - promise_handle: Handle from createPromise
    ///
    /// Returns:
    ///   - Opaque pointer to the JS Promise object
    getPromiseObject: *const fn (
        promise_handle: *anyopaque,
    ) *anyopaque,

    /// Create a JavaScript string from UTF-8 bytes
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - bytes: UTF-8 encoded string data
    ///
    /// Returns:
    ///   - Opaque pointer to JS string value
    createString: ?*const fn (
        engine_ctx: *anyopaque,
        bytes: []const u8,
    ) EngineError!*anyopaque,

    /// Create an event loop for async operations
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - allocator: Allocator for event loop storage
    ///
    /// Returns:
    ///   - Opaque pointer to event loop
    createEventLoop: ?*const fn (
        engine_ctx: *anyopaque,
        allocator: std.mem.Allocator,
    ) EngineError!*anyopaque,

    /// Destroy an event loop
    ///
    /// Arguments:
    ///   - event_loop: Event loop from createEventLoop
    ///   - allocator: Same allocator used to create it
    destroyEventLoop: ?*const fn (
        event_loop: *anyopaque,
        allocator: std.mem.Allocator,
    ) void,

    // ========================================================================
    // Callback Interface Support
    // ========================================================================

    /// Create a callback wrapper from a JavaScript value
    ///
    /// Used for WebIDL callback interfaces (EventListener, NodeFilter, etc.)
    /// The wrapper stores a persistent reference to the JS function/object.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, etc.)
    ///   - js_value: Opaque pointer to JS value (function or object)
    ///   - method_name: For object callbacks, the method to call (e.g., "handleEvent")
    ///   - allocator: Allocator for wrapper storage
    ///
    /// Returns:
    ///   - Opaque pointer to callback wrapper, or null if value is not callable
    createCallbackWrapper: ?*const fn (
        engine_ctx: *anyopaque,
        js_value: *anyopaque,
        method_name: [*:0]const u8,
        allocator: std.mem.Allocator,
    ) EngineError!?*anyopaque,

    /// Invoke a callback wrapper with arguments
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - callback_wrapper: Wrapper from createCallbackWrapper
    ///   - args: Array of opaque pointers to JS values
    ///   - args_len: Number of arguments
    ///
    /// Returns:
    ///   - Opaque pointer to return value (may be undefined)
    invokeCallback: ?*const fn (
        engine_ctx: *anyopaque,
        callback_wrapper: *anyopaque,
        args: [*]const *anyopaque,
        args_len: usize,
    ) EngineError!?*anyopaque,

    /// Destroy a callback wrapper
    ///
    /// Releases the persistent handle to the JS function/object.
    ///
    /// Arguments:
    ///   - callback_wrapper: Wrapper from createCallbackWrapper
    destroyCallbackWrapper: ?*const fn (
        callback_wrapper: *anyopaque,
    ) void,

    // ========================================================================
    // Garbage Collection (TestUtils support)
    // ========================================================================

    /// Request garbage collection (implementation-defined)
    ///
    /// Per WHATWG TestUtils spec, this performs "implementation-defined steps
    /// to perform a garbage collection". Each engine decides the GC strategy:
    /// - V8: May use LowMemoryNotification() or RequestGarbageCollectionForTesting()
    /// - JSC: May use JSGarbageCollect()
    /// - SpiderMonkey: May use JS_GC()
    ///
    /// The GC should cover "at least the entry Realm" but engines typically
    /// perform GC at the isolate/VM level which exceeds this requirement.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Isolate, JSC VM, etc.)
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError.OperationFailed if GC could not be performed
    ///   - EngineError.NoEngine if GC is not supported
    ///
    /// Thread Safety:
    ///   This function may be called from any thread. The engine implementation
    ///   must handle thread safety appropriately (e.g., V8 requires Locker).
    ///
    /// Note: This is for testing only. Must not be enabled in production builds.
    /// See: https://testutils.spec.whatwg.org/
    requestGarbageCollection: ?*const fn (
        engine_ctx: *anyopaque,
    ) EngineError!void,

    // ========================================================================
    // Main Thread Scheduling (Cross-thread coordination)
    // ========================================================================

    /// Schedule a callback to run on the main JavaScript thread
    ///
    /// This is used for cross-thread coordination when async operations
    /// complete on background threads and need to interact with the JS engine
    /// (e.g., resolving Promises, firing events).
    ///
    /// The callback will be invoked on the next tick of the engine's event loop,
    /// in the context of the main thread where JavaScript executes.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Isolate, JSC VM, etc.)
    ///   - callback: Function to call on main thread
    ///   - user_data: Opaque data passed to callback
    ///
    /// Returns:
    ///   - void on success (callback scheduled)
    ///   - EngineError.OperationFailed if scheduling failed
    ///
    /// Thread Safety:
    ///   This function is SAFE to call from any thread. That's the entire point -
    ///   it allows background threads to post work to the main thread.
    ///
    /// Memory:
    ///   The caller is responsible for ensuring user_data remains valid until
    ///   the callback is invoked. Typically this means allocating user_data on
    ///   the heap and freeing it in the callback.
    ///
    /// Engine Implementation Notes:
    ///   - V8: Use platform->GetForegroundTaskRunner(isolate)->PostTask()
    ///   - JSC: Use dispatch_async to main queue
    ///   - SpiderMonkey: Use JS_RequestInterruptCallback
    scheduleOnMainThread: ?*const fn (
        engine_ctx: *anyopaque,
        callback: MainThreadCallback,
        user_data: *anyopaque,
    ) EngineError!void,

    // ========================================================================
    // Stream Algorithm Callback Support
    // ========================================================================

    /// Invoke a JavaScript callback function for stream algorithms
    ///
    /// Used by WHATWG Streams to invoke pull(), cancel(), start() callbacks.
    /// The callback is a JS function stored as an opaque pointer (V8 Global<Value>*).
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - js_callback: Opaque pointer to JS function (V8 Global<Value>*)
    ///   - controller_v8: Opaque pointer to V8 wrapper of controller (or null)
    ///   - arg: Optional argument (e.g., reason for cancel)
    ///
    /// Returns:
    ///   - Opaque pointer to resulting Promise, or null on failure
    ///
    /// Note: The returned Promise should be awaited or the result handled by
    /// the stream machinery. The caller is responsible for any cleanup.
    invokeStreamCallback: ?*const fn (
        engine_ctx: *anyopaque,
        js_callback: *const anyopaque,
        controller_v8: ?*anyopaque,
        arg: ?*const anyopaque,
    ) EngineError!?*anyopaque,

    /// Engine name for debugging/logging
    name: []const u8,

    /// Engine version string
    version: []const u8,
};

/// Stub engine interface for testing without a JS engine
///
/// All operations return errors, useful for testing Zig-only code paths.
pub const stub_engine: EngineInterface = .{
    .wrapAsyncIterator = stubWrapAsyncIterator,
    .createPromise = stubCreatePromise,
    .resolvePromise = stubResolvePromise,
    .rejectPromise = stubRejectPromise,
    .getPromiseObject = stubGetPromiseObject,
    .createString = null,
    .createEventLoop = null,
    .destroyEventLoop = null,
    .createCallbackWrapper = null,
    .invokeCallback = null,
    .destroyCallbackWrapper = null,
    .requestGarbageCollection = stubRequestGarbageCollection,
    .scheduleOnMainThread = stubScheduleOnMainThread,
    .invokeStreamCallback = stubInvokeStreamCallback,
    .name = "stub",
    .version = "0.0.0",
};

fn stubWrapAsyncIterator(_: *anyopaque, _: *anyopaque) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubCreatePromise(_: *anyopaque, _: std.mem.Allocator) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubResolvePromise(_: *anyopaque, _: *anyopaque, _: ?*const anyopaque) EngineError!void {
    return EngineError.NoEngine;
}

fn stubRejectPromise(_: *anyopaque, _: *anyopaque, _: anyerror) EngineError!void {
    return EngineError.NoEngine;
}

fn stubGetPromiseObject(_: *anyopaque) *anyopaque {
    // This should never be called if createPromise returns error
    unreachable;
}

fn stubRequestGarbageCollection(_: *anyopaque) EngineError!void {
    // Stub engine has no GC - return success (no-op)
    // This allows testing without a real engine
    return;
}

fn stubScheduleOnMainThread(
    _: *anyopaque,
    callback: MainThreadCallback,
    user_data: *anyopaque,
) EngineError!void {
    // Stub: Execute callback immediately (for testing without real engine)
    // In real engines, this would post to the event loop
    callback(user_data);
}

fn stubInvokeStreamCallback(
    _: *anyopaque,
    _: *const anyopaque,
    _: ?*anyopaque,
    _: ?*const anyopaque,
) EngineError!?*anyopaque {
    // Stub: No JS engine available, can't invoke callback
    return EngineError.NoEngine;
}

// ============================================================================
// Tests
// ============================================================================

test "EngineInterface - stub returns errors" {
    const testing = std.testing;

    // All stub operations should return NoEngine error
    try testing.expectError(EngineError.NoEngine, stub_engine.wrapAsyncIterator(undefined, undefined));
    try testing.expectError(EngineError.NoEngine, stub_engine.createPromise(undefined, testing.allocator));
}

test "EngineInterface - struct size" {
    const testing = std.testing;

    // Interface should be reasonably small (just function pointers + strings)
    try testing.expect(@sizeOf(EngineInterface) < 128);
}
