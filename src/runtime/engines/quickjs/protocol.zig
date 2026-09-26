//! The QuickJS adapter's protocol root: module `engine_impl` in a
//! `-Dengine=quickjs` build (`protocol`, below, is what the engine protocol -
//! src/runtime/engine_protocol.zig - forwards to).
//!
//! No engine is linked yet, so every operation is explicit (AGENTS.md, "The
//! engine boundary"): NotSupported where it can fail, and the answer
//! "nothing" where it cannot - no realm, nothing callable, nothing to release,
//! destroy or collect; a value's type and identity read from its IDL arm. It
//! declares none of the engine capabilities; the operations gated on one are
//! declared anyway (the protocol checks every signature) and never reachable.
//! tests/runtime/engine_protocol_test.zig is compiled against this file,
//! which is what checks it against the protocol.

const std = @import("std");
const engine = @import("engine");

pub const protocol = @This();

pub const name = "QuickJS";

pub const capabilities: engine.Capabilities = .{
    .module_scripts = .unsupported,
    .promise_rejection_tracking = .unsupported,
    .reuse_window_proxy = .unsupported,
    .microtask_checkpoint_control = .unsupported,
    .exact_function_realm = .unsupported,
    .restores_snapshots = .unsupported,
    .can_block_control = .unsupported,
    .heap_statistics = .unsupported,
    .heap_snapshots = .unsupported,
    .diagnostic_counters = .unsupported,
};

/// Nothing runs script, so nothing is ever prepared to.
pub const ScriptScope = struct {};

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Agent = engine.Agent;
const Instance = engine.Instance;
const Allocator = std.mem.Allocator;

// 4.1 Engine and agents
pub fn initializeEngine(_: engine.EngineOptions) Error!void {
    return error.NotSupported;
}
pub fn deinitializeEngine() void {}
pub fn createAgent(_: engine.AgentOptions) Error!*Agent {
    return error.NotSupported;
}
pub fn destroyAgent(_: *Agent) void {}
pub fn hasRunningScript(_: *Agent) bool {
    return false;
}
pub fn hasPendingEngineWork(_: *Agent) bool {
    return false;
}
pub fn runEngineTasks(_: *Agent) bool {
    return false;
}
pub fn requestGarbageCollection(_: *Agent) void {}

// 4.2 Realms
pub fn createWindowRealm(_: *const engine.WindowRealmOptions) Error!Context {
    return error.NotSupported;
}
pub fn destroyWindowRealm(_: Context) void {}
pub fn createWorkerRealm(_: *Agent, _: *const engine.WorkerRealmOptions) Error!engine.WorkerRealm {
    return error.NotSupported;
}
pub fn destroyWorkerRealm(_: Context, _: ?engine.RealmSteps, _: ?*anyopaque) void {}
pub fn currentRealm() ?Context {
    return null;
}
pub fn entryRealm() ?Context {
    return null;
}
pub fn incumbentRealm() ?Context {
    return null;
}
pub fn functionRealm(_: JSValue) ?Context {
    return null;
}
pub fn installWindowOperations(_: Context, _: *const engine.WindowOperations) Error!void {
    return error.NotSupported;
}
pub fn defineBuiltinFunction(_: Context, _: []const u8, _: u32, _: *const engine.BuiltinFunction) Error!void {
    return error.NotSupported;
}

// 4.3 Running script
pub fn runClassicScript(_: Context, _: engine.ScriptSource, _: []const u8, _: engine.Reporter) Error!void {
    return error.NotSupported;
}
pub fn evaluateClassicScript(_: Context, _: engine.ScriptSource, _: []const u8, _: bool, _: Allocator, _: engine.Reporter) Error!Owned {
    return error.NotSupported;
}
pub fn compileEventHandler(_: Context, _: *const engine.EventHandlerSource, _: engine.Reporter) Error!?Owned {
    return error.NotSupported;
}
pub fn prepareToRunScript(_: Context) Error!ScriptScope {
    return error.NotSupported;
}
pub fn cleanUpAfterRunningScript(_: ScriptScope) void {}
pub fn runInRealm(_: Context, _: engine.RealmSteps, _: ?*anyopaque) Error!void {
    return error.NotSupported;
}
pub fn runTaskInRealm(_: Context, _: engine.RealmSteps, _: ?*anyopaque) Error!void {
    return error.NotSupported;
}
pub fn performMicrotaskCheckpoint(_: Context) void {}
pub fn queueMicrotask(_: Context, _: engine.RealmSteps, _: ?*anyopaque) Error!void {
    return error.NotSupported;
}
pub fn extractErrorInformation(_: Context, _: JSValue, _: Allocator) Error!engine.ErrorInfo {
    return error.NotSupported;
}
pub fn parseModule(_: Context, _: []const u8, _: []const u8, _: ?*anyopaque) Error!engine.ParseResult {
    return error.NotSupported;
}
pub fn parseJSONModule(_: Context, _: []const u8, _: []const u8, _: ?*anyopaque) Error!engine.ParseResult {
    return error.NotSupported;
}
pub fn moduleRequests(_: *engine.ModuleRecord, _: Allocator) Error![]engine.ModuleRequest {
    return error.NotSupported;
}
pub fn linkModule(_: Context, _: *engine.ModuleRecord, _: engine.ResolveModule, _: ?*anyopaque) Error!?Owned {
    return error.NotSupported;
}
pub fn evaluateModule(_: Context, _: *engine.ModuleRecord) Error!engine.ModuleEvaluation {
    return error.NotSupported;
}
pub fn finishDynamicImport(_: *engine.ImportRequest, _: engine.DynamicImportOutcome) void {}
pub fn releaseModuleRecord(_: *engine.ModuleRecord) void {}

// 4.4 Invoking callbacks
pub fn invokeCallbackFunction(_: JSValue, _: engine.CallbackThis, _: []const JSValue, _: engine.ExceptionBehavior) Error!engine.Completion {
    return error.NotSupported;
}
pub fn callUserObjectOperation(_: JSValue, _: []const u8, _: engine.CallbackThis, _: []const JSValue, _: engine.ExceptionBehavior) Error!engine.Completion {
    return error.NotSupported;
}
pub fn isCallable(_: JSValue) bool {
    return false;
}
pub fn takeCallbackFunction(_: *const anyopaque) Owned {
    return .{ .value = JSValue.jsUndefined };
}

// 4.5 ECMAScript values
pub fn getProperty(_: Context, _: JSValue, _: []const u8) Error!Owned {
    return error.NotSupported;
}
pub fn setProperty(_: Context, _: JSValue, _: []const u8, _: JSValue) Error!void {
    return error.NotSupported;
}
pub fn defineOwnProperty(_: Context, _: JSValue, _: []const u8, _: JSValue, _: engine.PropertyAttributes) Error!void {
    return error.NotSupported;
}
pub fn hasProperty(_: Context, _: JSValue, _: []const u8) Error!bool {
    return error.NotSupported;
}
/// Read from the value's IDL arm; with no engine, a handle or a platform
/// object is an object.
pub fn typeOf(value: JSValue) engine.ValueType {
    return switch (value) {
        .undefined => .undefined,
        .null => .null,
        .boolean => .boolean,
        .number => .number,
        .string => .string,
        .handle, .instance => .object,
    };
}
/// SameValue over the IDL arms: numbers by SameValue (NaN is NaN, +0 is not
/// -0), strings by their code units, objects by identity.
pub fn sameValue(a: JSValue, b: JSValue) bool {
    return switch (a) {
        .undefined => b == .undefined,
        .null => b == .null,
        .boolean => |x| b == .boolean and b.boolean == x,
        .number => |x| b == .number and (if (std.math.isNan(x)) std.math.isNan(b.number) else x == b.number and std.math.signbit(x) == std.math.signbit(b.number)),
        .string => |x| b == .string and std.mem.eql(u8, x.data, b.string.data),
        .handle => |x| b == .handle and x.ptr == b.handle.ptr,
        .instance => |x| b == .instance and x == b.instance,
    };
}
pub fn retainValue(_: Context, _: JSValue) Error!Owned {
    return error.NotSupported;
}
pub fn releaseValue(_: Owned) void {}
pub fn throwValue(_: Context, _: JSValue) Error!void {
    return error.NotSupported;
}
pub fn parseJsonToValue(_: Context, _: []const u8) Error!Owned {
    return error.NotSupported;
}

// 4.6 WebIDL: ECMAScript to IDL
pub fn convertToDOMString(_: Context, _: JSValue, _: Allocator) Error![]u8 {
    return error.NotSupported;
}
pub fn convertToUSVString(_: Context, _: JSValue, _: Allocator) Error![]u8 {
    return error.NotSupported;
}
pub fn convertToUnrestrictedDouble(_: Context, _: JSValue) Error!f64 {
    return error.NotSupported;
}
pub fn convertToPlatformObject(_: Context, _: JSValue) ?*Instance {
    return null;
}
pub fn convertToSequenceOfPlatformObjects(_: Context, _: JSValue, _: Allocator) Error![]*Instance {
    return error.NotSupported;
}
pub fn convertToSequenceOfObjects(_: Context, _: JSValue, _: Allocator) Error![]Owned {
    return error.NotSupported;
}
pub fn convertToSequenceOfDOMStrings(_: Context, _: JSValue, _: Allocator) Error!?[][]u8 {
    return error.NotSupported;
}
pub fn convertToRecordOfStrings(_: Context, _: JSValue, _: engine.StringConversion, _: engine.StringConversion, _: Allocator) Error![]engine.StringRecordEntry {
    return error.NotSupported;
}
pub fn getCopyOfBufferSourceBytes(_: Context, _: JSValue, _: Allocator) Error!?[]u8 {
    return error.NotSupported;
}
pub fn convertToSequence(_: Context, _: JSValue, _: Allocator) Error![]Owned {
    return error.NotSupported;
}
pub fn convertToSequenceOfStringPairs(_: Context, _: JSValue, _: engine.StringConversion, _: Allocator) Error!?[]engine.StringRecordEntry {
    return error.NotSupported;
}
pub fn iterate(_: Context, _: JSValue, _: engine.IterateSteps, _: ?*anyopaque) Error!bool {
    return error.NotSupported;
}
pub fn getIterator(_: Context, _: JSValue, _: engine.IteratorKind) Error!*engine.IteratorRecord {
    return error.NotSupported;
}
pub fn iteratorNext(_: Context, _: *engine.IteratorRecord) Error!Owned {
    return error.NotSupported;
}
pub fn iteratorReturn(_: Context, _: *engine.IteratorRecord, _: JSValue) Error!?Owned {
    return error.NotSupported;
}
pub fn iteratorResult(_: Context, _: JSValue) Error!engine.IteratorResult {
    return error.NotSupported;
}
pub fn releaseIteratorRecord(_: *engine.IteratorRecord) void {}

// 4.7 WebIDL: IDL to ECMAScript
pub fn createSequenceOfValues(_: Context, _: []const JSValue) Error!Owned {
    return error.NotSupported;
}
pub fn createSequenceOfPlatformObjects(_: Context, _: []const *Instance) Error!Owned {
    return error.NotSupported;
}
pub fn createDictionaryObject(_: Context, _: []const engine.DictionaryMember) Error!Owned {
    return error.NotSupported;
}
pub fn createObservableArray(_: Context) Error!JSValue {
    return error.NotSupported;
}
pub fn createFrozenArray(_: Context, _: []const JSValue) Error!Owned {
    return error.NotSupported;
}
pub fn createAsyncIterator(_: Context, _: *const engine.AsyncIteratorSteps, _: ?*anyopaque) Error!Owned {
    return error.NotSupported;
}

// 4.8 Exceptions
pub fn createSimpleException(_: Context, _: engine.SimpleExceptionKind, _: []const u8) Error!Owned {
    return error.NotSupported;
}
pub fn createDOMException(_: Context, _: []const u8, _: []const u8) Error!Owned {
    return error.NotSupported;
}

// 4.9 Promises
pub fn createPromise(_: Context) Error!engine.PromiseCapability {
    return error.NotSupported;
}
pub fn resolvePromise(_: *engine.PromiseCapability, _: JSValue) void {}
pub fn rejectPromise(_: *engine.PromiseCapability, _: JSValue) void {}
pub fn releasePromiseCapability(_: *engine.PromiseCapability) void {}
pub fn createResolvedPromise(_: Context, _: JSValue) Error!Owned {
    return error.NotSupported;
}
pub fn createRejectedPromise(_: Context, _: JSValue) Error!Owned {
    return error.NotSupported;
}
pub fn reactToPromise(_: Context, _: JSValue, _: *const engine.PromiseReactionSteps, _: ?*anyopaque) Error!void {
    return error.NotSupported;
}
pub fn markPromiseAsHandled(_: JSValue) void {}
pub fn promiseIsHandled(_: JSValue) bool {
    return false;
}

// 4.10 Buffers
pub fn createArrayBuffer(_: Context, _: []const u8) Error!Owned {
    return error.NotSupported;
}
pub fn allocateArrayBuffer(_: Context, _: usize) Error!Owned {
    return error.NotSupported;
}
pub fn createArrayBufferView(_: Context, _: engine.ViewType, _: JSValue, _: usize, _: usize) Error!Owned {
    return error.NotSupported;
}
pub fn describeArrayBufferView(_: JSValue) ?engine.ArrayBufferViewDescription {
    return null;
}
pub fn writeIntoArrayBufferView(_: JSValue, _: []const u8, _: usize) Error!void {
    return error.NotSupported;
}
pub fn borrowArrayBufferBytes(_: JSValue) ?[]u8 {
    return null;
}
pub fn isDetachedBuffer(_: JSValue) bool {
    return false;
}
pub fn canTransferArrayBuffer(_: JSValue) bool {
    return false;
}
pub fn transferArrayBuffer(_: Context, _: JSValue) Error!Owned {
    return error.NotSupported;
}
pub fn getViewedArrayBuffer(_: Context, _: JSValue) Error!Owned {
    return error.NotSupported;
}

// 4.11 Structured serialization
pub fn structuredSerializeForStorage(_: Context, _: JSValue, _: Allocator) Error![]u8 {
    return error.NotSupported;
}
pub fn structuredDeserialize(_: Context, _: []const u8) Error!Owned {
    return error.NotSupported;
}
pub fn structuredSerializeWithTransfer(_: Context, _: JSValue, _: []const JSValue, _: engine.TransferableCheck, _: ?*anyopaque, _: Allocator) Error!engine.SerializedWithTransfer {
    return error.NotSupported;
}
pub fn structuredDeserializeWithTransfer(_: Context, _: []const u8, _: []const []const u8) Error!Owned {
    return error.NotSupported;
}

// 4.12 Platform objects
pub fn hasWrapper(_: *Instance) bool {
    return false;
}
pub fn keepPlatformObjectAlive(_: *Instance) void {}
pub fn releasePlatformObject(_: *Instance) void {}
pub fn platformObjectDestroyed(_: *Instance) void {}

// 4.13 Diagnostics tier
pub fn heapStatistics(_: *Agent) engine.HeapStatistics {
    return .{ .used = 0, .total = 0, .external = 0, .realm_count = 0, .detached_realm_count = 0 };
}
pub fn writeHeapSnapshot(_: *Agent, _: [:0]const u8) bool {
    return false;
}
pub fn diagnosticCounters(_: Allocator) Error![]engine.Counter {
    return error.NotSupported;
}
