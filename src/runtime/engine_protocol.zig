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
//! Every operation that reads a value takes the realm to read it in: an
//! adapter never depends on whichever agent happens to be entered. Engine
//! failures are never swallowed: an operation that can fail says so.
//!
//! Status: phase 3 step A - every operation of the design
//! (tmp/plans/engine-protocol-design.md section 4) is declared and checked;
//! adapters answer the ones not yet built with NotSupported, marked
//! `TODO(protocol): implement` in the adapter. The runtime Engine table that
//! came before it (engine_interface.zig, reached through ctx.getEngine()) is
//! gone; the types it shared with the protocol are engine_types.zig's.

const std = @import("std");
const runtime = @import("runtime");
const impl = @import("engine_impl").protocol;

// ============================================================================
// Types (design section 2)
// ============================================================================

/// A realm's identity - HTML's realm, ECMAScript's Realm Record - as the
/// runtime records it. Stable until the realm is torn down; a retired realm
/// has no engine realm behind it. BORROWED wherever an operation takes one.
///
/// Work queued on the realm's own agent (a task, a timer, an async request)
/// may keep a Context across turns: a torn-down realm's Context stays a
/// valid, inert record until its agent ends, and `hasEngine()` turns false
/// at retirement. Keeping one is not a root - it keeps nothing alive. Such
/// work checks `hasEngine()` before every step that enters the realm, and
/// passes operations only a Context that answers true; a retired one may
/// only be compared. Work that could outlive the realm's agent keeps no
/// Context.
pub const Context = runtime.Context;

/// An ECMAScript agent: a V8 isolate, a JavaScriptCore context group. Opaque;
/// a realm records its own (`Context.agent`).
pub const Agent = runtime.Agent;

/// The IDL-level value. As a parameter, always BORROWED for the call.
pub const JSValue = runtime.JSValue;

/// A platform object: the host's side of a wrapper.
///
/// An Instance lives no longer than its realm: when the realm is torn down,
/// its wrapper cache frees every Instance it alone wraps (a node still in a
/// tree excepted) and severs the wrapper, whatever still points at it - a
/// traceChild edge or an Owned value roots the wrapper, not the Instance.
/// So a pointer to an Instance kept across turns is valid only while its
/// realm `hasEngine()`: whoever keeps one keeps that realm's Context beside
/// it and checks it before every dereference - never through the Instance's
/// own `ctx`, which goes with it. (Blink keeps a reachable object alive past
/// its context's end; Crane does not yet.)
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
/// - `ExceptionReported`: script threw, the exception was reported through
///   the operation's Reporter, and nothing is pending.
/// - `OperationFailed`: the engine failed (no context, out of handles).
pub const Error = error{
    OperationFailed,
    ExceptionReported,
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
    /// to take ownership - the binding, for an impl's result: the binding
    /// releases every value an impl returns once it is the call's result.
    pub fn take(self: Owned) JSValue {
        return self.value;
    }

    /// The value BORROWED, while this Owned is held: to pass to an operation
    /// or a function that takes a JSValue. Never an impl's result - the
    /// binding releases what an impl returns, so a value the object keeps
    /// goes back as a hold of the binding's own:
    /// `(try retainValue(realm, kept.value)).take()`.
    pub fn borrow(self: Owned) JSValue {
        return switch (self.value) {
            .string => |text| .{ .string = .{ .data = text.data, .owned = false } },
            else => self.value,
        };
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
    /// The exception is the script's PARSE ERROR: HTML "create a classic
    /// script" found its source text unparsable and set the script's parse
    /// error and error to rethrow - not an exception its evaluation threw (a
    /// top-level `throw`, even of a SyntaxError, is false). Set by the
    /// classic-script operations (runClassicScript, evaluateClassicScript*).
    /// Its consumer is "run a worker" onComplete step 1: a worker whose
    /// script has an error to rethrow fires a plain `error` event at its
    /// Worker and runs nothing, rather than reporting the exception. A window
    /// ignores it ("run a classic script" reports both alike). An engine that
    /// cannot tell leaves it false (docs/engine-protocol.md: JavaScriptCore
    /// and QuickJS, for now).
    parse_error: bool = false,
};

/// HTML "report an exception", as the host supplies it to an operation that
/// runs script with "rethrow errors" false. The engine calls `report` at the
/// point the operation's own algorithm reports: WebIDL "invoke a callback
/// function", after "clean up after running script"; HTML "run a classic
/// script" (8.1.4.4 step 8.3), evaluateClassicScript* and compileEventHandler,
/// before it.
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

/// WebIDL: a callback function type's value (3.2.19) - "a reference to the
/// function object, and a callback context": the incumbent realm when the
/// value was converted (null when there was none). OWNED: `release` gives the
/// function back.
pub const CallbackFunction = struct {
    function: Owned,
    context: ?Context,

    pub fn release(self: CallbackFunction) void {
        self.function.release();
    }
};

/// A callback interface value as the binding converts it today - what
/// takeCallbackInterface takes. TRANSITIONAL.
pub const CallbackWrapper = runtime.CallbackWrapper;

/// WebIDL: a callback interface type's value (3.2.16) - the object, and a
/// callback context as for CallbackFunction. OWNED: `release` gives the
/// object back.
pub const CallbackInterface = struct {
    object: Owned,
    context: ?Context,

    pub fn release(self: CallbackInterface) void {
        self.object.release();
    }
};

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
///
/// For each `reactToPromise` that succeeded, exactly ONE of `fulfilled`,
/// `rejected` and `dropped` runs, once - so the host frees its `data` at the
/// end of its steps and in `dropped`, and nowhere else.
pub const PromiseReactionSteps = struct {
    fulfilled: ?*const fn (data: ?*anyopaque, value: JSValue) void = null,
    rejected: ?*const fn (data: ?*anyopaque, reason: JSValue) void = null,
    /// The reaction ended without running a step of these: the promise
    /// settled the way no step is given for, or the engine dropped the
    /// reaction while the promise was pending - its realm ended (before the
    /// realm's objects are torn down), the engine collected the promise with
    /// the reaction, or the agent ended. Frees `data`. Never runs script, and
    /// never runs while the engine collects (4.12, "Teardown and the
    /// collector"), so it may release engine values. `reactToPromise` on a
    /// realm that has ended fails, and `data` stays the caller's.
    dropped: ?*const fn (data: ?*anyopaque) void = null,
};

/// WebIDL's steps behind an asynchronous iterator object (3.7.10): the
/// engine keeps the object's ongoing promise and is finished, and calls these.
pub const AsyncIteratorSteps = struct {
    /// "get the next iteration result": a promise (or a value, resolving
    /// one) for an iterator result object - `{ value, done: false }` for the
    /// next value, `done: true` for end of iteration. OWNED.
    next: *const fn (data: ?*anyopaque) Error!Owned,
    /// "asynchronous iterator return", when the declaration has one: a
    /// promise. `value` BORROWED; the result OWNED.
    @"return": ?*const fn (data: ?*anyopaque, value: JSValue) Error!Owned = null,
    /// The iterator object was collected: free `data`. Called after the
    /// collection, never while the engine collects (see 4.12, "Teardown and
    /// the collector"), so it may release engine values. Or when the realm
    /// ends, whichever is first; after the realm ends, next() and return()
    /// reject with a TypeError and never call the steps.
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
/// HTML 2.7.1 serializable objects: the engine-neutral records a
/// [Serializable] interface's serialization steps fill and its
/// deserialization steps read, and the pair of steps a generated interface
/// publishes as `serializable_steps` (src/runtime/serialization_record.zig).
pub const SerializationRecord = runtime.SerializationRecord;
pub const DeserializationRecord = runtime.DeserializationRecord;
pub const SerializableSteps = runtime.SerializableSteps;
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

/// How hard the host wants memory back (notifyMemoryPressure).
pub const MemoryPressure = enum {
    /// Collect what is cheap to find, when convenient.
    moderate,
    /// Collect everything that can be collected, now: a page was let go.
    critical,
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
    /// What the engine allocates for the agent itself (its caches, what
    /// destroyAgent frees), BORROWED for the agent's life.
    allocator: std.mem.Allocator = std.heap.c_allocator,
};

/// The host's side of the ECMAScript host hooks, installed per agent. A hook
/// whose capability the engine lacks is never called.
pub const HostHooks = struct {
    /// HostLoadImportedModule for `import()` [module_scripts]: the host owns
    /// `request` until `finishDynamicImport`.
    loadImportedModule: ?*const fn (host: ?*anyopaque, realm: Context, referrer: ImportReferrer, specifier: []const u8, type_attribute: ?[]const u8, request: *ImportRequest) void = null,
    /// HostGetImportMetaProperties [module_scripts]: `import.meta.url` of the
    /// module the host defined as `module_host_defined`.
    importMetaUrl: ?*const fn (host: ?*anyopaque, module_host_defined: *anyopaque) []const u8 = null,
    /// HTML HostGetImportMetaProperties(moduleRecord) steps 4-6
    /// [module_scripts]: import.meta.resolve. The engine makes the builtin
    /// function "resolve" (length 1, not a constructor) beside `url`, and
    /// its steps, given specifier, are "1. Set specifier to ?
    /// ToString(specifier). 2. Let url be the result of resolving a module
    /// specifier given moduleScript and specifier. 3. Return the
    /// serialization of url." Resolving reads only moduleScript's settings
    /// object - `realm`'s - and its base URL, which import.meta.url
    /// serializes: the engine passes those. The result is OWNED
    /// (`allocator`); null is the failure "resolve a module specifier"
    /// throws, which the engine throws as a TypeError. An engine that does
    /// not call this makes no `resolve` on import.meta.
    importMetaResolve: ?*const fn (host: ?*anyopaque, realm: Context, base_url: []const u8, specifier: []const u8, allocator: std.mem.Allocator) ?[]u8 = null,
    /// HostPromiseRejectionTracker [promise_rejection_tracking]. `promise`
    /// OWNED. `reason` OWNED: on "reject" the rejection value - the promise's
    /// [[PromiseResult]] from then on, which the host keeps beside the promise
    /// because no operation reads [[PromiseResult]] (JavaScriptCore has none);
    /// null on "handle".
    promiseRejectionTracker: ?*const fn (host: ?*anyopaque, realm: Context, promise: Owned, operation: RejectionOperation, reason: ?Owned) void = null,
    /// HTML "perform a microtask checkpoint" step 5: notify about rejected
    /// promises.
    afterMicrotaskCheckpoint: ?*const fn (host: ?*anyopaque, agent: *Agent) void = null,
    /// HostEnsureCanCompileStrings(realm, parameterStrings, bodyString,
    /// codeString, compilationType, parameterArgs, bodyArg)
    /// [code_generation_checks] (HTML 8.1.6.2): whether eval or a Function
    /// constructor in `realm` may compile `compilation.code_string`.
    /// `.blocked`: the engine throws an EvalError in `realm` and compiles
    /// nothing. A verdict, never a replacement source: CSP 4.4.1 step 2.4.3
    /// throws when the default policy changes the string, so an allowed
    /// compilation compiles codeString as it is. The host may run script (a
    /// Trusted Types default policy) and leaves no exception pending (step
    /// 2.4.2: a throw there is the EvalError the verdict carries). Called
    /// for every compilation from a string in a realm of an agent that has
    /// the hook - before any policy exists as much as after - so it costs
    /// every eval and Function call one host call.
    ensureCanCompileStrings: ?*const fn (host: ?*anyopaque, realm: Context, compilation: *const StringCompilation) StringCompilationVerdict = null,
    /// HostGetCodeForEval(argument) [code_generation_checks] (HTML 8.1.6.3):
    /// the code of an eval argument that is an object - a TrustedScript's
    /// data - OWNED (`allocator`), or null for "no-code": eval then returns
    /// the argument unchanged, compiling and checking nothing. `argument`
    /// BORROWED for the call. Runs no script.
    getCodeForEval: ?*const fn (host: ?*anyopaque, realm: Context, argument: JSValue, allocator: std.mem.Allocator) ?[]u8 = null,
    /// HostEnsureCanCompileWasmBytes(realm) [code_generation_checks]
    /// (WebAssembly JS API; CSP 4.5.1): whether WebAssembly bytes may be
    /// compiled in `realm`. False: the engine throws a
    /// WebAssembly.CompileError (a compile that returns a promise rejects
    /// with one).
    ensureCanCompileWasmBytes: ?*const fn (host: ?*anyopaque, realm: Context) bool = null,
};

/// HostEnsureCanCompileStrings's compilationType (Dynamic Code Brand Checks;
/// HTML 8.1.6.2) as an engine reports it. Direct and indirect eval are one
/// value: no engine API tells them apart, and neither CSP 4.4.1 nor Trusted
/// Types reads the difference. "TIMER" is not here: a timer's string
/// handler is compiled by the host, which runs that check itself.
pub const StringCompilationType = enum {
    /// PerformEval: CSP's compilationSink "eval".
    eval,
    /// CreateDynamicFunction (the Function, AsyncFunction,
    /// GeneratorFunction and AsyncGeneratorFunction constructors):
    /// compilationSink "Function".
    function,
};

/// What HostEnsureCanCompileStrings is given, as far as the host reads it.
pub const StringCompilation = struct {
    compilation_type: StringCompilationType,
    /// codeString, UTF-8, BORROWED for the call. For eval, the argument
    /// string (or the code `getCodeForEval` gave for an object). For a
    /// constructor, CreateDynamicFunction's sourceString: "<prefix>
    /// anonymous(" + P + "\n) {" + LF + body + LF + "}".
    code_string: []const u8,
    /// Whether bodyArg and every one of parameterArgs are code-like -
    /// TrustedScript objects (CSP 4.4.1 steps 2.2-2.3, isTrusted). An engine
    /// that cannot see the arguments says false.
    arguments_are_code_like: bool,
};

/// HostEnsureCanCompileStrings's answer.
pub const StringCompilationVerdict = enum { allowed, blocked };

/// HostLoadImportedModule's referrer: the [[HostDefined]] of the script or
/// module whose `import()` this is, or none.
pub const ImportReferrer = union(enum) {
    /// A module record's `host_defined` (parseModule).
    module: *anyopaque,
    /// A classic script's `host_defined` (runClassicScript,
    /// evaluateClassicScript*): the host resolves against its base URL.
    script: *anyopaque,
    /// [[ScriptOrModule]] is null (an event handler, eval, a timer's string
    /// handler): the host uses the current settings object's API base URL.
    realm,
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
    /// The host's event loop, recorded in the realm record for host
    /// algorithms that queue tasks (streams, Blob); shared by every realm of
    /// the agent. The engine stores it and never runs it.
    event_loop: ?runtime.EventLoop = null,
    /// The realm's origin, serialized; null for an opaque one.
    origin: ?[]const u8 = null,
    global_this: GlobalThis = .new_window_proxy,
    /// The realm of the navigable's parent - an iframe's container document's
    /// window, or a popup's opener - or null for a top-level one. A realm
    /// with a parent shares its engine-level access with it (V8's security
    /// token; the WindowProxy checks are the host's), ends when the parent
    /// ends if it has not already, and - made while the parent's script runs -
    /// is entered only for the calls that run in it. A realm without one
    /// stays the agent's entered realm for its life.
    parent: ?Context = null,
    /// HTML "create a new realm", the customization for the global object:
    /// the host makes the realm's Window. `global_this` is BORROWED until
    /// destroyWindowRealm: the host's Window may keep it as the global it is
    /// bound to, and must not release it. On null the engine undoes the realm
    /// and fails.
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
    /// HTML "abort a running script" from another thread
    /// (`abortRunningScript`). Unsupported: a script that never returns holds
    /// its agent's thread until something outside the process ends it.
    script_abort: Support,
    /// HostEnsureCanCompileStrings, HostGetCodeForEval and
    /// HostEnsureCanCompileWasmBytes reach the host (HostHooks).
    /// Unsupported: eval, the Function constructors and WebAssembly
    /// compilation are never checked - CSP script-src without 'unsafe-eval'
    /// or 'wasm-unsafe-eval', and Trusted Types' eval sink, are not
    /// enforced. A security-relevant difference, declared.
    code_generation_checks: Support,
};

/// The capabilities of the engine this build selected.
pub const capabilities: Capabilities = impl.capabilities;

/// The engine this build selected, for messages ("V8", "JavaScriptCore").
pub const name: []const u8 = impl.name;

/// The log scope the adapter logs under, for hosts that filter its output.
pub const log_scope = impl.log_scope;

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

/// The `host` pointer `agent` was created with (AgentOptions.host): the
/// embedder's own pointer handed back, no engine handle. Null when none was
/// given, once the agent is destroyed, or for an agent the adapter did not
/// make.
pub inline fn agentHost(agent: *Agent) ?*anyopaque {
    return impl.agentHost(agent);
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

/// The host wants `agent`'s memory back: it has just let go of what a page
/// held (a navigation's old realm, a removed frame's), which is garbage now,
/// or it is short of memory. The engine collects as `level` asks. No spec
/// observes it; every engine answers, doing what it can.
pub inline fn notifyMemoryPressure(agent: *Agent, level: MemoryPressure) void {
    impl.notifyMemoryPressure(agent, level);
}

/// HTML 8.1.4.5 "abort a running script": the script running in `agent`
/// ceases - every ScriptEvaluation and module Evaluate on its stack, without
/// `catch` or `finally` - and its execution context stack empties. A user
/// agent's resource limit (a CPU quota, a total execution time) is what calls
/// it; HTML lets the limit "abort the script without an exception".
///
/// Callable from ANY thread: a time limit has to come from outside the agent's
/// thread while that thread is in script. When no script is running, the next
/// one to start in the agent is aborted at once. Every host step that was
/// running script sees it end abruptly (an error path, never a value); the
/// agent runs no script again until `resumeScripts`, or until the abort has
/// unwound past the outermost script on its own.
pub inline fn abortRunningScript(agent: *Agent) void {
    comptime gate(.script_abort, "abortRunningScript");
    impl.abortRunningScript(agent);
}

/// End an `abortRunningScript` that is still in force, so that `agent` can run
/// script again - the host decided to go on (to let a harness report what ran,
/// for one). On the agent's own thread. A no-op when no abort is in force.
pub inline fn resumeScripts(agent: *Agent) void {
    comptime gate(.script_abort, "resumeScripts");
    impl.resumeScripts(agent);
}

// ============================================================================
// 4.2 Realms
// ============================================================================

/// HTML "create a new realm" with a Window global. OWNED: `destroyWindowRealm`.
pub inline fn createWindowRealm(options: *const WindowRealmOptions) Error!Context {
    return impl.createWindowRealm(options);
}

/// How a Window realm ends - Blink's LocalWindowProxy lifecycle states.
pub const WindowRealmEnd = enum {
    /// Its page is gone, or a navigation gave its navigable a new Window
    /// (Blink kGlobalObjectIsDetached): the WindowProxy is detached from the
    /// global object, and script that still holds it reaches nothing. A
    /// frame's realm a navigation replaced - its WindowProxy went on to the
    /// new realm - does not end at once: HTML unloads and destroys its
    /// document, and its Window lives on for as long as script reaches
    /// anything of the realm (its document, a node, a function). Its script
    /// activity and tasks stop, the engine keeps no root into it, and it ends
    /// once the collector takes it or with its page, whichever is first - as
    /// `navigable_destroyed` does.
    global_detached,
    /// HTML "destroy a child navigable": its navigable is gone - an iframe
    /// was removed - but script may still hold its WindowProxy (Blink
    /// kFrameIsDetached, which leaves the global attached). The global stays
    /// attached, severed from the Window the host frees: its own properties
    /// (`self`, `frames`, `globalThis`) and `window` keep answering, and a
    /// member that needs the Window throws a TypeError. (The spec keeps the
    /// Window alive for as long as a WindowProxy for it is held; that is not
    /// modelled yet.)
    navigable_destroyed,
};

/// Destroy a Window realm (Blink's DisposeContext order), as `how` says -
/// and the realms of its frames first, the same way. After it the Context may
/// only be compared.
pub inline fn destroyWindowRealm(realm: Context, how: WindowRealmEnd) void {
    impl.destroyWindowRealm(realm, how);
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
/// cleaned up after. `host_defined` is the host's classic script (the
/// referrer an `import()` from it names), BORROWED for as long as the script
/// can run - pending `import()`s included; null for none.
pub inline fn runClassicScript(realm: Context, source: ScriptSource, url: []const u8, host_defined: ?*anyopaque, reporter: Reporter) Error!void {
    return impl.runClassicScript(realm, source, url, host_defined, reporter);
}

/// A classic script's completion value - for host scripts (the harness,
/// WebDriver, the REPL) and HTML "evaluate a javascript: URL". What it throws
/// is reported, and the call fails with ExceptionReported. OWNED.
pub inline fn evaluateClassicScript(realm: Context, source: ScriptSource, url: []const u8, host_defined: ?*anyopaque, reporter: Reporter) Error!Owned {
    return impl.evaluateClassicScript(realm, source, url, host_defined, reporter);
}

/// As evaluateClassicScript, the completion value then ECMAScript
/// ToString'd: OWNED, allocated with `allocator`. What the script or ToString
/// throws is reported, and the call fails.
pub inline fn evaluateClassicScriptToString(realm: Context, source: ScriptSource, url: []const u8, host_defined: ?*anyopaque, allocator: std.mem.Allocator, reporter: Reporter) Error![]u8 {
    return impl.evaluateClassicScriptToString(realm, source, url, host_defined, allocator, reporter);
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

/// HTML "perform a microtask checkpoint" for `agent` - an event loop's, and
/// an event loop is an agent's: its microtask queue is the agent's, whichever
/// realm queued each microtask. Where the engine lacks
/// `microtask_checkpoint_control` it drains on its own, and this does nothing.
pub inline fn performMicrotaskCheckpoint(agent: *Agent) Error!void {
    return impl.performMicrotaskCheckpoint(agent);
}

/// HTML "queue a microtask": `steps(data)` at `agent`'s next checkpoint -
/// the surrounding agent's event loop's microtask queue, whichever realm the
/// caller is in. `data` BORROWED until then; a microtask still queued when
/// the agent is torn down is dropped. The steps run with no realm entered:
/// what needs one enters it (runInRealm).
pub inline fn queueMicrotask(agent: *Agent, steps: RealmSteps, data: ?*anyopaque) Error!void {
    return impl.queueMicrotask(agent, steps, data);
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

/// ECMA-262 CreateDefaultExportSyntheticModule(defaultExport): a Synthetic
/// Module Record whose only export, "default", is `value` (BORROWED) once
/// it is evaluated - what HTML "create a CSS module script" step 6 makes of
/// the constructed CSSStyleSheet. `url` names the module (its resource
/// name); `host_defined` is the host's, as for parseModule. The record is
/// OWNED (releaseModuleRecord).
pub inline fn createDefaultExportSyntheticModule(realm: Context, value: JSValue, url: []const u8, host_defined: ?*anyopaque) Error!*ModuleRecord {
    comptime gate(.module_scripts, "createDefaultExportSyntheticModule");
    return impl.createDefaultExportSyntheticModule(realm, value, url, host_defined);
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

/// WebIDL "invoke a callback function". `realm` is where the callback is read
/// - a realm of its agent; the call runs in the function's associated realm
/// (prepare to run script there), with the callback's context as the
/// incumbent (prepare to run a callback), then cleans up. `callback` is
/// BORROWED.
pub inline fn invokeCallbackFunction(realm: Context, callback: *const CallbackFunction, this_arg: CallbackThis, args: []const JSValue, behavior: ExceptionBehavior) Error!Completion {
    return impl.invokeCallbackFunction(realm, callback, this_arg, args, behavior);
}

/// WebIDL "call a user object's operation": a callback interface value
/// called as a function, or through its `operation`. `realm` and the
/// incumbent as for invokeCallbackFunction; `callback` is BORROWED.
pub inline fn callUserObjectOperation(realm: Context, callback: *const CallbackInterface, operation: []const u8, this_arg: CallbackThis, args: []const JSValue, behavior: ExceptionBehavior) Error!Completion {
    return impl.callUserObjectOperation(realm, callback, operation, this_arg, args, behavior);
}

/// ECMAScript IsCallable(`value`).
pub inline fn isCallable(realm: Context, value: JSValue) bool {
    return impl.isCallable(realm, value);
}

/// ECMAScript IsConstructor(`value`) (7.2.4): whether `value` is an object
/// with a [[Construct]] internal method - false for a non-object. A Proxy
/// has one when its target does, revoked or not.
pub inline fn isConstructor(realm: Context, value: JSValue) bool {
    return impl.isConstructor(realm, value);
}

/// A callback-function argument as the binding hands it over, as a
/// CallbackFunction (OWNED) whose context is the incumbent realm now - the
/// operation being called is converting its arguments. TRANSITIONAL, until
/// codegen types callback parameters as CallbackFunction.
pub inline fn takeCallbackFunction(argument: *const anyopaque) CallbackFunction {
    return impl.takeCallbackFunction(argument);
}

/// A callback-interface argument as the binding hands it over (the
/// runtime.CallbackWrapper it converted), as a CallbackInterface of its own
/// (OWNED) whose context is the incumbent realm now. The wrapper is BORROWED,
/// as every argument is: the binding releases it when the call returns.
/// TRANSITIONAL, as takeCallbackFunction.
pub inline fn takeCallbackInterface(argument: *const CallbackWrapper) CallbackInterface {
    return impl.takeCallbackInterface(argument);
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

/// ECMAScript HasOwnProperty(O, P) (7.3.12): whether O.[[GetOwnProperty]](P)
/// is not undefined. What that throws (a Proxy's getOwnPropertyDescriptor
/// trap) is left pending: ExceptionPending, never a silent false. TypeError
/// when `object` is not an Object.
pub inline fn hasOwnProperty(realm: Context, object: JSValue, property: []const u8) Error!bool {
    return impl.hasOwnProperty(realm, object, property);
}

/// Type(V).
pub inline fn typeOf(realm: Context, value: JSValue) ValueType {
    return impl.typeOf(realm, value);
}

/// ECMAScript thisTimeValue(value) (21.4.4), without the TypeError: a Date's
/// [[DateValue]] - NaN for an invalid date - or null when `value` has no
/// [[DateValue]] internal slot. Never runs script.
pub inline fn thisTimeValue(realm: Context, value: JSValue) ?f64 {
    return impl.thisTimeValue(realm, value);
}

/// Whether `value` is an Array exotic object (ECMAScript 10.4.2) - NOT
/// IsArray, which looks through a Proxy: a Proxy of an array is no Array
/// exotic object (IndexedDB "convert a value to a key"). Never runs script.
pub inline fn isArrayExoticObject(realm: Context, value: JSValue) bool {
    return impl.isArrayExoticObject(realm, value);
}

/// A new Date of `realm` whose [[DateValue]] is TimeClip(`time_value`)
/// (ECMAScript 21.4.2.1, Date(value) given a number). OWNED.
pub inline fn createDate(realm: Context, time_value: f64) Error!Owned {
    return impl.createDate(realm, time_value);
}

/// SameValue(x, y).
pub inline fn sameValue(realm: Context, a: JSValue, b: JSValue) bool {
    return impl.sameValue(realm, a, b);
}

/// ECMAScript ToBoolean(`value`) (7.1.2): false for undefined, null, false,
/// +0, -0, NaN, 0n and the empty string - and an [[IsHTMLDDA]] object
/// (`document.all`) - and true for anything else, every other object
/// included. Never runs script.
pub inline fn toBoolean(realm: Context, value: JSValue) bool {
    return impl.toBoolean(realm, value);
}

/// Hold `value` past the call. OWNED. Undefined, null, a boolean or a
/// number holds no engine resource: it is held by value, with nothing entered
/// (any realm will do), and releasing it does nothing. A platform object is
/// held as its wrapper, made in `realm` if it has none yet - pass its relevant
/// realm.
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

/// ECMAScript Completion(...): run `steps` in `realm`; if they leave an
/// exception pending, catch it and return the thrown value OWNED, with nothing
/// pending; null on a normal completion. A step's TypeError or DataCloneError
/// ("the spec throws one here", nothing thrown yet) is a throw completion of a
/// new one; any other error is the engine failing and propagates. For spec
/// steps that consume an abrupt completion rather than propagate it - the
/// Streams size algorithm's result conversion, say.
pub inline fn completionOf(realm: Context, steps: *const fn (data: ?*anyopaque) Error!void, data: ?*anyopaque) Error!?Owned {
    return impl.completionOf(realm, steps, data);
}

/// Infra "parse JSON bytes to a JavaScript value".
pub inline fn parseJsonToValue(realm: Context, bytes: []const u8) Error!Owned {
    return impl.parseJsonToValue(realm, bytes);
}

/// ECMAScript JSON.parse "in the context of a new global object" (WebCrypto
/// "parse a JWK" step 4): `bytes` UTF-8 decoded (a leading BOM dropped, as
/// Infra's "parse JSON bytes" does) and parsed by a NEW global's intrinsic
/// JSON.parse, so the result's objects and arrays inherit that global's
/// Object.prototype and Array.prototype - nothing `realm`'s script did to its
/// own prototypes (`Object.prototype.kty = "oct"`) shows through them. OWNED.
/// The new global lives as long as the result refers to it; the operation
/// keeps nothing of it.
///
/// A SyntaxError is thrown in `realm` - the CALLER's SyntaxError, with the
/// new global's message - and left pending: ExceptionPending. NotSupported
/// where an adapter cannot make a new global (QuickJS, the test adapter).
pub inline fn parseJsonInNewGlobal(realm: Context, bytes: []const u8) Error!Owned {
    return impl.parseJsonInNewGlobal(realm, bytes);
}

/// Infra "serialize a JavaScript value to JSON bytes": ? Call(%JSON.stringify%,
/// undefined, « value ») - the intrinsic, whatever script did to the global
/// JSON - UTF-8 encoded. TypeError when it returns undefined (`value` has no
/// JSON representation: undefined, a function, a Symbol), with nothing
/// thrown; what the serializer throws (a cycle, a BigInt, a getter or toJSON)
/// is left pending: ExceptionPending. OWNED (`allocator`).
pub inline fn serializeJsonToBytes(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]u8 {
    return impl.serializeJsonToBytes(realm, value, allocator);
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

/// WebIDL "get a copy of the bytes held by the buffer source", for a value
/// converted to BufferSource - (ArrayBufferView or ArrayBuffer), NOT
/// [AllowShared]: null when `value` is not a buffer source, a
/// SharedArrayBuffer included; a view over a SharedArrayBuffer is a
/// TypeError. A detached buffer's copy is empty. OWNED. For
/// AllowSharedBufferSource use getCopyOfAllowSharedBufferSourceBytes.
pub inline fn getCopyOfBufferSourceBytes(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error!?[]u8 {
    return impl.getCopyOfBufferSourceBytes(realm, value, allocator);
}

/// WebIDL "get a copy of the bytes held by the buffer source", for a value
/// converted to AllowSharedBufferSource - (ArrayBuffer or SharedArrayBuffer or
/// [AllowShared] ArrayBufferView): an ArrayBuffer, a SharedArrayBuffer (never
/// detached), or the window of a view over either. Null when `value` is none
/// of those; a detached ArrayBuffer's copy is empty. OWNED.
pub inline fn getCopyOfAllowSharedBufferSourceBytes(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error!?[]u8 {
    return impl.getCopyOfAllowSharedBufferSourceBytes(realm, value, allocator);
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
pub inline fn resolvePromise(capability: *PromiseCapability, value: JSValue) Error!void {
    return impl.resolvePromise(capability, value);
}

/// WebIDL "reject" with `reason` (BORROWED).
pub inline fn rejectPromise(capability: *PromiseCapability, reason: JSValue) Error!void {
    return impl.rejectPromise(capability, reason);
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
pub inline fn markPromiseAsHandled(realm: Context, promise: JSValue) void {
    impl.markPromiseAsHandled(realm, promise);
}

/// [[PromiseIsHandled]] of `promise` - what HTML's "notify about rejected
/// promises" reads. False for a value that is not a promise.
pub inline fn promiseIsHandled(realm: Context, promise: JSValue) bool {
    comptime gate(.promise_rejection_tracking, "promiseIsHandled");
    return impl.promiseIsHandled(realm, promise);
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
pub inline fn describeArrayBufferView(realm: Context, value: JSValue) ?ArrayBufferViewDescription {
    return impl.describeArrayBufferView(realm, value);
}

/// WebIDL "write" `bytes` into `view` from `starting_offset`.
pub inline fn writeIntoArrayBufferView(realm: Context, view: JSValue, bytes: []const u8, starting_offset: usize) Error!void {
    return impl.writeIntoArrayBufferView(realm, view, bytes, starting_offset);
}

/// An ArrayBuffer's bytes, BORROWED until script next runs or the buffer is
/// detached; null when detached or not an ArrayBuffer.
pub inline fn borrowArrayBufferBytes(realm: Context, buffer: JSValue) ?[]u8 {
    return impl.borrowArrayBufferBytes(realm, buffer);
}

/// IsDetachedBuffer(`buffer`).
pub inline fn isDetachedBuffer(realm: Context, buffer: JSValue) bool {
    return impl.isDetachedBuffer(realm, buffer);
}

/// Streams CanTransferArrayBuffer(`buffer`).
pub inline fn canTransferArrayBuffer(realm: Context, buffer: JSValue) bool {
    return impl.canTransferArrayBuffer(realm, buffer);
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
//
// Platform objects (StructuredSerializeInternal steps 19-20 and 26.3,
// StructuredDeserialize steps 22-24): one whose PRIMARY interface is
// [Serializable] and has steps - its generated interface's
// `serializable_steps`, found by the interface's identifier - is written as
// that identifier, the record its serialization steps fill
// (SerializationRecord: forStorage true only through
// structuredSerializeForStorage) and its sub-serializations, serialized with
// the same memory as the rest of the value; it is read back as a new
// instance of that interface in the target realm, set up by its
// deserialization steps. Any other platform object throws a
// "DataCloneError" DOMException. The serialized form holds everything
// inline - no pointer into any realm, agent or thread - so a worker's
// message and an IndexedDB record can be read anywhere.

/// StructuredSerializeForStorage of any value: an inline primitive is
/// serialized as it is (HTML StructuredSerializeInternal step 4), and so is
/// a bare platform object (its wrapper); a platform object that is not
/// [Serializable] throws DataCloneError. OWNED bytes (`allocator`).
pub inline fn structuredSerializeForStorage(realm: Context, value: JSValue, allocator: std.mem.Allocator) Error![]u8 {
    return impl.structuredSerializeForStorage(realm, value, allocator);
}

/// StructuredDeserialize of what StructuredSerializeForStorage made, into
/// `realm` (targetRealm): its platform objects are made there. OWNED.
pub inline fn structuredDeserialize(realm: Context, bytes: []const u8) Error!Owned {
    return impl.structuredDeserialize(realm, bytes);
}

/// StructuredSerializeWithTransfer: StructuredSerializeInternal with
/// forStorage false, so a [Serializable] platform object's steps see
/// forStorage false. OWNED (`allocator`).
pub inline fn structuredSerializeWithTransfer(realm: Context, value: JSValue, transfer_list: []const JSValue, check: TransferableCheck, check_data: ?*anyopaque, allocator: std.mem.Allocator) Error!SerializedWithTransfer {
    return impl.structuredSerializeWithTransfer(realm, value, transfer_list, check, check_data, allocator);
}

/// StructuredDeserializeWithTransfer into `realm` (targetRealm): its
/// platform objects are made there. OWNED.
pub inline fn structuredDeserializeWithTransfer(realm: Context, serialized: []const u8, array_buffers: []const []const u8) Error!Owned {
    return impl.structuredDeserializeWithTransfer(realm, serialized, array_buffers);
}

// ============================================================================
// 4.12 Platform objects (engine concerns, no spec)
// ============================================================================
//
// Teardown and the collector. An instance's teardown - its vtable deinit, and
// everything it releases - never runs while the engine is collecting. When the
// collector takes a platform object's wrapper, the adapter makes the instance
// unreachable through the binding at once (a later wrap makes a new wrapper)
// and defers its teardown to a point where engine calls are allowed: a deinit
// may release Owned values, end holds and traced edges, and call any
// operation an ordinary step may. V8: the first pass of its weak callbacks
// only unlinks the wrapper cache's entry; the instance is torn down in the
// second pass (SetSecondPassCallback, v8-weak-callback-info.h: "No v8 other
// api calls may be called in the first callback"), as Blink's
// ScriptWrappable did (firstWeakCallback reset the wrapper,
// secondWeakCallback freed the object). An engine whose finalizers run
// inside its collector (JavaScriptCore's JSObjectFinalizeCallback, QuickJS's
// class finalizer) queues the teardown the same way. Nor does a teardown run
// for an instance wrapped again in between: the new wrapper owns it.

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

/// The host has freed `instance`: its wrapper must not free it again - nor a
/// teardown the adapter deferred past a collection (4.12) run for it.
pub inline fn platformObjectDestroyed(instance: *Instance) void {
    impl.platformObjectDestroyed(instance);
}

/// Which of its children an owner keeps through `traceChild`: the member that
/// holds it, by name ("selection", "navigator") - Blink's `Member<>` field that
/// the owner's `Trace` visits. A key, never a property: script cannot see or
/// reach it. One child per (owner, slot); a name is unique within its owner's
/// interface, not across interfaces.
pub const TracedSlot = struct { name: []const u8 };

/// `owner` keeps `child` alive: `child`'s wrapper lives for exactly as long as
/// `owner`'s wrapper does - an edge the collector traces, never a root, so an
/// owner and a child that keep each other (a shadow root and its host) still
/// go together once script holds neither. Blink: `owner`'s `Trace` visiting a
/// `Member<>`; WebKit: `visitChildren`; V8: a private property on `owner`'s
/// wrapper; JavaScriptCore: an opaque root / `JSManagedValue` owner.
///
/// Makes `child`'s wrapper if script has not seen it yet, in its relevant
/// realm - never `owner`'s (a Window's wrapper is its global object). An
/// owner script has not seen yet - a Zig-made event before its dispatch, a
/// constructor's instance before the binding caches `this` - holds `child`
/// STRONGLY until its wrapper is made, and the edge is drawn on that wrapper
/// then: a wrapper made here would be the collector's to free the owner
/// with, and a constructor's `this` would replace it. An owner that can be
/// freed without ever being wrapped ends such an edge in its teardown
/// (`forgetTracedChild`). Tracing a new child into an occupied slot replaces
/// the edge. Does nothing when `owner`'s realm has no engine realm left.
///
/// The edge keeps `child` only while `owner`'s wrapper lives, so that wrapper
/// must live as long as `owner` does: true of a Window (its global object),
/// of an owner script holds, and of anything a traced edge itself keeps. Not
/// of an owner the host keeps while the collector may take its wrapper.
/// Never call it while the collector runs - no teardown does (4.12).
/// OWNED: nothing - the edge dies with `owner`'s wrapper.
pub inline fn traceChild(owner: *Instance, child: *Instance, slot: TracedSlot) void {
    impl.traceChild(owner, child, slot);
}

/// End the edge `traceChild` drew from `owner` in `slot` (the member was
/// cleared: Selection's range removed), or the one waiting for `owner`'s
/// wrapper. A no-op when there is none; never makes a wrapper. The teardown
/// of an owner script has seen need not call it - the edge dies with the
/// wrapper. An owner that can be freed unwrapped calls it from its teardown,
/// where it only lets the waiting edge go: an owner the collector frees has
/// no wrapper left by then. Like `traceChild`, it must not run while the
/// collector does - no teardown does (4.12).
pub inline fn forgetTracedChild(owner: *Instance, slot: TracedSlot) void {
    impl.forgetTracedChild(owner, slot);
}

/// `owner` keeps `value` - a JavaScript value it holds for script, such as a
/// FileReader's result, a CustomEvent's detail or a NavigateEvent's info -
/// alive for exactly as long as `owner`'s wrapper: an edge the collector
/// traces, never a root, so a value that reaches back to its owner (a detail
/// that closes over its event, a result kept on the reader's own realm's
/// global) still goes with it once script holds neither. Blink: a
/// `TraceWrapperV8Reference` the owner's `Trace` visits; V8: a private
/// property on `owner`'s wrapper; JavaScriptCore: a property under a private
/// symbol on the owner's JSObject, or a JSManagedValue it owns.
///
/// `slot` names the member, in `traceChild`'s namespace: one value or child
/// per (owner, slot), a new one replacing the old. `tracedValue` reads it
/// back and `forgetTracedChild` ends it. `value` is BORROWED, and may be any
/// value - a platform object is kept as its wrapper in its relevant realm, a
/// primitive as itself. As with `traceChild`: an owner script has not seen
/// yet holds `value` strongly until its wrapper is made; the owner's wrapper
/// must live as long as the owner; it must not be called while the
/// collector runs; it does nothing when `owner`'s realm has no engine realm
/// left. An engine that keeps no traced values does nothing, and its
/// `tracedValue` answers null. OWNED: nothing - the edge dies with `owner`'s
/// wrapper.
pub inline fn traceValue(owner: *Instance, value: JSValue, slot: TracedSlot) void {
    impl.traceValue(owner, value, slot);
}

/// The value `traceValue` keeps in `owner`'s `slot` - the same value, not a
/// copy - as an `Owned` the caller releases (a getter hands it on with
/// `take()`); null when the slot holds none: never set, ended
/// (`forgetTracedChild`), or gone with `owner`'s wrapper. Never makes a
/// wrapper; must not be called while the collector runs.
pub inline fn tracedValue(owner: *Instance, slot: TracedSlot) ?Owned {
    return impl.tracedValue(owner, slot);
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
// Helpers over the operations (not operations: an adapter provides nothing
// for them)
// ============================================================================

/// A dictionary member of type boolean, as WebIDL 3.2.18 reads one: Get(O,
/// P), then - when it is not undefined - ToBoolean. Null when the member is
/// not present. What a getter throws is pending (ExceptionPending); an
/// `object` that is not an Object is a TypeError.
pub fn getPropertyBoolean(realm: Context, object: JSValue, property: []const u8) Error!?bool {
    const member = try getProperty(realm, object, property);
    defer member.release();
    if (typeOf(realm, member.value) == .undefined) return null;
    return toBoolean(realm, member.value);
}

/// A dictionary member of an interface type, as WebIDL 3.2.18 reads one:
/// null when not present (undefined); the platform object otherwise, or a
/// TypeError when it is not one (null included). BORROWED: the object lives
/// as long as its wrapper, which `object` keeps.
pub fn getPropertyPlatformObject(realm: Context, object: JSValue, property: []const u8) Error!?*Instance {
    const member = try getProperty(realm, object, property);
    defer member.release();
    if (typeOf(realm, member.value) == .undefined) return null;
    return convertToPlatformObject(realm, member.value) orelse error.TypeError;
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
        // nothing calls still has to type-check. Not an adapter with an
        // engine behind it: compiling every operation whole links the
        // engine, and a test of engine-neutral code that reaches the facade
        // (an impl's Zig state) links none. That adapter's own tests compile
        // it whole (tests/v8, "every protocol operation's V8 function
        // compiles").
        if (@import("builtin").is_test and !impl.links_engine) _ = &@field(impl, decl.name);
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
