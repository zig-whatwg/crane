//! The worker host: the HTML half of "run a worker" for a dedicated worker.
//!
//! Spec: HTML Standard § 10.2.4 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! A worker is an agent and a realm in it whose global object is a
//! DedicatedWorkerGlobalScope. The ENGINE half - making the agent and the
//! realm, binding the global object, running script, the engine's own posted
//! tasks, the realm's end - is the JavaScript engine's, and this file reaches
//! it only through the Engine table (AGENTS.md, "The engine boundary"; V8's
//! side is src/runtime/engines/v8/worker_realm.zig). What is here is the
//! worker as HTML describes it:
//!
//! - its event loop: the worker's tasks run as timers on the page's loop, and
//!   each ends the worker's way (`endTask`) - a microtask checkpoint, the
//!   engine's posted tasks, and whatever the worker posted leaving for its
//!   owner;
//! - its timers (§ 8.6), messages in both directions (the implicit ports),
//!   errors reported to its global scope and then to its Worker object;
//! - its life: running, closing (close() or "terminate a worker"), the
//!   realm's end, the agent's.

const std = @import("std");
const log = std.log.scoped(.worker_host);
const Allocator = std.mem.Allocator;

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");

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
threadlocal var current_worker_context: ?*WorkerV8Context = null;

// Thread-local storage for timer interface (set by caller before worker operations)
threadlocal var current_worker_timer_interface: ?runtime.TimerInterface = null;

/// Set the current worker context (for use by external code before invoking worker callbacks)
pub fn setCurrentWorkerContext(ctx: ?*WorkerV8Context) void {
    current_worker_context = ctx;
}

/// Get the current worker context (for internal use)
pub fn getCurrentWorkerContext() ?*WorkerV8Context {
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
    /// The timer's handler, retained through the Engine table (OWNED).
    callback: runtime.JSValue,
    /// Current timer ID (may change on reschedule for intervals)
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
    worker_v8_context: *WorkerV8Context,
};

/// Thread-local storage for worker timer contexts
threadlocal var worker_timer_contexts: ?std.AutoHashMap(runtime.TimerId, *WorkerTimerContext) = null;

/// Initialize worker timer storage
fn initWorkerTimerStorage(allocator: Allocator) void {
    if (worker_timer_contexts == null) {
        worker_timer_contexts = std.AutoHashMap(runtime.TimerId, *WorkerTimerContext).init(allocator);
    }
}

/// Release a timer context and the handler it holds.
fn freeWorkerTimer(ctx: *WorkerTimerContext) void {
    const wctx = ctx.worker_v8_context;
    if (wctx.engine.releaseValue) |release| release(ctx.callback);
    ctx.allocator.destroy(ctx);
}

/// Cancel and free every timer `owner` armed: HTML "terminate a worker" step 2
/// and close() step 1 discard the worker's tasks, and a timer is one.
///
/// The map is shared by every worker on this thread. This used to clear all of
/// it whenever ANY worker was torn down, so one worker's end silently dropped
/// every other worker's timers. A timer whose callback is on the stack is only
/// marked: its trampoline owns it until the callback returns, and frees it.
fn cancelWorkerTimers(owner: *WorkerV8Context) void {
    const map = if (worker_timer_contexts) |*m| m else return;
    var ids: std.ArrayListUnmanaged(runtime.TimerId) = .empty;
    defer ids.deinit(owner.allocator);
    var iter = map.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.*.worker_v8_context == owner) ids.append(owner.allocator, entry.key_ptr.*) catch {};
    }
    for (ids.items) |id| {
        const ctx = map.get(id) orelse continue;
        ctx.cancelled = true;
        if (ctx.executing) continue;
        // Not armed any more, or armed and now cancelled: either way the
        // timer manager will not hand it back, so it is ours to free.
        if (WorkerV8Context.getTimerInterface()) |timer| _ = timer.clearTimeout(id);
        _ = map.remove(id);
        freeWorkerTimer(ctx);
    }
}

/// Register a timer context for tracking
fn registerWorkerTimerContext(timer_id: runtime.TimerId, ctx: *WorkerTimerContext) void {
    if (worker_timer_contexts) |*map| {
        map.put(timer_id, ctx) catch {};
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
fn unregisterWorkerTimerContext(timer_id: runtime.TimerId) void {
    const map = if (worker_timer_contexts) |*m| m else return;
    const ctx = map.get(timer_id) orelse return;
    ctx.cancelled = true;
    if (ctx.executing) return;
    if (WorkerV8Context.getTimerInterface()) |timer| _ = timer.clearTimeout(timer_id);
    _ = map.remove(timer_id);
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
/// The timer carries the WorkerV8Context, which records it so that `deinit`
/// can disarm it. It used to carry a bare `*DedicatedWorker` that nothing
/// cancelled: a Worker collected, or torn down with its page, while the timer
/// was armed left it to fire into freed memory - SIGSEGV at 0xAAAA...AAAA in
/// `processQueuedMessages`, in whichever test the same process ran next.
/// One crash per sharded `html/webappapis/timers/` run, in a file with no
/// worker in it.
fn scheduleMessageDispatch(wctx: *WorkerV8Context) void {
    if (wctx.message_dispatch != null) return;
    const dedicated_worker = wctx.dedicated_worker orelse return;
    if (dedicated_worker.port_pair.outside_port.message_queue.items.len == 0) return;
    const timer = WorkerV8Context.getTimerInterface() orelse return;
    const id = timer.setTimeout(0, workerMessageDispatchCallback, wctx);
    if (id == 0) return;
    wctx.message_dispatch = .{ .timer = timer, .id = id };
}

/// Every worker whose realm is still there, for `finishTaskIn` and
/// `scopeSettings`.
threadlocal var live_contexts: std.ArrayListUnmanaged(*WorkerV8Context) = .empty;

fn removeLive(wctx: *WorkerV8Context) void {
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
};

/// The settings for a global scope created in the realm whose runtime
/// context is `ctx`, if that is a worker this host runs.
pub fn scopeSettings(ctx: runtime.Context) ?ScopeSettings {
    const wctx = forScope(ctx) orelse return null;
    return .{
        .url = wctx.effective_url,
        .worker_type = wctx.worker_type,
        .name = if (wctx.dedicated_worker) |dw| dw.getName() else "",
    };
}

/// The worker's end of a task, as its realm's `end_of_task`: what
/// `finishTaskIn` does, found by the realm instead of the agent.
fn endTaskOfRealm(ctx: runtime.Context) void {
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

fn forScope(ctx: runtime.Context) ?*WorkerV8Context {
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
    const wctx: *WorkerV8Context = @ptrCast(@alignCast(context_ptr orelse return));
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
    const wctx = ctx.worker_v8_context;

    // Cancelled while armed, or its worker has closed: a discarded task (HTML
    // close() step 1, "terminate a worker" step 2). Free it - this is the last
    // time the timer system will reference this context.
    if (ctx.cancelled or !wctx.runsTasks()) {
        if (worker_timer_contexts) |*map| _ = map.remove(ctx.current_timer_id);
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
        if (WorkerV8Context.getTimerInterface()) |timer| {
            // Unregister the old timer ID from tracking
            if (worker_timer_contexts) |*map| {
                _ = map.remove(ctx.current_timer_id);
            }

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
                ctx.current_timer_id = new_timer_id;
                // Re-register with the new timer ID
                registerWorkerTimerContext(new_timer_id, ctx);
                return;
            }
            // Reschedule failed: it is neither armed nor tracked now, so free it.
            freeWorkerTimer(ctx);
            return;
        }
    }

    // A one-shot that has run, or a repeat that was cancelled: the timer
    // manager has already dropped it, so nothing will hand it back.
    if (worker_timer_contexts) |*map| _ = map.remove(ctx.current_timer_id);
    freeWorkerTimer(ctx);
}

/// The timer task's steps: run the callback in the worker's realm, then the
/// end of the task - a microtask checkpoint, the engine's posted tasks, and
/// the messages the callback posted leaving for the page.
fn runWorkerTimerCallback(ctx: *WorkerTimerContext) void {
    const wctx = ctx.worker_v8_context;

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
        const wctx = ctx.worker_v8_context;
        const invoke = wctx.engine.invokeCallbackFunction orelse return;
        const realm = wctx.realm orelse return;
        invoke(realm, ctx.callback, .global_this, &.{}, WorkerV8Context.reportException, wctx) catch {};
    }
};

/// Get the effective URL for a worker, applying WPT URL rewriting rules.
/// Per WPT convention:
///   - .https. tests use https://localhost:8443
///   - .h2. tests use https://localhost:9000 (HTTP/2)
fn getEffectiveWorkerUrl(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
    const is_h2 = std.mem.indexOf(u8, url, ".h2.") != null;
    const is_https = std.mem.indexOf(u8, url, ".https.") != null;

    if (is_h2 or is_https) {
        // Determine target port based on test type
        const target_port: []const u8 = if (is_h2) "9000" else "8443";

        // Rewrite http:// to https:// for location object
        if (std.mem.startsWith(u8, url, "http://localhost:8000")) {
            // Replace http://localhost:8000 with https://localhost:<port>
            const rest = url["http://localhost:8000".len..];
            return try std.fmt.allocPrint(allocator, "https://localhost:{s}{s}", .{ target_port, rest });
        } else if (std.mem.startsWith(u8, url, "http://")) {
            // Generic http:// to https:// replacement (preserve original port if present)
            const rest = url["http://".len..];
            return try std.fmt.allocPrint(allocator, "https://{s}", .{rest});
        }
    }

    // Return a duplicate of the original URL (caller owns the memory)
    return try allocator.dupe(u8, url);
}

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

/// The worker a Worker object runs: its agent and realm (through the Engine
/// table), its event loop's tasks, its life.
pub const WorkerV8Context = struct {
    /// The Engine table of the realm that made the worker; the worker's agent
    /// and realm are this engine's.
    engine: *const runtime.EngineInterface,

    /// The worker's agent - its own, separate from its owner's.
    agent: *runtime.Agent,

    /// The worker's realm: its runtime context, which every Instance created
    /// in it points at - the global scope first. Null until the global scope
    /// is set up (`setupWorkerGlobalScope`) and again once the realm is gone.
    realm: ?runtime.Context = null,

    /// The realm's global object's platform object: its
    /// DedicatedWorkerGlobalScope. The realm owns it, and frees it when the
    /// realm goes.
    global_scope: ?*runtime.Instance = null,

    /// Script URL for error messages
    script_url: []const u8,

    /// The URL the global scope reports as its own: the script's final URL,
    /// with WPT's https rewrite applied (`getEffectiveWorkerUrl`). Owned.
    effective_url: []const u8,

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
    /// worker agent, through `engine` (the owner realm's Engine table). The
    /// realm follows when the global scope is set up.
    pub fn init(
        allocator: Allocator,
        engine: *const runtime.EngineInterface,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const create_agent = engine.createAgent orelse return error.NotSupported;
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);
        const effective_url = try getEffectiveWorkerUrl(allocator, script_url);
        errdefer allocator.free(effective_url);

        const agent = try create_agent();
        self.* = .{
            .engine = engine,
            .agent = agent,
            .script_url = url_copy,
            .effective_url = effective_url,
            .worker_type = worker_type,
            .allocator = allocator,
        };
        live_contexts.append(std.heap.page_allocator, self) catch {};
        return self;
    }

    /// Whether the worker runs tasks: not once its closing flag is set.
    pub fn runsTasks(self: *const Self) bool {
        return self.phase == .running;
    }

    /// Run `steps` as a task of the worker's realm - its agent entered, and
    /// the task ended the worker's way (`endTaskOfRealm`) - counting the
    /// entry.
    fn runTask(self: *Self, steps: runtime.RealmSteps, data: ?*anyopaque) void {
        const realm = self.realm orelse return;
        const run = self.engine.runTaskInRealm orelse return;
        self.entered += 1;
        defer self.entered -= 1;
        run(realm, steps, data) catch {};
    }

    /// The end of a task that ran script in this worker: a microtask
    /// checkpoint, the tasks the engine has posted for its agent, and whatever
    /// the worker posted leaving for the page. Call with the agent entered.
    fn endTask(self: *Self) void {
        if (self.realm) |realm| {
            if (self.engine.performMicrotaskCheckpoint) |checkpoint| checkpoint(realm) catch {};
        }
        if (self.engine.runEngineTasks) |pump| _ = pump(self.agent);
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
        if (!again) {
            const pending = self.engine.hasPendingEngineWork orelse return;
            if (!pending(self.agent)) return;
        }
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
            const engine = pump.host.engine;
            // Read before pumping: background work that ends between the two
            // posts its task after the pump looked, and a pending answer taken
            // first means one more round to find it.
            if (engine.hasPendingEngineWork) |pending| pump.pending = pending(pump.host.agent);
            if (engine.runEngineTasks) |run| pump.ran = run(pump.host.agent);
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
        const script_running = if (self.engine.hasRunningScript) |running| running(self.agent) else false;
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
        self.realm = null;
        // The realm's per-context data - the callbacks its script registered,
        // its wrapper cache and every Instance in it, the global scope first -
        // goes with it; the realm is retired, so anything holding it across
        // turns (a fetch) reads it as gone.
        self.global_scope = null;
        if (self.engine.destroyWorkerRealm) |destroy_realm| destroy_realm(realm, sweepFetches, null);
        self.releaseOwnerWhenIdle();
    }

    /// The worker has ended, so its Worker object has no pending activity
    /// left once nothing the worker posted remains to be delivered - Blink's
    /// DedicatedWorker::HasPendingActivity() turning false. Then the Engine
    /// table's `releasePlatformObject` undoes the Worker's
    /// `keepPlatformObjectAlive`, and a Worker script no longer references is
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
        const engine = owner.ctx.getEngine() orelse return;
        log.debug("owner released: {*}", .{owner});
        if (engine.releasePlatformObject) |release| release(owner);
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
        if (self.engine.destroyAgent) |destroy_agent| destroy_agent(self.agent);
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
        self.allocator.free(self.script_url);
        self.allocator.free(self.effective_url);
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

        const create_realm = self.engine.createWorkerRealm orelse return error.NotSupported;
        const made = try create_realm(self.agent, .{
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
        const define = self.engine.defineBuiltinFunction orelse return error.NotSupported;
        const realm = made.realm;
        try define(realm, "setTimeout", 1, &self.builtins[0]);
        try define(realm, "clearTimeout", 0, &self.builtins[1]);
        try define(realm, "setInterval", 1, &self.builtins[2]);
        try define(realm, "clearInterval", 0, &self.builtins[3]);
        // done() for the WPT harness: testharness.js defines its own, which
        // replaces this one when it loads.
        try define(realm, "done", 0, &self.builtins[4]);

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
    }

    /// Run one of the host's own setup scripts in the realm.
    fn runSetupScript(self: *Self, source: []const u8) !void {
        const realm = self.realm orelse return error.NoRealm;
        const run = self.engine.runClassicScript orelse return error.NotSupported;
        try run(realm, source, null, reportException, self);
        if (self.engine.performMicrotaskCheckpoint) |checkpoint| try checkpoint(realm);
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
    /// exception", then "clean up after running script".
    fn runScript(self: *Self, source: []const u8, url: []const u8, checkpoint_after: bool) !void {
        const realm = self.realm orelse return error.NoRealm;
        const run = self.engine.runClassicScript orelse return error.NotSupported;
        self.entered += 1;
        defer self.entered -= 1;
        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;
        try run(realm, source, url, reportException, self);
        if (!checkpoint_after) return;
        if (self.engine.performMicrotaskCheckpoint) |checkpoint| try checkpoint(realm);
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
        if (self.engine.runEngineTasks) |pump| _ = pump(self.agent);
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
        if (WorkerV8Context.getTimerInterface()) |timer| {
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
        deliverEngineMessage(self.engine, realm, global_scope, message, fireMessageEvent);
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

        var serialized = try serializeMessage(self.engine, realm, message, transfer, self.allocator);
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
        const callable = self.engine.isCallable orelse return 0;
        if (!callable(args[0])) return 0;

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

        const retain = self.engine.retainValue orelse return 0;
        const handler = retain(realm, args[0]) catch return 0;
        const timer_ctx = self.allocator.create(WorkerTimerContext) catch {
            if (self.engine.releaseValue) |release| release(handler);
            return 0;
        };

        // Apply HTML §8.6's clamp against the CURRENT nesting level: the spec
        // reads it in step 4, clamps in step 6, and only then increments for
        // the timer it is creating.
        const clamped_ms = runtime.timer.clampTimeout(delay_ms, runtime.timer.nesting_level);
        const delay_u64: u64 = if (clamped_ms >= 0) @intCast(clamped_ms) else 0;
        timer_ctx.* = .{
            .callback = handler,
            .current_timer_id = 0, // Updated after scheduling
            .is_interval = repeat,
            .interval_delay_ms = delay_u64,
            .nesting_level = runtime.timer.nesting_level +| 1,
            .allocator = self.allocator,
            .cancelled = false,
            .worker_v8_context = self,
        };

        const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);
        if (timer_id == 0) {
            freeWorkerTimer(timer_ctx);
            return 0;
        }
        timer_ctx.current_timer_id = timer_id;
        registerWorkerTimerContext(timer_id, timer_ctx);
        return @truncate(timer_id);
    }
};

/// Serialize `message` with `transfer` in `realm` for a worker's implicit
/// port - from either side: StructuredSerializeWithTransfer, then the
/// transfer steps of every MessagePort in `transfer`. OWNED (`deinit`).
pub fn serializeMessage(
    engine: *const runtime.EngineInterface,
    realm: runtime.Context,
    message: runtime.JSValue,
    transfer: []const runtime.JSValue,
    allocator: Allocator,
) !EngineMessage {
    const serialize = engine.structuredSerializeWithTransfer orelse return error.NotSupported;
    var result = try serialize(realm, message, transfer, transferablePort, null, allocator);
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
    engine: *const runtime.EngineInterface,
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

    const deserialize = engine.structuredDeserializeWithTransfer orelse return;
    const data = deserialize(realm, message.serialized, message.array_buffers) catch {
        fire(realm, target, "messageerror", runtime.JSValue.jsUndefined, &.{});
        return;
    };
    defer if (engine.releaseValue) |release| release(data);
    fire(realm, target, "message", data, ports.items);
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
// Engine Callbacks Implementation
// ============================================================================

/// Compile and run a script, returns result value pointer
fn compileAndRunScriptCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!?*anyopaque {
    _ = source_url;
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
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
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));

    // For now, execute as script.
    try self.executeScript(source);
}

/// Run microtask checkpoint
fn runMicrotasksCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    const realm = self.realm orelse return;
    if (self.engine.performMicrotaskCheckpoint) |checkpoint| checkpoint(realm) catch {};
}

/// Dispose engine context
fn disposeContextCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    self.deinit();
}

/// Process incoming messages from the main thread
///
/// This should be called after the worker script has set up its onmessage
/// handler.
pub fn processIncomingMessages(worker_ctx: *WorkerV8Context) void {
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
        if (worker_ctx.engine.runEngineTasks) |pump| _ = pump(worker_ctx.agent);
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

test "WorkerV8Context - struct definition" {
    const T = WorkerV8Context;
    try std.testing.expect(@sizeOf(T) > 0);
}
