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
const JSValue = @import("js_value.zig").JSValue;
const Context = @import("context.zig").Context;
const Instance = @import("instance.zig").Instance;

/// Callback signature for main thread scheduling
///
/// This is the function that will be called on the main thread.
/// The user_data pointer is passed through from scheduleOnMainThread.
///
/// KEEP: user_data is *anyopaque - Required for C ABI callback compatibility.
/// Cross-thread callbacks need type-erased context because the concrete type
/// is determined by the caller, not this interface.
pub const MainThreadCallback = *const fn (user_data: *anyopaque) void;

/// Callback type for promise fulfillment handler
/// Called when a JS Promise fulfills
///
/// KEEP: Uses *anyopaque for both parameters - Required for C ABI compatibility.
/// - context: Type-erased user data (caller-determined type)
/// - value: Engine-specific JS value (V8 Value*, JSC JSValue, etc.)
///
/// Arguments:
///   - context: The context pointer passed when creating the handler
///   - value: The fulfillment value (engine-specific), or null for undefined
pub const PromiseFulfillCallback = *const fn (context: ?*anyopaque, value: ?*anyopaque) callconv(.c) void;

/// Callback type for promise rejection handler
/// Called when a JS Promise rejects
///
/// KEEP: Uses *anyopaque for both parameters - Required for C ABI compatibility.
/// - context: Type-erased user data (caller-determined type)
/// - reason: Engine-specific JS value (V8 Value*, JSC JSValue, etc.)
///
/// Arguments:
///   - context: The context pointer passed when creating the handler
///   - reason: The rejection reason (engine-specific), or null for undefined
pub const PromiseRejectCallback = *const fn (context: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void;

/// Callback type for forEach-style iteration over collections
///
/// Called for each element in a JS collection (Array, Set, Map, NodeList, etc.).
/// The callback receives the element value, its index, and user data.
///
/// KEEP: Uses *anyopaque for value and user_data - Required for runtime polymorphism.
/// - value: Engine-specific JS value (type varies by collection element)
/// - user_data: Type-erased caller context (caller-determined type)
///
/// Arguments:
///   - value: Opaque pointer to the element value
///   - index: Zero-based index of the element (for arrays), or iteration count (for Sets/Maps)
///   - user_data: Context pointer passed to invokeForEach
///
/// Returns:
///   - true to continue iteration
///   - false to break early (short-circuit)
pub const ForEachCallback = *const fn (
    value: *anyopaque,
    index: u32,
    user_data: *anyopaque,
) bool;

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
    /// Script threw (a getter, a conversion) and the exception is pending
    /// in the engine: return without throwing another.
    ExceptionPending,
    /// V8 object creation from template failed
    ObjectCreationFailed,
    /// This engine does not provide the operation (AGENTS.md, "The engine
    /// boundary": every Engine operation has an explicit entry in every
    /// engine's table, so a missing one fails loudly, never silently).
    NotSupported,
    /// HTML: the value is not serializable - "throw a DataCloneError" where
    /// nothing has been thrown yet (compare ExceptionPending).
    DataCloneError,
};

/// HTML "extract error information" (8.1.4.6 "report an exception", step 2)
/// from a thrown value: what an ErrorEvent carries.
///
/// BORROWED FOR THE CALL: every field, `error_value` included, is valid only
/// until the callback it is handed to returns. A reporter that keeps any of it
/// copies it first.
pub const ErrorInfo = struct {
    message: []const u8,
    /// The script's URL, or "" when it has none.
    filename: []const u8,
    /// 1-based; 0 when unknown.
    lineno: u32,
    /// 1-based, as every engine that reports ErrorEvent.colno counts; 0 when
    /// unknown.
    colno: u32,
    /// The thrown value itself - `runtime.JSValue.handle` with
    /// `needs_disposal = false`, since the engine owns it.
    error_value: ?JSValue,
};

/// HTML "report an exception", as the host supplies it to an operation that
/// runs script with "rethrow errors" false. The engine calls it from inside
/// the operation, before any microtask checkpoint and with the engine's
/// automatic checkpoints held off - "run a classic script" reports (step 8)
/// before "clean up after running script" performs the checkpoint (step 9).
/// `host` is the pointer the caller passed alongside it.
pub const ReportExceptionFn = *const fn (host: ?*anyopaque, info: *const ErrorInfo) void;

/// Steps an operation runs inside a realm: `data` is the pointer the caller
/// passed alongside them.
pub const RealmSteps = *const fn (data: ?*anyopaque) void;

/// The Engine table of the engine this build selected (`-Dengine=`), as its
/// adapter registered it when the engine was initialized - the way code with
/// no realm yet (a browser's first navigation) reaches `createWindowRealm`.
/// Null before any engine has been initialized. Process-wide: every agent and
/// thread uses the same table.
var configured_engine: ?*const EngineInterface = null;

/// The build's engine, or null before it is initialized.
pub fn configuredEngine() ?*const EngineInterface {
    return configured_engine;
}

/// Called by an engine adapter when it initializes its engine.
pub fn setConfiguredEngine(engine: *const EngineInterface) void {
    configured_engine = engine;
}

// Lane regions for types the lanes' operations use (declarations cannot go
// between container fields). Each lane declares only inside its own region.
// ---- lane: page-realm ----

/// The `this` value a callback function is invoked with - WebIDL "invoke a
/// callback function", its callback this value.
pub const CallbackThis = union(enum) {
    /// undefined: WebIDL's value when the caller gives none.
    undefined,
    /// The realm's global this binding: for a Window realm its WindowProxy.
    global_this,
    /// This value, BORROWED for the call.
    value: JSValue,
};

/// setTimeout's and setInterval's `TimerHandler` - `(TrustedScript or
/// DOMString or Function)` - after WebIDL conversion. Either way an OWNED
/// handle, which its holder releases with `releaseValue`.
pub const WindowTimerHandler = union(enum) {
    /// A callable: the union conversion picks the Function member.
    function: JSValue,
    /// Anything else, converted by ToString when setTimeout or setInterval was
    /// called - which runs script, so it happens at the call and not when the
    /// timer fires. (A TrustedScript converts the same way: its stringifier is
    /// its data.) A string handle, so the source keeps every code unit until
    /// it runs.
    string: JSValue,
};

/// The host's steps behind a Window's native operations: its timers (HTML
/// 8.6, "timers") and its animation frames (HTML 8.10). The engine binds the
/// operations - WebIDL argument conversion, the return value - and calls
/// these with the converted values; the host keeps the spec's state (the map
/// of active timers, the map of animation frame callbacks). `realm` is the
/// realm of the function that was called: the Window whose method it is.
pub const WindowOperations = struct {
    /// The timer initialization steps, for setTimeout (`repeat` false) and
    /// setInterval (`repeat` true). `handler` and every element of
    /// `arguments` are OWNED and handed over - the host releases each with
    /// `releaseValue` - while the `arguments` slice itself is BORROWED for the
    /// call. Returns the id script receives, or 0 when no timer was set.
    initializeTimer: *const fn (realm: Context, handler: WindowTimerHandler, timeout: i32, arguments: []const JSValue, repeat: bool) i32,
    /// clearTimeout(id) and clearInterval(id): `id` after ToInt32.
    clearTimer: *const fn (realm: Context, id: i32) void,
    /// requestAnimationFrame(callback), for a callable `callback`, OWNED and
    /// handed over. Returns the handle, or 0 when none was registered.
    requestAnimationFrame: *const fn (realm: Context, callback: JSValue) u32,
    /// cancelAnimationFrame(handle), for a handle in 1..2^32-1.
    cancelAnimationFrame: *const fn (realm: Context, handle: u32) void,
    /// A frame's Window realm whose document is being destroyed (HTML
    /// "unloading document cleanup steps": clear its map of active timers; its
    /// animation frame callbacks go with it). Called while the realm is still
    /// intact.
    windowDestroyed: *const fn (realm: Context) void,
};

// ---- end lane: page-realm ----
// ---- lane: runtime-impls ----
// ---- end lane: runtime-impls ----

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

    /// Read a property off a JS object and report its ECMAScript truthiness.
    ///
    /// The engine-agnostic primitive that was missing. WebIDL dictionaries
    /// arrive at an impl as an opaque object handle, and without this the only
    /// ways to read one were to import V8 into the impl - growing the boundary
    /// debt - or to ignore the dictionary entirely, which is what
    /// `addEventListener` did: `{capture: true}` silently flattened to false.
    ///
    /// Truthiness rather than the raw value because that is what a
    /// `boolean` dictionary member needs, and `{capture: 2}` must be true.
    /// A richer accessor can come when something needs one.
    ///
    /// Returns `default` when the object has no such property, so a caller
    /// need not distinguish "absent" from "present and falsy" unless it wants
    /// to - the two are the same for a defaulted boolean member.
    getPropertyTruthy: ?*const fn (
        engine_ctx: *anyopaque,
        object: *anyopaque,
        name: []const u8,
        default: bool,
    ) EngineError!bool,

    /// Read a `boolean` dictionary member off a JS object (WebIDL 3.2.18):
    /// null when the member is absent (the property reads as undefined),
    /// otherwise its ToBoolean. Unlike `getPropertyTruthy` it tells an
    /// absent member from a false one, which "if options[passive] exists"
    /// needs, and it reports a throwing getter as `ExceptionPending`.
    getPropertyBoolean: ?*const fn (
        engine_ctx: *anyopaque,
        object: *anyopaque,
        name: []const u8,
    ) EngineError!?bool,

    /// Read an interface-typed dictionary member off a JS object: null when
    /// absent, the platform object's Instance when it is one, `TypeError`
    /// for any other value (null included - a nullable member would say
    /// so), `ExceptionPending` when the getter threw. Which interface the
    /// Instance implements is the caller's check (`stateAs`).
    getPropertyInstance: ?*const fn (
        engine_ctx: *anyopaque,
        object: *anyopaque,
        name: []const u8,
    ) EngineError!?*anyopaque,

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

    /// Set a property on a JavaScript object using [[Set]] semantics
    ///
    /// Per WebIDL [PutForwards] extended attribute: the assignment is performed
    /// by invoking the [[Set]] internal method of the object with the property
    /// name as the key and the assigned value.
    ///
    /// This respects the JavaScript prototype chain, getters/setters, and
    /// user-defined property descriptors.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - target: Opaque pointer to JS object to set property on
    ///   - property_name: Name of the property to set
    ///   - value: String value to set (for [PutForwards], this is always a string)
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError.TypeError if target is not an object
    ///   - EngineError.OperationFailed if [[Set]] returns false
    setPropertyOnObject: ?*const fn (
        engine_ctx: *anyopaque,
        target: *anyopaque,
        property_name: []const u8,
        value: []const u8,
    ) EngineError!void,

    /// Define an own property on a JavaScript object using [[DefineOwnProperty]] semantics
    ///
    /// Per WebIDL [Replaceable] extended attribute: the setter steps are to perform
    /// ? [[DefineOwnProperty]] on this with the attribute's identifier as the property
    /// name and PropertyDescriptor{[[Value]]: V, [[Writable]]: true, [[Enumerable]]: true,
    /// [[Configurable]]: true}.
    ///
    /// This creates an own data property on the object, shadowing any inherited
    /// accessor property (like the readonly getter).
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - target: Opaque pointer to JS object to define property on
    ///   - property_name: Name of the property to define
    ///   - value: Any JavaScript value to set as the property value
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError.TypeError if target is not an object
    ///   - EngineError.OperationFailed if [[DefineOwnProperty]] returns false
    defineOwnPropertyOnObject: ?*const fn (
        engine_ctx: *anyopaque,
        target: *anyopaque,
        property_name: []const u8,
        value: *anyopaque,
    ) EngineError!void,

    /// Convert an engine-agnostic runtime.JSValue to an engine-specific value pointer
    ///
    /// This is used when impl code needs to pass a runtime.JSValue to engine APIs
    /// that expect engine-native pointers (e.g., defineOwnPropertyOnObject).
    ///
    /// The conversion handles all JSValue variants:
    /// - undefined → engine's undefined value
    /// - null → engine's null value
    /// - boolean → engine's boolean value
    /// - number → engine's number value
    /// - string → engine's string value
    /// - handle → returns the engine handle directly
    /// - instance → wraps the instance as a JS object
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - value: The engine-agnostic JSValue to convert
    ///
    /// Returns:
    ///   - Opaque pointer to the engine-native value
    ///   - EngineError if conversion fails
    convertJSValueToEngine: ?*const fn (
        engine_ctx: *anyopaque,
        value: JSValue,
    ) EngineError!*anyopaque,

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

    /// HTML "create a classic script" (8.1.4.2) from `source` and "run a
    /// classic script" (8.1.4.4) with rethrow errors false, in `realm`: a parse error or a thrown exception is handed to
    /// `report` (see `ReportExceptionFn`) and is not returned. The engine
    /// opens and closes whatever scope it needs, so a caller needs none, and
    /// no engine handle outlives the call. Muting (step 8's "muted errors")
    /// is the reporter's to apply; the engine reports what was thrown.
    ///
    /// "Clean up after running script" is the caller's: call
    /// `performMicrotaskCheckpoint` when the JavaScript execution context
    /// stack is empty.
    ///
    /// Arguments:
    ///   - realm: the realm to run in (a runtime.Context)
    ///   - source: UTF-8 source text
    ///   - source_url: the script's URL (the base for its errors), or null
    ///   - report, host: the host's "report an exception" and its context
    runClassicScript: ?*const fn (
        realm: Context,
        source: []const u8,
        source_url: ?[]const u8,
        report: ReportExceptionFn,
        host: ?*anyopaque,
    ) EngineError!void,

    /// HTML "perform a microtask checkpoint" (8.1.7.3) for the agent `realm`
    /// belongs to: run the microtask queue until it is empty.
    /// "Clean up after running script" performs it when the JavaScript
    /// execution context stack is empty.
    performMicrotaskCheckpoint: ?*const fn (
        realm: Context,
    ) EngineError!void,

    /// HTML "queue a global task" (8.1.7.1), the task's run side: run
    /// `steps` as a task of `realm` - entering the realm (for a
    /// worker realm on this thread, its agent too), and afterwards doing
    /// what ends a task there: the microtask checkpoint, and for a worker
    /// whatever else its event loop does at the end of a task. For a caller
    /// on the host's event loop - a network completion, a timer - that is not
    /// already running script in that realm.
    runTaskInRealm: ?*const fn (
        realm: Context,
        steps: RealmSteps,
        data: ?*anyopaque,
    ) EngineError!void,

    /// Run `steps` synchronously with `realm` as the current realm - what "create X in the relevant realm of Y" needs when the
    /// caller is running in another one. No task boundary, no checkpoint.
    runInRealm: ?*const fn (
        realm: Context,
        steps: RealmSteps,
        data: ?*anyopaque,
    ) EngineError!void,

    /// WebIDL "create a DOMException" named `name` with `message`, in
    /// `realm`. OWNED: the caller releases the result with
    /// `releaseValue` (or hands it to an operation documented to take it).
    createDOMException: ?*const fn (
        realm: Context,
        name: []const u8,
        message: []const u8,
    ) EngineError!JSValue,

    /// HTML StructuredSerializeForStorage (2.7.4) of an object `value` - a
    /// `.handle`; a caller keeps primitives and strings itself. OWNED: the
    /// bytes are allocated with `allocator` and are the caller's. Fails with
    /// DataCloneError when the value cannot be serialized and nothing was
    /// thrown, ExceptionPending when a "DataCloneError" DOMException, or
    /// whatever script threw during serialization, is pending.
    structuredSerializeForStorage: ?*const fn (
        realm: Context,
        value: JSValue,
        allocator: std.mem.Allocator,
    ) EngineError![]u8,

    /// HTML StructuredDeserialize (2.7.7) of `bytes` that
    /// structuredSerializeForStorage produced, in `realm`. OWNED: release the
    /// result with `releaseValue`.
    structuredDeserialize: ?*const fn (
        realm: Context,
        bytes: []const u8,
    ) EngineError!JSValue,

    /// WebIDL "resolve" a promise made by createPromise with a platform
    /// object: its wrapper in the promise's realm. The handle stays valid
    /// until destroyPromiseHandle.
    resolvePromiseWithInstance: ?*const fn (
        promise_handle: *anyopaque,
        instance: *Instance,
    ) EngineError!void,

    /// WebIDL "reject" a promise made by createPromise with `value` - any
    /// JSValue, a createDOMException result included (BORROWED: the caller
    /// still releases its own value).
    rejectPromiseWithValue: ?*const fn (
        promise_handle: *anyopaque,
        value: JSValue,
    ) EngineError!void,

    /// WebIDL "mark as handled": a rejection of this promise is never
    /// reported as unhandled.
    markPromiseAsHandled: ?*const fn (
        promise_handle: *anyopaque,
    ) void,

    /// WebIDL: a `sequence<T>` of platform objects converted to a new array in
    /// `realm`, each element the object's wrapper there. OWNED: release it
    /// with `releaseValue`, or hand it to something documented to take it.
    createSequenceOfPlatformObjects: ?*const fn (
        realm: Context,
        instances: []const *Instance,
    ) EngineError!JSValue,

    /// HTML "relevant global object" of `instance`: the global object of the
    /// realm it was created in - a Window, or a WorkerGlobalScope - or null
    /// when that realm has none any more.
    relevantGlobalObject: ?*const fn (
        instance: *Instance,
    ) ?*Instance,

    /// Release a value an operation documented as OWNED returned. A value
    /// with `needs_disposal = false`, or one that is not a handle, is left
    /// alone, so any JSValue may be passed.
    releaseValue: ?*const fn (
        value: JSValue,
    ) void,

    // Lane regions (AGENTS.md "The engine boundary"): each V8-abstraction lane
    // adds its operations only inside its own region, here and in every
    // engine's table, so parallel lanes never edit the same lines.
    // ---- lane: page-realm ----

    /// WebIDL "invoke a callback function" with exception behavior "report":
    /// call `callback` with `this_arg` and `args` in `realm`, discarding the
    /// return value. Everything passed is BORROWED for the call. A `callback`
    /// that is not callable is not called ([LegacyTreatNonObjectAsNull]).
    /// What the call throws is handed to `report` (with `host`) after "clean
    /// up after running script" - so after the microtask checkpoint that an
    /// empty execution context stack performs, as WebIDL orders it - and is
    /// not returned. `ErrorInfo.error_value` is the thrown value.
    invokeCallbackFunction: ?*const fn (
        realm: Context,
        callback: JSValue,
        this_arg: CallbackThis,
        args: []const JSValue,
        report: ReportExceptionFn,
        host: ?*anyopaque,
    ) EngineError!void,

    /// Define a Window's native operations - setTimeout, clearTimeout,
    /// setInterval, clearInterval, requestAnimationFrame and
    /// cancelAnimationFrame - on `realm`'s global object, and on the global of
    /// every Window realm created in its agent from now on (its frames), with
    /// `operations` as their steps; a frame's `windowDestroyed` is called as
    /// its document is destroyed. `operations` is BORROWED until the realm is
    /// destroyed (a static table).
    ///
    /// Native because the WebIDL members' impl cannot serve them yet: they
    /// belong to the WindowOrWorkerGlobalScope and AnimationFrameProvider
    /// mixins, whose impl is held by the paused networking branch and still
    /// stubs setTimeout. When that mixin impl owns these steps, the generated
    /// binding replaces this operation.
    installWindowOperations: ?*const fn (
        realm: Context,
        operations: *const WindowOperations,
    ) EngineError!void,

    // ---- end lane: page-realm ----
    // ---- lane: runtime-impls ----
    // ---- end lane: runtime-impls ----

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

    // ========================================================================
    // ForEach Callback Support (Collection Iteration)
    // ========================================================================

    /// Invoke a forEach-style callback for each element in a JS collection
    ///
    /// Used for iterating arrays, Sets, Maps, NodeLists, and other collections
    /// with a callback function. The callback receives each element and its index.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Context, JSC VM, etc.)
    ///   - collection: Opaque pointer to JS collection (Array, Set, Map, NodeList, etc.)
    ///   - callback: Zig callback function to invoke for each element
    ///   - user_data: Context pointer passed to callback
    ///
    /// Returns:
    ///   - void on success
    ///   - EngineError on failure
    ///
    /// Callback Signature:
    ///   fn(value: *anyopaque, index: u32, user_data: *anyopaque) bool
    ///   Returns true to continue iteration, false to break early.
    invokeForEach: ?*const fn (
        engine_ctx: *anyopaque,
        collection: *anyopaque,
        callback: ForEachCallback,
        user_data: *anyopaque,
    ) EngineError!void,

    /// Get the length/size of a JS collection
    ///
    /// Works with arrays (length), Sets/Maps (size), NodeLists, etc.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - collection: Opaque pointer to JS collection
    ///
    /// Returns:
    ///   - Length/size of the collection
    ///   - 0 if collection is empty or not a valid collection
    getCollectionLength: ?*const fn (
        engine_ctx: *anyopaque,
        collection: *anyopaque,
    ) u32,

    /// Get an element from a JS collection by index
    ///
    /// For arrays and array-like objects, returns the element at the index.
    /// For Maps, the index is meaningless (use iteration instead).
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - collection: Opaque pointer to JS collection
    ///   - index: Zero-based index
    ///
    /// Returns:
    ///   - Opaque pointer to the element value
    ///   - null if index out of bounds or collection doesn't support indexing
    getCollectionElement: ?*const fn (
        engine_ctx: *anyopaque,
        collection: *anyopaque,
        index: u32,
    ) ?*anyopaque,

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
    .getPropertyTruthy = null,
    .getPropertyBoolean = null,
    .getPropertyInstance = null,
    .createArrayBuffer = null,
    .createUint8Array = null,
    .parseJson = null,
    .wrapInstance = null,
    .isString = null,
    .extractString = null,
    .setPropertyOnObject = stubSetPropertyOnObject,
    .defineOwnPropertyOnObject = stubDefineOwnPropertyOnObject,
    .convertJSValueToEngine = stubConvertJSValueToEngine,
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
    .runClassicScript = null,
    .performMicrotaskCheckpoint = null,
    .runTaskInRealm = null,
    .runInRealm = null,
    .createDOMException = null,
    .releaseValue = null,
    .structuredSerializeForStorage = null,
    .structuredDeserialize = null,
    .resolvePromiseWithInstance = null,
    .rejectPromiseWithValue = null,
    .markPromiseAsHandled = null,
    .createSequenceOfPlatformObjects = null,
    .relevantGlobalObject = null,
    // ---- lane: page-realm ----
    .invokeCallbackFunction = null,
    .installWindowOperations = null,
    // ---- end lane: page-realm ----
    // ---- lane: runtime-impls ----
    // ---- end lane: runtime-impls ----
    .compileModule = stubCompileModule,
    .runModule = stubRunModule,
    .disposeScript = stubDisposeScript,
    .disposeModule = stubDisposeModule,
    .runModuleAsync = stubRunModuleAsync,
    .hasTopLevelAwait = stubHasTopLevelAwait,
    .freeze = stubFreeze,
    .thaw = stubThaw,
    .isFrozen = stubIsFrozen,
    .invokeForEach = stubInvokeForEach,
    .getCollectionLength = stubGetCollectionLength,
    .getCollectionElement = stubGetCollectionElement,
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

fn stubInvokeForEach(
    _: *anyopaque,
    _: *anyopaque,
    _: ForEachCallback,
    _: *anyopaque,
) EngineError!void {
    // Stub: No JS engine available for forEach iteration
    return EngineError.NoEngine;
}

fn stubGetCollectionLength(
    _: *anyopaque,
    _: *anyopaque,
) u32 {
    // Stub: No collection access without engine
    return 0;
}

fn stubGetCollectionElement(
    _: *anyopaque,
    _: *anyopaque,
    _: u32,
) ?*anyopaque {
    // Stub: No collection access without engine
    return null;
}

fn stubSetPropertyOnObject(
    _: *anyopaque,
    _: *anyopaque,
    _: []const u8,
    _: []const u8,
) EngineError!void {
    // Stub: No JS engine available for property setting
    return EngineError.NoEngine;
}

fn stubDefineOwnPropertyOnObject(
    _: *anyopaque,
    _: *anyopaque,
    _: []const u8,
    _: *anyopaque,
) EngineError!void {
    // Stub: No JS engine available for property definition
    return EngineError.NoEngine;
}

fn stubConvertJSValueToEngine(
    _: *anyopaque,
    _: JSValue,
) EngineError!*anyopaque {
    // Stub: No JS engine available for value conversion
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
