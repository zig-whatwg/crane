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
const isolate_templates = @import("isolate_templates.zig");
const template_registry = @import("template_registry.zig");
const context_manager = @import("context_manager.zig");
/// worker_realm.zig's agent operations.
const worker_realm = @import("worker_realm.zig");

const Context = engine.Context;
const Agent = engine.Agent;
const Error = engine.Error;

const log = std.log.scoped(.protocol_agents);

// ============================================================================
// initializeEngine / deinitializeEngine
// ============================================================================

/// V8's bytes of the snapshot initializeEngine was given (its stamp split
/// off), BORROWED until deinitializeEngine. Read by createAgent on any
/// thread, written only while no agent is being made.
var engine_snapshot: ?[]const u8 = null;

/// Prepare V8 for agents: its flags and platform - once per process: V8
/// freezes its flags when the platform starts and cannot start again after
/// it stops - and the snapshot agents may be made from.
pub fn initializeEngine(options: engine.EngineOptions) Error!void {
    // A host that already started the platform set the runtime flags then
    // too.
    if (!ffi.v8_Platform_IsInitialized()) snapshot_loader.initializePlatformForRuntime();
    // Node wrappers' strength follows their tree (dom.mutation's insertion and
    // removing steps), installed once while the process starts.
    @import("wrapper_cache.zig").installTreeHooks();
    // The teardown handlers of the adapter's per-isolate modules, once, while
    // the process starts: agents are made on every Browser and worker thread
    // (docs/instances.md), and the handler table is read-only after this.
    isolate_lifecycle.registerBuiltinHandlers() catch |err| log.warn("the isolate teardown handlers were not registered: {}", .{err});
    // [code_generation_checks]: the process's dispatchers, once, before any
    // agent's thread runs; each agent enables its isolate's callbacks.
    ffi.v8_SetProtocolCodeGenerationDispatchers(onCodeGenerationFromStrings, onWasmCodeGeneration);
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
pub fn deinitializeEngine() void {
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
    /// The agent's ShadowRealms (shadow_realm.zig): made with the agent,
    /// freed by its end. Null when ShadowRealm support was not installed.
    shadow_realms: ?*shadow_realm.ShadowRealmCallbackData = null,
};

var agents_lock: std.Io.Mutex = .init;
/// Every agent made by createAgent and not yet destroyed, by isolate.
var agents: std.AutoHashMapUnmanaged(*ffi.Isolate, *AgentRecord) = .empty;

/// The hooks of the agent whose isolate this is; null for an isolate
/// createAgent did not make (a test's own).
pub fn recordOf(isolate: *ffi.Isolate) ?*AgentRecord {
    std.Io.Threaded.mutexLock(&agents_lock);
    defer std.Io.Threaded.mutexUnlock(&agents_lock);
    return agents.get(isolate);
}

/// engine.agentHost: the host pointer `agent` was made with; null once
/// endAgent has forgotten it, or for an isolate createAgent did not make.
pub fn agentHost(agent: *Agent) ?*anyopaque {
    const record = recordOf(@ptrCast(@alignCast(agent))) orelse return null;
    return record.host;
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

    // [[CanBlock]]: false for a similar-origin window agent, whose one thread
    // Atomics.wait() would freeze - it throws a TypeError instead.
    ffi.v8_Isolate_SetAllowAtomicsWait(isolate, options.can_block);

    const record = std.heap.c_allocator.create(AgentRecord) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(record);
    record.* = .{ .isolate = isolate, .hooks = options.hooks, .host = options.host, .allocator = options.allocator, .host_agent = host_agent };
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
    // its ShadowRealms). destroyAgent undoes them. The teardown handlers of
    // the adapter's per-isolate modules are the process's (initializeEngine);
    // a host that never started the engine gets them here, on its one thread.
    {
        const entered = EnteredIsolate.of(@ptrCast(isolate));
        defer entered.leave();
        if (!isolate_lifecycle.builtinHandlersRegistered()) {
            isolate_lifecycle.registerBuiltinHandlers() catch |err| log.warn("the isolate's teardown handlers were not registered: {}", .{err});
        }
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
    const record = recordOf(isolate);
    const allocator = if (record) |r| r.allocator else std.heap.c_allocator;
    const host_agent = if (record) |r| r.host_agent else false;
    const shadow_realms = if (record) |r| r.shadow_realms else null;
    forgetAgent(agent);
    const entered = EnteredIsolate.of(agent);
    defer entered.leave();
    // This agent's ShadowRealms, whichever kind of agent it is: they were
    // every agent's once, cleared by whichever host agent ended first.
    if (shadow_realms) |data| shadow_realm.deinitializeShadowRealmSupport(data);
    if (host_agent) {
        isolate_lifecycle.cleanupAll(isolate, allocator);
    } else {
        // cleanupAll's isolate-scoped handlers, without the thread's.
        isolate_templates.cleanupTemplateStorage(isolate, allocator);
        template_registry.clearForIsolate(isolate);
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
            // A third pass for what the second's weak callbacks revived.
            ffi.v8_Isolate_RequestGarbageCollection(entered.isolate);
        },
        .moderate => _ = ffi.v8_Isolate_ContextDisposedNotification(entered.isolate, false),
    }
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
    // Not v8_Isolate_ClearPromiseRejectCallback: that one also drops the
    // process-wide callback data every other isolate's tracker uses.
    if (record.hooks.promiseRejectionTracker != null) ffi.v8_Isolate_ClearProtocolPromiseRejectCallback(isolate);
    if (record.hooks.afterMicrotaskCheckpoint != null) {
        ffi.v8_Isolate_RemoveMicrotasksCompletedCallback(isolate, onMicrotasksCompleted, record);
    }
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
