//! The V8 adapter's side of the engine protocol: in a V8 build `engine_impl`
//! is the v8 module, and its root re-exports this file as `protocol` - what
//! the engine protocol (src/runtime/engine_protocol.zig) forwards to. Every
//! operation has the protocol's signature exactly; the facade checks it.
//!
//! A file of the v8 module, so it calls the adapter functions it wraps by
//! name. Each operation is one of:
//!
//! - wired: the existing adapter function that does the job, with the
//!   protocol's types around it (Owned results, the protocol's Error, the
//!   realm entered where the function works on the current context);
//! - partly wired: the existing function covers some of the operation, and
//!   the rest answers NotSupported;
//! - a stub: nothing does the job yet. It answers NotSupported - or, for an
//!   operation that cannot fail, panics - and is marked
//!   `TODO(protocol): implement - design <section>` (grep for it; step B of
//!   the plan fills them in by area).
//!
//! The worker and agent operations reach worker_realm.zig through the runtime
//! Engine table's comptime-known entries - direct calls - while the
//! engine-boundary lane is changing that file.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const v8_engine = @import("engine.zig");
const realm_entry = @import("realm_entry.zig");
const context_manager = @import("context_manager.zig");
const current_realm = @import("current_realm.zig");
const value_construction = @import("value_construction.zig");
const page_realm = @import("page_realm.zig");
const callback_interfaces = @import("callback_interfaces.zig");
const array_buffer_views = @import("array_buffer_views.zig");
const observable_array = @import("observable_array.zig");
const webidl_conversions = @import("webidl_conversions.zig");
const webidl_conversions_numeric = @import("webidl_conversions_numeric.zig");
const value_operations = @import("value_operations.zig");
const structured_serialization = @import("structured_serialization.zig");
const isolate_ownership = @import("isolate_ownership.zig");
const protocol_agents = @import("protocol_agents.zig");
const protocol_modules = @import("protocol_modules.zig");
const protocol_realms = @import("protocol_realms.zig");
const protocol_scripts = @import("protocol_scripts.zig");
const support = @import("protocol_support.zig");

/// For the worker and agent operations only (see above).
const table = v8_engine.v8_engine_interface;

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Agent = engine.Agent;
const Instance = engine.Instance;
const Allocator = std.mem.Allocator;
const EngineError = runtime.EngineError;

pub const name = "V8";

/// engine.log_scope: engine.zig logs under it.
pub const log_scope = .v8_engine;

pub const capabilities: engine.Capabilities = .{
    .module_scripts = .native,
    .promise_rejection_tracking = .native,
    .reuse_window_proxy = .native,
    .microtask_checkpoint_control = .native,
    .exact_function_realm = .native,
    .restores_snapshots = .native,
    .can_block_control = .native,
    .heap_statistics = .native,
    .heap_snapshots = .native,
    .diagnostic_counters = .native,
};

/// Every operation is V8 code: a test binary that compiles them all links V8.
pub const links_engine = true;

/// HTML "prepare to run script" entered `realm`: undone by "clean up".
pub const ScriptScope = realm_entry.Entered;

// ============================================================================
// Helpers
// ============================================================================

/// The runtime table's errors as the protocol's: the table's own failure
/// codes (NoEngine, PromiseError, ...) are all the engine failing.
fn protocolError(err: EngineError) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError => error.TypeError,
        error.ExceptionPending => error.ExceptionPending,
        error.DataCloneError => error.DataCloneError,
        error.NotSupported => error.NotSupported,
        error.NoEngine,
        error.OperationFailed,
        error.PromiseError,
        error.AsyncIteratorError,
        error.RegistrationFailed,
        error.ObjectCreationFailed,
        => error.OperationFailed,
    };
}

fn owned(value: JSValue) Owned {
    return .{ .value = value };
}

/// An OWNED handle for a Global the FFI made.
fn ownedGlobal(ptr: *anyopaque) Owned {
    return owned(realm_entry.owned(ptr));
}

fn handleOf(value: JSValue) ?*ffi.Value {
    return switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => null,
    };
}

fn isolateOf(agent: *Agent) *ffi.Isolate {
    return @ptrCast(@alignCast(agent));
}

/// Enter `realm` for an adapter function that works on the current context.
fn enter(realm: Context) Error!realm_entry.Entered {
    return realm_entry.enter(realm) catch |err| protocolError(err);
}

/// An operation that cannot fail, reached before it is built: fail loudly.
fn notImplemented(comptime operation: []const u8, comptime section: []const u8) noreturn {
    @panic("engine." ++ operation ++ " is not implemented on V8 yet (TODO(protocol): design " ++ section ++ ")");
}

// ============================================================================
// 4.1 Engine and agents
// ============================================================================

pub fn initializeEngine(options: engine.EngineOptions) Error!void {
    return protocol_agents.initializeEngine(options);
}

pub fn deinitializeEngine() void {
    protocol_agents.deinitializeEngine();
}

pub fn createAgent(options: engine.AgentOptions) Error!*Agent {
    return protocol_agents.createAgent(options);
}

/// The agent ends (its hooks forgotten, the adapter's per-isolate modules
/// torn down, its garbage collected) before its isolate is disposed.
pub fn destroyAgent(agent: *Agent) void {
    protocol_agents.endAgent(agent);
    table.destroyAgent.?(agent);
}

pub fn hasRunningScript(agent: *Agent) bool {
    return table.hasRunningScript.?(agent);
}

pub fn hasPendingEngineWork(agent: *Agent) bool {
    return table.hasPendingEngineWork.?(agent);
}

pub fn runEngineTasks(agent: *Agent) bool {
    return table.runEngineTasks.?(agent);
}

/// A realm's agent is its isolate (context_manager records it so).
/// LowMemoryNotification: a full, synchronous collection.
pub fn requestGarbageCollection(agent: *Agent) void {
    ffi.v8_Isolate_RequestGarbageCollection(isolateOf(agent));
}

pub fn notifyMemoryPressure(agent: *Agent, level: engine.MemoryPressure) void {
    protocol_agents.notifyMemoryPressure(agent, level);
}

// ============================================================================
// 4.2 Realms
// ============================================================================

pub fn createWindowRealm(options: *const engine.WindowRealmOptions) Error!Context {
    return protocol_realms.createWindowRealm(options);
}

pub fn destroyWindowRealm(realm: Context) void {
    protocol_realms.destroyWindowRealm(realm);
}

pub fn createWorkerRealm(agent: *Agent, options: *const engine.WorkerRealmOptions) Error!engine.WorkerRealm {
    return table.createWorkerRealm.?(agent, options.*) catch |err| protocolError(err);
}

pub fn destroyWorkerRealm(realm: Context, retire: ?engine.RealmSteps, data: ?*anyopaque) void {
    table.destroyWorkerRealm.?(realm, retire, data);
}

pub fn currentRealm() ?Context {
    return current_realm.currentRealm();
}

pub fn entryRealm() ?Context {
    return protocol_realms.entryRealm();
}

pub fn incumbentRealm() ?Context {
    return protocol_realms.incumbentRealm();
}

pub fn functionRealm(value: JSValue) ?Context {
    return protocol_realms.functionRealm(value);
}

pub fn installWindowOperations(realm: Context, operations: *const engine.WindowOperations) Error!void {
    return page_realm.installWindowOperations(realm, operations) catch |err| protocolError(err);
}

pub fn defineBuiltinFunction(realm: Context, function_name: []const u8, length: u32, function: *const engine.BuiltinFunction) Error!void {
    return table.defineBuiltinFunction.?(realm, function_name, length, function) catch |err| protocolError(err);
}

// ============================================================================
// 4.3 Running script
// ============================================================================

pub fn runClassicScript(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, reporter: engine.Reporter) Error!void {
    return protocol_scripts.runClassicScript(realm, source, url, host_defined, reporter);
}

pub fn evaluateClassicScript(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, reporter: engine.Reporter) Error!Owned {
    return protocol_scripts.evaluateClassicScript(realm, source, url, host_defined, reporter);
}

pub fn evaluateClassicScriptToString(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, allocator: Allocator, reporter: engine.Reporter) Error![]u8 {
    return protocol_scripts.evaluateClassicScriptToString(realm, source, url, host_defined, allocator, reporter);
}

pub fn compileEventHandler(realm: Context, source: *const engine.EventHandlerSource, reporter: engine.Reporter) Error!?Owned {
    return protocol_scripts.compileEventHandler(realm, source, reporter);
}

pub fn prepareToRunScript(realm: Context) Error!ScriptScope {
    return protocol_scripts.prepareToRunScript(realm);
}

pub fn cleanUpAfterRunningScript(scope: ScriptScope) void {
    protocol_scripts.cleanUpAfterRunningScript(scope);
}

pub fn runInRealm(realm: Context, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    return v8_engine.v8RunInRealm(realm, steps, data) catch |err| protocolError(err);
}

pub fn runTaskInRealm(realm: Context, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    return v8_engine.v8RunTaskInRealm(realm, steps, data) catch |err| protocolError(err);
}

pub fn performMicrotaskCheckpoint(agent: *Agent) Error!void {
    protocol_agents.performMicrotaskCheckpoint(agent);
}

pub fn queueMicrotask(agent: *Agent, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    return protocol_agents.queueMicrotask(agent, steps, data);
}

pub fn extractErrorInformation(realm: Context, value: JSValue, allocator: Allocator) Error!engine.ErrorInfo {
    return protocol_scripts.extractErrorInformation(realm, value, allocator);
}

pub const parseModule = protocol_modules.parseModule;
pub const parseJSONModule = protocol_modules.parseJSONModule;
pub const moduleRequests = protocol_modules.moduleRequests;
pub const linkModule = protocol_modules.linkModule;
pub const evaluateModule = protocol_modules.evaluateModule;
pub const finishDynamicImport = protocol_modules.finishDynamicImport;
pub const releaseModuleRecord = protocol_modules.releaseModuleRecord;

// ============================================================================
// 4.4 Invoking callbacks
// ============================================================================

const protocol_callbacks = @import("protocol_callbacks.zig");
pub const invokeCallbackFunction = protocol_callbacks.invokeCallbackFunction;
pub const callUserObjectOperation = protocol_callbacks.callUserObjectOperation;

/// In `realm`'s agent: a realm that cannot be entered reads nothing.
pub fn isCallable(realm: Context, value: JSValue) bool {
    const entered = enter(realm) catch return false;
    defer entered.leave();
    return table.isCallable.?(value);
}

pub const takeCallbackFunction = protocol_callbacks.takeCallbackFunction;
pub const takeCallbackInterface = protocol_callbacks.takeCallbackInterface;

// ============================================================================
// 4.5 ECMAScript values
// ============================================================================

const protocol_values = @import("protocol_values.zig");
pub const getProperty = protocol_values.getProperty;
pub const setProperty = protocol_values.setProperty;
pub const defineOwnProperty = protocol_values.defineOwnProperty;
pub const hasProperty = protocol_values.hasProperty;
pub const typeOf = protocol_values.typeOf;
pub const sameValue = protocol_values.sameValue;
pub const toBoolean = protocol_values.toBoolean;

pub fn retainValue(realm: Context, value: JSValue) Error!Owned {
    switch (value) {
        // No engine resource to hold: by value, with nothing entered, so a
        // realm with no engine behind it (a host's stack context) will do.
        .undefined, .null, .boolean, .number => return .{ .value = value },
        else => {},
    }
    const entered = try enter(realm);
    defer entered.leave();
    // A platform object: its wrapper in its relevant realm.
    return support.owned(try support.ownGlobal(entered, value));
}

pub fn releaseValue(value: Owned) void {
    v8_engine.v8ReleaseValue(value.value);
}

pub fn throwValue(realm: Context, value: JSValue) Error!void {
    const entered = try enter(realm);
    defer entered.leave();
    const relevant = try support.Relevant.of(entered.isolate, value);
    defer relevant.release();
    return value_operations.throwValue(realm, relevant.value) catch |err| protocolError(err);
}

pub const completionOf = @import("protocol_completion.zig").completionOf;

pub const parseJsonToValue = protocol_values.parseJsonToValue;
pub const serializeJsonToBytes = protocol_values.serializeJsonToBytes;

// ============================================================================
// 4.6 WebIDL: ECMAScript to IDL
// ============================================================================

pub fn convertToDOMString(realm: Context, value: JSValue, allocator: Allocator) Error![]u8 {
    return webidl_conversions.convertToDOMString(realm, value, allocator) catch |err| protocolError(err);
}

pub fn convertToUSVString(realm: Context, value: JSValue, allocator: Allocator) Error![]u8 {
    return webidl_conversions.convertToUSVString(realm, value, allocator) catch |err| protocolError(err);
}

pub fn convertToUnrestrictedDouble(realm: Context, value: JSValue) Error!f64 {
    return webidl_conversions_numeric.convertToUnrestrictedDouble(realm, value) catch |err| protocolError(err);
}

pub fn convertToPlatformObject(realm: Context, value: JSValue) ?*Instance {
    return webidl_conversions.convertToPlatformObject(realm, value);
}

pub fn convertToSequenceOfPlatformObjects(realm: Context, value: JSValue, allocator: Allocator) Error![]*Instance {
    return webidl_conversions.convertToSequenceOfPlatformObjects(realm, value, allocator) catch |err| protocolError(err);
}

/// The table's OWNED handles, re-typed as Owned.
pub fn convertToSequenceOfObjects(realm: Context, value: JSValue, allocator: Allocator) Error![]Owned {
    const values = webidl_conversions.convertToSequenceOfObjects(realm, value, allocator) catch |err| return protocolError(err);
    defer allocator.free(values);
    const items = allocator.alloc(Owned, values.len) catch {
        for (values) |item| v8_engine.v8ReleaseValue(item);
        return error.OutOfMemory;
    };
    for (values, items) |item, *out| out.* = owned(item);
    return items;
}

pub fn convertToSequenceOfDOMStrings(realm: Context, value: JSValue, allocator: Allocator) Error!?[][]u8 {
    return webidl_conversions.convertToSequenceOfDOMStrings(realm, value, allocator) catch |err| protocolError(err);
}

pub fn convertToRecordOfStrings(realm: Context, value: JSValue, keys: engine.StringConversion, values: engine.StringConversion, allocator: Allocator) Error![]engine.StringRecordEntry {
    return webidl_conversions.convertToRecordOfStrings(realm, value, keys, values, allocator) catch |err| protocolError(err);
}

pub fn getCopyOfBufferSourceBytes(realm: Context, value: JSValue, allocator: Allocator) Error!?[]u8 {
    return webidl_conversions.getCopyOfBufferSourceBytes(realm, value, allocator) catch |err| protocolError(err);
}

const protocol_conversions = @import("protocol_conversions.zig");
pub const convertToSequence = protocol_conversions.convertToSequence;
pub const convertToSequenceOfStringPairs = protocol_conversions.convertToSequenceOfStringPairs;
pub const iterate = protocol_conversions.iterate;
pub const getIterator = protocol_conversions.getIterator;
pub const iteratorNext = protocol_conversions.iteratorNext;
pub const iteratorReturn = protocol_conversions.iteratorReturn;
pub const iteratorResult = protocol_conversions.iteratorResult;
pub const releaseIteratorRecord = protocol_conversions.releaseIteratorRecord;

// ============================================================================
// 4.7 WebIDL: IDL to ECMAScript
// ============================================================================

/// Each platform object becomes its wrapper in its relevant realm
/// (support.RelevantList), not the realm the array is made in.
pub fn createSequenceOfValues(realm: Context, values: []const JSValue) Error!Owned {
    const entered = try enter(realm);
    defer entered.leave();
    const relevant = try support.RelevantList.of(entered.isolate, values);
    defer relevant.release();
    return owned(webidl_conversions.createSequenceOfValues(realm, relevant.values) catch |err| return protocolError(err));
}

pub fn createSequenceOfPlatformObjects(realm: Context, instances: []const *Instance) Error!Owned {
    const values = std.heap.c_allocator.alloc(JSValue, instances.len) catch return error.OutOfMemory;
    defer std.heap.c_allocator.free(values);
    for (instances, values) |instance, *value| value.* = .{ .instance = instance };
    return createSequenceOfValues(realm, values);
}

pub fn createDictionaryObject(realm: Context, members: []const engine.DictionaryMember) Error!Owned {
    const entered = try enter(realm);
    defer entered.leave();
    const values = std.heap.c_allocator.alloc(JSValue, members.len) catch return error.OutOfMemory;
    defer std.heap.c_allocator.free(values);
    for (members, values) |member, *value| value.* = member.value;
    const relevant = try support.RelevantList.of(entered.isolate, values);
    defer relevant.release();
    const relevant_members = std.heap.c_allocator.alloc(engine.DictionaryMember, members.len) catch return error.OutOfMemory;
    defer std.heap.c_allocator.free(relevant_members);
    for (members, relevant.values, relevant_members) |member, value, *out| out.* = .{ .name = member.name, .value = value };
    return owned(value_construction.createDictionaryObject(realm, relevant_members) catch |err| return protocolError(err));
}

pub fn createObservableArray(realm: Context) Error!JSValue {
    return observable_array.createObservableArray(realm) catch |err| protocolError(err);
}

pub const createFrozenArray = protocol_conversions.createFrozenArray;

pub const createAsyncIterator = @import("protocol_async_iterator.zig").createAsyncIterator;

// ============================================================================
// 4.8 Exceptions
// ============================================================================

/// V8's embedder API reaches no EvalError or URIError intrinsic; those are
/// NotSupported, as the table's answer them.
pub fn createSimpleException(realm: Context, kind: engine.SimpleExceptionKind, message: []const u8) Error!Owned {
    const table_kind: runtime.SimpleExceptionKind = switch (kind) {
        .EvalError => .EvalError,
        .RangeError => .RangeError,
        .ReferenceError => .ReferenceError,
        .TypeError => .TypeError,
        .URIError => .URIError,
        .SyntaxError => return @import("protocol_values.zig").createSyntaxError(realm, message),
    };
    return owned(value_construction.createSimpleException(realm, table_kind, message) catch |err| return protocolError(err));
}

pub fn createDOMException(realm: Context, exception_name: []const u8, message: []const u8) Error!Owned {
    return owned(v8_engine.v8CreateDOMException(realm, exception_name, message) catch |err| return protocolError(err));
}

// ============================================================================
// 4.9 Promises
// ============================================================================

/// The table's promise handles are allocated here, and freed with the same.
const promise_allocator = std.heap.c_allocator;

pub fn createPromise(realm: Context) Error!engine.PromiseCapability {
    const entered = try enter(realm);
    defer entered.leave();
    const state = v8_engine.v8CreatePromise(@ptrCast(entered.context()), promise_allocator) catch |err| return protocolError(err);
    return .{
        // The capability owns the promise's Global; this is its view.
        .promise = .{ .handle = .{ .ptr = v8_engine.v8GetPromiseObject(state), .needs_disposal = false } },
        .state = state,
    };
}

pub fn resolvePromise(capability: *engine.PromiseCapability, value: JSValue) Error!void {
    const resolved = switch (value) {
        // Its wrapper in its relevant realm, not the promise's.
        .instance => |instance| blk: {
            const handle: *v8_engine.V8PromiseHandle = @ptrCast(@alignCast(capability.state));
            const scope = @import("js_scope.zig").JsScope.initFromV8Context(handle.context) orelse return error.OperationFailed;
            defer scope.deinit();
            const wrapper = try support.relevantWrapper(handle.isolate, instance);
            defer ffi.v8_Global_Dispose(wrapper);
            break :blk v8_engine.v8ResolvePromise(capability.state, capability.state, wrapper);
        },
        .handle => |h| v8_engine.v8ResolvePromise(capability.state, capability.state, h.ptr),
        .undefined => v8_engine.v8ResolvePromise(capability.state, capability.state, null),
        else => resolveWithConverted(capability.state, value),
    };
    return resolved catch |err| protocolError(err);
}

/// A primitive or string, converted in the promise's realm - as the table's
/// rejectPromiseWithValue converts a reason.
fn resolveWithConverted(state: *anyopaque, value: JSValue) EngineError!void {
    const handle: *v8_engine.V8PromiseHandle = @ptrCast(@alignCast(state));
    const scope = @import("js_scope.zig").JsScope.initFromV8Context(handle.context) orelse return EngineError.OperationFailed;
    defer scope.deinit();
    const converted = try realm_entry.EngineValue.of(handle.isolate, handle.context, value);
    defer converted.release();
    if (!ffi.v8_PromiseResolver_Resolve(handle.resolver, handle.context, converted.ptr)) return EngineError.PromiseError;
}

pub fn rejectPromise(capability: *engine.PromiseCapability, reason: JSValue) Error!void {
    const handle: *v8_engine.V8PromiseHandle = @ptrCast(@alignCast(capability.state));
    const scope = @import("js_scope.zig").JsScope.initFromV8Context(handle.context) orelse return error.OperationFailed;
    defer scope.deinit();
    const relevant = try support.Relevant.of(handle.isolate, reason);
    defer relevant.release();
    return v8_engine.v8RejectPromiseWithValue(capability.state, relevant.value) catch |err| protocolError(err);
}

pub fn releasePromiseCapability(capability: *engine.PromiseCapability) void {
    if (handleOf(capability.promise)) |promise| ffi.v8_Promise_Dispose(@ptrCast(promise));
    v8_engine.v8DestroyPromiseHandle(capability.state, promise_allocator);
}

pub fn createResolvedPromise(realm: Context, value: JSValue) Error!Owned {
    const entered = try enter(realm);
    defer entered.leave();
    const relevant = try support.Relevant.of(entered.isolate, value);
    defer relevant.release();
    return owned(value_construction.createResolvedPromise(realm, relevant.value) catch |err| return protocolError(err));
}

pub fn createRejectedPromise(realm: Context, reason: JSValue) Error!Owned {
    const entered = try enter(realm);
    defer entered.leave();
    const relevant = try support.Relevant.of(entered.isolate, reason);
    defer relevant.release();
    return owned(value_construction.createRejectedPromise(realm, relevant.value) catch |err| return protocolError(err));
}

pub const reactToPromise = @import("protocol_promises.zig").reactToPromise;

/// A `.handle` is a Global either way it is tagged; the FFI leaves anything
/// but a promise alone.
pub fn markPromiseAsHandled(realm: Context, promise: JSValue) void {
    const value = handleOf(promise) orelse return;
    const entered = enter(realm) catch return;
    defer entered.leave();
    ffi.v8_Promise_MarkAsHandled(value);
}

pub fn promiseIsHandled(realm: Context, promise: JSValue) bool {
    const value = handleOf(promise) orelse return false;
    const entered = enter(realm) catch return false;
    defer entered.leave();
    return ffi.v8_Promise_HasHandler(value);
}

// ============================================================================
// 4.10 Buffers
// ============================================================================

pub fn createArrayBuffer(realm: Context, bytes: []const u8) Error!Owned {
    const entered = try enter(realm);
    defer entered.leave();
    return ownedGlobal(v8_engine.v8CreateArrayBuffer(@ptrCast(entered.context()), bytes) catch |err| return protocolError(err));
}

pub fn allocateArrayBuffer(realm: Context, byte_length: usize) Error!Owned {
    const entered = try enter(realm);
    defer entered.leave();
    return ownedGlobal(ffi.v8_ArrayBuffer_Allocate(byte_length) orelse return error.OperationFailed);
}

pub fn createArrayBufferView(realm: Context, view_type: engine.ViewType, buffer: JSValue, byte_offset: usize, length: usize) Error!Owned {
    const target = handleOf(buffer) orelse return error.TypeError;
    const kind: ffi.ViewKind = switch (view_type) {
        .int8_array => .int8,
        .uint8_array => .uint8,
        .uint8_clamped_array => .uint8_clamped,
        .int16_array => .int16,
        .uint16_array => .uint16,
        .int32_array => .int32,
        .uint32_array => .uint32,
        .float32_array => .float32,
        .float64_array => .float64,
        .bigint64_array => .bigint64,
        .biguint64_array => .biguint64,
        .data_view => .data_view,
    };
    const entered = try enter(realm);
    defer entered.leave();
    return ownedGlobal(ffi.v8_ArrayBufferView_New(kind, target, byte_offset, length) orelse return error.OperationFailed);
}

pub fn describeArrayBufferView(realm: Context, value: JSValue) ?engine.ArrayBufferViewDescription {
    const entered = enter(realm) catch return null;
    defer entered.leave();
    return array_buffer_views.describeArrayBufferView(value);
}

pub fn writeIntoArrayBufferView(realm: Context, view: JSValue, bytes: []const u8, starting_offset: usize) Error!void {
    const entered = try enter(realm);
    defer entered.leave();
    return array_buffer_views.writeIntoArrayBufferView(view, bytes, starting_offset) catch |err| protocolError(err);
}

pub fn borrowArrayBufferBytes(realm: Context, buffer: JSValue) ?[]u8 {
    const target = handleOf(buffer) orelse return null;
    const entered = enter(realm) catch return null;
    defer entered.leave();
    var data: ?*anyopaque = null;
    var byte_length: usize = 0;
    if (!ffi.v8_ArrayBuffer_Bytes(target, &data, &byte_length)) return null;
    const bytes: [*]u8 = @ptrCast(data orelse return @constCast(&[_]u8{}));
    return bytes[0..byte_length];
}

pub fn isDetachedBuffer(realm: Context, buffer: JSValue) bool {
    const target = handleOf(buffer) orelse return false;
    const entered = enter(realm) catch return false;
    defer entered.leave();
    return ffi.v8_ArrayBuffer_IsDetachedValue(target);
}

pub fn canTransferArrayBuffer(realm: Context, buffer: JSValue) bool {
    const target = handleOf(buffer) orelse return false;
    const entered = enter(realm) catch return false;
    defer entered.leave();
    return ffi.v8_ArrayBuffer_CanTransfer(target);
}

pub fn transferArrayBuffer(realm: Context, buffer: JSValue) Error!Owned {
    const target = handleOf(buffer) orelse return error.TypeError;
    const entered = try enter(realm);
    defer entered.leave();
    return ownedGlobal(ffi.v8_ArrayBuffer_Transfer(target) orelse return error.TypeError);
}

pub fn getViewedArrayBuffer(realm: Context, view: JSValue) Error!Owned {
    const target = handleOf(view) orelse return error.TypeError;
    const entered = try enter(realm);
    defer entered.leave();
    return ownedGlobal(ffi.v8_ArrayBufferView_Buffer(target) orelse return error.TypeError);
}

// ============================================================================
// 4.11 Structured serialization
// ============================================================================

pub fn structuredSerializeForStorage(realm: Context, value: JSValue, allocator: Allocator) Error![]u8 {
    return v8_engine.v8StructuredSerializeForStorage(realm, value, allocator) catch |err| protocolError(err);
}

pub fn structuredDeserialize(realm: Context, bytes: []const u8) Error!Owned {
    return owned(v8_engine.v8StructuredDeserialize(realm, bytes) catch |err| return protocolError(err));
}

pub fn structuredSerializeWithTransfer(realm: Context, value: JSValue, transfer_list: []const JSValue, check: engine.TransferableCheck, check_data: ?*anyopaque, allocator: Allocator) Error!engine.SerializedWithTransfer {
    return structured_serialization.structuredSerializeWithTransfer(realm, value, transfer_list, check, check_data, allocator) catch |err| protocolError(err);
}

pub fn structuredDeserializeWithTransfer(realm: Context, serialized: []const u8, array_buffers: []const []const u8) Error!Owned {
    return owned(structured_serialization.structuredDeserializeWithTransfer(realm, serialized, array_buffers) catch |err| return protocolError(err));
}

// ============================================================================
// 4.12 Platform objects
// ============================================================================

/// In `instance`'s relevant realm: the wrapper cache of the realm it was
/// created in.
pub fn hasWrapper(instance: *Instance) bool {
    const cache = instance.ctx.getV8WrapperCacheStorage() orelse return false;
    return v8_engine.v8GetWrapperForInstance(cache, cache, instance) != null;
}

pub fn keepPlatformObjectAlive(instance: *Instance) void {
    table.keepPlatformObjectAlive.?(instance);
}

pub fn releasePlatformObject(instance: *Instance) void {
    table.releasePlatformObject.?(instance);
}

pub fn platformObjectDestroyed(instance: *Instance) void {
    context_manager.markInstanceCleanedUp(instance);
}

// ============================================================================
// 4.13 Diagnostics tier
// ============================================================================

pub fn heapStatistics(agent: *Agent) engine.HeapStatistics {
    const isolate = isolateOf(agent);
    var statistics: engine.HeapStatistics = .{ .used = 0, .total = 0, .external = 0, .realm_count = 0, .detached_realm_count = 0 };
    ffi.v8_Isolate_GetHeapUsage(isolate, &statistics.used, &statistics.total, &statistics.external);
    ffi.v8_Isolate_GetContextCounts(isolate, &statistics.realm_count, &statistics.detached_realm_count);
    return statistics;
}

pub fn writeHeapSnapshot(agent: *Agent, path: [:0]const u8) bool {
    return ffi.v8_Debug_WriteHeapSnapshot(isolateOf(agent), path.ptr);
}

/// The adapter's counters, every one cumulative or live as its comment says:
/// - live handles by kind: Globals created minus disposed;
/// - `global_handle_bytes`: V8's used global handle bytes for the current
///   isolate (0 with none), which counts every Global whoever made it;
/// - `wrapper_cache_entries`: the wrappers every realm's wrapper cache on this
///   thread holds, each keeping its instance alive until the wrapper dies;
/// - `globals_created`: Globals made through the wrapper's tracked path,
///   cumulative - 0 unless v8_wrapper.cpp is built with
///   -DCRANE_TRACK_GLOBALS=1, as gc_bench's is;
/// - `object_globals_from.<entry point>`: Global<Object> creations by the FFI
///   entry point that made them, cumulative - which of them a per-element
///   leak comes from;
/// and, where the Phase 5 instrument is compiled in, how many agent-ownership
/// checks ran and how many failed (isolate_ownership.zig) - hosts read "not
/// measured" when those are not reported.
pub fn diagnosticCounters(allocator: Allocator) Error![]engine.Counter {
    const handles = [_]engine.Counter{
        .{ .name = "live_string_globals", .value = ffi.v8_Debug_LiveStringGlobals() },
        .{ .name = "live_context_globals", .value = ffi.v8_Debug_LiveContextGlobals() },
        .{ .name = "live_object_globals", .value = ffi.v8_Debug_LiveObjectGlobals() },
        .{ .name = "live_weak_callback_data", .value = ffi.v8_Debug_LiveWeakCallbackData() },
        // V8's own count (used_global_handles_size) for the current isolate:
        // no bookkeeping of ours in it, so it is the cross-check on the
        // counters above.
        .{ .name = "global_handle_bytes", .value = if (ffi.v8_Isolate_GetCurrent()) |isolate| @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate)) else 0 },
        .{ .name = "wrapper_cache_entries", .value = @intCast(@import("wrapper_cache.zig").liveEntryCount()) },
        .{ .name = "globals_created", .value = ffi.v8_Debug_CreatedGlobals() },
        // v8_wrapper.cpp's g_obj_src slots, in its order.
        .{ .name = "object_globals_from.FunctionCallbackInfo_This", .value = ffi.v8_Debug_ObjSrc(0) },
        .{ .name = "object_globals_from.PropertyCallbackInfo_This", .value = ffi.v8_Debug_ObjSrc(1) },
        .{ .name = "object_globals_from.Context_Global", .value = ffi.v8_Debug_ObjSrc(2) },
        .{ .name = "object_globals_from.GetGlobalPrototype", .value = ffi.v8_Debug_ObjSrc(3) },
        .{ .name = "object_globals_from.FunctionTemplate_GetPrototypeObject", .value = ffi.v8_Debug_ObjSrc(4) },
        .{ .name = "object_globals_from.ObjectTemplate_NewInstance", .value = ffi.v8_Debug_ObjSrc(5) },
    };
    const ownership = [_]engine.Counter{
        .{ .name = "ownership_checks", .value = @intCast(isolate_ownership.checks()) },
        .{ .name = "ownership_violations", .value = @intCast(isolate_ownership.violations()) },
    };
    const measured = isolate_ownership.mode != .off;
    const counters = allocator.alloc(engine.Counter, handles.len + if (measured) ownership.len else 0) catch return error.OutOfMemory;
    @memcpy(counters[0..handles.len], &handles);
    if (measured) @memcpy(counters[handles.len..], &ownership);
    return counters;
}
