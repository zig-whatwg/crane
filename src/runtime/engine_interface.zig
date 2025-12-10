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

/// Callback type for promise fulfillment handler
/// Called when a JS Promise fulfills
/// Arguments:
///   - context: The context pointer passed when creating the handler
///   - value: The fulfillment value (engine-specific), or null for undefined
pub const PromiseFulfillCallback = *const fn (context: ?*anyopaque, value: ?*anyopaque) callconv(.c) void;

/// Callback type for promise rejection handler
/// Called when a JS Promise rejects
/// Arguments:
///   - context: The context pointer passed when creating the handler
///   - reason: The rejection reason (engine-specific), or null for undefined
pub const PromiseRejectCallback = *const fn (context: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void;

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
    /// V8 object creation from template failed
    ObjectCreationFailed,
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

    /// Destroy a Promise handle after use
    ///
    /// Must be called after getPromiseObject() to free the handle allocated
    /// by createPromise(). The JS Promise object remains valid after this call
    /// (it's managed by V8's GC), but the handle cannot be used again.
    ///
    /// Arguments:
    ///   - promise_handle: Handle from createPromise
    ///   - allocator: Same allocator passed to createPromise
    destroyPromiseHandle: ?*const fn (
        promise_handle: *anyopaque,
        allocator: std.mem.Allocator,
    ) void,

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

    /// Create a JavaScript ArrayBuffer from bytes
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - bytes: Data to copy into ArrayBuffer
    ///
    /// Returns:
    ///   - Opaque pointer to JS ArrayBuffer value
    createArrayBuffer: ?*const fn (
        engine_ctx: *anyopaque,
        bytes: []const u8,
    ) EngineError!*anyopaque,

    /// Create a JavaScript Uint8Array from bytes
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - bytes: Data to copy into Uint8Array
    ///
    /// Returns:
    ///   - Opaque pointer to JS Uint8Array value
    createUint8Array: ?*const fn (
        engine_ctx: *anyopaque,
        bytes: []const u8,
    ) EngineError!*anyopaque,

    /// Parse JSON string and return JavaScript value
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - json_str: UTF-8 encoded JSON string
    ///
    /// Returns:
    ///   - Opaque pointer to parsed JS value
    parseJson: ?*const fn (
        engine_ctx: *anyopaque,
        json_str: []const u8,
    ) EngineError!*anyopaque,

    /// Wrap a Zig runtime.Instance as a JavaScript object
    ///
    /// Used to convert Zig interface instances (Blob, FormData, etc.) to
    /// their JavaScript wrapper objects for returning to JS code.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - instance: Pointer to runtime.Instance to wrap
    ///
    /// Returns:
    ///   - Opaque pointer to JS wrapper object
    wrapInstance: ?*const fn (
        engine_ctx: *anyopaque,
        instance: *anyopaque,
    ) EngineError!*anyopaque,

    /// Check if a JavaScript value is a string
    ///
    /// Arguments:
    ///   - js_value: Opaque pointer to JS value
    ///
    /// Returns:
    ///   - true if the value is a string
    isString: ?*const fn (
        js_value: *const anyopaque,
    ) bool,

    /// Extract a string from a JavaScript value
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - js_value: Opaque pointer to JS string value
    ///   - allocator: Allocator for the resulting string
    ///
    /// Returns:
    ///   - Zig slice containing the string data
    extractString: ?*const fn (
        engine_ctx: *anyopaque,
        js_value: *const anyopaque,
        allocator: std.mem.Allocator,
    ) EngineError![]const u8,

    /// Create a JavaScript array from a slice of strings
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - strings: Slice of string slices to convert
    ///
    /// Returns:
    ///   - Opaque pointer to JS array
    createStringArray: ?*const fn (
        engine_ctx: *anyopaque,
        strings: []const []const u8,
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

    /// Get the JS wrapper for a Zig runtime instance
    ///
    /// Used to retrieve the V8/JSC wrapper object for a Zig instance.
    /// This is needed when invoking JS callbacks that expect the wrapper.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - wrapper_cache: Opaque pointer to the wrapper cache
    ///   - instance: The Zig runtime instance
    ///
    /// Returns:
    ///   - Opaque pointer to JS wrapper object, or null if not cached
    getWrapperForInstance: ?*const fn (
        engine_ctx: *anyopaque,
        wrapper_cache: *anyopaque,
        instance: *anyopaque,
    ) ?*anyopaque,

    /// Chain a fulfillment/rejection handler to a JS Promise
    ///
    /// Used to bridge JS Promises to Zig AsyncPromise. When the JS Promise
    /// settles, the appropriate Zig callback is invoked.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - js_promise: Opaque pointer to JS Promise
    ///   - on_fulfill: Zig callback for fulfillment
    ///   - on_fulfill_ctx: Context pointer passed to fulfillment callback
    ///   - on_reject: Zig callback for rejection
    ///   - on_reject_ctx: Context pointer passed to rejection callback
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError on failure
    chainPromiseHandlers: ?*const fn (
        engine_ctx: *anyopaque,
        js_promise: *anyopaque,
        on_fulfill: PromiseFulfillCallback,
        on_fulfill_ctx: ?*anyopaque,
        on_reject: PromiseRejectCallback,
        on_reject_ctx: ?*anyopaque,
    ) EngineError!void,

    // ========================================================================
    // Script Execution Support
    // ========================================================================

    /// Compile a classic script from source
    ///
    /// Compiles JavaScript source code into an executable script object.
    /// The script can then be executed with runScript().
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - source: UTF-8 encoded JavaScript source code
    ///   - source_url: Optional URL for error messages and source maps
    ///
    /// Returns:
    ///   - Opaque pointer to compiled script object
    ///   - null if compilation failed (syntax error, etc.)
    ///   - EngineError on engine-level failure
    compileScript: ?*const fn (
        engine_ctx: *anyopaque,
        source: []const u8,
        source_url: ?[]const u8,
    ) EngineError!?*anyopaque,

    /// Run a compiled script
    ///
    /// Executes a previously compiled script in the current context.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - script: Compiled script from compileScript()
    ///
    /// Returns:
    ///   - Opaque pointer to result value (may be undefined)
    ///   - null if execution threw an exception
    ///   - EngineError on engine-level failure
    runScript: ?*const fn (
        engine_ctx: *anyopaque,
        script: *anyopaque,
    ) EngineError!?*anyopaque,

    /// Compile an ES module from source
    ///
    /// Compiles JavaScript module source code into a module object.
    /// The module must be instantiated and evaluated with runModule().
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - source: UTF-8 encoded JavaScript module source code
    ///   - source_url: URL for the module (required for import resolution)
    ///
    /// Returns:
    ///   - Opaque pointer to compiled module object
    ///   - null if compilation failed
    ///   - EngineError on engine-level failure
    compileModule: ?*const fn (
        engine_ctx: *anyopaque,
        source: []const u8,
        source_url: []const u8,
    ) EngineError!?*anyopaque,

    /// Instantiate and evaluate a module
    ///
    /// Links module dependencies and executes the module's top-level code.
    /// For modules with imports, the engine will use its module resolution
    /// callback to resolve specifiers.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - module: Compiled module from compileModule()
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError on instantiation or evaluation failure
    runModule: ?*const fn (
        engine_ctx: *anyopaque,
        module: *anyopaque,
    ) EngineError!void,

    /// Dispose of a compiled script
    ///
    /// Releases resources associated with a compiled script.
    /// Must be called when the script is no longer needed.
    ///
    /// Arguments:
    ///   - script: Compiled script from compileScript()
    disposeScript: ?*const fn (
        script: *anyopaque,
    ) void,

    /// Dispose of a compiled module
    ///
    /// Releases resources associated with a compiled module.
    /// Must be called when the module is no longer needed (e.g., document destruction).
    ///
    /// Arguments:
    ///   - module: Compiled module from compileModule()
    disposeModule: ?*const fn (
        module: *anyopaque,
    ) void,

    /// Evaluate a module asynchronously (for top-level await support)
    ///
    /// This function is specifically for modules that may contain top-level await.
    /// It returns a Promise that resolves when the module evaluation completes
    /// (including any awaited promises in top-level code).
    ///
    /// Per HTML Standard and TC39 proposal, top-level await:
    /// - Makes the module evaluation asynchronous
    /// - The evaluation Promise resolves when the module finishes executing
    /// - Parent modules wait for async dependencies before their own evaluation
    /// - Errors in TLA are propagated via Promise rejection
    ///
    /// Spec: https://tc39.es/proposal-top-level-await/
    /// HTML Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - module: Compiled and instantiated module from compileModule()
    ///
    /// Returns:
    ///   - Promise handle that resolves with the module namespace on success
    ///   - null if evaluation cannot start (module not instantiated)
    ///   - EngineError on engine-level failure
    ///
    /// Note: The returned Promise must be awaited for modules with TLA.
    /// For modules without TLA, the Promise resolves immediately.
    runModuleAsync: ?*const fn (
        engine_ctx: *anyopaque,
        module: *anyopaque,
    ) EngineError!?*anyopaque,

    /// Check if a module contains top-level await
    ///
    /// This can be used to determine if async evaluation is needed.
    /// Must be called after module instantiation.
    ///
    /// Arguments:
    ///   - module: Instantiated module from compileModule()
    ///
    /// Returns:
    ///   - true if the module or any of its dependencies has TLA
    ///   - false otherwise
    hasTopLevelAwait: ?*const fn (
        module: *anyopaque,
    ) bool,

    // ========================================================================
    // Bfcache Support (Back-Forward Cache)
    // ========================================================================

    /// Freeze a context for the back-forward cache
    ///
    /// Suspends task queue processing, retains the context, and prepares
    /// for potential DOM detachment. The context can be restored later
    /// with thaw().
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC Context, etc.)
    ///   - context_handle: Handle to the context being frozen
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError.OperationFailed if freeze cannot be performed
    ///
    /// Note: Freezing should:
    ///   - Stop timer and task processing
    ///   - Retain the context (don't destroy on navigation)
    ///   - Prepare for DOM detachment (optional)
    freeze: ?*const fn (
        engine_ctx: *anyopaque,
        context_handle: *anyopaque,
    ) EngineError!void,

    /// Thaw a context from the back-forward cache
    ///
    /// Re-enters the context, resumes task queue processing, and reattaches
    /// any detached DOM state.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - context_handle: Handle to the context being thawed
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError.OperationFailed if thaw cannot be performed
    ///
    /// Note: Thawing should:
    ///   - Re-enter the context (v8::Context::Enter())
    ///   - Resume timer and task processing
    ///   - Reattach any detached DOM state
    thaw: ?*const fn (
        engine_ctx: *anyopaque,
        context_handle: *anyopaque,
    ) EngineError!void,

    /// Check if a context is currently frozen
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - context_handle: Handle to check
    ///
    /// Returns:
    ///   - true if the context is frozen
    ///   - false otherwise
    isFrozen: ?*const fn (
        engine_ctx: *anyopaque,
        context_handle: *anyopaque,
    ) bool,

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
    .destroyPromiseHandle = null,
    .createString = null,
    .createArrayBuffer = null,
    .createUint8Array = null,
    .parseJson = null,
    .wrapInstance = null,
    .isString = null,
    .extractString = null,
    .createStringArray = null,
    .createEventLoop = null,
    .destroyEventLoop = null,
    .createCallbackWrapper = null,
    .invokeCallback = null,
    .destroyCallbackWrapper = null,
    .requestGarbageCollection = stubRequestGarbageCollection,
    .scheduleOnMainThread = stubScheduleOnMainThread,
    .invokeStreamCallback = stubInvokeStreamCallback,
    .getWrapperForInstance = stubGetWrapperForInstance,
    .chainPromiseHandlers = stubChainPromiseHandlers,
    .compileScript = stubCompileScript,
    .runScript = stubRunScript,
    .compileModule = stubCompileModule,
    .runModule = stubRunModule,
    .disposeScript = stubDisposeScript,
    .disposeModule = stubDisposeModule,
    .runModuleAsync = stubRunModuleAsync,
    .hasTopLevelAwait = stubHasTopLevelAwait,
    .freeze = stubFreeze,
    .thaw = stubThaw,
    .isFrozen = stubIsFrozen,
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

fn stubGetWrapperForInstance(
    _: *anyopaque,
    _: *anyopaque,
    _: *anyopaque,
) ?*anyopaque {
    // Stub: No wrapper cache available
    return null;
}

fn stubChainPromiseHandlers(
    _: *anyopaque,
    _: *anyopaque,
    _: PromiseFulfillCallback,
    _: ?*anyopaque,
    _: PromiseRejectCallback,
    _: ?*anyopaque,
) EngineError!void {
    // Stub: No JS engine available
    return EngineError.NoEngine;
}

fn stubCompileScript(
    _: *anyopaque,
    _: []const u8,
    _: ?[]const u8,
) EngineError!?*anyopaque {
    // Stub: No JS engine available for script compilation
    return EngineError.NoEngine;
}

fn stubRunScript(
    _: *anyopaque,
    _: *anyopaque,
) EngineError!?*anyopaque {
    // Stub: No JS engine available for script execution
    return EngineError.NoEngine;
}

fn stubCompileModule(
    _: *anyopaque,
    _: []const u8,
    _: []const u8,
) EngineError!?*anyopaque {
    // Stub: No JS engine available for module compilation
    return EngineError.NoEngine;
}

fn stubRunModule(
    _: *anyopaque,
    _: *anyopaque,
) EngineError!void {
    // Stub: No JS engine available for module execution
    return EngineError.NoEngine;
}

fn stubDisposeScript(
    _: *anyopaque,
) void {
    // Stub: Nothing to dispose
}

fn stubDisposeModule(
    _: *anyopaque,
) void {
    // Stub: Nothing to dispose
}

fn stubRunModuleAsync(
    _: *anyopaque,
    _: *anyopaque,
) EngineError!?*anyopaque {
    // Stub: No JS engine available for async module evaluation
    return EngineError.NoEngine;
}

fn stubHasTopLevelAwait(
    _: *anyopaque,
) bool {
    // Stub: No module to check, return false
    return false;
}

fn stubFreeze(
    _: *anyopaque,
    _: *anyopaque,
) EngineError!void {
    // Stub: No bfcache support
    return EngineError.OperationFailed;
}

fn stubThaw(
    _: *anyopaque,
    _: *anyopaque,
) EngineError!void {
    // Stub: No bfcache support
    return EngineError.OperationFailed;
}

fn stubIsFrozen(
    _: *anyopaque,
    _: *anyopaque,
) bool {
    // Stub: Never frozen
    return false;
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
