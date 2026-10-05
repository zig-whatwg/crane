//! The types the engine protocol (src/runtime/engine_protocol.zig) and the
//! runtime share: values the host and an engine adapter hand each other, and
//! the callbacks the host supplies. No operations - those are the protocol's.
//!
//! They lived beside the runtime Engine table (engine_interface.zig), a
//! struct of optional function pointers reached through `ctx.getEngine()`.
//! The table is gone: every operation is the protocol's.

const std = @import("std");
const JSValue = @import("js_value.zig").JSValue;
const Context = @import("context.zig").Context;
const Instance = @import("instance.zig").Instance;
const ContextData = @import("context.zig").ContextData;
const TimerInterface = @import("timer.zig").TimerInterface;

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
    /// This engine does not provide the operation (an adapter's answer where
    /// its engine cannot - the JavaScriptCore and QuickJS adapters' for many).
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
    /// The thrown value itself, BORROWED: the engine keeps it.
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

/// WebIDL's simple exception types (§ 2.8 "Exceptions"): the ECMAScript error
/// objects an operation throws by name. Error and SyntaxError are not among
/// them - the spec reserves them for authors and the parser.
pub const SimpleExceptionKind = enum { EvalError, RangeError, ReferenceError, TypeError, URIError };

/// One present member of an IDL dictionary value, for createDictionaryObject.
/// `value` is BORROWED for the call.
pub const DictionaryMember = struct {
    name: []const u8,
    value: JSValue,
};

/// What an ArrayBufferView is: its type ([[TypedArrayName]], or a DataView)
/// and the part of its [[ViewedArrayBuffer]] it views, for
/// describeArrayBufferView.
pub const ArrayBufferViewDescription = struct {
    view_type: @import("arraybuffer_view.zig").ViewType,
    /// [[ByteOffset]] into the viewed buffer.
    byte_offset: usize,
    /// [[ByteLength]]: 0 when the buffer is detached.
    byte_length: usize,
    /// IsDetachedBuffer([[ViewedArrayBuffer]]).
    detached: bool,
    /// IsSharedArrayBuffer([[ViewedArrayBuffer]]).
    shared: bool,
};

/// HTML's "serialize with transfer result" (2.7.5), as an engine produces it
/// and StructuredDeserializeWithTransfer takes it back. `serialized` and
/// `array_buffers` are OWNED (the allocator the operation was given; free them
/// with `deinit`). `platform_objects` are BORROWED: the transferred platform
/// objects in transfer-list order, valid for the caller to run their transfer
/// steps (a MessagePort's) - the slice is freed by `deinit`, the objects are
/// not.
pub const SerializedWithTransfer = struct {
    /// The engine's serialization of the value - opaque to everyone else.
    serialized: []u8,
    /// Each transferred ArrayBuffer's contents, in transfer-list order. The
    /// sender's buffers are detached.
    array_buffers: [][]u8,
    /// The transferred platform objects, in transfer-list order.
    platform_objects: []*Instance,

    pub fn deinit(self: *SerializedWithTransfer, allocator: std.mem.Allocator) void {
        allocator.free(self.serialized);
        for (self.array_buffers) |contents| allocator.free(contents);
        allocator.free(self.array_buffers);
        allocator.free(self.platform_objects);
        self.* = .{ .serialized = &.{}, .array_buffers = &.{}, .platform_objects = &.{} };
    }
};

/// What a platform object in a transfer list is (HTML 2.7.5 steps 2.1 and
/// 5.2): one without a [[Detached]] internal slot is not transferable, and one
/// whose [[Detached]] is true cannot be transferred again.
pub const TransferableState = enum { not_transferable, transferable, detached };

/// The caller's answer for one platform object in a transfer list; `data` is
/// the pointer it passed alongside (the source port, say, which may not be in
/// its own transfer list).
pub const TransferableCheck = *const fn (data: ?*anyopaque, instance: *Instance) TransferableState;

/// An agent (ECMAScript 9.7): a thread of script execution with its own
/// heap - a worker has its own. Opaque: V8's is an isolate, JavaScriptCore's
/// a VM.
pub const Agent = opaque {};

/// What a host gives the engine for a worker realm (HTML "run a worker" steps
/// 5-7).
pub const WorkerRealmOptions = struct {
    /// The kinds of HTML's "worker global scope": what "run a worker" step 5
    /// makes the realm's global object - a new DedicatedWorkerGlobalScope, or,
    /// when `is shared`, a new SharedWorkerGlobalScope. (A service worker's
    /// ServiceWorkerGlobalScope would be a third.)
    pub const WorkerGlobal = enum { dedicated, shared };

    /// The worker's script URL: the realm's API base URL. Borrowed.
    url: []const u8,
    /// The realm's global object, and so the interfaces [Exposed] in it.
    global: WorkerGlobal = .dedicated,
    /// The timers the realm's tasks run on.
    timer: ?TimerInterface,
    /// The host's event loop for the realm - the worker's own, on the
    /// worker's thread - recorded in the realm for host algorithms that
    /// queue tasks (streams, Blob, fetch). The engine stores it and never
    /// runs it. Null for a realm whose tasks run on another loop's timers.
    event_loop: ?@import("event_loop").EventLoop = null,
    /// What ends a task in the realm (see ContextData.end_of_task).
    end_of_task: ?*const fn (realm: *ContextData) void = null,
    /// Called once the realm exists and before its global object is made, so
    /// the host can record the realm's settings the global scope reads.
    on_realm: ?*const fn (data: ?*anyopaque, realm: Context) void = null,
    /// Passed to `on_realm`.
    data: ?*anyopaque = null,
    allocator: std.mem.Allocator,
};

/// A worker realm and its global object.
pub const WorkerRealm = struct {
    realm: Context,
    /// The DedicatedWorkerGlobalScope or SharedWorkerGlobalScope behind the
    /// global object, as `WorkerRealmOptions.global` asked. The realm owns it.
    global_scope: *Instance,
};

/// The steps of a built-in function a host defines (`defineBuiltinFunction`):
/// `data` is the pointer the host gave; `args` are BORROWED for the call (a
/// primitive as itself, a string as UTF-8, anything else a handle). The
/// result is returned to script and is the engine's: a value made for it, or
/// a handle it releases once it is the result - a value the host keeps goes
/// back as `retainValue(...).take()`.
/// ExceptionPending leaves what was thrown in flight; any other error is
/// thrown as WebIDL does an impl's.
pub const BuiltinSteps = *const fn (data: ?*anyopaque, args: []const JSValue) EngineError!JSValue;

/// A built-in function: its steps and their data.
pub const BuiltinFunction = struct {
    steps: BuiltinSteps,
    data: ?*anyopaque,
};

/// The string type a record's keys or values convert to: DOMString
/// (WebIDL 3.2.10) or USVString (3.2.12), as UTF-8. (ByteString, 3.2.11, is
/// not here: its bytes are code units, a representation Crane's ByteString
/// does not use yet.)
pub const StringConversion = enum { dom_string, usv_string };

/// One entry of an IDL record<K, V> whose K and V are string types, as
/// `convertToRecordOfStrings` returns them. Both slices are OWNED by the list
/// (`freeAll`).
pub const StringRecordEntry = struct {
    key: []u8,
    value: []u8,

    /// Free a list `convertToRecordOfStrings` returned, entries and all.
    pub fn freeAll(entries: []StringRecordEntry, allocator: std.mem.Allocator) void {
        for (entries) |entry| {
            allocator.free(entry.key);
            allocator.free(entry.value);
        }
        allocator.free(entries);
    }
};
