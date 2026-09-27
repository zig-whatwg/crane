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

// TODO(protocol): implement - design 4.1 (snapshot_loader.initializePlatformForRuntime is the platform half; the snapshot blob is new)
pub fn initializeEngine(options: engine.EngineOptions) Error!void {
    _ = options;
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.1
pub fn deinitializeEngine() void {
    notImplemented("deinitializeEngine", "4.1");
}

/// Partly wired: an isolate as worker_realm makes one, [[CanBlock]] set.
pub fn createAgent(options: engine.AgentOptions) Error!*Agent {
    // TODO(protocol): implement - design 4.1 (agents from the snapshot, and the host hooks installed per agent)
    if (options.from_snapshot) return error.NotSupported;
    const hooks = options.hooks;
    if (hooks.loadImportedModule != null or hooks.importMetaUrl != null or
        hooks.promiseRejectionTracker != null or hooks.afterMicrotaskCheckpoint != null) return error.NotSupported;
    const agent = table.createAgent.?() catch |err| return protocolError(err);
    if (!options.can_block) ffi.v8_Isolate_SetAllowAtomicsWait(isolateOf(agent), false);
    return agent;
}

pub fn destroyAgent(agent: *Agent) void {
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

// ============================================================================
// 4.2 Realms
// ============================================================================

// TODO(protocol): implement - design 4.2 (page-realm drafts: createWindowRealm from Context.zig's createV8Context/createV8ContextFresh)
pub fn createWindowRealm(options: *const engine.WindowRealmOptions) Error!Context {
    _ = options;
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.2 (Blink DisposeContext order)
pub fn destroyWindowRealm(realm: Context) void {
    _ = realm;
    notImplemented("destroyWindowRealm", "4.2");
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

// TODO(protocol): implement - design 4.2 (replaces GetEnteredOrMicrotaskContext)
pub fn entryRealm() ?Context {
    notImplemented("entryRealm", "4.2");
}

// TODO(protocol): implement - design 4.2 (replaces the accessor-window stack)
pub fn incumbentRealm() ?Context {
    notImplemented("incumbentRealm", "4.2");
}

// TODO(protocol): implement - design 4.2 (GetFunctionRealm follows bound functions and proxies; V8's creation context does not)
pub fn functionRealm(value: JSValue) ?Context {
    _ = value;
    notImplemented("functionRealm", "4.2");
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

/// The table's reporter, reporting as the protocol's: the table's
/// ErrorInfo, with the realm the script ran in.
const ReportBridge = struct {
    reporter: engine.Reporter,
    realm: Context,

    fn report(host: ?*anyopaque, info: *const runtime.ErrorInfo) void {
        const self: *const ReportBridge = @ptrCast(@alignCast(host.?));
        const protocol_info: engine.ErrorInfo = .{
            .message = info.message,
            .filename = info.filename,
            .lineno = info.lineno,
            .colno = info.colno,
            .error_value = info.error_value orelse JSValue.jsUndefined,
            .realm = self.realm,
        };
        self.reporter.report(self.reporter.host, &protocol_info);
    }
};

/// Partly wired: UTF-8 source through the table's runClassicScript.
pub fn runClassicScript(realm: Context, source: engine.ScriptSource, url: []const u8, reporter: engine.Reporter) Error!void {
    const text = switch (source) {
        .utf8 => |text| text,
        // TODO(protocol): implement - design 4.3 (a string source keeps every code unit: timer string handlers)
        .string => return error.NotSupported,
    };
    const bridge: ReportBridge = .{ .reporter = reporter, .realm = realm };
    v8_engine.v8RunClassicScript(realm, text, if (url.len == 0) null else url, ReportBridge.report, @constCast(&bridge)) catch |err|
        return protocolError(err);
}

// TODO(protocol): implement - design 4.3 (page-realm draft; replaces compileScript/runScript and Context.evaluateScript)
pub fn evaluateClassicScript(realm: Context, source: engine.ScriptSource, url: []const u8, to_string: bool, allocator: Allocator, reporter: engine.Reporter) Error!Owned {
    _ = .{ realm, source, url, to_string, allocator, reporter };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (the handler's scopes: document, form owner, element)
pub fn compileEventHandler(realm: Context, source: *const engine.EventHandlerSource, reporter: engine.Reporter) Error!?Owned {
    _ = .{ realm, source, reporter };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (HTML 8.1.4.3: the entry stack, and a checkpoint on clean up; realm_entry.enter is the entering half)
pub fn prepareToRunScript(realm: Context) Error!ScriptScope {
    _ = realm;
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3
pub fn cleanUpAfterRunningScript(scope: ScriptScope) void {
    _ = scope;
    notImplemented("cleanUpAfterRunningScript", "4.3");
}

pub fn runInRealm(realm: Context, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    return v8_engine.v8RunInRealm(realm, steps, data) catch |err| protocolError(err);
}

pub fn runTaskInRealm(realm: Context, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    return v8_engine.v8RunTaskInRealm(realm, steps, data) catch |err| protocolError(err);
}

/// A realm that cannot be entered any more has no microtasks left to run.
pub fn performMicrotaskCheckpoint(realm: Context) void {
    v8_engine.v8PerformMicrotaskCheckpoint(realm) catch {};
}

pub fn queueMicrotask(realm: Context, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    return value_construction.queueMicrotask(realm, steps, data) catch |err| protocolError(err);
}

// TODO(protocol): implement - design 4.3 (engine.zig's reportPending builds it for runClassicScript)
pub fn extractErrorInformation(realm: Context, value: JSValue, allocator: Allocator) Error!engine.ErrorInfo {
    _ = .{ realm, value, allocator };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (modules; replace compileModule/runModule/runModuleAsync/hasTopLevelAwait/disposeModule)
pub fn parseModule(realm: Context, source: []const u8, url: []const u8, host_defined: ?*anyopaque) Error!engine.ParseResult {
    _ = .{ realm, source, url, host_defined };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (modules)
pub fn parseJSONModule(realm: Context, source: []const u8, url: []const u8, host_defined: ?*anyopaque) Error!engine.ParseResult {
    _ = .{ realm, source, url, host_defined };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (modules)
pub fn moduleRequests(record: *engine.ModuleRecord, allocator: Allocator) Error![]engine.ModuleRequest {
    _ = .{ record, allocator };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (modules)
pub fn linkModule(realm: Context, record: *engine.ModuleRecord, resolve: engine.ResolveModule, data: ?*anyopaque) Error!?Owned {
    _ = .{ realm, record, resolve, data };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (modules)
pub fn evaluateModule(realm: Context, record: *engine.ModuleRecord) Error!engine.ModuleEvaluation {
    _ = .{ realm, record };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.3 (modules)
pub fn finishDynamicImport(request: *engine.ImportRequest, outcome: engine.DynamicImportOutcome) void {
    _ = .{ request, outcome };
    notImplemented("finishDynamicImport", "4.3");
}

// TODO(protocol): implement - design 4.3 (modules)
pub fn releaseModuleRecord(record: *engine.ModuleRecord) void {
    _ = record;
    notImplemented("releaseModuleRecord", "4.3");
}

// ============================================================================
// 4.4 Invoking callbacks
// ============================================================================

// TODO(protocol): implement - design 4.4 (page_realm.invokeCallbackFunction is the report-only, realm-given form; the protocol's takes the callback's realm and returns the Completion)
pub fn invokeCallbackFunction(callback: JSValue, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior) Error!engine.Completion {
    _ = .{ callback, this_arg, args, behavior };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.4 (callback_interfaces.callUserObjectOperation takes a CallbackWrapper and rethrows only)
pub fn callUserObjectOperation(callback: JSValue, operation: []const u8, this_arg: engine.CallbackThis, args: []const JSValue, behavior: engine.ExceptionBehavior) Error!engine.Completion {
    _ = .{ callback, operation, this_arg, args, behavior };
    return error.NotSupported;
}

pub fn isCallable(value: JSValue) bool {
    return table.isCallable.?(value);
}

pub fn takeCallbackFunction(argument: *const anyopaque) Owned {
    return owned(callback_interfaces.takeCallbackFunction(argument));
}

// ============================================================================
// 4.5 ECMAScript values
// ============================================================================

// TODO(protocol): implement - design 4.5 (engine.zig's getMember is Get for the getProperty* helpers)
pub fn getProperty(realm: Context, object: JSValue, property: []const u8) Error!Owned {
    _ = .{ realm, object, property };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.5 (replaces setPropertyOnObject, which sets strings only)
pub fn setProperty(realm: Context, object: JSValue, property: []const u8, value: JSValue) Error!void {
    _ = .{ realm, object, property, value };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.5 (replaces defineOwnPropertyOnObject)
pub fn defineOwnProperty(realm: Context, object: JSValue, property: []const u8, value: JSValue, attributes: engine.PropertyAttributes) Error!void {
    _ = .{ realm, object, property, value, attributes };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.5
pub fn hasProperty(realm: Context, object: JSValue, property: []const u8) Error!bool {
    _ = .{ realm, object, property };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.5
pub fn typeOf(value: JSValue) engine.ValueType {
    _ = value;
    notImplemented("typeOf", "4.5");
}

// TODO(protocol): implement - design 4.5
pub fn sameValue(a: JSValue, b: JSValue) bool {
    _ = .{ a, b };
    notImplemented("sameValue", "4.5");
}

pub fn retainValue(realm: Context, value: JSValue) Error!Owned {
    return owned(value_operations.retainValue(realm, value) catch |err| return protocolError(err));
}

pub fn releaseValue(value: Owned) void {
    v8_engine.v8ReleaseValue(value.value);
}

pub fn throwValue(realm: Context, value: JSValue) Error!void {
    return value_operations.throwValue(realm, value) catch |err| protocolError(err);
}

// TODO(protocol): implement - design 4.5 (the table's parseJson evaluates a JSON.parse script; v8_JSON_Parse_FromBuffer returns a Local and leaves the SyntaxError pending)
pub fn parseJsonToValue(realm: Context, bytes: []const u8) Error!Owned {
    _ = .{ realm, bytes };
    return error.NotSupported;
}

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

// TODO(protocol): implement - design 4.6 (webidl_conversions.iterate is the walk)
pub fn convertToSequence(realm: Context, value: JSValue, allocator: Allocator) Error![]Owned {
    _ = .{ realm, value, allocator };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (URLSearchParams / Headers init)
pub fn convertToSequenceOfStringPairs(realm: Context, value: JSValue, conversion: engine.StringConversion, allocator: Allocator) Error!?[]engine.StringRecordEntry {
    _ = .{ realm, value, conversion, allocator };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (replaces invokeForEach/getCollectionLength/getCollectionElement)
pub fn iterate(realm: Context, value: JSValue, each: engine.IterateSteps, data: ?*anyopaque) Error!bool {
    _ = .{ realm, value, each, data };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (iterator records)
pub fn getIterator(realm: Context, value: JSValue, kind: engine.IteratorKind) Error!*engine.IteratorRecord {
    _ = .{ realm, value, kind };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (iterator records)
pub fn iteratorNext(realm: Context, record: *engine.IteratorRecord) Error!Owned {
    _ = .{ realm, record };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (iterator records)
pub fn iteratorReturn(realm: Context, record: *engine.IteratorRecord, value: JSValue) Error!?Owned {
    _ = .{ realm, record, value };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (iterator records)
pub fn iteratorResult(realm: Context, result: JSValue) Error!engine.IteratorResult {
    _ = .{ realm, result };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.6 (iterator records)
pub fn releaseIteratorRecord(record: *engine.IteratorRecord) void {
    _ = record;
    notImplemented("releaseIteratorRecord", "4.6");
}

// ============================================================================
// 4.7 WebIDL: IDL to ECMAScript
// ============================================================================

pub fn createSequenceOfValues(realm: Context, values: []const JSValue) Error!Owned {
    return owned(webidl_conversions.createSequenceOfValues(realm, values) catch |err| return protocolError(err));
}

pub fn createSequenceOfPlatformObjects(realm: Context, instances: []const *Instance) Error!Owned {
    return owned(v8_engine.v8CreateSequenceOfPlatformObjects(realm, instances) catch |err| return protocolError(err));
}

pub fn createDictionaryObject(realm: Context, members: []const engine.DictionaryMember) Error!Owned {
    return owned(value_construction.createDictionaryObject(realm, members) catch |err| return protocolError(err));
}

pub fn createObservableArray(realm: Context) Error!JSValue {
    return observable_array.createObservableArray(realm) catch |err| protocolError(err);
}

// TODO(protocol): implement - design 4.7 (value_operations.createFrozenArrayOfPlatformObjects is the platform-object form)
pub fn createFrozenArray(realm: Context, values: []const JSValue) Error!Owned {
    _ = .{ realm, values };
    return error.NotSupported;
}

// TODO(protocol): implement - design 4.7 (was wrapAsyncIterator, a stub)
pub fn createAsyncIterator(realm: Context, steps: *const engine.AsyncIteratorSteps, data: ?*anyopaque) Error!Owned {
    _ = .{ realm, steps, data };
    return error.NotSupported;
}

// ============================================================================
// 4.8 Exceptions
// ============================================================================

/// Partly wired: every kind but SyntaxError. V8's embedder API reaches no
/// EvalError or URIError intrinsic either; those stay NotSupported, as the
/// table's answer them.
pub fn createSimpleException(realm: Context, kind: engine.SimpleExceptionKind, message: []const u8) Error!Owned {
    const table_kind: runtime.SimpleExceptionKind = switch (kind) {
        .EvalError => .EvalError,
        .RangeError => .RangeError,
        .ReferenceError => .ReferenceError,
        .TypeError => .TypeError,
        .URIError => .URIError,
        // TODO(protocol): implement - design 4.8 (SyntaxError, for HTML module errors)
        .SyntaxError => return error.NotSupported,
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

/// A resolve that fails leaves the promise pending: the engine failed, and
/// "resolve" has no way to say so.
pub fn resolvePromise(capability: *engine.PromiseCapability, value: JSValue) void {
    switch (value) {
        .instance => |instance| v8_engine.v8ResolvePromiseWithInstance(capability.state, instance) catch {},
        .handle => |h| v8_engine.v8ResolvePromise(capability.state, capability.state, h.ptr) catch {},
        .undefined => v8_engine.v8ResolvePromise(capability.state, capability.state, null) catch {},
        else => resolveWithConverted(capability.state, value) catch {},
    }
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

/// As resolvePromise: a reject that fails leaves the promise pending.
pub fn rejectPromise(capability: *engine.PromiseCapability, reason: JSValue) void {
    v8_engine.v8RejectPromiseWithValue(capability.state, reason) catch {};
}

pub fn releasePromiseCapability(capability: *engine.PromiseCapability) void {
    if (handleOf(capability.promise)) |promise| ffi.v8_Promise_Dispose(@ptrCast(promise));
    v8_engine.v8DestroyPromiseHandle(capability.state, promise_allocator);
}

pub fn createResolvedPromise(realm: Context, value: JSValue) Error!Owned {
    return owned(value_construction.createResolvedPromise(realm, value) catch |err| return protocolError(err));
}

pub fn createRejectedPromise(realm: Context, reason: JSValue) Error!Owned {
    return owned(value_construction.createRejectedPromise(realm, reason) catch |err| return protocolError(err));
}

// TODO(protocol): implement - design 4.9 (was chainPromiseHandlers, whose callbacks get raw engine values)
pub fn reactToPromise(realm: Context, promise: JSValue, steps: *const engine.PromiseReactionSteps, data: ?*anyopaque) Error!void {
    _ = .{ realm, promise, steps, data };
    return error.NotSupported;
}

/// A `.handle` is a Global either way it is tagged; the FFI leaves anything
/// but a promise alone.
pub fn markPromiseAsHandled(promise: JSValue) void {
    if (handleOf(promise)) |value| ffi.v8_Promise_MarkAsHandled(value);
}

pub fn promiseIsHandled(promise: JSValue) bool {
    return ffi.v8_Promise_HasHandler(handleOf(promise) orelse return false);
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

pub fn describeArrayBufferView(value: JSValue) ?engine.ArrayBufferViewDescription {
    return array_buffer_views.describeArrayBufferView(value);
}

pub fn writeIntoArrayBufferView(view: JSValue, bytes: []const u8, starting_offset: usize) Error!void {
    return array_buffer_views.writeIntoArrayBufferView(view, bytes, starting_offset) catch |err| protocolError(err);
}

pub fn borrowArrayBufferBytes(buffer: JSValue) ?[]u8 {
    const target = handleOf(buffer) orelse return null;
    var data: ?*anyopaque = null;
    var byte_length: usize = 0;
    if (!ffi.v8_ArrayBuffer_Bytes(target, &data, &byte_length)) return null;
    const bytes: [*]u8 = @ptrCast(data orelse return @constCast(&[_]u8{}));
    return bytes[0..byte_length];
}

pub fn isDetachedBuffer(buffer: JSValue) bool {
    return ffi.v8_ArrayBuffer_IsDetachedValue(handleOf(buffer) orelse return false);
}

pub fn canTransferArrayBuffer(buffer: JSValue) bool {
    return ffi.v8_ArrayBuffer_CanTransfer(handleOf(buffer) orelse return false);
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

// TODO(protocol): implement - design 4.12 (the engine-boundary lane's commit 4 adds the release of pending activity)
pub fn releasePlatformObject(instance: *Instance) void {
    _ = instance;
    notImplemented("releasePlatformObject", "4.12");
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

/// The adapter's live-handle counters: Globals created minus disposed.
pub fn diagnosticCounters(allocator: Allocator) Error![]engine.Counter {
    const counters = [_]engine.Counter{
        .{ .name = "live_string_globals", .value = ffi.v8_Debug_LiveStringGlobals() },
        .{ .name = "live_context_globals", .value = ffi.v8_Debug_LiveContextGlobals() },
        .{ .name = "live_object_globals", .value = ffi.v8_Debug_LiveObjectGlobals() },
        .{ .name = "live_weak_callback_data", .value = ffi.v8_Debug_LiveWeakCallbackData() },
    };
    return allocator.dupe(engine.Counter, &counters) catch error.OutOfMemory;
}
