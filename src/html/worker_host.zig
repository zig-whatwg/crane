//! The worker host: the HTML half of "run a worker" for a dedicated worker.
//!
//! Spec: HTML Standard § 10.2.4 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! A worker is an agent and a realm in it whose global object is a
//! DedicatedWorkerGlobalScope. The ENGINE half - making the agent and the
//! realm, binding the global object, running script, the engine's own posted
//! tasks, the realm's end - is the JavaScript engine's, and this file reaches
//! it only through the engine protocol (`@import("engine")`; AGENTS.md, "The
//! engine boundary"; V8's side is src/runtime/engines/v8/worker_realm.zig).
//! What is here is the worker as HTML describes it:
//!
//! - its event loop: the worker's tasks run as timers on the page's loop, and
//!   each ends the worker's way (`endTask`) - a microtask checkpoint, the
//!   engine's posted tasks, and whatever the worker posted leaving for its
//!   owner;
//! - its timers (§ 8.6), messages in both directions (the implicit ports),
//!   errors reported to its global scope and then to its Worker object;
//! - its life: running, closing (close() or "terminate a worker"), the
//!   realm's end, the agent's;
//! - its agent's host hooks: import() in the worker, and import.meta of the
//!   modules it imports, served by its own module map and resolved against
//!   its settings (its script's URL is its API base URL).

const std = @import("std");
/// The user agent's cookie jar (src/cookiestore's, reached through fetch).
const CookieJar = @import("fetch").internal.CookieJar;
const log = std.log.scoped(.worker_host);
const Allocator = std.mem.Allocator;

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");

// A worker's module scripts: its module map, and import()'s graph.
const module_script = @import("module_script.zig");

// Firing an event at a target from outside EventTarget's hierarchy, and the
// MessagePort transfer steps.
const fire_event = @import("dom").fire_event;
const message_ports = @import("dom").message_ports;

// A realm's fetches in flight, released when the realm goes.
const async_fetch = @import("fetch").algorithms.async_fetch;

// Worker types from html_core
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerContext = workers.WorkerContext;

const EngineCallbacks = workers.worker_context.EngineCallbacks;
const WorkerType = workers.WorkerType;
const DedicatedWorker = workers.DedicatedWorker;
const script_fetch = workers.script_fetch;
const EngineMessage = workers.message_channel.EngineMessage;
const QueuedMessage = workers.message_channel.QueuedMessage;

/// Opaque engine context type expected by WorkerContext
const EngineContext = workers.worker_context.EngineContext;

// Thread-local storage for the worker whose script is running (used by the
// built-ins, and by nested workers made from inside one).
threadlocal var current_worker_context: ?*WorkerHost = null;

// Thread-local storage for timer interface (set by caller before worker operations)
threadlocal var current_worker_timer_interface: ?runtime.TimerInterface = null;

/// Set the current worker context (for use by external code before invoking worker callbacks)
pub fn setCurrentWorkerContext(ctx: ?*WorkerHost) void {
    current_worker_context = ctx;
}

/// Get the current worker context (for internal use)
pub fn getCurrentWorkerContext() ?*WorkerHost {
    return current_worker_context;
}

// ============================================================================
// Timers (HTML § 8.6)
// ============================================================================

// The timer nesting level and the § 8.6 clamp are the window's too
// (runtime.timer): a worker's task saves and restores the level around its
// callback, so the page's tasks, which never run inside it, keep theirs.

/// One active timer.
const WorkerTimerContext = struct {
    /// The timer's handler (OWNED), with its callback context.
    callback: engine.CallbackFunction,
    /// The id script holds: HTML's key in the global's map of setTimeout and
    /// setInterval IDs, and `worker_timer_contexts`' key here. It names the
    /// timer for as long as it lives - a repeating timer keeps it across
    /// repeats (timer initialization steps, "previousId") - so clearInterval
    /// finds an interval however often it has fired.
    id: runtime.TimerId,
    /// The timer manager's id for the run currently armed; a repeat arms a
    /// new one. Never seen by script.
    current_timer_id: runtime.TimerId,
    /// Whether this is an interval (repeating) timer
    is_interval: bool,
    /// Interval delay in milliseconds (for rescheduling)
    interval_delay_ms: u64,
    /// The timer nesting level this timer was created at. HTML §8.6 records it so
    /// timers created INSIDE the callback nest one deeper and get clamped.
    nesting_level: u32,
    /// Allocator for cleanup
    allocator: Allocator,
    /// Whether this timer has been cancelled
    cancelled: bool,
    /// True while this timer's callback is on the stack.
    ///
    /// A callback may cancel ITSELF - clearTimeout(id) from inside the timer is
    /// ordinary JS. While this is set the running trampoline owns the context and is
    /// the only thing allowed to free it; freeing underneath it releases the
    /// handler the callback is still using.
    executing: bool = false,
    /// The worker that armed the timer. Its realm is the one the callback
    /// runs in, and it outlives the timer: teardown frees every timer first.
    worker_host: *WorkerHost,
};

/// Thread-local storage for worker timer contexts, keyed by the id script
/// holds (`WorkerTimerContext.id`).
threadlocal var worker_timer_contexts: ?std.AutoHashMap(runtime.TimerId, *WorkerTimerContext) = null;

/// The next id handed to script: greater than zero, and never one a live
/// timer on this thread has (HTML timer initialization step 2). Its own
/// counter, not the timer manager's: an interval's manager id changes on
/// every repeat, and the id script holds must not.
threadlocal var next_worker_timer_id: runtime.TimerId = 1;

/// Initialize worker timer storage
fn initWorkerTimerStorage(allocator: Allocator) void {
    if (worker_timer_contexts == null) {
        worker_timer_contexts = std.AutoHashMap(runtime.TimerId, *WorkerTimerContext).init(allocator);
    }
}

/// Release a timer context and the handler it holds.
fn freeWorkerTimer(ctx: *WorkerTimerContext) void {
    ctx.callback.release();
    ctx.allocator.destroy(ctx);
}

/// Cancel and free every timer `owner` armed: HTML "terminate a worker" step 2
/// and close() step 1 discard the worker's tasks, and a timer is one.
///
/// The map is shared by every worker on this thread. This used to clear all of
/// it whenever ANY worker was torn down, so one worker's end silently dropped
/// every other worker's timers. A timer whose callback is on the stack is only
/// marked: its trampoline owns it until the callback returns, and frees it.
fn cancelWorkerTimers(owner: *WorkerHost) void {
    const map = if (worker_timer_contexts) |*m| m else return;
    var ids: std.ArrayListUnmanaged(runtime.TimerId) = .empty;
    defer ids.deinit(owner.allocator);
    var iter = map.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.*.worker_host == owner) ids.append(owner.allocator, entry.key_ptr.*) catch {};
    }
    for (ids.items) |id| {
        const ctx = map.get(id) orelse continue;
        ctx.cancelled = true;
        if (ctx.executing) continue;
        // Not armed any more, or armed and now cancelled: either way the
        // timer manager will not hand it back, so it is ours to free.
        if (WorkerHost.getTimerInterface()) |timer| _ = timer.clearTimeout(ctx.current_timer_id);
        _ = map.remove(id);
        freeWorkerTimer(ctx);
    }
}

/// Register a timer context for tracking, under the id script holds.
fn registerWorkerTimerContext(ctx: *WorkerTimerContext) void {
    if (worker_timer_contexts) |*map| {
        map.put(ctx.id, ctx) catch {};
    }
}

/// clearTimeout() / clearInterval(): cancel the timer and free it, unless its
/// callback is on the stack - the running trampoline then frees it on return.
///
/// This used to fetchRemove, dispose the handler and destroy the ctx
/// unconditionally. If the timer was still armed it then fired into
/// workerTimerTrampoline, which read ctx.cancelled from freed memory. clearTimeout
/// removes an armed timer from the manager, and a fired one-shot is already out
/// of the map, so a context found here and not executing is never handed back.
fn unregisterWorkerTimerContext(id: runtime.TimerId) void {
    const map = if (worker_timer_contexts) |*m| m else return;
    const ctx = map.get(id) orelse return;
    ctx.cancelled = true;
    if (ctx.executing) return;
    if (WorkerHost.getTimerInterface()) |timer| _ = timer.clearTimeout(ctx.current_timer_id);
    _ = map.remove(id);
    freeWorkerTimer(ctx);
}

// ============================================================================
// Worker Error Handling Support
// ============================================================================

/// Callback to dispatch worker error events to the parent context.
/// This is scheduled after an error occurs in the worker and self.onerror
/// didn't handle it.
fn workerErrorDispatchCallback(context_ptr: ?*anyopaque) void {
    const error_ctx: *WorkerErrorDispatchContext = @ptrCast(@alignCast(context_ptr orelse return));
    defer error_ctx.allocator.destroy(error_ctx);

    // Fire the error event to the parent Worker object
    error_ctx.dedicated_worker.fireErrorToParent(error_ctx.error_event);
}

/// Context for scheduling error dispatch to parent
const WorkerErrorDispatchContext = struct {
    dedicated_worker: *DedicatedWorker,
    error_event: *workers.worker_error.WorkerErrorEvent,
    allocator: Allocator,
};

/// Arm a 0ms timer that dispatches the worker's queued messages on the owner's
/// event loop, unless one is already armed - the callback drains the whole
/// queue, so one is enough.
///
/// The timer carries the WorkerHost, which records it so that `deinit`
/// can disarm it. It used to carry a bare `*DedicatedWorker` that nothing
/// cancelled: a Worker collected, or torn down with its page, while the timer
/// was armed left it to fire into freed memory - SIGSEGV at 0xAAAA...AAAA in
/// `processQueuedMessages`, in whichever test the same process ran next.
/// One crash per sharded `html/webappapis/timers/` run, in a file with no
/// worker in it.
fn scheduleMessageDispatch(wctx: *WorkerHost) void {
    if (wctx.message_dispatch != null) return;
    const dedicated_worker = wctx.dedicated_worker orelse return;
    if (dedicated_worker.port_pair.outside_port.message_queue.items.len == 0) return;
    const timer = WorkerHost.getTimerInterface() orelse return;
    const id = timer.setTimeout(0, workerMessageDispatchCallback, wctx);
    if (id == 0) return;
    wctx.message_dispatch = .{ .timer = timer, .id = id };
}

/// Every worker whose realm is still there, for `finishTaskIn` and
/// `scopeSettings`.
threadlocal var live_contexts: std.ArrayListUnmanaged(*WorkerHost) = .empty;

fn removeLive(wctx: *WorkerHost) void {
    for (live_contexts.items, 0..) |live, i| {
        if (live == wctx) {
            _ = live_contexts.swapRemove(i);
            return;
        }
    }
}

/// The end of a task that ran script in `agent` from outside the worker's
/// own timers, if `agent` is a worker's: what a timer task does after its
/// callback. The microtask checkpoint runs, and whatever the worker posted
/// leaves it for the page. Without this the worker's messages sat in its
/// queue, and a test that reports its results by message timed out. Call it
/// with `agent` entered.
///
/// Callers that still name the agent (XMLHttpRequest, Response and
/// WindowOrWorkerGlobalScope pass their V8 isolate, which is what the V8
/// adapter's agent is) are moving to the Engine table's `runTaskInRealm`,
/// which ends a task through the realm's `end_of_task` instead.
pub fn finishTaskIn(agent: *anyopaque) void {
    const wctx = for (live_contexts.items) |live| {
        if (@intFromPtr(live.agent) == @intFromPtr(agent)) break live;
    } else return;
    const prev_context = current_worker_context;
    current_worker_context = wctx;
    defer current_worker_context = prev_context;
    wctx.endTask();
}

/// What a worker's global scope takes from the worker that runs it: "run a
/// worker" steps 7-9 set the global scope's type, URL and name before its
/// script runs. The slices are the worker's, valid while its realm is.
pub const ScopeSettings = struct {
    url: []const u8,
    worker_type: WorkerType,
    name: []const u8,
    /// The user agent's cookie jar: the creating global's, which the
    /// worker's settings object hands out in turn.
    cookie_jar: ?*CookieJar = null,
};

/// The settings for a global scope created in the realm whose runtime
/// context is `ctx`, if that is a worker this host runs.
pub fn scopeSettings(ctx: runtime.Context) ?ScopeSettings {
    const wctx = forScope(ctx) orelse return null;
    return .{
        .url = wctx.script_url,
        .worker_type = wctx.worker_type,
        .name = if (wctx.dedicated_worker) |dw| dw.getName() else "",
        .cookie_jar = wctx.cookie_jar,
    };
}

/// The hooks a worker's realm carries for its host (runtime.ContextData):
/// the end of a task, and "report an exception" for what nothing else
/// reports. Installed as the realm is made, before any script runs in it.
pub fn installRealmHooks(realm: *runtime.ContextData) void {
    realm.end_of_task = endTaskOfRealm;
    realm.report_exception = reportExceptionOfRealm;
}

/// The worker's "report an exception", as its realm's `report_exception`:
/// what an event listener threw in the worker, say - an ErrorEvent at the
/// global scope, then at the Worker with `error` null. A realm no worker
/// runs any more reports nothing.
pub fn reportExceptionOfRealm(realm: *runtime.ContextData, info: *const runtime.ErrorInfo) void {
    const wctx = forScope(realm) orelse return;
    const prev_context = current_worker_context;
    current_worker_context = wctx;
    defer current_worker_context = prev_context;
    WorkerHost.reportException(wctx, info);
}

/// The worker's end of a task, as its realm's `end_of_task`: what
/// `finishTaskIn` does, found by the realm instead of the agent.
pub fn endTaskOfRealm(ctx: runtime.Context) void {
    const wctx = forScope(ctx) orelse return;
    const prev_context = current_worker_context;
    current_worker_context = wctx;
    defer current_worker_context = prev_context;
    wctx.endTask();
}

/// DedicatedWorkerGlobalScope close() for the global scope whose realm's
/// runtime context is `ctx`.
pub fn closeScope(ctx: runtime.Context) void {
    const wctx = forScope(ctx) orelse return;
    wctx.closeFromScript();
}

/// DedicatedWorkerGlobalScope postMessage(message, transfer) for the global
/// scope whose realm is `ctx`: the message port post message steps for the
/// worker's implicit port, whose entangled port is its Worker object's. The
/// message is serialized in the worker's realm now and leaves for the page
/// when the task ends (`endTask`).
pub fn postMessageFromScope(ctx: runtime.Context, message: runtime.JSValue, transfer: []const runtime.JSValue) anyerror!void {
    const wctx = forScope(ctx) orelse return;
    try wctx.postMessageToOwner(message, transfer);
}

/// WorkerGlobalScope importScripts(): run the fetched `source` of `url` in
/// the worker whose realm is `ctx`, as the worker's scripts run.
pub fn runImportedScript(ctx: runtime.Context, source: []const u8, url: []const u8) anyerror!void {
    const wctx = forScope(ctx) orelse return error.InvalidStateError;
    if (!wctx.runsTasks()) return;
    // importScripts() is called from script: the execution context stack is
    // not empty, so "clean up after running script" performs no microtask
    // checkpoint.
    try wctx.runScript(source, url, false);
}

fn forScope(ctx: runtime.Context) ?*WorkerHost {
    for (live_contexts.items) |live| {
        if (live.realm == ctx) return live;
    }
    return null;
}

/// Worker agents disposed on this thread so far. A worker that ends and
/// never gets here keeps its whole heap for the life of the process.
threadlocal var disposed_isolates: usize = 0;

pub fn disposedIsolateCount() usize {
    return disposed_isolates;
}

/// Workers on this thread whose realm has not been torn down.
pub fn liveWorkerCount() usize {
    return live_contexts.items.len;
}

/// Callback to dispatch worker messages in the main thread context.
/// This is scheduled after worker timer callbacks flush messages to ensure
/// messages are processed in a clean state.
fn workerMessageDispatchCallback(context_ptr: ?*anyopaque) void {
    const wctx: *WorkerHost = @ptrCast(@alignCast(context_ptr orelse return));
    // Fired: nothing left to cancel, and a message queued from here on arms a
    // fresh timer.
    wctx.message_dispatch = null;
    const dedicated_worker = wctx.dedicated_worker orelse return;

    // Process queued messages - this fires `message` at the Worker object.
    dedicated_worker.processQueuedMessages();
}

/// Timer callback trampoline - invoked by the timer manager
fn workerTimerTrampoline(context_ptr: ?*anyopaque) void {
    const ctx: *WorkerTimerContext = @ptrCast(@alignCast(context_ptr orelse return));
    const wctx = ctx.worker_host;

    // Cancelled while armed, or its worker has closed: a discarded task (HTML
    // close() step 1, "terminate a worker" step 2). Free it - this is the last
    // time the timer system will reference this context.
    if (ctx.cancelled or !wctx.runsTasks()) {
        if (worker_timer_contexts) |*map| _ = map.remove(ctx.id);
        freeWorkerTimer(ctx);
        return;
    }

    // This trampoline owns the context for the duration of the callback, so a
    // clearTimeout from inside it defers the free to us rather than pulling the
    // handler out from under the running callback.
    ctx.executing = true;
    runWorkerTimerCallback(ctx);
    ctx.executing = false;

    // For intervals, reschedule the timer
    if (ctx.is_interval and !ctx.cancelled and wctx.runsTasks()) {
        if (WorkerHost.getTimerInterface()) |timer| {
            // HTML §8.6: each repeat nests one deeper, and the clamp is re-applied.
            // Without this a `setInterval(f, 0)` stays at 0ms forever and spins the
            // loop as fast as it can reschedule - the spec's answer is that by the
            // sixth repeat it is clamped to 4ms, exactly like nested setTimeout.
            ctx.nesting_level +|= 1;
            const repeat_ms = runtime.timer.clampTimeout(
                @intCast(@min(ctx.interval_delay_ms, @as(u64, std.math.maxInt(i32)))),
                ctx.nesting_level,
            );
            ctx.interval_delay_ms = if (repeat_ms >= 0) @intCast(repeat_ms) else 0;

            // Schedule the next interval
            const new_timer_id = timer.setTimeout(ctx.interval_delay_ms, workerTimerTrampoline, ctx);
            if (new_timer_id != 0) {
                // The same timer, armed again: script's id, and the map entry
                // under it, stay (HTML timer initialization, "previousId").
                ctx.current_timer_id = new_timer_id;
                return;
            }
            // Reschedule failed: it is not armed now, so untrack and free it.
            if (worker_timer_contexts) |*map| _ = map.remove(ctx.id);
            freeWorkerTimer(ctx);
            return;
        }
    }

    // A one-shot that has run, or a repeat that was cancelled: the timer
    // manager has already dropped it, so nothing will hand it back.
    if (worker_timer_contexts) |*map| _ = map.remove(ctx.id);
    freeWorkerTimer(ctx);
}

/// The timer task's steps: run the callback in the worker's realm, then the
/// end of the task - a microtask checkpoint, the engine's posted tasks, and
/// the messages the callback posted leaving for the page.
fn runWorkerTimerCallback(ctx: *WorkerTimerContext) void {
    const wctx = ctx.worker_host;

    // HTML §8.6: while this callback runs, the nesting level IS this timer's level,
    // so a setTimeout called from inside it nests one deeper. Restored afterwards
    // because the same thread goes on to run other tasks.
    const saved_nesting = runtime.timer.nesting_level;
    runtime.timer.nesting_level = ctx.nesting_level;
    defer runtime.timer.nesting_level = saved_nesting;

    // The built-ins (postMessage, the timers) find their worker here.
    const prev_context = current_worker_context;
    current_worker_context = wctx;
    defer current_worker_context = prev_context;

    // A task of the worker's realm: its agent entered from the page's loop,
    // and ended the worker's way (`endTaskOfRealm`).
    wctx.runTask(TimerCall.steps, ctx);
}

const TimerCall = struct {
    /// Timer initialization step 7.1: "invoke handler given arguments and
    /// "report", and with callback this value set to thisArg" - the global.
    fn steps(data: ?*anyopaque) void {
        const ctx: *WorkerTimerContext = @ptrCast(@alignCast(data orelse return));
        const wctx = ctx.worker_host;
        const realm = wctx.realm orelse return;
        const completion = engine.invokeCallbackFunction(realm, &ctx.callback, .global_this, &.{}, .{
            .report = wctx.reporter(),
        }) catch return;
        switch (completion) {
            inline else => |value| value.release(),
        }
    }
};

/// One armed timer on the owner's loop: the manager it was armed on, and its id.
const MessageDispatchTimer = struct {
    timer: runtime.TimerInterface,
    id: runtime.TimerId,
};

/// Where a worker is in its life, as its host sees it.
///
/// HTML "run a worker" runs the worker's event loop until its global scope's
/// closing flag is set; then the realm goes, and with it the agent. Here the
/// "event loop" is the worker's timers on the page's loop, so the host tracks
/// the steps itself.
const Phase = enum {
    /// Running tasks.
    running,
    /// close() or "terminate a worker" set the closing flag: no further task
    /// runs. The realm is still there, and teardown is armed.
    closing,
    /// The realm is gone: the engine released it. The agent goes one timer
    /// later (`disposeAgentLater`).
    realm_gone,
    /// The agent is disposed.
    disposed,
};

/// The worker a Worker object runs: its agent and realm (through the engine
/// protocol), its event loop's tasks, its life.
pub const WorkerHost = struct {
    /// The worker's agent - its own, separate from its owner's - made with
    /// this host's hooks (`worker_hooks`).
    agent: *runtime.Agent,

    /// The worker's realm: its runtime context, which every Instance created
    /// in it points at - the global scope first. Null until the global scope
    /// is set up (`setupWorkerGlobalScope`) and again once the realm is gone.
    realm: ?runtime.Context = null,

    /// The realm's global object's platform object: its
    /// DedicatedWorkerGlobalScope. The realm owns it, and frees it when the
    /// realm goes.
    global_scope: ?*runtime.Instance = null,

    /// The worker's script URL, absolute: the URL its global scope reports
    /// as its own ("run a worker" step 9 - HTML takes the response's URL) and
    /// the one importScripts() resolves against. Owned.
    script_url: []const u8,
    /// The user agent's cookie jar, from the global that created this
    /// worker (BORROWED: the Browser outlives its workers). The worker's
    /// global scope takes it through `scopeSettings`.
    cookie_jar: ?*CookieJar = null,

    /// Worker type (classic or module)
    worker_type: WorkerType,

    /// Allocator
    allocator: Allocator,

    /// Reference to the DedicatedWorker (set during setupWorkerGlobalScope).
    /// Cleared when the owner lets go (`deinit`): it is freed right after.
    dedicated_worker: ?*DedicatedWorker = null,

    /// The owner-side timer armed by `scheduleMessageDispatch`, while it is
    /// armed. `deinit` cancels it: it reaches `dedicated_worker`, which is freed
    /// right after this context is deinitialized.
    message_dispatch: ?MessageDispatchTimer = null,

    /// Set by the owner's first `deinit` (Worker.deinit, or the agent's
    /// WorkerContext through disposeContextCallback); the second does nothing.
    is_deinitialized: bool = false,

    /// How deep this host has run script in the worker on the current stack.
    /// While it is above zero the worker's script may be running, and the
    /// realm must not be torn down under it.
    entered: u32 = 0,

    phase: Phase = .running,

    /// "In error reporting mode" for the global scope (HTML "report an
    /// exception"): an error reported while one is being reported goes no
    /// further.
    reporting_error: bool = false,

    /// The timer that runs the next teardown step, while one is armed.
    teardown_timer: ?MessageDispatchTimer = null,

    /// The timer that pumps the engine's posted tasks while nothing else
    /// would (`armPlatformPump`), while one is armed.
    platform_pump: ?MessageDispatchTimer = null,

    /// The timer that asks again whether the Worker object's pending activity
    /// has ended (`releaseOwnerWhenIdle`), while one is armed.
    release_owner_timer: ?MessageDispatchTimer = null,

    /// The owner has let go (`destroy`). The memory goes once this is set and
    /// the agent is disposed, whichever comes last.
    owner_released: bool = false,

    /// The built-in functions this host defines on the global object. The
    /// engine reads them on every call, so they live as long as this does.
    builtins: [5]runtime.BuiltinFunction = undefined,

    /// The worker's module map (HTML "module map" of its settings object):
    /// keys owned, values a `*module_script.ModuleScript` or
    /// `module_script.fetch_failed`, disposed with the realm.
    modules: std.StringHashMapUnmanaged(*anyopaque) = .empty,

    /// The classic scripts run in the realm - the worker's own and each
    /// importScripts() one - as the [[HostDefined]] an import() in them
    /// names: their base URLs. They live as long as the realm, since a
    /// function one defined can call import() at any time.
    classic_scripts: std.ArrayListUnmanaged(*module_script.ClassicScript) = .empty,

    /// import()s whose fetch task is queued and has not run: each holds an
    /// engine request that must be finished while the agent lives.
    pending_imports: std.ArrayListUnmanaged(*DynamicImportTask) = .empty,

    const Self = @This();

    /// Set the timer interface for worker operations.
    /// This should be called by the browser/runtime before creating or using workers.
    /// The timer interface is stored in thread-local storage and shared across all workers.
    pub fn setTimerInterface(timer: runtime.TimerInterface) void {
        current_worker_timer_interface = timer;
    }

    /// Get the current timer interface from thread-local storage.
    ///
    /// This is used for nested workers: when a Worker is created from within another
    /// Worker, the nested Worker's constructor can use the parent worker's timer
    /// (stored in thread-local storage) to schedule deferred initialization.
    pub fn getTimerInterface() ?runtime.TimerInterface {
        return current_worker_timer_interface;
    }

    /// A worker for `script_url`: "run a worker" step 4, obtain a dedicated
    /// worker agent - [[CanBlock]] true - with this host's hooks
    /// (`worker_hooks`). The realm follows when the global scope is set up.
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // The hooks are called with this host, so it exists first.
        const agent = try engine.createAgent(.{
            .can_block = true,
            .from_snapshot = false,
            .hooks = &worker_hooks,
            .host = self,
        });
        self.* = .{
            .agent = agent,
            .script_url = url_copy,
            .worker_type = worker_type,
            .allocator = allocator,
        };
        live_contexts.append(std.heap.page_allocator, self) catch {};
        return self;
    }

    /// This host's "report an exception", as the engine protocol takes it.
    fn reporter(self: *Self) engine.Reporter {
        return .{ .report = reportEngineException, .host = self };
    }

    const moduleEnvironment = WorkerModules.moduleEnvironment;
    const disposeModules = WorkerModules.disposeModules;
    const queueDynamicImport = WorkerModules.queueDynamicImport;
    const forgetImport = WorkerModules.forgetImport;
    const freeImport = WorkerModules.freeImport;
    const finishPendingImports = WorkerModules.finishPendingImports;

    /// Whether the worker runs tasks: not once its closing flag is set.
    pub fn runsTasks(self: *const Self) bool {
        return self.phase == .running;
    }

    /// Run `steps` as a task of the worker's realm - its agent entered, and
    /// the task ended the worker's way (`endTaskOfRealm`) - counting the
    /// entry.
    fn runTask(self: *Self, steps: runtime.RealmSteps, data: ?*anyopaque) void {
        const realm = self.realm orelse return;
        self.entered += 1;
        defer self.entered -= 1;
        engine.runTaskInRealm(realm, steps, data) catch {};
    }

    /// The end of a task that ran script in this worker: a microtask
    /// checkpoint, the tasks the engine has posted for its agent, and whatever
    /// the worker posted leaving for the page. Call with the agent entered.
    fn endTask(self: *Self) void {
        if (self.realm != null) engine.performMicrotaskCheckpoint(self.agent) catch {};
        _ = engine.runEngineTasks(self.agent);
        DedicatedWorker.flushPendingMessages();
        scheduleMessageDispatch(self);
        self.armPlatformPump(false);
    }

    /// How often an otherwise idle worker pumps while the engine has
    /// background work for it.
    const platform_pump_interval_ms = 1;

    /// Keep the engine's posted tasks running while nothing else would.
    ///
    /// A worker's tasks run as timers on the page's loop, and each ends by
    /// pumping its agent (`endTask`). But V8 posts some tasks from a
    /// background thread when its work there is done - an asynchronous
    /// WebAssembly compile settles its promise that way - and a worker with no
    /// timer due and no message arriving never pumped again, so the promise
    /// never settled. While the engine reports background work for the agent,
    /// a pump stays armed: d8 keeps its message loop waiting on the same test
    /// (Shell::CompleteMessageLoop). `again` re-arms regardless - a pump that
    /// ran a task may have more to run.
    fn armPlatformPump(self: *Self, again: bool) void {
        if (self.platform_pump != null or !self.runsTasks()) return;
        if (!again and !engine.hasPendingEngineWork(self.agent)) return;
        const timer = getTimerInterface() orelse return;
        const id = timer.setTimeout(platform_pump_interval_ms, platformPumpCallback, self);
        if (id == 0) return;
        self.platform_pump = .{ .timer = timer, .id = id };
    }

    /// The pump: a task that runs what the engine has posted, then ends as
    /// every worker task does.
    fn platformPumpCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.platform_pump = null;
        if (!self.runsTasks()) return;

        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;

        var pumped = Pump{ .host = self };
        self.runTask(Pump.steps, &pumped);
        if (pumped.pending or pumped.ran) self.armPlatformPump(true);
    }

    const Pump = struct {
        host: *Self,
        pending: bool = false,
        ran: bool = false,

        fn steps(data: ?*anyopaque) void {
            const pump: *Pump = @ptrCast(@alignCast(data orelse return));
            // Read before pumping: background work that ends between the two
            // posts its task after the pump looked, and a pending answer taken
            // first means one more round to find it.
            pump.pending = engine.hasPendingEngineWork(pump.host.agent);
            pump.ran = engine.runEngineTasks(pump.host.agent);
        }
    };

    /// Stop one armed timer of ours, if any.
    fn disarm(slot: *?MessageDispatchTimer) void {
        if (slot.*) |armed| _ = armed.timer.clearTimeout(armed.id);
        slot.* = null;
    }

    // ------------------------------------------------------------------
    // The end of a worker
    // ------------------------------------------------------------------

    /// HTML "terminate a worker", from the owner's side (worker.terminate()):
    /// 1. set the closing flag, 2. discard the worker's tasks, 3. abort its
    /// script, 4. empty the port message queue of the port its implicit port
    /// is entangled with - the page's side, so nothing the worker posted is
    /// delivered from now on. The realm and the agent then go, from later
    /// tasks (`scheduleTeardown`). Step 3 has nothing to abort: the owner's
    /// script runs on this thread, so the worker's cannot be running.
    pub fn terminate(self: *Self) void {
        if (self.phase == .realm_gone or self.phase == .disposed) return;
        self.phase = .closing;
        cancelWorkerTimers(self);
        disarm(&self.platform_pump);
        disarm(&self.message_dispatch);
        if (self.dedicated_worker) |dw| {
            emptyPortQueue(dw.port_pair.outside_port);
            emptyPortQueue(dw.port_pair.inside_port);
        }
        self.scheduleTeardown();
    }

    /// DedicatedWorkerGlobalScope close(), from the worker's own script:
    /// 1. discard the tasks queued for the worker's agent, 2. set the closing
    /// flag. The task that called it runs to its end, and what it posts is
    /// delivered (workers/interfaces/WorkerGlobalScope/close/sending-messages);
    /// then the realm goes.
    fn closeFromScript(self: *Self) void {
        if (self.phase != .running) return;
        // What the task posted so far joins the port's queue; its end posts
        // the rest.
        DedicatedWorker.flushPendingMessages();
        if (self.dedicated_worker) |dw| dw.close();
        self.phase = .closing;
        cancelWorkerTimers(self);
        disarm(&self.platform_pump);
        self.scheduleTeardown();
    }

    /// Arm the next teardown step. Every step runs from a timer on the page's
    /// loop, never from the call that ended the worker: that call may be the
    /// worker's own script (close()), a Worker collected inside a page GC's
    /// weak callbacks, or the page's own teardown. With no loop to run it on,
    /// the realm and agent stay until the process ends, as they always did.
    fn scheduleTeardown(self: *Self) void {
        if (self.teardown_timer != null or self.phase == .realm_gone or self.phase == .disposed) return;
        const timer = getTimerInterface() orelse return;
        const id = timer.setTimeout(0, teardownCallback, self);
        if (id == 0) return;
        self.teardown_timer = .{ .timer = timer, .id = id };
    }

    fn teardownCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.teardown_timer = null;
        // The worker's script is on the stack - a nested loop inside one of
        // its tasks: after that task, then.
        const script_running = engine.hasRunningScript(self.agent);
        log.debug("teardown step: entered={d} script_running={}", .{ self.entered, script_running });
        if (self.entered > 0 or script_running) {
            self.scheduleTeardown();
            return;
        }
        self.teardownRealm();
        self.disposeAgentLater();
    }

    /// The realm's end: what "run a worker" does once the event loop exits -
    /// clear the active timers, disentangle the ports - and the engine's end
    /// of the realm (`destroyWorkerRealm`). Nothing runs in the realm again.
    fn teardownRealm(self: *Self) void {
        self.phase = .realm_gone;
        removeLive(self);
        cancelWorkerTimers(self);
        disarm(&self.platform_pump);

        const realm = self.realm orelse return;
        // The import()s still waiting for their fetch task are discarded with
        // the worker's other tasks: their requests are finished now, while
        // the realm and its agent are there to finish them in.
        self.finishPendingImports();
        // The module map goes with the settings object: its records are
        // engine handles of this agent.
        self.disposeModules();
        self.realm = null;
        // The realm's per-context data - the callbacks its script registered,
        // its wrapper cache and every Instance in it, the global scope first -
        // goes with it; the realm is retired, so anything holding it across
        // turns (a fetch) reads it as gone.
        self.global_scope = null;
        engine.destroyWorkerRealm(realm, sweepFetches, null);
        // Nothing can call import() in the realm any more.
        self.freeClassicScripts();
        self.releaseOwnerWhenIdle();
    }

    /// The worker has ended, so its Worker object has no pending activity
    /// left once nothing the worker posted remains to be delivered - Blink's
    /// DedicatedWorker::HasPendingActivity() turning false. Then the engine's
    /// `releasePlatformObject` undoes the Worker's `keepPlatformObjectAlive`,
    /// and a Worker script no longer references is
    /// collected like any other object. Always from a timer turn on the
    /// owner's loop, never from inside a dispatch: a handler that drops the
    /// last reference must not have its Worker collected while the port is
    /// still being walked.
    fn releaseOwnerWhenIdle(self: *Self) void {
        const dedicated_worker = self.dedicated_worker orelse return;
        if (dedicated_worker.port_pair.outside_port.message_queue.items.len > 0) {
            log.debug("owner release deferred: {d} messages to deliver", .{dedicated_worker.port_pair.outside_port.message_queue.items.len});
            // Delivered by later turns: ask again after them.
            if (self.release_owner_timer != null) return;
            const timer = getTimerInterface() orelse return;
            const id = timer.setTimeout(0, ownerReleaseCallback, self);
            if (id != 0) self.release_owner_timer = .{ .timer = timer, .id = id };
            return;
        }
        const owner: *runtime.Instance = @ptrCast(@alignCast(dedicated_worker.getUserData() orelse return));
        log.debug("owner released: {*}", .{owner});
        engine.releasePlatformObject(owner);
    }

    fn ownerReleaseCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.release_owner_timer = null;
        self.releaseOwnerWhenIdle();
    }

    /// Fetches still in flight for the realm release their promises, while the
    /// agent those belong to is alive.
    fn sweepFetches(_: ?*anyopaque) void {
        _ = async_fetch.sweep();
    }

    /// Dispose the agent one timer after the realm is gone.
    ///
    /// A fetch whose response arrived before the realm ended has its settle
    /// task armed as a 0 ms timer on the page's loop
    /// (WindowOrWorkerGlobalScope.call_fetch). It has left the fetch list, so
    /// `async_fetch.sweep()` cannot reach it, and when it runs it finds the
    /// realm gone and releases its promise resolver - a handle of THIS agent.
    /// Every such timer was armed before this one, so it runs first.
    fn disposeAgentLater(self: *Self) void {
        const timer = getTimerInterface() orelse return;
        const id = timer.setTimeout(0, disposeAgentCallback, self);
        if (id == 0) return;
        self.teardown_timer = .{ .timer = timer, .id = id };
    }

    fn disposeAgentCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.teardown_timer = null;
        engine.destroyAgent(self.agent);
        self.phase = .disposed;
        disposed_isolates += 1;
        if (self.owner_released) self.free();
    }

    /// The owner is done with the worker: the Worker object is going away, or
    /// the agent's WorkerContext is (both reach here; the second call does
    /// nothing). The DedicatedWorker this points at is freed right after, so
    /// nothing may reach it again. A worker still running is terminated.
    pub fn deinit(self: *Self) void {
        if (self.is_deinitialized) return;
        self.is_deinitialized = true;

        // Disarm the pending message dispatch before the DedicatedWorker it
        // reaches is freed. The callback clears this record the moment it
        // fires, so a record still here is a timer that has not fired, and
        // clearTimeout removes it from the manager - `poll` re-checks each due
        // id before firing, so it cannot still run.
        disarm(&self.message_dispatch);
        disarm(&self.release_owner_timer);
        self.dedicated_worker = null;

        if (self.phase == .running or self.phase == .closing) {
            self.phase = .closing;
            cancelWorkerTimers(self);
            disarm(&self.platform_pump);
            self.scheduleTeardown();
        }
    }

    /// The owner lets go of this object. Its memory goes once the owner has
    /// let go and the agent is disposed, whichever comes last; a worker with
    /// no teardown ahead of it (no loop to run one on) goes now, leaving its
    /// realm and agent to the process, as they always were.
    pub fn destroy(self: *Self) void {
        self.owner_released = true;
        if (self.phase == .disposed or self.teardown_timer == null) self.free();
    }

    fn free(self: *Self) void {
        removeLive(self);
        disarm(&self.teardown_timer);
        disarm(&self.platform_pump);
        disarm(&self.message_dispatch);
        disarm(&self.release_owner_timer);
        // A worker with no teardown ahead of it (no loop to run one on) still
        // has its realm and agent: what they hold of this host goes now.
        self.finishPendingImports();
        self.pending_imports.deinit(self.allocator);
        self.disposeModules();
        self.freeClassicScripts();
        self.allocator.free(self.script_url);
        self.allocator.destroy(self);
    }

    // ------------------------------------------------------------------
    // The global scope
    // ------------------------------------------------------------------

    /// "Run a worker" steps 5-9: the realm - a new realm in the worker's agent
    /// whose global object is a new DedicatedWorkerGlobalScope, with its
    /// settings (URL, type, name) recorded before the global scope is made -
    /// and what this host puts on its global: the timers, and the harness's
    /// hooks.
    ///
    /// The global object's members come from the generated bindings: the
    /// DedicatedWorkerGlobalScope Instance behind it, and the interfaces on
    /// its prototype chain - WorkerGlobalScope's, which include every
    /// WindowOrWorkerGlobalScope member, and EventTarget's. postMessage and
    /// importScripts are the bound operations (DedicatedWorkerGlobalScope,
    /// WorkerGlobalScope), which reach this host. Built-ins remain for the
    /// timers, whose bound operations (WindowOrWorkerGlobalScope) return
    /// NotImplemented.
    pub fn setupWorkerGlobalScope(self: *Self, dedicated_worker: *DedicatedWorker) !void {
        self.dedicated_worker = dedicated_worker;

        const made = try engine.createWorkerRealm(self.agent, &.{
            .url = self.script_url,
            .timer = getTimerInterface(),
            .end_of_task = endTaskOfRealm,
            .on_realm = recordRealm,
            .data = self,
            .allocator = self.allocator,
        });
        self.global_scope = made.global_scope;

        // The built-ins find their worker here while setup scripts run.
        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;

        // HTML § 8.6: the timers, as built-ins on the global - own data
        // properties, shadowing the bound operations further up the chain.
        self.builtins = .{
            .{ .steps = setTimeoutSteps, .data = self },
            .{ .steps = clearTimerSteps, .data = self },
            .{ .steps = setIntervalSteps, .data = self },
            .{ .steps = clearTimerSteps, .data = self },
            .{ .steps = doneSteps, .data = self },
        };
        const realm = made.realm;
        try engine.defineBuiltinFunction(realm, "setTimeout", 1, &self.builtins[0]);
        try engine.defineBuiltinFunction(realm, "clearTimeout", 0, &self.builtins[1]);
        try engine.defineBuiltinFunction(realm, "setInterval", 1, &self.builtins[2]);
        try engine.defineBuiltinFunction(realm, "clearInterval", 0, &self.builtins[3]);
        // done() for the WPT harness: testharness.js defines its own, which
        // replaces this one when it loads.
        try engine.defineBuiltinFunction(realm, "done", 0, &self.builtins[4]);

        // Set up GLOBAL object for WPT tests
        // This is required by testharness.js to detect the execution context
        try self.runSetupScript(
            \\self.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
        );

        // Set up console object (no-op implementation for workers)
        try self.runSetupScript(
            \\(function() {
            \\  function consoleNoop() {}
            \\  globalThis.console = {
            \\    log: consoleNoop,
            \\    warn: consoleNoop,
            \\    error: consoleNoop,
            \\    info: consoleNoop,
            \\    debug: consoleNoop,
            \\    trace: consoleNoop,
            \\    dir: consoleNoop,
            \\    table: consoleNoop,
            \\    assert: consoleNoop,
            \\    clear: consoleNoop,
            \\    count: consoleNoop,
            \\    countReset: consoleNoop,
            \\    group: consoleNoop,
            \\    groupCollapsed: consoleNoop,
            \\    groupEnd: consoleNoop,
            \\    time: consoleNoop,
            \\    timeLog: consoleNoop,
            \\    timeEnd: consoleNoop,
            \\  };
            \\})();
        );

        // Polyfills for WindowOrWorkerGlobalScope attributes whose bound
        // getters have nothing to return yet (NotImplemented): crypto,
        // performance and indexedDB. They are defined as OWN data properties -
        // assigning would reach the getter-only accessors on
        // WorkerGlobalScope.prototype and, in sloppy mode, silently do nothing.
        //
        // Crypto API - Per Web Crypto spec: https://w3c.github.io/webcrypto/
        // (not cryptographically secure - Math.random).
        try self.runSetupScript(
            \\(function() {
            \\  function define(name, value) {
            \\    Object.defineProperty(globalThis, name, { value: value, writable: true, enumerable: true, configurable: true });
            \\  }
            \\  // SubtleCrypto placeholder for crypto.subtle
            \\  var subtle = {
            \\    encrypt: function() { return Promise.reject(new Error('Not implemented')); },
            \\    decrypt: function() { return Promise.reject(new Error('Not implemented')); },
            \\    sign: function() { return Promise.reject(new Error('Not implemented')); },
            \\    verify: function() { return Promise.reject(new Error('Not implemented')); },
            \\    digest: function() { return Promise.reject(new Error('Not implemented')); },
            \\    generateKey: function() { return Promise.reject(new Error('Not implemented')); },
            \\    deriveKey: function() { return Promise.reject(new Error('Not implemented')); },
            \\    deriveBits: function() { return Promise.reject(new Error('Not implemented')); },
            \\    importKey: function() { return Promise.reject(new Error('Not implemented')); },
            \\    exportKey: function() { return Promise.reject(new Error('Not implemented')); },
            \\    wrapKey: function() { return Promise.reject(new Error('Not implemented')); },
            \\    unwrapKey: function() { return Promise.reject(new Error('Not implemented')); }
            \\  };
            \\  define('crypto', {
            \\    subtle: subtle,
            \\    getRandomValues: function(array) {
            \\      if (!(array instanceof Int8Array || array instanceof Uint8Array ||
            \\            array instanceof Int16Array || array instanceof Uint16Array ||
            \\            array instanceof Int32Array || array instanceof Uint32Array ||
            \\            array instanceof Uint8ClampedArray || array instanceof BigInt64Array ||
            \\            array instanceof BigUint64Array)) {
            \\        throw new TypeError('Argument must be an integer typed array');
            \\      }
            \\      for (var i = 0; i < array.length; i++) {
            \\        array[i] = Math.floor(Math.random() * 256);
            \\      }
            \\      return array;
            \\    },
            \\    randomUUID: function() {
            \\      // RFC 4122 version 4 UUID
            \\      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            \\        var r = Math.random() * 16 | 0;
            \\        var v = c === 'x' ? r : (r & 0x3 | 0x8);
            \\        return v.toString(16);
            \\      });
            \\    }
            \\  });
            \\
            \\  // Performance API - https://w3c.github.io/hr-time/
            \\  var timeOrigin = Date.now();
            \\  define('performance', {
            \\    timeOrigin: timeOrigin,
            \\    now: function() { return Date.now() - timeOrigin; },
            \\    toJSON: function() { return { timeOrigin: this.timeOrigin }; }
            \\  });
            \\
            \\  // IndexedDB - https://w3c.github.io/IndexedDB/ (a stub).
            \\  function IDBFactory() {}
            \\  IDBFactory.prototype.open = function(name, version) {
            \\    return Promise.reject(new Error('IndexedDB not implemented'));
            \\  };
            \\  IDBFactory.prototype.deleteDatabase = function(name) {
            \\    return Promise.reject(new Error('IndexedDB not implemented'));
            \\  };
            \\  IDBFactory.prototype.databases = function() {
            \\    return Promise.resolve([]);
            \\  };
            \\  IDBFactory.prototype.cmp = function(a, b) {
            \\    if (a < b) return -1;
            \\    if (a > b) return 1;
            \\    return 0;
            \\  };
            \\  globalThis.IDBFactory = IDBFactory;
            \\  define('indexedDB', new IDBFactory());
            \\})();
        );
    }

    /// `createWorkerRealm`'s `on_realm`: the realm exists, and its global
    /// scope - which reads this worker's settings as it is made
    /// (`scopeSettings`) - does not yet.
    fn recordRealm(data: ?*anyopaque, realm: runtime.Context) void {
        const self: *Self = @ptrCast(@alignCast(data orelse return));
        self.realm = realm;
        installRealmHooks(realm);
    }

    /// Run one of the host's own setup scripts in the realm. It is no
    /// script of the worker's: an import() from it names no referrer.
    fn runSetupScript(self: *Self, source: []const u8) !void {
        const realm = self.realm orelse return error.NoRealm;
        try engine.runClassicScript(realm, .{ .utf8 = source }, "", null, self.reporter());
        try engine.performMicrotaskCheckpoint(self.agent);
    }

    /// Get the engine context pointer for WorkerContext.setEngineContext()
    pub fn getEngineContext(self: *Self) *EngineContext {
        return @ptrCast(self);
    }

    /// Get the engine callbacks for WorkerContext.setEngineContext()
    pub fn getCallbacks(self: *const Self) EngineCallbacks {
        _ = self;
        return .{
            .compileAndRunScript = compileAndRunScriptCallback,
            .compileAndRunModule = compileAndRunModuleCallback,
            .runMicrotasks = runMicrotasksCallback,
            .disposeContext = disposeContextCallback,
            .configureImportMeta = null, // TODO: Implement for module workers
            .registerDynamicImportHandler = null, // TODO: Implement for module workers
        };
    }

    // ------------------------------------------------------------------
    // Running script
    // ------------------------------------------------------------------

    /// "Run a classic script" for the worker, with this host's "report an
    /// exception", then "clean up after running script". The script - its
    /// base URL, `url` - is what an import() in it resolves against, for as
    /// long as the realm lives.
    fn runScript(self: *Self, source: []const u8, url: []const u8, checkpoint_after: bool) !void {
        const realm = self.realm orelse return error.NoRealm;
        const script = try self.classicScript(url);
        self.entered += 1;
        defer self.entered -= 1;
        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;
        try engine.runClassicScript(realm, .{ .utf8 = source }, url, script, self.reporter());
        if (!checkpoint_after) return;
        try engine.performMicrotaskCheckpoint(self.agent);
    }

    /// A classic script whose base URL is `url` (copied), kept until the
    /// realm's end.
    fn classicScript(self: *Self, url: []const u8) !*module_script.ClassicScript {
        const script = try self.allocator.create(module_script.ClassicScript);
        errdefer self.allocator.destroy(script);
        const base_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(base_url);
        script.* = .{ .base_url = base_url };
        try self.classic_scripts.append(self.allocator, script);
        return script;
    }

    fn freeClassicScripts(self: *Self) void {
        for (self.classic_scripts.items) |script| {
            self.allocator.free(script.base_url);
            self.allocator.destroy(script);
        }
        self.classic_scripts.deinit(self.allocator);
        self.classic_scripts = .empty;
    }

    /// Execute a script in this worker's realm (with optional message
    /// processing afterwards).
    ///
    /// If process_messages is true, also processes any pending incoming messages
    /// after script execution, allowing the worker's onmessage handler to be invoked.
    fn executeScriptEx(self: *Self, source: []const u8, process_messages: bool) !void {
        // A worker whose closing flag is set runs no further task.
        if (!self.runsTasks()) return error.WorkerClosed;

        try self.runScript(source, self.script_url, true);

        // Process any incoming messages from the main thread (only if requested)
        // This allows the worker's onmessage handler (set up by the script) to run
        if (process_messages) self.processIncomingMessagesInternal();

        // What the engine posted while the script ran; and if it left
        // background work (an asynchronous compile), a pump to finish it.
        _ = engine.runEngineTasks(self.agent);
        self.armPlatformPump(false);
    }

    /// Execute a script in this worker's realm (processes messages after)
    pub fn executeScript(self: *Self, source: []const u8) !void {
        return self.executeScriptEx(source, true);
    }

    /// HTML "report an exception" for the worker's global scope, as
    /// runClassicScript and invokeCallbackFunction hand it over: fire `error`
    /// at the global scope (cancelable - `self.onerror` returning true, or a
    /// listener's preventDefault(), handles it); if not handled, the worker's
    /// Worker object hears it, with `error` null.
    fn reportEngineException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const runtime_info: runtime.ErrorInfo = .{
            .message = info.message,
            .filename = info.filename,
            .lineno = info.lineno,
            .colno = info.colno,
            .error_value = info.error_value,
        };
        reportException(host, &runtime_info);
    }

    fn reportException(host: ?*anyopaque, info: *const runtime.ErrorInfo) void {
        const self: *Self = @ptrCast(@alignCast(host orelse return));
        log.debug("worker script error: {s}", .{info.message});
        var not_handled = true;
        if (!self.reporting_error) {
            self.reporting_error = true;
            defer self.reporting_error = false;
            not_handled = self.fireErrorAtGlobalScope(info);
        }
        if (not_handled) self.sendErrorToParent(info.message, info.filename, info.lineno, info.colno);
    }

    /// Fire an ErrorEvent named `error` at the global scope; whether it went
    /// unhandled (not canceled).
    fn fireErrorAtGlobalScope(self: *Self, info: *const runtime.ErrorInfo) bool {
        const realm = self.realm orelse return true;
        const global_scope = self.global_scope orelse return true;
        const init_dict = dictionaries.ErrorEventInit{
            .base = .{ .cancelable = true },
            .message = runtime.DOMString.initInterned(info.message),
            .filename = info.filename,
            .lineno = info.lineno,
            .colno = info.colno,
            .@"error" = info.error_value,
        };
        const event = interfaces.ErrorEvent.call_constructor(
            realm,
            runtime.DOMString.initInterned("error"),
            webidl.Opt(dictionaries.ErrorEventInit).passed(init_dict),
        ) catch return true;
        const generation = runtime.SlabAllocator.generationOf(event);
        const not_canceled = fire_event.dispatchTrusted(global_scope, event) catch true;
        event.releaseIfUnwrapped(generation);
        return not_canceled;
    }

    /// Send an error event to the parent Worker object via the callback mechanism.
    ///
    /// This schedules a WorkerErrorEvent to be dispatched on the parent thread.
    /// The main thread's event loop will dispatch the error via Worker.onerror
    /// or addEventListener('error').
    ///
    /// Spec: HTML Standard "report an exception": "queue a global task on the
    /// DOM manipulation task source with the global's associated Worker's
    /// relevant global object" to fire `error` at the Worker.
    fn sendErrorToParent(
        self: *Self,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    ) void {
        const dedicated_worker = self.dedicated_worker orelse return;

        // Create error event data
        const error_event = workers.worker_error.WorkerErrorEvent.init(
            self.allocator,
            message,
            if (filename.len > 0) filename else self.script_url,
            lineno,
            colno,
            null, // "The actual exception value will not be available in the owner realm"
        ) catch return;

        // Schedule error dispatch to parent thread via timer (0ms)
        if (WorkerHost.getTimerInterface()) |timer| {
            const dispatch_ctx = self.allocator.create(WorkerErrorDispatchContext) catch {
                error_event.deinit();
                return;
            };
            dispatch_ctx.* = .{
                .dedicated_worker = dedicated_worker,
                .error_event = error_event,
                .allocator = self.allocator,
            };
            _ = timer.setTimeout(0, workerErrorDispatchCallback, dispatch_ctx);
        } else {
            // No timer interface, dispatch synchronously (may not be ideal but better than dropping)
            dedicated_worker.fireErrorToParent(error_event);
        }
    }

    // ------------------------------------------------------------------
    // Messages
    // ------------------------------------------------------------------

    /// Process incoming messages - each one a task of the worker's realm.
    fn processIncomingMessagesInternal(self: *Self) void {
        const dedicated_worker = self.dedicated_worker orelse return;
        const inside_port = dedicated_worker.port_pair.inside_port;

        while (inside_port.message_queue.items.len > 0) {
            const msg = inside_port.message_queue.orderedRemove(0);
            defer msg.deinit();
            // A closing worker's tasks are discarded, the message's among them.
            if (!self.runsTasks()) continue;
            var delivery = Delivery{ .host = self, .msg = msg };
            self.runTask(Delivery.steps, &delivery);
        }
    }

    const Delivery = struct {
        host: *Self,
        msg: *QueuedMessage,

        fn steps(data: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(data orelse return));
            self.host.deliverMessage(self.msg);
        }
    };

    /// Deliver one message the page posted: StructuredDeserializeWithTransfer
    /// into the worker's realm, MessagePorts of the realm for the ports it
    /// transferred, and `message` fired at the global scope - or
    /// `messageerror`, when it does not deserialize. Run as a task of the
    /// worker's realm.
    fn deliverMessage(self: *Self, msg: *QueuedMessage) void {
        const realm = self.realm orelse return;
        const global_scope = self.global_scope orelse return;
        const message = if (msg.engine_message) |*m| m else return;
        deliverEngineMessage(realm, global_scope, message, fireMessageEvent);
    }

    /// The worker's side of the message port post message steps, for its
    /// implicit port: serialize `message` with `transfer` in the worker's
    /// realm, ship the transferred ports, and queue the message for the
    /// Worker object. It leaves for the page when the task ends.
    fn postMessageToOwner(self: *Self, message: runtime.JSValue, transfer: []const runtime.JSValue) !void {
        const realm = self.realm orelse return;
        const dedicated_worker = self.dedicated_worker orelse return;
        // A terminated worker's messages are never delivered ("terminate a
        // worker" step 4). A closing one's are: the task that called close()
        // runs to its end, and what it posts goes out
        // (workers/interfaces/WorkerGlobalScope/close/sending-messages).
        if (dedicated_worker.agent.isTerminated() or self.phase == .realm_gone) return;

        var serialized = try serializeMessage(realm, message, transfer, self.allocator);
        const queued = QueuedMessage.initEngine(self.allocator, serialized) catch |err| {
            serialized.deinit();
            return err;
        };
        errdefer queued.deinit();
        try DedicatedWorker.appendPendingMessage(dedicated_worker.port_pair.outside_port, queued);
    }

    fn setTimeoutSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.fromNumber(0)));
        return runtime.JSValue.fromNumber(@floatFromInt(self.setTimer(args, false)));
    }

    fn setIntervalSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.fromNumber(0)));
        return runtime.JSValue.fromNumber(@floatFromInt(self.setTimer(args, true)));
    }

    /// clearTimeout() and clearInterval(): the same list of active timers.
    fn clearTimerSteps(_: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        if (args.len < 1) return runtime.JSValue.jsUndefined;
        const id = switch (args[0]) {
            .number => |n| n,
            else => return runtime.JSValue.jsUndefined,
        };
        if (std.math.isNan(id) or std.math.isInf(id) or id < 0) return runtime.JSValue.jsUndefined;
        unregisterWorkerTimerContext(@intFromFloat(id));
        return runtime.JSValue.jsUndefined;
    }

    /// done() for the WPT harness, which defines its own when it loads.
    fn doneSteps(_: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        return runtime.JSValue.jsUndefined;
    }

    /// The timer initialization steps (HTML § 8.6) for setTimeout() or
    /// setInterval(): the new timer's id, or 0 when none was armed.
    fn setTimer(self: *Self, args: []const runtime.JSValue, repeat: bool) u32 {
        const realm = self.realm orelse return 0;
        // The handler: only a function is supported (a string handler is not).
        if (args.len < 1) return 0;
        if (!engine.isCallable(realm, args[0])) return 0;

        // The timeout (second argument, default 0).
        var delay_ms: i64 = 0;
        if (args.len >= 2) {
            switch (args[1]) {
                .number => |n| {
                    if (!std.math.isNan(n) and !std.math.isInf(n) and n >= 0) delay_ms = @intFromFloat(@min(n, @as(f64, std.math.maxInt(i32))));
                },
                else => {},
            }
        }

        const timer = getTimerInterface() orelse return 0;
        initWorkerTimerStorage(self.allocator);

        // The handler as a callback function, with the incumbent realm - the
        // worker's, whose built-in this is - as its callback context.
        const handler: engine.CallbackFunction = .{
            .function = engine.retainValue(realm, args[0]) catch return 0,
            .context = engine.incumbentRealm() orelse realm,
        };
        const timer_ctx = self.allocator.create(WorkerTimerContext) catch {
            handler.release();
            return 0;
        };

        // Apply HTML §8.6's clamp against the CURRENT nesting level: the spec
        // reads it in step 4, clamps in step 6, and only then increments for
        // the timer it is creating.
        const clamped_ms = runtime.timer.clampTimeout(delay_ms, runtime.timer.nesting_level);
        const delay_u64: u64 = if (clamped_ms >= 0) @intCast(clamped_ms) else 0;
        timer_ctx.* = .{
            .callback = handler,
            .id = 0, // Given once the timer is armed
            .current_timer_id = 0, // Updated after scheduling
            .is_interval = repeat,
            .interval_delay_ms = delay_u64,
            .nesting_level = runtime.timer.nesting_level +| 1,
            .allocator = self.allocator,
            .cancelled = false,
            .worker_host = self,
        };

        const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);
        if (timer_id == 0) {
            freeWorkerTimer(timer_ctx);
            return 0;
        }
        timer_ctx.current_timer_id = timer_id;
        timer_ctx.id = next_worker_timer_id;
        next_worker_timer_id += 1;
        registerWorkerTimerContext(timer_ctx);
        return @truncate(timer_ctx.id);
    }
};

/// Serialize `message` with `transfer` in `realm` for a worker's implicit
/// port - from either side: StructuredSerializeWithTransfer, then the
/// transfer steps of every MessagePort in `transfer`. OWNED (`deinit`).
pub fn serializeMessage(
    realm: runtime.Context,
    message: runtime.JSValue,
    transfer: []const runtime.JSValue,
    allocator: Allocator,
) !EngineMessage {
    var result = try engine.structuredSerializeWithTransfer(realm, message, transfer, transferablePort, null, allocator);
    errdefer result.deinit(allocator);

    // The transfer steps for each MessagePort: its end - queue and
    // entanglement - is the data holder.
    const ends = try allocator.alloc(*anyopaque, result.platform_objects.len);
    errdefer allocator.free(ends);
    for (result.platform_objects, 0..) |port, i| {
        ends[i] = message_ports.ship(port) orelse return error.DataCloneError;
    }
    allocator.free(result.platform_objects);

    return .{
        .allocator = allocator,
        .serialized = result.serialized,
        .array_buffers = result.array_buffers,
        .port_ends = ends,
    };
}

/// Deliver an engine-serialized `message` at `target` in `realm` - the
/// receiving half of the message port post message steps (step 7): the
/// transferred ports received into `realm`, StructuredDeserializeWithTransfer,
/// and `message` fired (or `messageerror`, when it does not deserialize).
/// Call with `realm` entered. The message's port ends are taken.
pub fn deliverEngineMessage(
    realm: runtime.Context,
    target: *runtime.Instance,
    message: *EngineMessage,
    fire: *const fn (realm: runtime.Context, target: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, ports: []const *runtime.Instance) void,
) void {
    const allocator = message.allocator;
    var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer ports.deinit(allocator);
    // The transferred ports' transfer-receiving steps: MessagePorts of the
    // receiving realm on the shipped ends.
    for (message.port_ends) |end| {
        const port = message_ports.receive(realm, end) catch continue;
        ports.append(allocator, port) catch continue;
    }
    // The ports belong to the message's receiver now, not the queue.
    allocator.free(message.port_ends);
    message.port_ends = &.{};

    const data = engine.structuredDeserializeWithTransfer(realm, message.serialized, message.array_buffers) catch {
        fire(realm, target, "messageerror", runtime.JSValue.jsUndefined, &.{});
        return;
    };
    defer data.release();
    fire(realm, target, "message", data.value, ports.items);
}

/// Which platform objects a worker's postMessage can transfer: MessagePorts
/// that are not detached.
fn transferablePort(_: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    return message_ports.transferableState(instance);
}

/// Fire a MessageEvent named `event_type` at `target`, made in `realm`. `data`
/// is borrowed: the event keeps its own.
pub fn fireMessageEvent(
    realm: runtime.Context,
    target: *runtime.Instance,
    event_type: []const u8,
    data: runtime.JSValue,
    ports: []const *runtime.Instance,
) void {
    const init_dict = dictionaries.MessageEventInit{
        .base = .{},
        .data = data,
        .ports = ports,
    };
    const event = interfaces.MessageEvent.call_constructor(
        realm,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent: trusted (DOM 2.10).
    _ = fire_event.dispatchTrusted(target, event) catch {};
    event.releaseIfUnwrapped(generation);
}

// ============================================================================
// import() in a worker - the agent's host hooks
// ============================================================================

/// A dedicated worker agent's host hooks (HTML "obtain a dedicated/shared
/// worker agent", which `WorkerHost.init` does): HostLoadImportedModule for
/// import() and HostGetImportMetaProperties for the modules it loads. The
/// hooks' `host` is the WorkerHost. (Only an engine with modules calls them.)
const worker_hooks: engine.HostHooks = .{
    .loadImportedModule = if (module_script.supported) loadImportedModule else null,
    .importMetaUrl = if (module_script.supported) module_script.importMetaUrl else null,
};

/// FinishLoadingImportedModule for an import(): ends the host's hold on
/// `request`.
fn finishImport(request: *engine.ImportRequest, outcome: engine.DynamicImportOutcome) void {
    if (module_script.supported) engine.finishDynamicImport(request, outcome);
}

/// FinishLoadingImportedModule with ThrowCompletion(a new TypeError).
fn finishImportWithTypeError(realm: runtime.Context, request: *engine.ImportRequest, message: []const u8) void {
    const exception = engine.createSimpleException(realm, .TypeError, message) catch
        return finishImport(request, .{ .failure = runtime.JSValue.jsUndefined });
    defer exception.release();
    finishImport(request, .{ .failure = exception.value });
}

/// HTML HostLoadImportedModule(referrer, moduleRequest, loadState: undefined,
/// payload) for an import() in a worker - `HostHooks.loadImportedModule`.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#hostloadimportedmodule
/// Every path finishes `request`.
fn loadImportedModule(
    host: ?*anyopaque,
    realm: runtime.Context,
    referrer: engine.ImportReferrer,
    specifier: []const u8,
    type_attribute: ?[]const u8,
    request: *engine.ImportRequest,
) void {
    const self: *WorkerHost = @ptrCast(@alignCast(host orelse
        return finishImportWithTypeError(realm, request, "import() is not supported here")));
    // Only the worker's own realm has its settings object.
    if (self.realm != realm or !self.runsTasks())
        return finishImportWithTypeError(realm, request, "import() in a worker that has ended");
    const env = self.moduleEnvironment() orelse
        return finishImportWithTypeError(realm, request, "import() in a worker that has ended");

    // Steps 1-6: the settings object is the current one - the worker's - and
    // the referencing script is the referrer's [[HostDefined]] when there is
    // one: its base URL is what the specifier resolves against. With none
    // (an event handler, eval, a setup script) it is the settings object's
    // API base URL: for a worker, its global scope's URL - its script's.
    const base_url: []const u8 = switch (referrer) {
        .module => |host_defined| if (module_script.scriptOf(host_defined)) |script| script.base_url else self.script_url,
        .script => |host_defined| module_script.classicScriptBaseUrl(host_defined),
        .realm => self.script_url,
    };

    // Steps 7.1.4-7.1.5 (for the one request an import() makes): module type
    // allowed - "css" only where CSSStyleSheet is exposed, which a worker's
    // global is not - or a TypeError.
    const module_type = module_script.moduleTypeFromAttribute(type_attribute) orelse
        return finishImportWithTypeError(realm, request, "Unsupported module type");
    if (module_type == .css) return finishImportWithTypeError(realm, request, "Unsupported module type");

    // Steps 8-9: resolve a module specifier, or reject with its TypeError.
    const url = module_script.resolve(&env, specifier, base_url) orelse
        return finishImportWithTypeError(realm, request, "Failed to resolve module specifier");
    defer realm.allocator.free(url);

    // Step 14: fetch - as a task of the worker's event loop, so the module
    // is fetched and evaluated after the script that called import() and its
    // microtasks, as a network fetch completes.
    self.queueDynamicImport(url, module_type, request) catch
        return finishImportWithTypeError(realm, request, "Out of memory");
}

/// An import() whose fetch is queued on the worker's event loop.
const DynamicImportTask = struct {
    host: *WorkerHost,
    /// Owned (the host's allocator).
    url: []const u8,
    module_type: module_script.ModuleType,
    /// The host's until finished.
    request: *engine.ImportRequest,
    /// The timer the task runs from, while it is armed.
    timer: ?MessageDispatchTimer = null,
    /// The fetch task ran, and finished the request.
    finished: bool = false,
};

fn runDynamicImport(context_ptr: ?*anyopaque) void {
    const task: *DynamicImportTask = @ptrCast(@alignCast(context_ptr orelse return));
    task.timer = null;
    const self = task.host;
    self.forgetImport(task);
    defer self.freeImport(task);

    // A worker whose closing flag is set runs no further task: the import is
    // discarded, and its request finished to release what it holds.
    if (!self.runsTasks()) return finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });

    const prev_context = current_worker_context;
    current_worker_context = self;
    defer current_worker_context = prev_context;

    self.runTask(dynamicImportSteps, task);
    // runTask runs nothing in a realm that has gone: the request is finished
    // either way.
    if (!task.finished) finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });
}

/// The fetch task: fetch a single imported module script and its
/// descendants, link, then FinishLoadingImportedModule - ContinueDynamicImport
/// (evaluate, and settle with the namespace or the reason) is the engine's.
fn dynamicImportSteps(data: ?*anyopaque) void {
    const task: *DynamicImportTask = @ptrCast(@alignCast(data.?));
    // Every path below finishes the request.
    task.finished = true;
    const self = task.host;
    const realm = self.realm orelse return finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });
    const env = self.moduleEnvironment() orelse
        return finishImportWithTypeError(realm, task.request, "import() in a worker that has ended");

    // A null graph is a failed fetch: TypeError.
    const graph = module_script.fetchImportedModuleScriptGraph(&env, task.url, task.module_type) orelse
        return finishImportWithTypeError(realm, task.request, "Failed to fetch dynamically imported module");

    // A graph that could not be loaded or linked rejects with its error to
    // rethrow; else the engine continues with its record.
    if (graph.error_to_rethrow) |reason| return finishImport(task.request, .{ .failure = reason.value });
    const record = graph.record orelse
        return finishImportWithTypeError(realm, task.request, "Failed to load dynamically imported module");
    finishImport(task.request, .{ .module = record });
}

// WorkerHost's side of import(), its module map included.
const WorkerModules = struct {
    /// The module loading environment for the worker's realm: its global
    /// scope, its module map, and no import map (a worker global's import map
    /// is empty).
    fn moduleEnvironment(self: *WorkerHost) ?module_script.Environment {
        const global_scope = self.global_scope orelse return null;
        return .{
            .allocator = self.allocator,
            .context_instance = global_scope,
            .map = .{ .context = self, .getFn = &mapGet, .putFn = &mapPut },
        };
    }

    fn mapGet(context: *anyopaque, key: []const u8) ?*anyopaque {
        const self: *WorkerHost = @ptrCast(@alignCast(context));
        return self.modules.get(key);
    }

    fn mapPut(context: *anyopaque, key: []const u8, value: *anyopaque) bool {
        const self: *WorkerHost = @ptrCast(@alignCast(context));
        const owned_key = self.allocator.dupe(u8, key) catch return false;
        const entry = self.modules.getOrPut(self.allocator, owned_key) catch {
            self.allocator.free(owned_key);
            return false;
        };
        if (entry.found_existing) {
            self.allocator.free(owned_key);
            module_script.disposeEntry(entry.value_ptr.*);
        }
        entry.value_ptr.* = value;
        return true;
    }

    /// Release every module script in the map: their records are the agent's.
    fn disposeModules(self: *WorkerHost) void {
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            module_script.disposeEntry(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.modules.deinit(self.allocator);
        self.modules = .empty;
    }

    fn queueDynamicImport(self: *WorkerHost, url: []const u8, module_type: module_script.ModuleType, request: *engine.ImportRequest) !void {
        const timer = WorkerHost.getTimerInterface() orelse return error.NoEventLoop;
        const task = try self.allocator.create(DynamicImportTask);
        errdefer self.allocator.destroy(task);
        task.* = .{
            .host = self,
            .url = try self.allocator.dupe(u8, url),
            .module_type = module_type,
            .request = request,
        };
        errdefer self.allocator.free(task.url);
        try self.pending_imports.append(self.allocator, task);
        errdefer _ = self.pending_imports.pop();
        const id = timer.setTimeout(0, runDynamicImport, task);
        if (id == 0) return error.NoEventLoop;
        task.timer = .{ .timer = timer, .id = id };
    }

    fn forgetImport(self: *WorkerHost, task: *DynamicImportTask) void {
        for (self.pending_imports.items, 0..) |pending, i| {
            if (pending == task) {
                _ = self.pending_imports.swapRemove(i);
                return;
            }
        }
    }

    fn freeImport(self: *WorkerHost, task: *DynamicImportTask) void {
        self.allocator.free(task.url);
        self.allocator.destroy(task);
    }

    /// Discard the import()s whose fetch task has not run: disarm each, and
    /// finish its request - which rejects a promise nothing will observe - so
    /// the engine's hold on it ends while the agent is alive.
    fn finishPendingImports(self: *WorkerHost) void {
        while (self.pending_imports.pop()) |task| {
            if (task.timer) |armed| _ = armed.timer.clearTimeout(armed.id);
            finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });
            self.freeImport(task);
        }
    }
};

// ============================================================================
// Engine Callbacks Implementation
// ============================================================================

/// Compile and run a script, returns result value pointer
fn compileAndRunScriptCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!?*anyopaque {
    _ = source_url;
    const self: *WorkerHost = @ptrCast(@alignCast(engine_ctx));
    try self.executeScript(source);
    return null;
}

/// Compile and run a module
fn compileAndRunModuleCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!void {
    _ = source_url; // TODO: Used for import resolution
    const self: *WorkerHost = @ptrCast(@alignCast(engine_ctx));

    // For now, execute as script.
    try self.executeScript(source);
}

/// Run microtask checkpoint
fn runMicrotasksCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerHost = @ptrCast(@alignCast(engine_ctx));
    if (self.realm == null) return;
    engine.performMicrotaskCheckpoint(self.agent) catch {};
}

/// Dispose engine context
fn disposeContextCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerHost = @ptrCast(@alignCast(engine_ctx));
    self.deinit();
}

/// Process incoming messages from the main thread
///
/// This should be called after the worker script has set up its onmessage
/// handler.
pub fn processIncomingMessages(worker_ctx: *WorkerHost) void {
    const dedicated_worker = worker_ctx.dedicated_worker orelse return;

    // A closing worker runs no further task; its messages are discarded
    // (close() step 1, "terminate a worker" step 2), and once its realm is
    // gone there is nothing to deliver them to.
    if (!worker_ctx.runsTasks()) {
        emptyPortQueue(dedicated_worker.port_pair.inside_port);
        return;
    }

    {
        // Set current_worker_context for any callbacks
        const prev_context = current_worker_context;
        current_worker_context = worker_ctx;
        defer current_worker_context = prev_context;

        worker_ctx.processIncomingMessagesInternal();

        // The end of the turn: the engine's posted tasks, and a pump if
        // background work is left.
        _ = engine.runEngineTasks(worker_ctx.agent);
        worker_ctx.armPlatformPump(false);
    }

    // What the worker posted while its handlers ran joins its outside port's
    // queue now.
    DedicatedWorker.flushPendingMessages();
}

/// Drop every message queued on `port`.
fn emptyPortQueue(port: anytype) void {
    while (port.message_queue.items.len > 0) {
        const msg = port.message_queue.orderedRemove(0);
        msg.deinit();
    }
}

// ============================================================================
// Tests
// ============================================================================

test "WorkerHost - struct definition" {
    const T = WorkerHost;
    try std.testing.expect(@sizeOf(T) > 0);
}
