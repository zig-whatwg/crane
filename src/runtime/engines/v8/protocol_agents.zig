//! The engine protocol's engine and agents on V8 (design 4.1): the platform
//! and the snapshot agents are made from, and an agent - an isolate - with
//! the host's hooks installed on it.
//!
//! protocol.zig forwards these operations here. V8 keeps its callbacks per
//! isolate but hands most of them no data, and an isolate's four data slots
//! are taken (the isolate allocator, its templates, the snapshot's data), so
//! each agent's hooks are found by its isolate in a process-wide table.
//! Agents live on different threads (a worker's is its own), hence the lock.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const snapshot_loader = @import("snapshot_loader.zig");
const external_references = @import("external_references.zig");
const current_realm = @import("current_realm.zig");
const support = @import("protocol_support.zig");
const protocol_modules = @import("protocol_modules.zig");
const isolate_lifecycle = @import("isolate_lifecycle.zig");
const isolate_allocator = @import("isolate_allocator.zig");
const shadow_realm = @import("shadow_realm.zig");
const intl_binding = @import("intl_binding.zig");
const observable_array = @import("observable_array.zig");
const context_manager = @import("context_manager.zig");
const callback_registry = @import("callback_registry.zig");
/// worker_realm.zig's agent operations.
const worker_realm = @import("worker_realm.zig");
const protocol_realms = @import("protocol_realms.zig");
const protocol_webassembly = @import("protocol_webassembly.zig");
/// [repl_mode]: the agent's console session (AgentRecord `repl`).
const protocol_repl = @import("protocol_repl.zig");
/// An agent's WebAssembly streaming compilations (AgentRecord
/// `webassembly_compilations`), named for tests/v8.
pub const WebAssemblyCompilations = protocol_webassembly.Compilations;

const Context = engine.Context;
const Agent = engine.Agent;
const Error = engine.Error;

const log = std.log.scoped(.protocol_agents);

// ============================================================================
// initializeEngine / deinitializeEngine
// ============================================================================

/// V8's bytes of the snapshot initializeEngine was given (its stamp split
/// off), BORROWED until deinitializeEngine. Read by createAgent on any
/// thread, written only while no agent is being made. Every agent restored
/// from it reads these bytes IN PLACE for its whole life - no copy per
/// isolate (v8_Isolate_NewFromSnapshot) - which the protocol allows: the
/// host lends them until deinitializeEngine, and that comes after every
/// agent is destroyed (engine_protocol.zig). One blob for every isolate of
/// the process, as Chromium points every isolate's StartupData into its one
/// snapshot mapping (gin/v8_initializer.cc, GetMappedFileData).
// process-wide: the one blob every isolate of the process restores from (V8 keeps one read-only heap per process); written by initializeEngine/deinitializeEngine at the process start and end - and by snapshot tests, which run alone - only when it changes (setEngineSnapshot), so another Browser's createAgent reading it on its thread races no write
var engine_snapshot: ?[]const u8 = null;

/// Set `engine_snapshot`, writing nothing when it already holds `blob`. A
/// test's own initializeEngine(.{}) beside another Browser's createAgent (the
/// many-Browsers variant: tests/html's engine-starting tests, ev1 among them)
/// then puts the null that is there back as a read, not a write - the data
/// race ThreadSanitizer reported (lane gstate4's -Dsanitize-thread
/// -Dmany-browsers tests-html run). The same rule as every hook slot's
/// install (src/process/hook.zig). A test that CHANGES the snapshot restores
/// agents from it and runs alone (build.zig `snapshot_first`).
fn setEngineSnapshot(blob: ?[]const u8) void {
    if (sameBlob(engine_snapshot, blob)) return;
    engine_snapshot = blob;
}

/// Whether two snapshot blobs are the same bytes (the same pointer and
/// length; both absent counts as the same).
fn sameBlob(a: ?[]const u8, b: ?[]const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return x.ptr == y.ptr and x.len == y.len;
}

test "the engine snapshot is the same blob only for the same bytes, or both absent" {
    const bytes = "0123456789";
    try std.testing.expect(sameBlob(null, null));
    try std.testing.expect(sameBlob(bytes[0..4], bytes[0..4]));
    try std.testing.expect(!sameBlob(null, bytes[0..4]));
    try std.testing.expect(!sameBlob(bytes[0..4], null));
    try std.testing.expect(!sameBlob(bytes[0..4], bytes[0..5]));
    try std.testing.expect(!sameBlob(bytes[0..4], bytes[1..5]));
}

/// Prepare V8 for agents: its flags and platform - once per process: V8
/// freezes its flags when the platform starts and cannot start again after
/// it stops - and the snapshot agents may be made from.
pub fn initializeEngine(options: engine.EngineOptions) Error!void {
    // The runtime flags, then the platform, in one start that any thread may
    // be first to (v8_Platform_Start). Started already - by an isolate made
    // before this (ffi.v8_Isolate_New starts V8 with these same flags), or by
    // an earlier initializeEngine - it is a no-op; started with other flags,
    // which then stay in effect, it says so at err level.
    snapshot_loader.initializePlatformForRuntime();
    // [code_generation_checks]: the process's dispatchers, once, before any
    // agent's thread runs; each agent enables its isolate's callbacks.
    ffi.v8_SetProtocolCodeGenerationDispatchers(onCodeGenerationFromStrings, onWasmCodeGeneration);
    // HostPromiseRejectionTracker's and [module_scripts]' (import(),
    // import.meta.url and .resolve), the same way. Every createAgent used to
    // set these - one process global written on each agent's own thread, a
    // data race between Browsers (ThreadSanitizer, lane tsanfix1;
    // docs/testing/test-variant-findings-2026-11-02.tsv F1); AGENTS.md
    // "Global state" rule 2: installed once, at process start.
    ffi.v8_SetProtocolPromiseRejectDispatcher(onPromiseReject);
    ffi.v8_SetProtocolModuleDispatchers(protocol_modules.onDynamicImport, protocol_modules.onImportMetaUrl, protocol_modules.onImportMetaResolve);
    // HostCreateShadowRealmContextCallback's, the same way.
    shadow_realm.installDispatcher();
    // [webassembly_streaming]: the WasmStreamingCallback's, the same way.
    ffi.v8_SetProtocolWasmStreamingDispatcher(protocol_webassembly.onWasmStreaming);
    // [cross_origin_objects]: the access checks' dispatch, the same way.
    @import("cross_origin.zig").installDispatch();
    const blob: ?[]const u8 = if (options.snapshot) |stamped| usableSnapshot(stamped) catch |err| {
        setEngineSnapshot(null);
        return err;
    } else null;
    setEngineSnapshot(blob);
}

/// The V8 blob inside `stamped_data`, when this build can restore it: a blob
/// this build's snapshot generator made (its stamp), that V8 accepts, made
/// against the external references this build registers. A blob restored
/// against another build's references wires every callback to whatever sits
/// at its index now (docs/lessons/
/// debugging-a-tracked-build-artifact-shadows-the-build.md).
fn usableSnapshot(stamped_data: []const u8) Error![]const u8 {
    const stamped = snapshot_loader.splitStamp(stamped_data) orelse {
        log.warn("the snapshot carries no build stamp - not made by this build's snapshot generator", .{});
        return error.OperationFailed;
    };
    if (stamped.blob.len < 8 or !ffi.v8_Snapshot_IsValid(stamped.blob.ptr, @intCast(stamped.blob.len))) {
        log.warn("V8 does not accept the snapshot", .{});
        return error.OperationFailed;
    }
    // Registered in the order the generator registered them: V8 resolves a
    // callback by its index.
    external_references.registerAllExternalReferences();
    const count = external_references.getExternalReferenceStats().count;
    if (!snapshot_loader.stampMatches(stamped, count)) {
        log.warn("the snapshot was made against {d} external references and this build has {d}", .{ stamped.reference_count, count });
        return error.OperationFailed;
    }
    return stamped.blob;
}

/// The end of the engine for the host: the snapshot is forgotten (the host
/// may free it). V8's platform is kept - a V8 process cannot initialize it
/// again - so a later initializeEngine starts from where this left off.
///
/// The protocol calls this after every agent is destroyed. An agent restored
/// from the snapshot that is still alive reads the host's bytes in place, so
/// freeing them now would leave it a dangling blob for its next realm: said
/// loudly here, where the host broke the order, rather than as a crash in
/// whatever realm that agent makes next.
pub fn deinitializeEngine() void {
    if (engine_snapshot != null) {
        const live = liveSnapshotAgents();
        if (live != 0) log.err("deinitializeEngine with {d} agent(s) restored from the snapshot still alive: they read its bytes in place, so the host must destroy them before it frees the snapshot", .{live});
    }
    setEngineSnapshot(null);
}

// ============================================================================
// Agents
// ============================================================================

/// What the adapter keeps for an agent it made: the host's hooks.
const AgentRecord = struct {
    isolate: *ffi.Isolate,
    hooks: *const engine.HostHooks,
    host: ?*anyopaque,
    /// AgentOptions.allocator: the agent's own state.
    allocator: std.mem.Allocator,
    /// The isolate was restored from the engine's snapshot, whose bytes it
    /// reads in place for its whole life (v8_Isolate_NewFromSnapshot): the
    /// host may free them only after the agent is destroyed
    /// (`liveSnapshotAgents`, deinitializeEngine).
    from_snapshot: bool = false,
    /// The agent's ShadowRealms (shadow_realm.zig): made with the agent,
    /// freed by its end. Null when ShadowRealm support was not installed.
    shadow_realms: ?*shadow_realm.ShadowRealmCallbackData = null,
    /// The regexp operations' utility context and compiled regexps
    /// (engine.matchesPatternAttribute, regExpCreateCheck,
    /// regExpBuiltinExecCaptures; v8_wrapper.cpp, PatternMatcher): made on
    /// first use, on the agent's thread; deleted by its end.
    pattern_matcher: ?*ffi.PatternMatcher = null,
    /// [repl_mode]: the agent's console session (protocol_repl.Session) - an
    /// inspector of this isolate and one session of it, through which
    /// engine.evaluateReplScript evaluates console input. Made on the
    /// console's first use (`replSessionOf`), on the agent's thread; ended by
    /// the agent's end in two steps (endAgent says when). Never made for an
    /// agent no console evaluates in.
    repl: ?*protocol_repl.Session = null,
    /// AgentOptions.deferred_teardown: the host's queue a garbage tree's
    /// teardown goes to (dom.refcount_teardown, refcount step 7), BORROWED;
    /// the agent's end drains and closes it. For an agent made without one,
    /// `own_deferred_teardown`.
    deferred_teardown: ?*runtime.gc.DeferredTeardown = null,
    /// The agent's own queue, OWNED, when the host gave none (only a test's
    /// own agent): the adapter frees no node since the wrapper redesign's P2,
    /// so every agent needs a queue for what its counts leave garbage. It
    /// drains as a host's does - at a requested collection, each realm's
    /// end, the agent's end - but no event loop slices it; `endAgent` frees
    /// it, before the isolate is disposed (lane wr1 batch 2, the integrator's
    /// decision (A)).
    own_deferred_teardown: ?*runtime.gc.DeferredTeardown = null,
    /// The WindowProperties named properties object's template
    /// (window_properties.zig): this isolate's, made by its first window
    /// realm and reused by every later one, as Blink keeps its templates in
    /// V8PerIsolateData; disposed by the agent's end. Read and written on
    /// the agent's own thread only.
    window_properties_template: ?*ffi.FunctionTemplate = null,
    /// The agent's live Intl objects' internal slots (intl_binding.Objects):
    /// made by its first Intl construction, on the agent's thread; freed by
    /// its end. The adapter's per-isolate state is the agent's (instances
    /// B2), as the nine process-wide Intl registries it replaces were not.
    intl_objects: ?*intl_binding.Objects = null,
    /// The agent's live ObservableArray states (observable_array.Registry):
    /// made by its first array, on the agent's thread; freed by its end.
    observable_arrays: ?*observable_array.Registry = null,
    /// The Window realms the agent made and that have not ended, by realm
    /// (protocol_realms.zig): written by createWindowRealm and each realm's
    /// end, read and written on the agent's own thread only; its storage is
    /// freed with the record (forgetAgent). Every Window realm ends before
    /// its agent, so it is empty by then.
    window_realms: protocol_realms.WindowRealms = .empty,
    /// The agent's Window realms whose end is under way (protocol_realms.
    /// endRealm's re-entrancy guard): a stack of nodes on the endRealm
    /// frames' own stacks, innermost first. Read and written on the agent's
    /// own thread only, its end included. It was a `threadlocal`.
    ending_window_realms: ?*const protocol_realms.EndingRealm = null,
    /// [webassembly_streaming]: the compilations handed to the host's
    /// compilePotentialWebAssemblyResponse that it has not ended
    /// (protocol_webassembly.zig); the agent's end ends and frees them,
    /// before the isolate is disposed.
    webassembly_compilations: protocol_webassembly.Compilations,
    /// engine.deferTeardowns: the walks holding this agent's teardowns, and
    /// the collected entries waiting for the last of them to end
    /// (wrapper_cache.TeardownHolds). Read and written on the agent's own
    /// thread only; its storage is freed with the record (forgetAgent).
    teardown_holds: @import("wrapper_cache.zig").TeardownHolds = .{},
    /// The agent's realms (context_manager.Realms): the context manager's
    /// record of every context it hosts for the agent, live and retired -
    /// as Blink keeps an isolate's state on its V8PerIsolateData and WebKit
    /// on its VM's client data. Read and written on the agent's own thread
    /// only; ended by the agent's end (context_manager.endAgentRealms), which
    /// frees this agent's realms and no other's. It was a threadlocal, which
    /// the thread's host agent's end took down whole.
    realms: context_manager.Realms = .{},
    /// The agent's callback wrappers not yet freed (callback_registry.Live),
    /// so that a realm's end can release the handles its script's callbacks
    /// hold. Read and written on the agent's own thread only, through its
    /// end; its storage goes with the record (removeAgent). It was a
    /// `threadlocal`, every agent's on the thread in one set.
    callbacks: callback_registry.Live = .empty,
    /// The agent's module records alive, by identity hash
    /// (protocol_modules.Records), for the callbacks V8 hands a module - a
    /// Link's referrer, import.meta. Read and written on the agent's own
    /// thread only, through its end; its storage goes with the record. It
    /// was a `threadlocal`, every agent's on the thread in one map.
    modules: protocol_modules.Records = .empty,
    /// The agent's worker realms made and not yet destroyed
    /// (worker_realm.Records): what each one's end needs once the context
    /// manager has retired it. Read and written on the agent's own thread
    /// only; its storage goes with the record. It was a `threadlocal`.
    worker_realms: worker_realm.Records = .empty,
    /// The agent's live wrapper caches, one per realm (wrapper_cache.Caches):
    /// where a cache looks for another of the agent's realms still wrapping
    /// an instance before it frees it. Read and written on the agent's own
    /// thread only, through its end; its storage goes with the record. It was
    /// a `threadlocal`.
    caches: @import("wrapper_cache.zig").Caches = .empty,
    /// How many "prepare to run script"s are open on the agent without their
    /// "clean up" (protocol_scripts.zig): each a realm execution context on
    /// the agent's JavaScript execution context stack - an agent's own
    /// (ECMAScript 9.4 "an agent ... has its own execution context stack"),
    /// whether or not a JavaScript frame runs above it. Read and written on
    /// the agent's own thread only. It was a `threadlocal`: one agent's open
    /// prepare made another agent on the thread skip its checkpoint.
    prepared_scripts: u32 = 0,
    /// The agent is ending (`endAgent`): its hooks are forgotten, and
    /// `recordOf` no longer finds it - nothing reaches the host from here on,
    /// and nothing is made for the agent - while its realms end, which still
    /// look their contexts up (`realmsOf`). Then `removeAgent` takes it out.
    ending: bool = false,
};

/// The agent's teardown holds (engine.deferTeardowns); null for an isolate
/// createAgent did not make, which then holds nothing. Called on the agent's
/// own thread only.
pub fn teardownHoldsOf(isolate: *ffi.Isolate) ?*@import("wrapper_cache.zig").TeardownHolds {
    const record = recordOf(isolate) orelse return null;
    return &record.teardown_holds;
}

/// The agent's PatternMatcher, made on its first use; null for an isolate
/// createAgent did not make (a test's own), which then matches in a context
/// made for the call. Called on the agent's own thread only.
pub fn patternMatcherOf(isolate: *ffi.Isolate) ?*ffi.PatternMatcher {
    const record = recordOf(isolate) orelse return null;
    if (record.pattern_matcher == null) record.pattern_matcher = ffi.v8_PatternMatcher_New();
    return record.pattern_matcher;
}

/// [repl_mode] The agent's console session, made on its first use with the
/// agent's allocator; null for an isolate createAgent did not make (a test's
/// own), for an agent whose end has begun, or when V8 could not make one.
/// Called on the agent's own thread only, with its isolate entered.
pub fn replSessionOf(isolate: *ffi.Isolate) ?*protocol_repl.Session {
    const record = recordOf(isolate) orelse return null;
    if (record.repl == null) record.repl = protocol_repl.Session.create(record.allocator, isolate) catch null;
    return record.repl;
}

/// The agent's Intl objects, made on their first use with the agent's
/// allocator; null for an isolate createAgent did not make, or when there is
/// no memory for them. Called on the agent's own thread only.
pub fn intlObjectsOf(isolate: *ffi.Isolate) ?*intl_binding.Objects {
    const record = recordOf(isolate) orelse return null;
    if (record.intl_objects == null) record.intl_objects = intl_binding.Objects.create(record.allocator) catch null;
    return record.intl_objects;
}

/// The agent's ObservableArray registry, made on its first use with the
/// agent's allocator; null for an isolate createAgent did not make, or when
/// there is no memory for it. Called on the agent's own thread only.
pub fn observableArraysOf(isolate: *ffi.Isolate) ?*observable_array.Registry {
    const record = recordOf(isolate) orelse return null;
    if (record.observable_arrays == null) record.observable_arrays = observable_array.Registry.create(record.allocator) catch null;
    return record.observable_arrays;
}

// process-wide: the lock over `agents`, the process's one index of live agents, which every Browser's and worker's thread reaches
var agents_lock: std.Io.Mutex = .init;
/// Every agent made by createAgent and not yet destroyed, by isolate.
// process-wide: V8's isolates are the process's, and a hook dispatch finds its agent's record by isolate from any thread; each Browser and worker adds and removes only its own agents' records, always under agents_lock (the records themselves are their Browser's or WorkerHost's)
var agents: std.AutoHashMapUnmanaged(*ffi.Isolate, *AgentRecord) = .empty;

/// How many agents createAgent restored from the engine's snapshot and that
/// are not yet ended - each reads the snapshot's bytes in place, so the host
/// may free them only when this is 0 (deinitializeEngine checks it).
pub fn liveSnapshotAgents() usize {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    var count: usize = 0;
    var records = agents.valueIterator();
    while (records.next()) |record| {
        if (record.*.from_snapshot) count += 1;
    }
    return count;
}

/// How many agents createAgent made that are not yet ended - each with its
/// realms, Browsers' and tests' alike. Diagnostics only (the adapter's
/// `live_agents` counter): the Crane test runner reads it after every test,
/// and an agent a test left alive fails that test by name.
pub fn liveAgentCount() usize {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    return agents.count();
}

/// The hooks of the agent whose isolate this is; null for an isolate
/// createAgent did not make (a test's own), and for an agent whose end has
/// begun (`AgentRecord.ending`).
pub fn recordOf(isolate: *ffi.Isolate) ?*AgentRecord {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return if (record.ending) null else record;
}

/// The stack of the agent's Window realms whose end is under way
/// (`AgentRecord.ending_window_realms`), until the agent's record goes -
/// through its end too; null for an isolate createAgent did not make. Called
/// on the agent's own thread only.
pub fn endingWindowRealmsOf(isolate: *ffi.Isolate) ?*?*const protocol_realms.EndingRealm {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return &record.ending_window_realms;
}

/// The count of the agent's open "prepare to run script"s
/// (`AgentRecord.prepared_scripts`), until the agent's record goes - through
/// its end too; null for an isolate createAgent did not make. Called on the
/// agent's own thread only.
pub fn preparedScriptsOf(isolate: *ffi.Isolate) ?*u32 {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return &record.prepared_scripts;
}

/// The callback wrappers of the agent whose isolate this is
/// (callback_registry.Live), until the agent's record goes - through its end,
/// while its realms end; null for an isolate createAgent did not make.
/// Called on the agent's own thread only.
pub fn callbacksOf(isolate: *ffi.Isolate) ?*callback_registry.Live {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return &record.callbacks;
}

/// The module records of the agent whose isolate this is
/// (protocol_modules.Records), until the agent's record goes - through its
/// end; null for an isolate createAgent did not make. Called on the agent's
/// own thread only.
pub fn modulesOf(isolate: *ffi.Isolate) ?*protocol_modules.Records {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return &record.modules;
}

/// The worker realms of the agent whose isolate this is
/// (worker_realm.Records), until the agent's record goes; null for an isolate
/// createAgent did not make. Called on the agent's own thread only.
pub fn workerRealmsOf(isolate: *ffi.Isolate) ?*worker_realm.Records {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return &record.worker_realms;
}

/// The live wrapper caches of the agent whose isolate this is
/// (wrapper_cache.Caches), until the agent's record goes - through its end,
/// while its realms' caches end; null for an isolate createAgent did not
/// make. Called on the agent's own thread only.
pub fn cachesOf(isolate: *ffi.Isolate) ?*@import("wrapper_cache.zig").Caches {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    return &record.caches;
}

/// The realms of the agent whose isolate this is (context_manager.Realms),
/// until the agent's record goes - through the agent's end, while its realms
/// end; null for an isolate createAgent did not make. They allocate with the
/// agent's allocator unless a test chose another (context_manager.
/// useAllocator). Called on the agent's own thread only.
pub fn realmsOf(isolate: *ffi.Isolate) ?*context_manager.Realms {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    if (record.realms.allocator == null) record.realms.allocator = record.allocator;
    return &record.realms;
}

/// HostHooks.agentClusterOf for `realm` of the agent whose isolate this is:
/// the realm's agent cluster key, or 0 - no cluster known, nothing checked -
/// for an agent without the hook, or an isolate createAgent did not make.
pub fn agentClusterOf(isolate: *ffi.Isolate, realm: Context) u64 {
    const record = recordOf(isolate) orelse return 0;
    const call = record.hooks.agentClusterOf orelse return 0;
    return call(record.host, realm);
}

/// HTML's cross-origin isolated capability; absent hooks deny shared memory.
pub fn crossOriginIsolatedCapability(isolate: *ffi.Isolate, realm: Context) bool {
    const record = recordOf(isolate) orelse return false;
    const call = record.hooks.crossOriginIsolatedCapability orelse return false;
    return call(record.host, realm);
}

/// HostHooks.htmlConstructor [html_constructor] of the agent whose isolate
/// this is, with the host it is handed - what an [HTMLConstructor]
/// interface's construction runs (interface.zig). Null for an agent without
/// the hook, or an isolate createAgent did not make.
pub const HTMLConstructorHook = struct {
    call: *const fn (host: ?*anyopaque, realm: Context, new_target: engine.JSValue, interface: []const u8) Error!engine.HTMLConstructed,
    host: ?*anyopaque,
};

pub fn htmlConstructorHookOf(isolate: *ffi.Isolate) ?HTMLConstructorHook {
    const record = recordOf(isolate) orelse return null;
    const call = record.hooks.htmlConstructor orelse return null;
    return .{ .call = call, .host = record.host };
}

/// engine.agentHost: the host pointer `agent` was made with; null once
/// endAgent has forgotten it, or for an isolate createAgent did not make.
pub fn agentHost(agent: *Agent) ?*anyopaque {
    const record = recordOf(@ptrCast(@alignCast(agent))) orelse return null;
    return record.host;
}

/// The deferred teardown queue of the agent whose isolate this is: the one
/// the host gave it (AgentOptions.deferred_teardown), else the agent's own
/// (AgentRecord.own_deferred_teardown); null for an isolate createAgent did
/// not make, once its record went (removeAgent), and - a host's queue - once
/// its agent's end began.
pub fn deferredTeardownOf(isolate: *ffi.Isolate) ?*runtime.gc.DeferredTeardown {
    std.Io.Threaded.mutexLockUncancelable(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    const record = agents.get(isolate) orelse return null;
    // A host's queue is not answered once the agent's end began: the host
    // drained it, and freed what was left of its DOM (a Browser's sweeps,
    // Browser.deinit), before ending the agent. The agent's OWN queue (a test
    // agent, which nothing sweeps) is answered through its end, until its
    // record goes: the realms that end inside it (isolate_lifecycle.
    // cleanupAll) release what their caches held - an event's target - and a
    // tree that leaves garbage is queued and drained there (context_manager.
    // endRealms), the queue closed only after.
    if (record.ending and record.own_deferred_teardown == null) return null;
    return record.deferred_teardown;
}

/// Run every teardown queued for `agent` now, its isolate entered: a full
/// collection (requestGarbageCollection) or the host short of memory asked
/// for everything the collector found to be freed.
pub fn drainDeferredTeardown(agent: *Agent) void {
    const queue = deferredTeardownOf(@ptrCast(@alignCast(agent))) orelse return;
    if (queue.isEmpty()) return;
    // Not inside a walk holding the agent's teardowns: what it queued is
    // torn down at the next turn instead (engine.deferTeardowns).
    if (teardownsHeld(@ptrCast(@alignCast(agent)))) return;
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    queue.drainAll();
}

fn engineWakeTask(_: ?*anyopaque) void {}
fn wakeEngineLoop(data: ?*anyopaque) callconv(.c) void {
    const sink: *runtime.TaskSink = @ptrCast(@alignCast(data.?));
    _ = sink.post(.{ .run = engineWakeTask, .drop = engineWakeTask, .data = null });
}
fn releaseEngineSink(data: ?*anyopaque) callconv(.c) void {
    const sink: *runtime.TaskSink = @ptrCast(@alignCast(data.?));
    sink.release();
}

/// A restore from `blob` was refused or failed, and the agent is made without
/// the snapshot: said at warn, with why. V8 keeps ONE read-only heap per
/// process, made by the first live isolate from ITS snapshot (v8_wrapper.cpp
/// g_read_only_heap; V8 13.1 ReadOnlyHeap::SetUp): while isolates made from
/// another snapshot live, Crane's blob cannot be restored - it crashed V8
/// (docs/testing/test-variant-findings-2026-11-02.tsv M1). Normal use never
/// gets here: a Browser's window agent is its process's first isolate, and
/// its workers come after it.
fn warnSnapshotRefused(blob: []const u8) void {
    switch (ffi.readOnlyHeapOrigin(blob)) {
        .builtin => log.warn("an agent asked for the engine's snapshot ({d} bytes at {*}) is made without it: the process's first live isolate was made from V8's built-in snapshot, and V8 keeps one read-only heap per process (a Browser with snapshot_path \"\", or a bare isolate, made before any snapshot agent)", .{ blob.len, blob.ptr }),
        .other_blob => log.warn("an agent asked for the engine's snapshot ({d} bytes at {*}) is made without it: the process's first live isolate was made from another snapshot blob, and V8 keeps one read-only heap per process", .{ blob.len, blob.ptr }),
        .none, .same, _ => log.warn("V8 could not make an isolate from the engine's snapshot ({d} bytes at {*}); making one without it", .{ blob.len, blob.ptr }),
    }
}

/// Whether `agent` was restored from the engine's snapshot
/// (engine.agentRestoredFromSnapshot): only then can its Window realms be
/// restored from it.
pub fn restoredFromSnapshot(agent: *Agent) bool {
    const record = recordOf(@ptrCast(@alignCast(agent))) orelse return false;
    return record.from_snapshot;
}

/// HTML "obtain an agent" (a similar-origin window agent or a worker's): a
/// new isolate - restored from the engine's snapshot when asked for and one
/// was given - with [[CanBlock]] as the options say and the host's hooks
/// installed. The isolate is not entered.
pub fn createAgent(options: engine.AgentOptions) Error!*Agent {
    // [seeded_random] and [host_clock]: in the isolate's record before it
    // initializes - V8 may make its random number generator then. None of
    // either: an isolate exactly as before (v8_wrapper.cpp IsolateData).
    const isolate_options: ffi.IsolateOptions = .{
        .seeded = options.random_seed != null,
        .random_seed = options.random_seed orelse 0,
        .clock_context = if (options.clock) |agent_clock| agent_clock.context else null,
        .clock_wall_now = if (options.clock) |agent_clock| agent_clock.wall_now else null,
    };
    const isolate: *ffi.Isolate = blk: {
        if (options.from_snapshot) {
            if (engine_snapshot) |blob| {
                if (ffi.v8_Isolate_NewFromSnapshotWithOptions(blob.ptr, @intCast(blob.len), external_references.getRuntimeExternalReferencesPtr(), &isolate_options)) |i| break :blk i;
                warnSnapshotRefused(blob);
            }
        }
        // The engine is started by initializeEngine; a host that has not
        // called it gets the platform here, as worker_realm's agents do.
        break :blk ffi.v8_Isolate_NewWithOptions(&isolate_options) orelse return support.protocolError(error.OperationFailed);
    };
    errdefer ffi.v8_Isolate_Dispose(isolate);
    if (options.engine_task_sink) |sink| {
        const retained = sink.retain();
        if (!ffi.v8_Isolate_AttachForegroundTaskSink(isolate, retained, wakeEngineLoop, releaseEngineSink)) {
            retained.release();
            return error.OperationFailed;
        }
    }

    // [[CanBlock]]: false for a similar-origin window agent, whose one thread
    // Atomics.wait() would freeze - it throws a TypeError instead.
    ffi.v8_Isolate_SetAllowAtomicsWait(isolate, options.can_block);
    // [cross_origin_objects]: what V8 hands no cross-origin interceptor - a
    // [[Delete]], [[DefineOwnProperty]] or security-checked call on another
    // realm's WindowProxy or Location - throws a SecurityError.
    @import("cross_origin.zig").installOnIsolate(isolate);

    // The queue the agent's garbage trees go to: the host's, else the
    // agent's own (AgentRecord.own_deferred_teardown).
    const own_queue: ?*runtime.gc.DeferredTeardown = if (options.deferred_teardown != null) null else blk: {
        const queue = options.allocator.create(runtime.gc.DeferredTeardown) catch return error.OutOfMemory;
        queue.* = runtime.gc.DeferredTeardown.init(options.allocator);
        break :blk queue;
    };
    errdefer if (own_queue) |queue| options.allocator.destroy(queue);
    const deferred_teardown = options.deferred_teardown orelse own_queue;
    const record = std.heap.c_allocator.create(AgentRecord) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(record);
    record.* = .{ .isolate = isolate, .hooks = options.hooks, .host = options.host, .allocator = options.allocator, .from_snapshot = ffi.v8_Isolate_IsFromSnapshot(isolate), .deferred_teardown = deferred_teardown, .own_deferred_teardown = own_queue, .webassembly_compilations = .{ .allocator = options.allocator } };
    {
        std.Io.Threaded.mutexLockUncancelable(&agents_lock);
        defer std.Io.Threaded.mutexUnlock(&agents_lock);
        agents.put(std.heap.c_allocator, isolate, record) catch return error.OutOfMemory;
    }
    // The queue the "DOM algorithm active" depth is counted on, one load
    // from the isolate (dom_algorithm.zig; refcount design 9, risk 4).
    @import("dom_algorithm.zig").install(isolate, deferred_teardown);
    // [external_memory]: the host's native memory the agent's objects keep
    // alive, reported to V8 at the same safe points (external_memory.zig).
    @import("external_memory.zig").install(isolate, options.external_memory, deferred_teardown);
    // The finalizers of the agent's collected wrappers: V8's first pass
    // owes them to the queue, whose next binding exit into script runs them
    // (finalizer_safe_point.zig) - the safe point inside a task.
    @import("finalizer_safe_point.zig").install(isolate, deferred_teardown);

    // The hooks the host supplied, and only those: a hook left null is the
    // host's choice to have no such behaviour.
    if (options.hooks.promiseRejectionTracker != null) {
        // The dispatcher is the process's (initializeEngine).
        ffi.v8_Isolate_SetProtocolPromiseRejectCallback(isolate);
    }
    if (options.hooks.afterMicrotaskCheckpoint != null) {
        ffi.v8_Isolate_AddMicrotasksCompletedCallback(isolate, onMicrotasksCompleted, record);
    }
    // [code_generation_checks]: HostEnsureCanCompileStrings (with
    // HostGetCodeForEval) and HostEnsureCanCompileWasmBytes. The strings
    // check reaches the host only from realms made with code generation
    // from strings disallowed (`restrictCodeGenerationFromStrings`).
    // The dispatchers they reach are the process's, set by initializeEngine.
    const strings = options.hooks.ensureCanCompileStrings != null;
    const wasm = options.hooks.ensureCanCompileWasmBytes != null;
    if (strings or wasm) ffi.v8_Isolate_SetProtocolCodeGenerationHooks(isolate, strings, wasm);
    // [module_scripts]: import() and import.meta.
    const load = options.hooks.loadImportedModule != null;
    const meta = options.hooks.importMetaUrl != null;
    const resolve = options.hooks.importMetaResolve != null;
    // [webassembly_streaming]: WebAssembly.compileStreaming and
    // instantiateStreaming, in every realm made from here on - V8 installs
    // them per context only on an isolate with the callback.
    if (options.hooks.compilePotentialWebAssemblyResponse != null) ffi.v8_Isolate_SetProtocolWasmStreaming(isolate);
    // The dispatchers are the process's (initializeEngine); import.meta.resolve
    // is made beside import.meta.url, so only with it.
    if (load or meta) ffi.v8_Isolate_SetProtocolModuleHooks(isolate, load, meta, meta and resolve);

    // What every agent's isolate has before a realm is made in it: the
    // isolate's allocator (the templates it caches), and ShadowRealm support
    // (HostCreateShadowRealmContextCallback, and the agent's own record of
    // its ShadowRealms). destroyAgent undoes them (the teardown steps are
    // isolate_lifecycle's constant table).
    {
        const entered = EnteredIsolate.of(@ptrCast(isolate));
        defer entered.leave();
        isolate_allocator.initIsolateAllocator(isolate, options.allocator, false) catch |err| {
            // One restored from a snapshot may have it already.
            if (err != error.AllocatorAlreadyInitialized) log.warn("the isolate's allocator was not made: {}", .{err});
        };
        record.shadow_realms = shadow_realm.initializeShadowRealmSupport(isolate, options.allocator) catch |err| blk: {
            log.warn("ShadowRealm support was not installed: {}", .{err});
            break :blk null;
        };
    }
    return @ptrCast(isolate);
}

/// The end of an agent, before its isolate is disposed: its hooks are
/// forgotten (no callback reaches the host from here on), what the adapter
/// keeps for the agent is released - its realms (context_manager), templates
/// and allocator among it, isolate_lifecycle's steps - and its garbage
/// collected twice with a checkpoint between. The isolate is left not
/// entered, as disposal requires.
///
/// Every agent's end is the same, and frees what is the agent's and nothing
/// else. The adapter kept its context manager per THREAD, and the thread's
/// host agent - the one made with no isolate entered, as a Browser's page
/// agent is - took it down at its end, with every realm the thread's other
/// agents had made (tests/v8/agent_realms_isolation_test.zig). The realms are
/// the agent's own now (`AgentRecord.realms`), as Blink keeps an isolate's
/// state on its V8PerIsolateData and WebKit on its VM's client data.
///
/// The agent's C++ heap (cppgc: every agent has one, made with its isolate -
/// v8_wrapper.cpp IsolateData::cpp_heap) ends last, with the isolate: V8
/// detaches and terminates it inside Isolate::Dispose, and the isolate's
/// record frees it after (worker_realm.destroyAgent). Nothing is allocated on
/// it yet, so nothing of the agent's state below depends on it (the wrapper
/// redesign, tmp/redesign/wrapper-redesign-design.md 4.9).
pub fn endAgent(agent: *Agent) void {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_CloseForegroundTasks(isolate);
    const record = recordOf(isolate);
    const allocator = if (record) |r| r.allocator else std.heap.c_allocator;
    const shadow_realms = if (record) |r| r.shadow_realms else null;
    const pattern_matcher = if (record) |r| r.pattern_matcher else null;
    const window_properties = if (record) |r| r.window_properties_template else null;
    const deferred_teardown = if (record) |r| r.deferred_teardown else null;
    const own_deferred_teardown = if (record) |r| r.own_deferred_teardown else null;
    const intl_objects = if (record) |r| r.intl_objects else null;
    const observable_arrays = if (record) |r| r.observable_arrays else null;
    const repl = if (record) |r| r.repl else null;
    // The compilations the host never ended: V8's side of each holds a
    // WasmStreaming, which must not outlive the isolate, and its record is
    // the agent's. Ended before the record goes with forgetAgent.
    if (record) |r| r.webassembly_compilations.endAll();
    // [repl_mode] The console session ends in two steps, in this order:
    // 1. Now, while the host is still reached: every evaluation still
    //    waiting is dropped (its host's `dropped` frees its data), and the
    //    inspector forgets every context it still knows, while the contexts
    //    exist - so no inspector weak callback is left for the collections
    //    below to start and the closed task runner never to finish.
    // 2. Last, after the final microtask checkpoints and before the isolate
    //    is disposed (`destroy`, below): the inspector is deleted. Not
    //    sooner: a promise job of the inspector's still queued would run in
    //    those checkpoints and find no inspector (13.1 injected-script.cc,
    //    thenCallback reads v8::debug::GetInspector). Answers that arrive in
    //    between find no evaluation and are released.
    if (repl) |session| session.end();
    // Its node wrappers end, every one's reference let go (engine.
    // releaseNodeWrappers, idempotent: a host that called it before its last
    // drain left nothing here) - before the agent is forgotten, while the
    // counts still find its queue, which the drain below empties (the
    // wrapper redesign's P2, design 4.9 step 2).
    {
        const entered_for_wrappers = EnteredIsolate.of(agent);
        defer entered_for_wrappers.leave();
        @import("node_wrappers.zig").releaseNodeWrappers(isolate);
    }
    forgetAgent(agent);
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    // Its Intl objects' internal slots, whichever kind of agent it is: their
    // weak handles are this isolate's, disarmed here before the collections
    // below could reach a freed cell.
    if (intl_objects) |objects| objects.destroy();
    // Its ObservableArray states, the same way: their proxies' weak handles
    // disarmed before the collections below.
    if (observable_arrays) |registry| registry.destroy();
    // Its utility context and compiled patterns: handles of this isolate,
    // released before it is disposed.
    ffi.v8_PatternMatcher_Delete(pattern_matcher);
    // Its WindowProperties template: a handle of this isolate too.
    if (window_properties) |template| ffi.v8_FunctionTemplate_Dispose(template);
    // The deferred teardown queue: each realm's end drained its own (they end
    // before their agent), and what the counts queued after - a holder a
    // realm's coordinated teardown released (refcount step 7) - goes now, so
    // it is empty. It closes after the agent's remaining realms end (below).
    if (deferred_teardown) |queue| {
        queue.drainAll();
        std.debug.assert(queue.isEmpty());
        // No binding entry counts on it from here on.
        @import("dom_algorithm.zig").install(entered.isolate, null);
    }
    // Nor does a collection owe it finalizers: what the collections below
    // find dead runs when each returns (finalizer_safe_point.zig).
    @import("finalizer_safe_point.zig").uninstall(entered.isolate, deferred_teardown);
    // [external_memory]: V8's count goes back to where it was before the
    // agent reported, and the host's figure is no longer the agent's -
    // before the storage it lives on goes with the templates (cleanupAll).
    @import("external_memory.zig").uninstall(entered.isolate);
    // This agent's ShadowRealms, whichever kind of agent it is: they were
    // every agent's once, cleared by whichever host agent ended first.
    if (shadow_realms) |data| shadow_realm.deinitializeShadowRealmSupport(data);
    // Its realms - every one still on its record torn down, the retired
    // ones freed - while the record is still found for them (`realmsOf`),
    // then its templates and its allocator. Then the record goes.
    isolate_lifecycle.cleanupAll(isolate, allocator);
    // The realms' ends drained what they left garbage (context_manager.
    // endRealms): the queue is empty, and closed from here on - what the
    // collections below find is torn down as each returns, as before.
    if (deferred_teardown) |queue| {
        queue.drainAll();
        std.debug.assert(queue.isEmpty());
        queue.close();
    }
    removeAgent(isolate);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    // [repl_mode] Step 2 of the console session's end (above): the
    // inspector goes, with the isolate still entered and not yet disposed.
    if (repl) |session| session.destroy();
    // The agent's own queue (a host gave none): drained and closed above,
    // freed now - after the last collections, before the isolate is
    // disposed and its C++ heap freed (worker_realm.destroyAgent). What
    // those collections queued, if anything, goes first.
    if (own_deferred_teardown) |queue| {
        queue.drainAll();
        queue.deinit();
        allocator.destroy(queue);
    }
}

// ============================================================================
// Microtask checkpoints and memory
// ============================================================================

/// `agent` - its isolate - entered for the scope of a call, if it was not the
/// current one: V8 runs microtasks and collections only in the entered
/// isolate.
const EnteredIsolate = struct {
    isolate: *ffi.Isolate,
    entered: bool,

    fn of(agent: *Agent) EnteredIsolate {
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const entered = ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) ffi.v8_Isolate_Enter(isolate);
        return .{ .isolate = isolate, .entered = entered };
    }

    fn leave(self: EnteredIsolate) void {
        if (self.entered) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// A full collection of `agent`'s heap now (engine.requestGarbageCollection's
/// collection), with the agent's isolate entered for it as every other agent
/// operation here enters it: V8 15.7 checks that a collection runs on the
/// thread's current isolate (MainAllocator::identity, "Check failed: isolate_
/// == isolate" in Heap::FreeLinearAllocationAreas), which a worker agent made
/// on a thread whose current isolate is another, or none, is not - 13.1 did
/// not check.
pub fn collectGarbageNow(agent: *Agent) void {
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    ffi.v8_Isolate_RequestGarbageCollection(entered.isolate);
}

/// HTML "perform a microtask checkpoint" for the agent: V8's microtask queue
/// is the isolate's, and each microtask runs in its own context.
pub fn performMicrotaskCheckpoint(agent: *Agent) void {
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(entered.isolate);
    // A safe point after every task (the host's checkpoint after it): V8 is
    // told how the agent's DOM memory moved - not inside a DOM algorithm,
    // whose own binding exit tells it (external_memory.zig).
    const in_algorithm = if (deferredTeardownOf(entered.isolate)) |queue| queue.inAlgorithm() else false;
    if (!in_algorithm) @import("external_memory.zig").reportIfMovedOn(entered.isolate);
}

/// A queued microtask's steps and their data, until the microtask runs.
const QueuedMicrotask = struct {
    steps: engine.RealmSteps,
    data: ?*anyopaque,
};

/// V8 runs a callback microtask as `void (*)(void*)`.
fn runQueuedMicrotask(raw: ?*anyopaque) callconv(.c) void {
    const queued: *QueuedMicrotask = @ptrCast(@alignCast(raw orelse return));
    const steps = queued.steps;
    const data = queued.data;
    std.heap.c_allocator.destroy(queued);
    steps(data);
}

/// HTML "queue a microtask" on the agent: V8's microtask queue is the
/// isolate's. V8 drops a queued callback microtask when its isolate is
/// disposed, so a record still queued then is never freed - the declaration
/// says the steps may not run.
pub fn queueMicrotask(agent: *Agent, steps: engine.RealmSteps, data: ?*anyopaque) Error!void {
    const queued = std.heap.c_allocator.create(QueuedMicrotask) catch return error.OutOfMemory;
    queued.* = .{ .steps = steps, .data = data };
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    ffi.v8_Isolate_EnqueueMicrotask(entered.isolate, @ptrCast(&runQueuedMicrotask), queued);
}

/// notifyMemoryPressure: Isolate::MemoryPressureNotification at both levels,
/// the one signal Blink sends V8 for memory pressure (content/renderer/
/// blink_isolates_pressure_listener.cc OnReleaseMemory ->
/// blink::MemoryPressureNotificationToAllIsolates, Chromium 157.0.8103.51;
/// Blink's MemoryPurgeManager reaches the same call with a critical notice
/// for a renderer left in the background). The agent's isolate is entered on
/// this thread, so V8 answers before the call returns (15.7 src/heap/heap.cc
/// Heap::CheckMemoryPressure):
/// - `.moderate` starts an incremental collection that reduces the footprint;
///   V8's marking job finishes it in foreground tasks, the event loop's
///   engine-task step. Nothing is collected here.
/// - `.critical` drops V8's caches and collects everything now - once, and a
///   second time when the first left much to free
///   (Heap::CollectGarbageOnMemoryPressure) - with the weak callbacks' second
///   pass run inside it (kGCCallbackFlagCollectAllAvailableGarbage), so what
///   the collection found dead is finalized before it returns. Then the
///   reactions those finalizers queued run (a checkpoint), and the trees the
///   collection queued are torn down now - the host wants the memory back -
///   unless a walk holds the agent's teardowns, when they wait for its end or
///   the next turn (engine.deferTeardowns). What the teardown let go of is
///   V8's to collect at its next collection, as what a Blink finalizer lets
///   go of is.
/// It was three LowMemoryNotifications with checkpoints between at
/// `.critical` - at least six full collections for every page that ended -
/// and ContextDisposedNotification at `.moderate`, which starts no collection.
pub fn notifyMemoryPressure(agent: *Agent, level: engine.MemoryPressure) void {
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    switch (level) {
        .critical => {
            ffi.v8_Isolate_MemoryPressureNotification(entered.isolate, .critical);
            ffi.v8_Isolate_PerformMicrotaskCheckpoint(entered.isolate);
            if (!teardownsHeld(entered.isolate)) {
                if (deferredTeardownOf(entered.isolate)) |queue| queue.drainAll();
            }
        },
        .moderate => ffi.v8_Isolate_MemoryPressureNotification(entered.isolate, .moderate),
    }
}

/// Whether a walk holds the agent's teardowns now (engine.deferTeardowns).
fn teardownsHeld(isolate: *ffi.Isolate) bool {
    const holds = teardownHoldsOf(isolate) orelse return false;
    return holds.count != 0;
}

/// Forget `agent`'s hooks, before its isolate is disposed: from here on
/// `recordOf` does not find it (`AgentRecord.ending`). The record itself stays
/// for the agent's realms, which end after this (endAgent), and goes with
/// `removeAgent`.
pub fn forgetAgent(agent: *Agent) void {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const record = blk: {
        std.Io.Threaded.mutexLockUncancelable(&agents_lock);
        defer std.Io.Threaded.mutexUnlock(&agents_lock);
        const record = agents.get(isolate) orelse return;
        if (record.ending) return;
        record.ending = true;
        break :blk record;
    };
    // This isolate's tracker alone: the dispatcher is every agent's.
    if (record.hooks.promiseRejectionTracker != null) ffi.v8_Isolate_ClearProtocolPromiseRejectCallback(isolate);
    if (record.hooks.afterMicrotaskCheckpoint != null) {
        ffi.v8_Isolate_RemoveMicrotasksCompletedCallback(isolate, onMicrotasksCompleted, record);
    }
    // Its Window realms' map: every one has ended, so only its storage is
    // left - which a thread-local map kept after its thread had gone.
    if (record.window_realms.count() != 0) log.err("the agent ended with {d} Window realm(s) still alive; the host must destroy them first", .{record.window_realms.count()});
    record.window_realms.deinit(std.heap.c_allocator);
    // Its teardown holds: every walk ended (a hold is scoped to one), and
    // every entry it deferred was torn down by the last resume or by its
    // realm's end, which ran before.
    if (record.teardown_holds.count != 0) log.err("the agent ended inside {d} teardown hold(s); a walk did not release its engine.holdTeardowns", .{record.teardown_holds.count});
    record.teardown_holds.forgetCaches(&record.caches);
    record.teardown_holds.deinit();
}

/// The end of `isolate`'s agent record, once its realms have ended
/// (context_manager.endAgentRealms): taken out of the agents, and freed.
fn removeAgent(isolate: *ffi.Isolate) void {
    // endAgentRealms freed the lists and left them empty; a realm made in
    // the agent after that - by a teardown step - ends here, not with the
    // record's memory.
    if (realmsOf(isolate)) |realms| if (realms.contexts.count() != 0 or realms.retired.items.len != 0) {
        log.err("a realm was made in the agent while it ended; ending it now", .{});
        context_manager.endAgentRealms(isolate);
    };
    const record = blk: {
        std.Io.Threaded.mutexLockUncancelable(&agents_lock);
        defer std.Io.Threaded.mutexUnlock(&agents_lock);
        const kv = agents.fetchRemove(isolate) orelse return;
        break :blk kv.value;
    };
    std.debug.assert(record.ending);
    callback_registry.endAgent(&record.callbacks);
    protocol_modules.endAgent(&record.modules);
    worker_realm.endAgent(&record.worker_realms);
    @import("wrapper_cache.zig").endAgent(&record.caches);
    std.heap.c_allocator.destroy(record);
}

// ============================================================================
// The hooks' dispatch
// ============================================================================

/// V8's PromiseRejectEvent values HostPromiseRejectionTracker has an
/// operation for; the other two (a resolve or reject of a promise already
/// resolved) are not the spec's.
const kPromiseRejectWithNoHandler = 0;
const kPromiseHandlerAddedAfterReject = 1;

/// ECMAScript HostPromiseRejectionTracker(promise, operation), for the host
/// of the agent whose isolate this is. HTML's steps 1-4 choose the settings
/// object - the running script's, or the current one: V8 hands the callback
/// neither script nor muted-errors flag, so the realm is the current realm
/// (the promise's own when no context is current), and step 2's return for a
/// muted-errors classic script is not taken.
fn onPromiseReject(isolate: *ffi.Isolate, event: c_int, promise: *ffi.Value, reason: ?*ffi.Value) callconv(.c) void {
    var handed_on = false;
    defer if (!handed_on) {
        ffi.v8_Global_Dispose(promise);
        if (reason) |r| ffi.v8_Global_Dispose(r);
    };

    // HTML HostPromiseRejectionTracker steps 1-2: a running script with
    // muted errors suppresses both reject and handle. Nothing is adopted.
    if (ffi.v8_Isolate_CurrentScriptHasMutedErrors(isolate)) return;

    const record = recordOf(isolate) orelse return;
    const tracker = record.hooks.promiseRejectionTracker orelse return;
    const operation: engine.RejectionOperation = switch (event) {
        kPromiseRejectWithNoHandler => .reject,
        kPromiseHandlerAddedAfterReject => .handle,
        else => return,
    };
    const realm: Context = current_realm.currentRealm() orelse support.associatedRealm(promise) orelse return;
    handed_on = true;
    // The rejection's value goes with "reject" (PromiseRejectionEvent's
    // reason); "handle" has none.
    const handed_reason: ?engine.Owned = switch (operation) {
        .reject => if (reason) |r| support.owned(r) else null,
        .handle => blk: {
            if (reason) |r| ffi.v8_Global_Dispose(r);
            break :blk null;
        },
    };
    tracker(record.host, realm, support.owned(promise), operation, handed_reason);
}

// ---- lane: cspenforce ----

/// A realm of `isolate`'s agent, just made as `context`: when the agent's
/// host checks string compilation (HostHooks.ensureCanCompileStrings), the
/// context disallows code generation from strings, which is when V8 asks
/// the ModifyCodeGenerationFromStringsCallback
/// (Compiler::ValidateDynamicCompilationSource) - so every eval and Function
/// call in it reaches the host. Every realm path calls this: a window realm
/// (fresh, restored from the snapshot, a frame's) and a worker realm. The
/// isolate is entered. A realm of an agent with no such hook keeps V8's
/// default and never asks.
pub fn restrictCodeGenerationFromStrings(isolate: *ffi.Isolate, context: *ffi.Context) void {
    const record = recordOf(isolate) orelse return;
    if (record.hooks.ensureCanCompileStrings == null) return;
    ffi.v8_Context_AllowCodeGenerationFromStrings(context, false);
}

/// The prefixes CreateDynamicFunction gives the source it compiles, one per
/// constructor: V8 wraps ECMAScript's sourceString in parentheses
/// (builtins-function.cc: "(" + token + " anonymous(" ... "\n})").
const dynamic_function_prefixes = [_][]const u8{
    "(function anonymous(",
    "(async function anonymous(",
    "(function* anonymous(",
    "(async function* anonymous(",
};

/// What HostEnsureCanCompileStrings is told of a source V8 hands its
/// callback, which names no compilationType: a source of
/// CreateDynamicFunction's shape is a constructor's, its outer parentheses
/// stripped to ECMAScript's sourceString; anything else is eval's. Stated
/// V8 deviation (docs/engine-protocol.md): an eval of a string of exactly
/// that shape is reported as a constructor's.
pub fn stringCompilationOf(source: []const u8, is_code_like: bool) engine.StringCompilation {
    if (std.mem.endsWith(u8, source, "\n})")) {
        for (dynamic_function_prefixes) |prefix| {
            if (std.mem.startsWith(u8, source, prefix)) return .{
                .compilation_type = .function,
                .code_string = source[1 .. source.len - 1],
                .arguments_are_code_like = is_code_like,
            };
        }
    }
    return .{ .compilation_type = .eval, .code_string = source, .arguments_are_code_like = is_code_like };
}

/// V8's ModifyCodeGenerationFromStringsCallback, through
/// v8_wrapper.cpp's dispatcher: HostEnsureCanCompileStrings for a string;
/// for an object, HostGetCodeForEval first - its code, if it has any, is
/// checked as eval's with every argument code-like, and compiled in the
/// object's place. 0 blocked, 1 allowed as given, 2 allowed with `code.*`
/// (malloc'd; the dispatcher frees it). A context with no realm - a scratch
/// context the adapter made - and an agent the host never hooked are
/// allowed.
fn onCodeGenerationFromStrings(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    source: ?[*]const u8,
    source_len: usize,
    object: ?*ffi.Value,
    is_code_like: bool,
    code: *?[*]u8,
    code_len: *usize,
) callconv(.c) c_int {
    const allowed: c_int = 1;
    const record = recordOf(isolate) orelse return allowed;
    const ensure = record.hooks.ensureCanCompileStrings orelse return allowed;
    const realm = context_manager.get(context) orelse return allowed;
    if (source) |bytes| {
        const compilation = stringCompilationOf(bytes[0..source_len], is_code_like);
        return if (ensure(record.host, realm, &compilation) == .allowed) allowed else 0;
    }
    // An object: HostGetCodeForEval(argument). No code: eval returns it.
    const get_code = record.hooks.getCodeForEval orelse return allowed;
    const argument = object orelse return allowed;
    const eval_code = get_code(record.host, realm, .{ .handle = .{ .ptr = argument } }, std.heap.c_allocator) orelse return allowed;
    defer std.heap.c_allocator.free(eval_code);
    // PerformEval: HostEnsureCanCompileStrings with the code, the object as
    // bodyArg - a TrustedScript, so isTrusted.
    const compilation: engine.StringCompilation = .{ .compilation_type = .eval, .code_string = eval_code, .arguments_are_code_like = true };
    if (ensure(record.host, realm, &compilation) != .allowed) return 0;
    // The code goes back as V8's modified source: malloc'd for the
    // dispatcher's free().
    const copy: [*]u8 = @ptrCast(std.c.malloc(eval_code.len + 1) orelse return 0);
    @memcpy(copy[0..eval_code.len], eval_code);
    copy[eval_code.len] = 0;
    code.* = copy;
    code_len.* = eval_code.len;
    return 2;
}

/// V8's AllowWasmCodeGenerationCallback: HostEnsureCanCompileWasmBytes.
fn onWasmCodeGeneration(isolate: *ffi.Isolate, context: *ffi.Context) callconv(.c) bool {
    const record = recordOf(isolate) orelse return true;
    const ensure = record.hooks.ensureCanCompileWasmBytes orelse return true;
    const realm = context_manager.get(context) orelse return true;
    return ensure(record.host, realm);
}

// ---- end lane: cspenforce ----

/// HTML "perform a microtask checkpoint" step 5 - "notify about rejected
/// promises" - after every checkpoint of the agent's queue: V8's automatic
/// ones (kAuto) and explicit ones alike.
fn onMicrotasksCompleted(isolate: *ffi.Isolate, data: ?*anyopaque) callconv(.c) void {
    const record: *AgentRecord = @ptrCast(@alignCast(data orelse return));
    const after = record.hooks.afterMicrotaskCheckpoint orelse return;
    after(record.host, @ptrCast(isolate));
}

// ---- lane: speed ----
/// engine.abortRunningScript: V8's Isolate::TerminateExecution, which any
/// thread may call without the isolate's lock (v8-isolate.h). The script
/// running on the isolate's thread throws V8's uncatchable termination
/// exception at its next interrupt check - a loop's back edge, a function
/// entry - so no `catch` or `finally` runs; every API call it is inside
/// returns empty, which callers treat as an abrupt completion.
pub fn abortRunningScript(agent: *Agent) void {
    ffi.v8_Isolate_TerminateExecution(@ptrCast(@alignCast(agent)));
}

/// engine.resumeScripts: Isolate::CancelTerminateExecution. V8 also ends the
/// termination by itself once it has unwound past the outermost script (a
/// TryCatch at call depth zero clears it); a termination requested while no
/// script ran stays pending until this.
pub fn resumeScripts(agent: *Agent) void {
    ffi.v8_Isolate_CancelTerminateExecution(@ptrCast(@alignCast(agent)));
}
// ---- end lane: speed ----
