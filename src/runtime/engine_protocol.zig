//! Crane's JavaScript engine protocol: module `engine`.
//!
//! The operations every engine adapter provides, declared once here with the
//! signatures that ARE the contract (AGENTS.md, "The engine boundary").
//! Consumers `@import("engine")` and call `engine.op(...)`:
//!
//!     const engine = @import("engine");
//!     const promise = try engine.createResolvedPromise(realm, value);
//!     return promise.take(); // OWNED: the binding takes it
//!
//! Dispatch is static. build.zig binds `engine_impl` to the adapter
//! `-Dengine=` selects, whose root declares `pub const protocol` - the V8
//! module's src/runtime/engines/v8/protocol.zig, or the JavaScriptCore or
//! QuickJS protocol root - and each operation below is an inline function
//! whose body calls that namespace's function of the same name, so a call
//! site compiles to a direct call into the adapter: no table, no optional
//! unwrap, no `ctx.getEngine()`.
//!
//! The contract is checked at compile time, whenever this module is used (the
//! `comptime` block at the end). Every public inline function here is an
//! operation, and the adapter must declare a function of the same name with
//! exactly the same parameter and return types - every operation, including
//! those gated on a capability the engine lacks (its adapter answers them
//! NotSupported; the gate keeps them from being called). A missing or
//! mis-typed one is a compile error in this file that names the operation,
//! whether or not anything calls it. In a test build the adapter's functions
//! are also compiled whole, so a stub that does not type-check fails there.
//!
//! Capabilities are tri-state and comptime-known: `.native` (the engine does
//! it), `.emulated` (the adapter builds it on the engine's public API, with the
//! deviations listed at its constant) or `.unsupported` (the host takes the
//! declared fallback). Hosts branch only on `.unsupported`:
//!
//!     if (engine.capabilities.promise_rejection_tracking != .unsupported) {
//!         handled = engine.promiseIsHandled(promise);
//!     }
//!
//! On an engine where it is `.unsupported` that branch is compiled out, and
//! calling a gated operation outside such a branch is a compile error naming
//! the capability. A gated operation names its capability once: in its body.
//!
//! Ownership is in the types. A `JSValue` PARAMETER is BORROWED for the call;
//! a result the caller must release is `Owned`; `realm: Context` is BORROWED.
//! Slices an operation returns are allocated with the allocator it was given.
//!
//! Status: phase 3 step A - every operation of the design
//! (tmp/plans/engine-protocol-design.md section 4) is declared and checked;
//! adapters answer the ones not yet built with NotSupported, marked
//! `TODO(protocol): implement` in the adapter. The runtime Engine table
//! (src/runtime/engine_interface.zig) keeps serving existing callers.

const std = @import("std");
const runtime = @import("runtime");
const impl = @import("engine_impl").protocol;

// ============================================================================
// Types (design section 2)
// ============================================================================

/// A realm's identity - HTML's realm, ECMAScript's Realm Record - as the
/// runtime records it. Stable until the realm is torn down; a retired realm
/// has no engine realm behind it. BORROWED wherever an operation takes one.
pub const Context = runtime.Context;

/// An ECMAScript agent: a V8 isolate, a JavaScriptCore context group. Opaque;
/// a realm records its own (`Context.agent`).
pub const Agent = runtime.Agent;

/// The IDL-level value. As a parameter, always BORROWED for the call.
pub const JSValue = runtime.JSValue;

/// A platform object: the host's side of a wrapper.
pub const Instance = runtime.Instance;

/// Steps an operation runs inside a realm; `data` is the pointer the caller
/// passed alongside them.
pub const RealmSteps = runtime.RealmSteps;

/// What an operation fails with.
///
/// - `TypeError`: the spec says "throw a TypeError" and nothing has been
///   thrown yet - the caller throws it (a binding does, from its error).
/// - `ExceptionPending`: script threw, or the engine threw on the spec's
///   behalf; the exception is pending in the engine - return without
///   throwing another.
/// - `DataCloneError`: HTML serialization "throw a DataCloneError" where
///   nothing has been thrown yet.
/// - `NotSupported`: this engine does not provide the operation.
/// - `OperationFailed`: the engine failed (no context, out of handles).
pub const Error = error{
    OperationFailed,
    OutOfMemory,
    TypeError,
    ExceptionPending,
    DataCloneError,
    NotSupported,
};

/// A value the caller owns: every operation whose result must be released
/// returns one. Exactly one of `release` and `take` ends it.
pub const Owned = struct {
    value: JSValue,

    /// Give the value back to the engine.
    pub fn release(self: Owned) void {
        releaseValue(self);
    }

    /// Hand the value, and the duty to release it, to something documented
    /// to take ownership - the binding, for an operation's result.
    pub fn take(self: Owned) JSValue {
        return self.value;
    }
};

/// ECMAScript's Completion Record, from an operation that runs script: the
/// value it returned, or the value it threw. OWNED either way.
pub const Completion = union(enum) {
    normal: Owned,
    throw: Owned,
};

/// HTML "extract error information" (8.1.4.6 "report an exception", step 2):
/// what an ErrorEvent carries. BORROWED for the call it is handed to: a
/// reporter that keeps any of it copies it first.
pub const ErrorInfo = struct {
    message: []const u8,
    /// The script's URL, or "" when it has none.
    filename: []const u8,
    /// 1-based; 0 when unknown.
    lineno: u32,
    /// 1-based, as ErrorEvent.colno counts; 0 when unknown.
    colno: u32,
    /// The thrown value (undefined when there was none). BORROWED.
    error_value: JSValue,
    /// The realm whose global object the exception is reported for, when the
    /// engine knows it.
    realm: ?Context,
};

/// HTML "report an exception", as the host supplies it to an operation that
/// runs script with "rethrow errors" false. The engine calls `report` from
/// inside the operation, after "clean up after running script".
pub const Reporter = struct {
    report: *const fn (host: ?*anyopaque, info: *const ErrorInfo) void,
    host: ?*anyopaque = null,
};

/// WebIDL's exception behavior for invoking script.
pub const ExceptionBehavior = union(enum) {
    /// An abrupt completion comes back as `Completion.throw`: the caller
    /// throws it on (`throwValue`) or handles it.
    rethrow,
    /// An abrupt completion is reported, and the invocation completes
    /// normally with undefined.
    report: Reporter,
};

/// The `this` value a callback is invoked with.
pub const CallbackThis = runtime.CallbackThis;

/// A classic script's source: UTF-8 text, or a string value whose every code
/// unit is kept (a timer's string handler).
pub const ScriptSource = union(enum) {
    utf8: []const u8,
    /// BORROWED.
    string: JSValue,
};

/// HTML "getting the current value of the event handler", step 3: an event
/// handler content attribute's body, and the scopes it is compiled in.
pub const EventHandlerSource = struct {
    /// The attribute's value.
    body: []const u8,
    /// The handler's name ("onclick"): the function's name.
    name: []const u8,
    /// The document's URL: the script's URL.
    url: []const u8,
    /// Where the attribute is, for errors (1-based; 0 when unknown).
    lineno: u32,
    /// The function's parameter list (step 3.6).
    parameters: enum {
        /// `event` - every handler but the two below.
        event,
        /// `evt` - an SVG element's handlers.
        evt,
        /// `event, source, lineno, colno, error` - a Window's onerror.
        onerror,
    },
    /// The scopes (step 3.9), innermost last: the element's node document (or
    /// the Window's associated Document), its form owner, the element. Null
    /// where the handler has none.
    document: ?*Instance,
    form_owner: ?*Instance,
    element: ?*Instance,
};

/// The state the adapter keeps between "prepare to run script" and "clean up
/// after running script". The adapter's own type; hosts only pass it back.
pub const ScriptScope = impl.ScriptScope;

/// WebIDL "a new promise": the promise and what resolves or rejects it. OWNED
/// (`releasePromiseCapability`); `promise` is a BORROWED view, valid until
/// then - retain it to keep it past that.
pub const PromiseCapability = struct {
    promise: JSValue,
    /// The adapter's resolving state.
    state: *anyopaque,
};

/// WebIDL "react to" a promise: steps for fulfillment and for rejection. The
/// value each is given is BORROWED for the call.
pub const PromiseReactionSteps = struct {
    fulfilled: ?*const fn (data: ?*anyopaque, value: JSValue) void = null,
    rejected: ?*const fn (data: ?*anyopaque, reason: JSValue) void = null,
};

/// WebIDL's steps behind an asynchronous iterator object.
pub const AsyncIteratorSteps = struct {
    /// "get the next iteration result": a promise for an iterator result
    /// object. OWNED.
    next: *const fn (data: ?*anyopaque) Error!Owned,
    /// "asynchronous iterator return", when the declaration has one: a
    /// promise. `value` BORROWED; the result OWNED.
    @"return": ?*const fn (data: ?*anyopaque, value: JSValue) Error!Owned = null,
    /// The iterator object is gone: free `data`.
    finalize: ?*const fn (data: ?*anyopaque) void = null,
};

/// An ECMAScript Module Record. OWNED (`releaseModuleRecord`).
pub const ModuleRecord = opaque {};

/// An `import()` in flight: the host owns it from `loadImportedModule` until
/// `finishDynamicImport`.
pub const ImportRequest = opaque {};

/// A ModuleRequest Record: a specifier and its `type` import attribute.
pub const ModuleRequest = struct {
    specifier: []const u8,
    type_attribute: ?[]const u8,
};

/// ParseModule's result: a record, or the SyntaxError (OWNED).
pub const ParseResult = union(enum) {
    record: *ModuleRecord,
    parse_error: Owned,
};

/// Evaluate()'s result: completed, rejected with a value, or pending on a
/// promise (top-level await). OWNED values.
pub const ModuleEvaluation = union(enum) {
    completed,
    rejected: Owned,
    pending: Owned,
};

/// HostLoadImportedModule's answer, for Link: the record `request` of
/// `referrer` resolves to, or null (Link fails).
pub const ResolveModule = *const fn (data: ?*anyopaque, referrer: *ModuleRecord, request: ModuleRequest) ?*ModuleRecord;

/// FinishLoadingImportedModule's result for an `import()`.
pub const DynamicImportOutcome = union(enum) {
    module: *ModuleRecord,
    /// The failure to reject with. BORROWED.
    failure: JSValue,
};

/// An Iterator Record (async iteration, ReadableStream.from). OWNED
/// (`releaseIteratorRecord`).
pub const IteratorRecord = opaque {};

/// GetIterator's kind.
pub const IteratorKind = enum { sync, async };

/// IteratorComplete and IteratorValue of an iterator result object.
pub const IteratorResult = struct {
    done: bool,
    value: Owned,
};

/// The steps `iterate` runs for each item; `item` BORROWED for the call.
pub const IterateSteps = *const fn (data: ?*anyopaque, item: JSValue) Error!void;

/// ECMAScript Type(V).
pub const ValueType = enum { undefined, null, boolean, string, symbol, number, bigint, object };

/// A property's attributes, for DefinePropertyOrThrow.
pub const PropertyAttributes = struct {
    writable: bool,
    enumerable: bool,
    configurable: bool,
};

/// WebIDL "create a simple exception" of type T.
pub const SimpleExceptionKind = enum { EvalError, RangeError, ReferenceError, SyntaxError, TypeError, URIError };

/// A TypedArray's element type, or DataView.
pub const ViewType = runtime.arraybuffer_view.ViewType;
pub const ArrayBufferViewDescription = runtime.ArrayBufferViewDescription;

pub const StringConversion = runtime.StringConversion;
pub const StringRecordEntry = runtime.StringRecordEntry;
pub const DictionaryMember = runtime.DictionaryMember;
pub const SerializedWithTransfer = runtime.SerializedWithTransfer;
pub const TransferableState = runtime.TransferableState;
pub const TransferableCheck = runtime.TransferableCheck;
pub const WindowOperations = runtime.WindowOperations;
pub const WorkerRealmOptions = runtime.WorkerRealmOptions;
pub const WorkerRealm = runtime.WorkerRealm;
pub const BuiltinFunction = runtime.BuiltinFunction;

/// The process-wide engine: its heap snapshot, when it restores realms from
/// one.
pub const EngineOptions = struct {
    /// The snapshot blob agents are created from (`AgentOptions.from_snapshot`).
    /// BORROWED until `deinitializeEngine`.
    snapshot: ?[]const u8 = null,
};

/// HTML "obtain an agent".
pub const AgentOptions = struct {
    /// [[CanBlock]] - honoured where `can_block_control`.
    can_block: bool,
    /// Create the agent's realms from the engine's snapshot - honoured where
    /// `restores_snapshots`.
    from_snapshot: bool,
    /// BORROWED for the agent's life.
    hooks: *const HostHooks,
    /// Passed to every hook.
    host: ?*anyopaque = null,
};

/// The host's side of the ECMAScript host hooks, installed per agent. A hook
/// whose capability the engine lacks is never called.
pub const HostHooks = struct {
    /// HostLoadImportedModule for `import()` [module_scripts]: the host owns
    /// `request` until `finishDynamicImport`.
    loadImportedModule: ?*const fn (host: ?*anyopaque, realm: Context, referrer: ?*anyopaque, specifier: []const u8, type_attribute: ?[]const u8, request: *ImportRequest) void = null,
    /// HostGetImportMetaProperties [module_scripts]: `import.meta.url` of the
    /// module the host defined as `module_host_defined`.
    importMetaUrl: ?*const fn (host: ?*anyopaque, module_host_defined: *anyopaque) []const u8 = null,
    /// HostPromiseRejectionTracker [promise_rejection_tracking]. `promise` OWNED.
    promiseRejectionTracker: ?*const fn (host: ?*anyopaque, realm: Context, promise: Owned, operation: RejectionOperation) void = null,
    /// HTML "perform a microtask checkpoint" step 5: notify about rejected
    /// promises.
    afterMicrotaskCheckpoint: ?*const fn (host: ?*anyopaque, agent: *Agent) void = null,
};

/// HostPromiseRejectionTracker's operation.
pub const RejectionOperation = enum { reject, handle };

/// The global `this` of a new Window realm.
pub const GlobalThis = union(enum) {
    /// A new WindowProxy.
    new_window_proxy,
    /// The WindowProxy of a realm this one replaces (a navigation that makes
    /// a new Window) [reuse_window_proxy].
    window_proxy_of: Context,
};

/// HTML "create a new realm" with a Window global.
pub const WindowRealmOptions = struct {
    /// The agent to create the realm in. BORROWED; it outlives the realm.
    agent: *Agent,
    /// For the realm's runtime state.
    allocator: std.mem.Allocator,
    /// Restore the realm from the engine's snapshot - honoured where
    /// `restores_snapshots`; a restore that fails falls back to afresh.
    from_snapshot: bool,
    /// The host's timers, shared by every realm of the agent.
    timer: ?runtime.TimerInterface,
    /// The realm's origin, serialized; null for an opaque one.
    origin: ?[]const u8 = null,
    global_this: GlobalThis = .new_window_proxy,
    /// HTML "create a new realm", the customization for the global object:
    /// the host makes the realm's Window. `global_this` is OWNED and handed
    /// over: the Window keeps it as the global it is bound to. On null the
    /// engine releases it, undoes the realm and fails.
    create_global_object: *const fn (realm: Context, global_this: JSValue, host: ?*anyopaque) ?*Instance,
    /// HTML IsPlatformObjectSameOrigin, for the WindowProxy and Location
    /// cross-origin checks: whether `object` is same origin-domain with
    /// `current`.
    is_platform_object_same_origin: ?*const fn (host: ?*anyopaque, current: Context, object: *Instance) bool = null,
    host: ?*anyopaque = null,
};

/// An agent's heap, for the diagnostics tier.
pub const HeapStatistics = struct {
    used: usize,
    total: usize,
    external: usize,
    realm_count: usize,
    detached_realm_count: usize,
};

/// One of the adapter's own counters, for the diagnostics tier. `name` is
/// static.
pub const Counter = struct {
    name: []const u8,
    value: i64,
};

// ============================================================================
// Capabilities (design section 3)
// ============================================================================

/// How an engine has a capability.
pub const Support = enum {
    /// The engine does it.
    native,
    /// The adapter builds it on the engine's public API; its deviations are
    /// listed at the adapter's constant.
    emulated,
    /// The host takes the declared fallback.
    unsupported,
};

/// What an engine can do that another cannot - each a declared deviation,
/// never a silent one.
pub const Capabilities = struct {
    /// ECMAScript modules. Unsupported: `<script type=module>` fires `error`
    /// and `import()` rejects with a TypeError.
    module_scripts: Support,
    /// HostPromiseRejectionTracker and [[PromiseIsHandled]]. Unsupported: no
    /// `unhandledrejection` / `rejectionhandled` events.
    promise_rejection_tracking: Support,
    /// A WindowProxy distinct from the global, kept across navigations.
    /// Unsupported: a navigation that makes a new Window gives
    /// `contentWindow` a new identity.
    reuse_window_proxy: Support,
    /// Microtask checkpoints at HTML's points. Unsupported: they happen when
    /// the engine's outermost call returns, and report-before-checkpoint
    /// ordering is not guaranteed.
    microtask_checkpoint_control: Support,
    /// ECMAScript GetFunctionRealm. Unsupported: a callback's realm is the one
    /// recorded when it was converted.
    exact_function_realm: Support,
    /// Realms restored from a heap snapshot. Unsupported: every realm is
    /// created afresh.
    restores_snapshots: Support,
    /// An agent's [[CanBlock]] set by the host. Unsupported: the engine's
    /// default.
    can_block_control: Support,
    /// Diagnostics for tools, never for spec code. Unsupported: the
    /// diagnostics tier reports nothing.
    heap_statistics: Support,
    heap_snapshots: Support,
    diagnostic_counters: Support,
};

/// The capabilities of the engine this build selected.
pub const capabilities: Capabilities = impl.capabilities;

/// The engine this build selected, for messages ("V8", "JavaScriptCore").
pub const name: []const u8 = impl.name;

const Capability = std.meta.FieldEnum(Capabilities);

/// A gated operation reached where the engine lacks its capability: a compile
/// error that says so, and how to write the call.
fn gate(comptime capability: Capability, comptime operation: []const u8) void {
    if (@field(capabilities, @tagName(capability)) == .unsupported) @compileError("engine." ++ operation ++
        " needs engine.capabilities." ++ @tagName(capability) ++ ", which " ++ name ++
        " does not have: call it inside `if (engine.capabilities." ++ @tagName(capability) ++
        " != .unsupported)`, which compiles the call out on this engine");
}

// ============================================================================
// 4.1 Engine and agents
// ============================================================================

/// Initialize the process-wide engine: platform, flags, snapshot blob. Once,
/// before any agent.
pub inline fn initializeEngine(options: EngineOptions) Error!void {
    return impl.initializeEngine(options);
}

/// Tear the process-wide engine down, after every agent is destroyed.
pub inline fn deinitializeEngine() void {
    impl.deinitializeEngine();
}

/// HTML "obtain an agent": a new ECMAScript agent. OWNED: `destroyAgent`.
pub inline fn createAgent(options: AgentOptions) Error!*Agent {
    return impl.createAgent(options);
}

/// Destroy an agent `createAgent` made, after its realms.
pub inline fn destroyAgent(agent: *Agent) void {
    impl.destroyAgent(agent);
}

/// Whether the agent's execution context stack is non-empty.
pub inline fn hasRunningScript(agent: *Agent) bool {
    return impl.hasRunningScript(agent);
}

/// Whether the engine has tasks of its own posted for the agent (async
/// WebAssembly compilation, FinalizationRegistry cleanup).
pub inline fn hasPendingEngineWork(agent: *Agent) bool {
    return impl.hasPendingEngineWork(agent);
}

/// Run the engine's own posted tasks for the agent; whether any ran.
pub inline fn runEngineTasks(agent: *Agent) bool {
    return impl.runEngineTasks(agent);
}

/// Collect `agent`'s garbage now, as completely as the engine can - for
/// TestUtils.gc() only (never in a shipping configuration).
pub inline fn requestGarbageCollection(agent: *Agent) void {
    impl.requestGarbageCollection(agent);
}

// ============================================================================
// 4.2 Realms
// ============================================================================

/// HTML "create a new realm" with a Window global. OWNED: `destroyWindowRealm`.
pub inline fn createWindowRealm(options: *const WindowRealmOptions) Error!Context {
    return impl.createWindowRealm(options);
}

/// Destroy a Window realm (Blink's DisposeContext order). After it the
/// Context may only be compared.
pub inline fn destroyWindowRealm(realm: Context) void {
    impl.destroyWindowRealm(realm);
}

/// A worker's realm, in `agent`. OWNED: `destroyWorkerRealm`.
pub inline fn createWorkerRealm(agent: *Agent, options: *const WorkerRealmOptions) Error!WorkerRealm {
    return impl.createWorkerRealm(agent, options);
}

/// Destroy a worker realm; `retire(data)` runs once it is retired.
pub inline fn destroyWorkerRealm(realm: Context, retire: ?RealmSteps, data: ?*anyopaque) void {
    impl.destroyWorkerRealm(realm, retire, data);
}

/// ECMAScript's current realm: the realm of the running execution context -
/// while a binding runs, the realm of the running function object. Null when
/// no script is running, or the running context is not a realm the engine
/// hosts.
pub inline fn currentRealm() ?Context {
    return impl.currentRealm();
}

/// HTML's entry realm: the realm of the entry execution context.
pub inline fn entryRealm() ?Context {
    return impl.entryRealm();
}

/// HTML's incumbent realm (the incumbent settings object's).
pub inline fn incumbentRealm() ?Context {
    return impl.incumbentRealm();
}

/// ECMAScript GetFunctionRealm(`value`). BORROWED.
pub inline fn functionRealm(value: JSValue) ?Context {
    comptime gate(.exact_function_realm, "functionRealm");
    return impl.functionRealm(value);
}

/// Bind a Window's timers and animation frames on `realm`'s global (and on
/// its frames' as they are created); the host keeps their state.
/// `operations` BORROWED until the realm is destroyed.
pub inline fn installWindowOperations(realm: Context, operations: *const WindowOperations) Error!void {
    return impl.installWindowOperations(realm, operations);
}

/// ECMAScript CreateBuiltinFunction, defined on `realm`'s global object.
/// `function` BORROWED until the realm is destroyed.
pub inline fn defineBuiltinFunction(realm: Context, function_name: []const u8, length: u32, function: *const BuiltinFunction) Error!void {
    return impl.defineBuiltinFunction(realm, function_name, length, function);
}

// ============================================================================
// 4.3 Running script (HTML 8.1.4)
// ============================================================================

/// HTML "run a classic script": what it throws is reported, then script is
/// cleaned up after.
pub inline fn runClassicScript(realm: Context, source: ScriptSource, url: []const u8, reporter: Reporter) Error!void {
    return impl.runClassicScript(realm, source, url, reporter);
}

/// A classic script's completion value - for host scripts (the harness,
/// WebDriver, the REPL) and HTML "evaluate a javascript: URL". ToString'd
/// when `to_string` (the string allocated with `allocator`). What it throws
/// is reported, and the call fails.
pub inline fn evaluateClassicScript(realm: Context, source: ScriptSource, url: []const u8, to_string: bool, allocator: std.mem.Allocator, reporter: Reporter) Error!Owned {
    return impl.evaluateClassicScript(realm, source, url, to_string, allocator, reporter);
}

/// HTML "getting the current value of the event handler", step 3: the
/// handler's function. Null after reporting a SyntaxError.
pub inline fn compileEventHandler(realm: Context, source: *const EventHandlerSource, reporter: Reporter) Error!?Owned {
    return impl.compileEventHandler(realm, source, reporter);
}

/// HTML "prepare to run script" (8.1.4.3). OWNED: `cleanUpAfterRunningScript`.
pub inline fn prepareToRunScript(realm: Context) Error!ScriptScope {
    return impl.prepareToRunScript(realm);
}

/// HTML "clean up after running script": a microtask checkpoint when the
/// JavaScript execution context stack is then empty.
pub inline fn cleanUpAfterRunningScript(scope: ScriptScope) void {
    impl.cleanUpAfterRunningScript(scope);
}

/// Run `steps` synchronously with `realm` as the current realm. No task
/// boundary, no checkpoint.
pub inline fn runInRealm(realm: Context, steps: RealmSteps, data: ?*anyopaque) Error!void {
    return impl.runInRealm(realm, steps, data);
}

/// HTML "queue a global task", the task's run side: run `steps` as a task of
/// `realm`, then do what ends a task there (a worker's turn end).
pub inline fn runTaskInRealm(realm: Context, steps: RealmSteps, data: ?*anyopaque) Error!void {
    return impl.runTaskInRealm(realm, steps, data);
}

/// HTML "perform a microtask checkpoint" for `realm`'s agent. Where the engine
/// lacks `microtask_checkpoint_control` it drains on its own, and this does
/// nothing.
pub inline fn performMicrotaskCheckpoint(realm: Context) void {
    impl.performMicrotaskCheckpoint(realm);
}

/// HTML "queue a microtask": `steps(data)` at `realm`'s agent's next
/// checkpoint. `data` BORROWED until then; a microtask still queued when the
/// agent is torn down is dropped.
pub inline fn queueMicrotask(realm: Context, steps: RealmSteps, data: ?*anyopaque) Error!void {
    return impl.queueMicrotask(realm, steps, data);
}

/// HTML "report an exception" step 2, "extract error information" from a
/// thrown `value`: the strings allocated with `allocator`, `error_value`
/// BORROWED from `value`.
pub inline fn extractErrorInformation(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error!ErrorInfo {
    return impl.extractErrorInformation(realm, value, allocator);
}

/// ECMAScript ParseModule. `host_defined` is the host's, handed back to its
/// hooks.
pub inline fn parseModule(realm: Context, source: []const u8, url: []const u8, host_defined: ?*anyopaque) Error!ParseResult {
    comptime gate(.module_scripts, "parseModule");
    return impl.parseModule(realm, source, url, host_defined);
}

/// HTML "create a JSON module script": ParseJSONModule.
pub inline fn parseJSONModule(realm: Context, source: []const u8, url: []const u8, host_defined: ?*anyopaque) Error!ParseResult {
    comptime gate(.module_scripts, "parseJSONModule");
    return impl.parseJSONModule(realm, source, url, host_defined);
}

/// A Module Record's [[RequestedModules]], allocated with `allocator`.
pub inline fn moduleRequests(record: *ModuleRecord, allocator: std.mem.Allocator) Error![]ModuleRequest {
    comptime gate(.module_scripts, "moduleRequests");
    return impl.moduleRequests(record, allocator);
}

/// Link(): each request resolved through `resolve`. The link error (OWNED),
/// or null.
pub inline fn linkModule(realm: Context, record: *ModuleRecord, resolve: ResolveModule, data: ?*anyopaque) Error!?Owned {
    comptime gate(.module_scripts, "linkModule");
    return impl.linkModule(realm, record, resolve, data);
}

/// Evaluate().
pub inline fn evaluateModule(realm: Context, record: *ModuleRecord) Error!ModuleEvaluation {
    comptime gate(.module_scripts, "evaluateModule");
    return impl.evaluateModule(realm, record);
}

/// FinishLoadingImportedModule for an `import()`; ends the host's ownership
/// of `request`.
pub inline fn finishDynamicImport(request: *ImportRequest, outcome: DynamicImportOutcome) void {
    comptime gate(.module_scripts, "finishDynamicImport");
    impl.finishDynamicImport(request, outcome);
}

pub inline fn releaseModuleRecord(record: *ModuleRecord) void {
    comptime gate(.module_scripts, "releaseModuleRecord");
    impl.releaseModuleRecord(record);
}

// ============================================================================
// 4.4 Invoking callbacks (WebIDL 3.x)
// ============================================================================

/// WebIDL "invoke a callback function": prepare to run a callback in the
/// callback's realm (the incumbent realm), call, clean up.
pub inline fn invokeCallbackFunction(callback: JSValue, this_arg: CallbackThis, args: []const JSValue, behavior: ExceptionBehavior) Error!Completion {
    return impl.invokeCallbackFunction(callback, this_arg, args, behavior);
}

/// WebIDL "call a user object's operation": a callback interface value
/// called as a function, or through its `operation`.
pub inline fn callUserObjectOperation(callback: JSValue, operation: []const u8, this_arg: CallbackThis, args: []const JSValue, behavior: ExceptionBehavior) Error!Completion {
    return impl.callUserObjectOperation(callback, operation, this_arg, args, behavior);
}

/// ECMAScript IsCallable(`value`).
pub inline fn isCallable(value: JSValue) bool {
    return impl.isCallable(value);
}

/// A callback-function argument as the binding hands it over, as an OWNED
/// value. TRANSITIONAL, until codegen types callback parameters as JSValue.
pub inline fn takeCallbackFunction(argument: *const anyopaque) Owned {
    return impl.takeCallbackFunction(argument);
}

// ============================================================================
// 4.5 ECMAScript values
// ============================================================================

/// Get(O, P).
pub inline fn getProperty(realm: Context, object: JSValue, property: []const u8) Error!Owned {
    return impl.getProperty(realm, object, property);
}

/// Set(O, P, V, true).
pub inline fn setProperty(realm: Context, object: JSValue, property: []const u8, value: JSValue) Error!void {
    return impl.setProperty(realm, object, property, value);
}

/// DefinePropertyOrThrow(O, P, { [[Value]]: V, ...attributes }).
pub inline fn defineOwnProperty(realm: Context, object: JSValue, property: []const u8, value: JSValue, attributes: PropertyAttributes) Error!void {
    return impl.defineOwnProperty(realm, object, property, value, attributes);
}

/// HasProperty(O, P).
pub inline fn hasProperty(realm: Context, object: JSValue, property: []const u8) Error!bool {
    return impl.hasProperty(realm, object, property);
}

/// Type(V).
pub inline fn typeOf(value: JSValue) ValueType {
    return impl.typeOf(value);
}

/// SameValue(x, y).
pub inline fn sameValue(a: JSValue, b: JSValue) bool {
    return impl.sameValue(a, b);
}

/// Hold `value` past the call. OWNED.
pub inline fn retainValue(realm: Context, value: JSValue) Error!Owned {
    return impl.retainValue(realm, value);
}

/// Give an owned value back to the engine. A value that holds no engine
/// resource is left alone, so any Owned may be released.
pub inline fn releaseValue(value: Owned) void {
    impl.releaseValue(value);
}

/// ThrowCompletion(`value`) into the running script; the caller then returns
/// ExceptionPending.
pub inline fn throwValue(realm: Context, value: JSValue) Error!void {
    return impl.throwValue(realm, value);
}

/// Infra "parse JSON bytes to a JavaScript value".
pub inline fn parseJsonToValue(realm: Context, bytes: []const u8) Error!Owned {
    return impl.parseJsonToValue(realm, bytes);
}

// ============================================================================
// 4.6 WebIDL: ECMAScript to IDL
// ============================================================================

/// WebIDL "convert to DOMString". OWNED (`allocator`).
pub inline fn convertToDOMString(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]u8 {
    return impl.convertToDOMString(realm, value, allocator);
}

/// WebIDL "convert to USVString". OWNED (`allocator`).
pub inline fn convertToUSVString(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]u8 {
    return impl.convertToUSVString(realm, value, allocator);
}

/// WebIDL "convert to unrestricted double": ToNumber.
pub inline fn convertToUnrestrictedDouble(realm: Context, value: JSValue) Error!f64 {
    return impl.convertToUnrestrictedDouble(realm, value);
}

/// The platform object `value` is, or null.
pub inline fn convertToPlatformObject(realm: Context, value: JSValue) ?*Instance {
    return impl.convertToPlatformObject(realm, value);
}

/// WebIDL sequence<T> for an interface type T. OWNED slice.
pub inline fn convertToSequenceOfPlatformObjects(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]*Instance {
    return impl.convertToSequenceOfPlatformObjects(realm, value, allocator);
}

/// WebIDL sequence<object>. OWNED slice of OWNED values.
pub inline fn convertToSequenceOfObjects(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]Owned {
    return impl.convertToSequenceOfObjects(realm, value, allocator);
}

/// WebIDL sequence<DOMString>; null when `value` has no @@iterator. OWNED.
pub inline fn convertToSequenceOfDOMStrings(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error!?[][]u8 {
    return impl.convertToSequenceOfDOMStrings(realm, value, allocator);
}

/// WebIDL record<K, V> of strings. OWNED.
pub inline fn convertToRecordOfStrings(realm: Context, value: JSValue, keys: StringConversion, values: StringConversion, allocator: std.mem.Allocator) Error![]StringRecordEntry {
    return impl.convertToRecordOfStrings(realm, value, keys, values, allocator);
}

/// WebIDL "get a copy of the bytes held by the buffer source"; null when
/// `value` is not a buffer source. OWNED.
pub inline fn getCopyOfBufferSourceBytes(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error!?[]u8 {
    return impl.getCopyOfBufferSourceBytes(realm, value, allocator);
}

/// WebIDL sequence<any>. OWNED slice of OWNED values.
pub inline fn convertToSequence(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]Owned {
    return impl.convertToSequence(realm, value, allocator);
}

/// A sequence of string pairs, each of exactly two (URLSearchParams, Headers
/// init); null when `value` is not iterable. OWNED.
pub inline fn convertToSequenceOfStringPairs(realm: Context, value: JSValue, conversion: StringConversion, allocator: std.mem.Allocator) Error!?[]StringRecordEntry {
    return impl.convertToSequenceOfStringPairs(realm, value, conversion, allocator);
}

/// WebIDL "create a sequence from an iterable", item by item: false when
/// `value` has no @@iterator.
pub inline fn iterate(realm: Context, value: JSValue, each: IterateSteps, data: ?*anyopaque) Error!bool {
    return impl.iterate(realm, value, each, data);
}

/// GetIterator(`value`, kind). OWNED: `releaseIteratorRecord`.
pub inline fn getIterator(realm: Context, value: JSValue, kind: IteratorKind) Error!*IteratorRecord {
    return impl.getIterator(realm, value, kind);
}

/// IteratorNext: the result object. OWNED.
pub inline fn iteratorNext(realm: Context, record: *IteratorRecord) Error!Owned {
    return impl.iteratorNext(realm, record);
}

/// The iterator's `return` called with `value`: its result, or null when it
/// has none.
pub inline fn iteratorReturn(realm: Context, record: *IteratorRecord, value: JSValue) Error!?Owned {
    return impl.iteratorReturn(realm, record, value);
}

/// IteratorComplete and IteratorValue of `result`.
pub inline fn iteratorResult(realm: Context, result: JSValue) Error!IteratorResult {
    return impl.iteratorResult(realm, result);
}

pub inline fn releaseIteratorRecord(record: *IteratorRecord) void {
    impl.releaseIteratorRecord(record);
}

// ============================================================================
// 4.7 WebIDL: IDL to ECMAScript
// ============================================================================

/// A sequence<any> as a new Array of `realm`. OWNED.
pub inline fn createSequenceOfValues(realm: Context, values: []const JSValue) Error!Owned {
    return impl.createSequenceOfValues(realm, values);
}

/// A sequence of platform objects as a new Array of `realm`. OWNED.
pub inline fn createSequenceOfPlatformObjects(realm: Context, instances: []const *Instance) Error!Owned {
    return impl.createSequenceOfPlatformObjects(realm, instances);
}

/// An IDL dictionary value as a new ordinary object of `realm`. OWNED.
pub inline fn createDictionaryObject(realm: Context, members: []const DictionaryMember) Error!Owned {
    return impl.createDictionaryObject(realm, members);
}

/// WebIDL "create an observable array exotic object" with an empty backing
/// list. ENGINE-OWNED: never released by the caller.
pub inline fn createObservableArray(realm: Context) Error!JSValue {
    return impl.createObservableArray(realm);
}

/// WebIDL "create a frozen array". OWNED.
pub inline fn createFrozenArray(realm: Context, values: []const JSValue) Error!Owned {
    return impl.createFrozenArray(realm, values);
}

/// A WebIDL asynchronous iterator object over `steps`. OWNED.
pub inline fn createAsyncIterator(realm: Context, steps: *const AsyncIteratorSteps, data: ?*anyopaque) Error!Owned {
    return impl.createAsyncIterator(realm, steps, data);
}

// ============================================================================
// 4.8 Exceptions
// ============================================================================

/// WebIDL "create a simple exception": `realm`'s intrinsic %kind% constructed
/// with `message`. OWNED.
pub inline fn createSimpleException(realm: Context, kind: SimpleExceptionKind, message: []const u8) Error!Owned {
    return impl.createSimpleException(realm, kind, message);
}

/// WebIDL "create a DOMException". OWNED.
pub inline fn createDOMException(realm: Context, exception_name: []const u8, message: []const u8) Error!Owned {
    return impl.createDOMException(realm, exception_name, message);
}

// ============================================================================
// 4.9 Promises
// ============================================================================

/// WebIDL "a new promise" in `realm`. OWNED: `releasePromiseCapability`.
pub inline fn createPromise(realm: Context) Error!PromiseCapability {
    return impl.createPromise(realm);
}

/// WebIDL "resolve" with `value` (BORROWED; a platform object resolves with
/// its wrapper in the promise's realm).
pub inline fn resolvePromise(capability: *PromiseCapability, value: JSValue) void {
    impl.resolvePromise(capability, value);
}

/// WebIDL "reject" with `reason` (BORROWED).
pub inline fn rejectPromise(capability: *PromiseCapability, reason: JSValue) void {
    impl.rejectPromise(capability, reason);
}

pub inline fn releasePromiseCapability(capability: *PromiseCapability) void {
    impl.releasePromiseCapability(capability);
}

/// WebIDL "a promise resolved with" `value`, made in `realm`. OWNED.
pub inline fn createResolvedPromise(realm: Context, value: JSValue) Error!Owned {
    return impl.createResolvedPromise(realm, value);
}

/// WebIDL "a promise rejected with" `reason`, made in `realm`. OWNED.
pub inline fn createRejectedPromise(realm: Context, reason: JSValue) Error!Owned {
    return impl.createRejectedPromise(realm, reason);
}

/// WebIDL "react to" `promise`: `steps` upon fulfillment and upon rejection.
pub inline fn reactToPromise(realm: Context, promise: JSValue, steps: *const PromiseReactionSteps, data: ?*anyopaque) Error!void {
    return impl.reactToPromise(realm, promise, steps, data);
}

/// WebIDL "mark as handled". A value that is not a promise is left alone.
pub inline fn markPromiseAsHandled(promise: JSValue) void {
    impl.markPromiseAsHandled(promise);
}

/// [[PromiseIsHandled]] of `promise` - what HTML's "notify about rejected
/// promises" reads. False for a value that is not a promise.
pub inline fn promiseIsHandled(promise: JSValue) bool {
    comptime gate(.promise_rejection_tracking, "promiseIsHandled");
    return impl.promiseIsHandled(promise);
}

// ============================================================================
// 4.10 Buffers (ECMAScript 25.1, Streams 8.3)
// ============================================================================

/// A new ArrayBuffer of `realm` holding a copy of `bytes`. OWNED.
pub inline fn createArrayBuffer(realm: Context, bytes: []const u8) Error!Owned {
    return impl.createArrayBuffer(realm, bytes);
}

/// AllocateArrayBuffer(%ArrayBuffer%, byte_length): zeroed. OWNED.
pub inline fn allocateArrayBuffer(realm: Context, byte_length: usize) Error!Owned {
    return impl.allocateArrayBuffer(realm, byte_length);
}

/// A new view of `view_type` over `buffer`; `length` in elements (bytes for a
/// DataView). The caller checks the bounds first, as Streams does. OWNED.
pub inline fn createArrayBufferView(realm: Context, view_type: ViewType, buffer: JSValue, byte_offset: usize, length: usize) Error!Owned {
    return impl.createArrayBufferView(realm, view_type, buffer, byte_offset, length);
}

/// The ArrayBufferView `value` is, or null.
pub inline fn describeArrayBufferView(value: JSValue) ?ArrayBufferViewDescription {
    return impl.describeArrayBufferView(value);
}

/// WebIDL "write" `bytes` into `view` from `starting_offset`.
pub inline fn writeIntoArrayBufferView(view: JSValue, bytes: []const u8, starting_offset: usize) Error!void {
    return impl.writeIntoArrayBufferView(view, bytes, starting_offset);
}

/// An ArrayBuffer's bytes, BORROWED until script next runs or the buffer is
/// detached; null when detached or not an ArrayBuffer.
pub inline fn borrowArrayBufferBytes(buffer: JSValue) ?[]u8 {
    return impl.borrowArrayBufferBytes(buffer);
}

/// IsDetachedBuffer(`buffer`).
pub inline fn isDetachedBuffer(buffer: JSValue) bool {
    return impl.isDetachedBuffer(buffer);
}

/// Streams CanTransferArrayBuffer(`buffer`).
pub inline fn canTransferArrayBuffer(buffer: JSValue) bool {
    return impl.canTransferArrayBuffer(buffer);
}

/// Streams TransferArrayBuffer(`buffer`): `buffer` detached, a new one over
/// its data block. OWNED.
pub inline fn transferArrayBuffer(realm: Context, buffer: JSValue) Error!Owned {
    return impl.transferArrayBuffer(realm, buffer);
}

/// `view`.[[ViewedArrayBuffer]]. OWNED.
pub inline fn getViewedArrayBuffer(realm: Context, view: JSValue) Error!Owned {
    return impl.getViewedArrayBuffer(realm, view);
}

// ============================================================================
// 4.11 Structured serialization (HTML 2.7)
// ============================================================================

/// StructuredSerializeForStorage. OWNED bytes (`allocator`).
pub inline fn structuredSerializeForStorage(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]u8 {
    return impl.structuredSerializeForStorage(realm, value, allocator);
}

/// StructuredDeserialize of what StructuredSerializeForStorage made. OWNED.
pub inline fn structuredDeserialize(realm: Context, bytes: []const u8) Error!Owned {
    return impl.structuredDeserialize(realm, bytes);
}

/// StructuredSerializeWithTransfer. OWNED (`allocator`).
pub inline fn structuredSerializeWithTransfer(realm: Context, value: JSValue, transfer_list: []const JSValue, check: TransferableCheck, check_data: ?*anyopaque, allocator: std.mem.Allocator) Error!SerializedWithTransfer {
    return impl.structuredSerializeWithTransfer(realm, value, transfer_list, check, check_data, allocator);
}

/// StructuredDeserializeWithTransfer. OWNED.
pub inline fn structuredDeserializeWithTransfer(realm: Context, serialized: []const u8, array_buffers: []const []const u8) Error!Owned {
    return impl.structuredDeserializeWithTransfer(realm, serialized, array_buffers);
}

// ============================================================================
// 4.12 Platform objects (engine concerns, no spec)
// ============================================================================

/// Whether `instance` has a wrapper in its relevant realm.
pub inline fn hasWrapper(instance: *Instance) bool {
    return impl.hasWrapper(instance);
}

/// `instance` has pending activity: its wrapper is kept alive whatever script
/// holds, until `releasePlatformObject` or its realm ends.
pub inline fn keepPlatformObjectAlive(instance: *Instance) void {
    impl.keepPlatformObjectAlive(instance);
}

/// End what `keepPlatformObjectAlive` began.
pub inline fn releasePlatformObject(instance: *Instance) void {
    impl.releasePlatformObject(instance);
}

/// The host has freed `instance`: its wrapper must not free it again.
pub inline fn platformObjectDestroyed(instance: *Instance) void {
    impl.platformObjectDestroyed(instance);
}

// ============================================================================
// 4.13 Diagnostics tier (tools only; never spec code)
// ============================================================================

pub inline fn heapStatistics(agent: *Agent) HeapStatistics {
    comptime gate(.heap_statistics, "heapStatistics");
    return impl.heapStatistics(agent);
}

/// Write a heap snapshot of `agent` to `path`; whether it was written.
pub inline fn writeHeapSnapshot(agent: *Agent, path: [:0]const u8) bool {
    comptime gate(.heap_snapshots, "writeHeapSnapshot");
    return impl.writeHeapSnapshot(agent, path);
}

/// The adapter's own counters, allocated with `allocator`.
pub inline fn diagnosticCounters(allocator: std.mem.Allocator) Error![]Counter {
    comptime gate(.diagnostic_counters, "diagnosticCounters");
    return impl.diagnosticCounters(allocator);
}

// ============================================================================
// The contract, checked
// ============================================================================

comptime {
    @setEvalBranchQuota(100_000);
    const protocol = @This();
    for (@typeInfo(protocol).@"struct".decls) |decl| {
        const expected = switch (@typeInfo(@TypeOf(@field(protocol, decl.name)))) {
            .@"fn" => |f| f,
            else => continue,
        };
        // Every public inline function is an operation.
        if (expected.calling_convention != .@"inline") continue;
        conforms(decl.name, expected);
        // In a test build, compile the adapter's function whole: a stub
        // nothing calls still has to type-check.
        if (@import("builtin").is_test) _ = &@field(impl, decl.name);
    }
}

/// The adapter declares `operation` with exactly the protocol's parameter and
/// return types.
fn conforms(comptime operation: []const u8, comptime expected: std.builtin.Type.Fn) void {
    const adapter = name ++ " engine adapter (engine_impl.protocol)";
    if (!@hasDecl(impl, operation)) @compileError(adapter ++ " lacks protocol operation `" ++ operation ++ "`");
    const Actual = @TypeOf(@field(impl, operation));
    const actual = switch (@typeInfo(Actual)) {
        .@"fn" => |f| f,
        else => @compileError(adapter ++ ": `" ++ operation ++ "` is not a function"),
    };
    var same = actual.return_type == expected.return_type and actual.params.len == expected.params.len and !actual.is_generic;
    if (same) {
        for (actual.params, expected.params) |a, e| {
            if (a.type != e.type) same = false;
        }
    }
    if (!same) @compileError(adapter ++ ": `" ++ operation ++ "` is " ++ @typeName(Actual) ++
        "; the protocol's signature is " ++ signature(expected));
}

fn signature(comptime f: std.builtin.Type.Fn) []const u8 {
    var text: []const u8 = "fn (";
    for (f.params, 0..) |p, i| text = text ++ (if (i == 0) "" else ", ") ++ @typeName(p.type.?);
    return text ++ ") " ++ @typeName(f.return_type.?);
}
