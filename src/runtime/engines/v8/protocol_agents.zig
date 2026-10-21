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
const isolate_templates = @import("isolate_templates.zig");
const context_manager = @import("context_manager.zig");
/// worker_realm.zig's agent operations.
const worker_realm = @import("worker_realm.zig");
const protocol_realms = @import("protocol_realms.zig");
const protocol_webassembly = @import("protocol_webassembly.zig");
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
var engine_snapshot: ?[]const u8 = null;

/// Prepare V8 for agents: its flags and platform - once per process: V8
/// freezes its flags when the platform starts and cannot start again after
/// it stops - and the snapshot agents may be made from.
pub fn initializeEngine(options: engine.EngineOptions) Error!void {
    // A host that already started the platform set the runtime flags then
    // too.
    if (!ffi.v8_Platform_IsInitialized()) snapshot_loader.initializePlatformForRuntime();
    // [code_generation_checks]: the process's dispatchers, once, before any
    // agent's thread runs; each agent enables its isolate's callbacks.
    ffi.v8_SetProtocolCodeGenerationDispatchers(onCodeGenerationFromStrings, onWasmCodeGeneration);
    // HostCreateShadowRealmContextCallback's, the same way.
    shadow_realm.installDispatcher();
    // [webassembly_streaming]: the WasmStreamingCallback's, the same way.
    ffi.v8_SetProtocolWasmStreamingDispatcher(protocol_webassembly.onWasmStreaming);
    // [cross_origin_objects]: the access checks' dispatch, the same way.
    @import("cross_origin.zig").installDispatch();
    engine_snapshot = null;
    if (options.snapshot) |stamped| engine_snapshot = try usableSnapshot(stamped);
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
    engine_snapshot = null;
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
    /// The agent is its thread's host agent: the one whose end takes down
    /// what the adapter keeps per thread as well as per isolate (`endAgent`).
    /// Recorded when the agent is made - made with no isolate entered on the
    /// thread, as a Browser makes its page agent; a worker's is made by its
    /// owner's script, with the owner's isolate entered - and never
    /// re-derived. Which isolate is entered when an agent ENDS depends on who
    /// ends it: a Browser that ends its workers after its page realm has
    /// exited the page isolate has none entered, and a worker's end read as
    /// the host's took the thread's context manager and templates down under
    /// the page.
    host_agent: bool,
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
    /// AgentOptions.deferred_teardown: the host's queue a collected node's
    /// teardown goes to (wrapper_cache.queueCollectedNode), BORROWED; the
    /// agent's end drains and closes it.
    deferred_teardown: ?*runtime.gc.DeferredTeardown = null,
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

var agents_lock: std.Io.Mutex = .init;
/// Every agent made by createAgent and not yet destroyed, by isolate.
var agents: std.AutoHashMapUnmanaged(*ffi.Isolate, *AgentRecord) = .empty;

/// How many agents createAgent restored from the engine's snapshot and that
/// are not yet ended - each reads the snapshot's bytes in place, so the host
/// may free them only when this is 0 (deinitializeEngine checks it).
pub fn liveSnapshotAgents() usize {
    std.Io.Threaded.mutexLock(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    var count: usize = 0;
    var records = agents.valueIterator();
    while (records.next()) |record| {
        if (record.*.from_snapshot) count += 1;
    }
    return count;
}

/// The hooks of the agent whose isolate this is; null for an isolate
/// createAgent did not make (a test's own).
pub fn recordOf(isolate: *ffi.Isolate) ?*AgentRecord {
    std.Io.Threaded.mutexLock(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    return agents.get(isolate);
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

/// The deferred teardown queue the host gave the agent whose isolate this is
/// (AgentOptions.deferred_teardown); null when it gave none, or for an
/// isolate createAgent did not make - whose collected nodes are then torn
/// down in the second pass, as before.
pub fn deferredTeardownOf(isolate: *ffi.Isolate) ?*runtime.gc.DeferredTeardown {
    const record = recordOf(isolate) orelse return null;
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

/// HTML "obtain an agent" (a similar-origin window agent or a worker's): a
/// new isolate - restored from the engine's snapshot when asked for and one
/// was given - with [[CanBlock]] as the options say and the host's hooks
/// installed. The isolate is not entered.
pub fn createAgent(options: engine.AgentOptions) Error!*Agent {
    // Before the new isolate exists: whether another is entered above it.
    const host_agent = ffi.v8_Isolate_GetCurrent() == null;
    const isolate: *ffi.Isolate = blk: {
        if (options.from_snapshot) {
            if (engine_snapshot) |blob| {
                if (ffi.v8_Isolate_NewFromSnapshot(blob.ptr, @intCast(blob.len), external_references.getRuntimeExternalReferencesPtr())) |i| break :blk i;
                log.warn("V8 could not make an isolate from the snapshot; making one without it", .{});
            }
        }
        // The engine is started by initializeEngine; a host that has not
        // called it gets the platform here, as worker_realm's agents do.
        const agent = worker_realm.createAgent() catch |err| return support.protocolError(err);
        break :blk @ptrCast(@alignCast(agent));
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

    const record = std.heap.c_allocator.create(AgentRecord) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(record);
    record.* = .{ .isolate = isolate, .hooks = options.hooks, .host = options.host, .allocator = options.allocator, .host_agent = host_agent, .from_snapshot = ffi.v8_Isolate_IsFromSnapshot(isolate), .deferred_teardown = options.deferred_teardown, .webassembly_compilations = .{ .allocator = options.allocator } };
    {
        std.Io.Threaded.mutexLock(&agents_lock);
        defer std.Io.Threaded.mutexUnlock(&agents_lock);
        agents.put(std.heap.c_allocator, isolate, record) catch return error.OutOfMemory;
    }

    // The hooks the host supplied, and only those: a hook left null is the
    // host's choice to have no such behaviour.
    if (options.hooks.promiseRejectionTracker != null) {
        ffi.v8_Isolate_SetProtocolPromiseRejectCallback(isolate, onPromiseReject);
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
    if (load or meta) {
        ffi.v8_Isolate_SetProtocolModuleHooks(
            isolate,
            if (load) protocol_modules.onDynamicImport else null,
            if (meta) protocol_modules.onImportMetaUrl else null,
            // import.meta.resolve is made beside import.meta.url, so only
            // with it.
            if (meta and resolve) protocol_modules.onImportMetaResolve else null,
        );
    }

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
/// keeps for its isolate is released, and its garbage collected twice with a
/// checkpoint between. The isolate is left not entered, as disposal requires.
///
/// The adapter also keeps state per THREAD (the context manager, ShadowRealm
/// support). The thread's host agent - made with no other isolate entered, as
/// a Browser's page agent is (`AgentRecord.host_agent`) - takes that down too
/// (isolate_lifecycle.cleanupAll). Any other agent - a worker's, a test's
/// second one, one made inside another's script - releases only its own
/// isolate's, whatever is entered when it ends. An isolate createAgent did not
/// make is not the host's: the thread's state outlives it rather than going
/// under whoever still uses it.
pub fn endAgent(agent: *Agent) void {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_CloseForegroundTasks(isolate);
    const record = recordOf(isolate);
    const allocator = if (record) |r| r.allocator else std.heap.c_allocator;
    const host_agent = if (record) |r| r.host_agent else false;
    const shadow_realms = if (record) |r| r.shadow_realms else null;
    const pattern_matcher = if (record) |r| r.pattern_matcher else null;
    const window_properties = if (record) |r| r.window_properties_template else null;
    const deferred_teardown = if (record) |r| r.deferred_teardown else null;
    const intl_objects = if (record) |r| r.intl_objects else null;
    const observable_arrays = if (record) |r| r.observable_arrays else null;
    // The compilations the host never ended: V8's side of each holds a
    // WasmStreaming, which must not outlive the isolate, and its record is
    // the agent's. Ended before the record goes with forgetAgent.
    if (record) |r| r.webassembly_compilations.endAll();
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
    // The deferred teardown queue is empty: every node in it was queued by a
    // realm, and each realm's end drained its own (they end before their
    // agent). Closed from here on - what the collections below find is torn
    // down in the second pass, as before.
    if (deferred_teardown) |queue| {
        std.debug.assert(queue.isEmpty());
        queue.drainAll();
        queue.close();
    }
    // This agent's ShadowRealms, whichever kind of agent it is: they were
    // every agent's once, cleared by whichever host agent ended first.
    if (shadow_realms) |data| shadow_realm.deinitializeShadowRealmSupport(data);
    if (host_agent) {
        isolate_lifecycle.cleanupAll(isolate, allocator);
    } else {
        // cleanupAll's isolate-scoped steps, without the thread's.
        isolate_templates.cleanupTemplateStorage(isolate, allocator);
        isolate_allocator.deinitIsolateAllocator(isolate);
    }
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
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

/// HTML "perform a microtask checkpoint" for the agent: V8's microtask queue
/// is the isolate's, and each microtask runs in its own context.
pub fn performMicrotaskCheckpoint(agent: *Agent) void {
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(entered.isolate);
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

/// notifyMemoryPressure: `.critical` is LowMemoryNotification - a full,
/// synchronous collection - three times with checkpoints between, so that
/// what each pass's weak callbacks let go (and the reactions they queued) is
/// collected by the next; `.moderate` is the hint V8 takes after a
/// context is let go (ContextDisposedNotification, not forced), which moves
/// its next collection up.
pub fn notifyMemoryPressure(agent: *Agent, level: engine.MemoryPressure) void {
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    switch (level) {
        .critical => {
            ffi.v8_Isolate_RequestGarbageCollection(entered.isolate);
            ffi.v8_Isolate_PerformMicrotaskCheckpoint(entered.isolate);
            ffi.v8_Isolate_RequestGarbageCollection(entered.isolate);
            ffi.v8_Isolate_PerformMicrotaskCheckpoint(entered.isolate);
            // The trees the collections queued are torn down now - the host
            // wants the memory back - and what their teardown let go of is
            // collected by the third pass, which also takes what the
            // second's weak callbacks revived - unless a walk holds the
            // agent's teardowns, when they wait for its end or the next turn
            // (engine.deferTeardowns).
            const queue = if (teardownsHeld(entered.isolate)) null else deferredTeardownOf(entered.isolate);
            if (queue) |q| q.drainAll();
            ffi.v8_Isolate_RequestGarbageCollection(entered.isolate);
            if (queue) |q| q.drainAll();
        },
        .moderate => _ = ffi.v8_Isolate_ContextDisposedNotification(entered.isolate, false),
    }
}

/// Whether a walk holds the agent's teardowns now (engine.deferTeardowns).
fn teardownsHeld(isolate: *ffi.Isolate) bool {
    const holds = teardownHoldsOf(isolate) orelse return false;
    return holds.count != 0;
}

/// Forget `agent`'s hooks, before its isolate is disposed.
pub fn forgetAgent(agent: *Agent) void {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const record = blk: {
        std.Io.Threaded.mutexLock(&agents_lock);
        defer std.Io.Threaded.mutexUnlock(&agents_lock);
        const kv = agents.fetchRemove(isolate) orelse return;
        break :blk kv.value;
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
    record.teardown_holds.forgetCaches();
    record.teardown_holds.deinit();
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
