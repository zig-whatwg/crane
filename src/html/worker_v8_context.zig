//! Worker V8 Context Setup
//!
//! Spec: HTML Standard § 10.2.5 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This module creates V8 isolates and contexts for worker execution.
//! Each worker gets its own V8 isolate for complete memory isolation.
//!
//! ## Design
//!
//! Workers need isolated V8 execution contexts separate from the main thread.
//! This module provides:
//! - V8 isolate creation per worker
//! - V8 context creation within the isolate
//! - EngineCallbacks implementation for WorkerContext
//! - Global scope setup (self, console, etc.)
//!
//! ## Usage
//!
//! ```zig
//! const worker_v8 = @import("worker_v8_context.zig");
//!
//! // Create V8 context for a worker
//! const v8_ctx = try worker_v8.WorkerV8Context.init(allocator, script_url, worker_type);
//! defer v8_ctx.deinit();
//!
//! // Set up engine callbacks on WorkerContext
//! worker_context.setEngineContext(v8_ctx.getEngineContext(), v8_ctx.getCallbacks());
//!
//! // Execute script
//! try worker_context.executeScript(source);
//! ```

const std = @import("std");
const log = std.log.scoped(.worker_v8);
const Allocator = std.mem.Allocator;

// V8 FFI through runtime module
const v8 = @import("v8");
const native_timer = @import("v8").native_timer;
const context_manager = v8.context_manager;
const runtime = @import("runtime");

// V8Interface for registering constructors
const V8Interface = v8.V8Interface;

// Interface bindings for automatic [Exposed] attribute handling
const interface_bindings = v8.interface_bindings;

// Interfaces needed in worker context
const interfaces = @import("interfaces");

// A realm's fetches in flight, released when the realm goes.
const async_fetch = @import("fetch").algorithms.async_fetch;

// Worker types from html_core
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerContext = workers.WorkerContext;

// MessagePort impl for creating wrappers in worker context
const MessagePortImpl = @import("impls").MessagePort;
const EngineCallbacks = workers.worker_context.EngineCallbacks;
const WorkerType = workers.WorkerType;
const DedicatedWorker = workers.DedicatedWorker;
const script_fetch = workers.script_fetch;

/// Opaque engine context type expected by WorkerContext
const EngineContext = workers.worker_context.EngineContext;

// Thread-local storage for current worker context (used by V8 callbacks)
threadlocal var current_worker_context: ?*WorkerV8Context = null;

// Thread-local storage for timer interface (set by caller before worker operations)
threadlocal var current_worker_timer_interface: ?runtime.TimerInterface = null;

/// Set the current worker context (for use by external code before invoking worker callbacks)
///
/// This MUST be called before invoking any JavaScript callback that might call
/// worker-specific functions like postMessage(). The callback uses this thread-local
/// to route messages to the correct worker.
///
/// For nested workers, this is critical:
/// - When inner worker's message handler runs in outer worker's context,
///   the callback must know to route self.postMessage() to the outer worker
/// - Without this, messages would go to the wrong worker's port
pub fn setCurrentWorkerContext(ctx: ?*WorkerV8Context) void {
    current_worker_context = ctx;
}

/// Get the current worker context (for internal use)
pub fn getCurrentWorkerContext() ?*WorkerV8Context {
    return current_worker_context;
}

// ============================================================================
// Worker Timer Support
// ============================================================================

/// Timer context for tracking pending timers
const WorkerTimerContext = struct {
    /// V8 Global handle to the callback function
    callback_global: *v8.ffi.Value,
    /// The isolate this timer belongs to
    isolate: *v8.ffi.Isolate,
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
    /// the only thing allowed to free it; freeing underneath it disposes the V8
    /// Global the callback is still using.
    executing: bool = false,
    /// The worker that armed the timer. Its context is the one the callback
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

/// Release a timer context and the callback Global it owns.
fn freeWorkerTimer(ctx: *WorkerTimerContext) void {
    v8.ffi.v8_Global_Dispose(ctx.callback_global);
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
/// This used to fetchRemove, dispose the Global and destroy the ctx
/// unconditionally. If the timer was still armed it then fired into
/// workerTimerTrampoline, which read ctx.cancelled from freed memory and went on
/// to use a disposed Global - surfacing as UBSan trapping inside
/// v8_Global_Dispose (v8_wrapper.cpp:8434, `Reset()` on a non-null dangling
/// pointer). In ReleaseSafe that is a bare SIGTRAP with no message. clearTimeout
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

/// The end of a task that ran script in `isolate` from outside the worker's
/// own timers - AbortSignal.timeout()'s, say - if `isolate` is a worker's:
/// what workerTimerTrampoline does after its callback. The microtask
/// checkpoint runs, and whatever the worker posted leaves it for the page.
/// Without this the worker's messages sat in its queue, and a test that
/// reports its results by message timed out. Call it with `isolate` entered.
pub fn finishTaskIn(isolate: *v8.ffi.Isolate) void {
    const wctx = for (live_contexts.items) |live| {
        if (live.isolate == isolate) break live;
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

/// DedicatedWorkerGlobalScope close() for the global scope whose realm's
/// runtime context is `ctx`.
pub fn closeScope(ctx: runtime.Context) void {
    const wctx = forScope(ctx) orelse return;
    wctx.closeFromScript();
}

fn forScope(ctx: runtime.Context) ?*WorkerV8Context {
    for (live_contexts.items) |live| {
        if (live.scope_ctx == ctx) return live;
    }
    return null;
}

/// Worker isolates disposed on this thread so far. A worker that ends and
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
/// messages are processed in a clean V8 HandleScope state.
fn workerMessageDispatchCallback(context_ptr: ?*anyopaque) void {
    const wctx: *WorkerV8Context = @ptrCast(@alignCast(context_ptr orelse return));
    // Fired: nothing left to cancel, and a message queued from here on arms a
    // fresh timer.
    wctx.message_dispatch = null;
    const dedicated_worker = wctx.dedicated_worker orelse return;

    // Process queued messages - this invokes the Worker's onmessage handler
    // We're now in the main isolate context with clean HandleScope state
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
    // Global out from under the running callback.
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
            const repeat_ms = native_timer.clampTimeout(
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
    // manager has already dropped it, so nothing will hand it back. It used to
    // go through unregisterWorkerTimerContext here, which found it still
    // executing and left it - every one-shot worker timer leaked its context
    // and its callback's Global.
    if (worker_timer_contexts) |*map| _ = map.remove(ctx.current_timer_id);
    freeWorkerTimer(ctx);
}

/// The timer task's steps: run the callback in the worker's context, then the
/// end of the task - a microtask checkpoint, V8's posted tasks, and the
/// messages the callback posted leaving for the page.
fn runWorkerTimerCallback(ctx: *WorkerTimerContext) void {
    const wctx = ctx.worker_v8_context;

    // HTML §8.6: while this callback runs, the nesting level IS this timer's level,
    // so a setTimeout called from inside it nests one deeper. Restored afterwards
    // because the same thread goes on to run other tasks.
    const saved_nesting = native_timer.nesting_level;
    native_timer.nesting_level = ctx.nesting_level;
    defer native_timer.nesting_level = saved_nesting;

    // CRITICAL: Set current_worker_context so that callbacks like postMessage
    // can access the correct worker context. Save and restore the previous context.
    const prev_context = current_worker_context;
    current_worker_context = wctx;
    defer current_worker_context = prev_context;

    // Enter the worker's isolate and context
    wctx.enter();
    defer wctx.exit();

    // Phase 5 instrumentation, placed AFTER the Enter above on purpose: this
    // trampoline enters the isolate itself, so asserting beforehand just reports
    // that it has not happened yet. Workers spawn threads
    // (worker_threading.zig:406), so what is worth checking is whether the Enter
    // actually took effect on THIS thread.
    v8.isolate_ownership.assertOwned(ctx.isolate, "worker.timerTrampoline");

    // Create HandleScope for V8 operations
    const handle_scope = v8.ffi.v8_HandleScope_New(ctx.isolate);
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get the callback function from the Global handle
    const callback_fn = v8.ffi.v8_Global_Get(ctx.isolate, ctx.callback_global) orelse return;

    // Get global object for 'this'
    const global_obj = v8.ffi.v8_Context_Global(wctx.context) orelse return;
    defer v8.ffi.v8_Object_Dispose(global_obj);

    // Call the callback function
    var empty_args: [1]*v8.ffi.Value = undefined;
    if (v8.ffi.v8_Function_Call(
        @ptrCast(callback_fn),
        wctx.context,
        @ptrCast(global_obj),
        0,
        &empty_args,
    )) |result| v8.ffi.v8_Value_Dispose(result);

    wctx.endTask();
}

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
    /// The realm is gone: its context was removed and released. The isolate
    /// goes one timer later (`disposeIsolateLater`).
    realm_gone,
    /// The isolate is disposed.
    disposed,
};

/// V8 Context for Worker execution
///
/// Creates and manages a V8 isolate and context for a worker.
/// Each worker gets its own isolate for complete memory isolation.
pub const WorkerV8Context = struct {
    /// V8 Isolate for this worker (separate from main thread)
    isolate: *v8.ffi.Isolate,

    /// V8 Context within the isolate
    context: *v8.ffi.Context,

    /// Script URL for error messages and import.meta.url
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

    /// Runtime context for WebIDL operations (MessagePort, etc.)
    /// This is heap-allocated because Context = *ContextData
    runtime_ctx_data: ?*runtime.ContextData = null,

    /// The realm's runtime context: the context manager's entry for `context`.
    /// Every Instance created in the realm points here - the global scope's
    /// first - and `scopeSettings` finds this worker by it.
    scope_ctx: ?runtime.Context = null,

    /// The global object's platform object: the realm's
    /// DedicatedWorkerGlobalScope. The realm's wrapper cache owns it, and
    /// frees it when the realm is removed.
    global_scope: ?*runtime.Instance = null,

    /// A function made in the realm that fires a MessageEvent at the global
    /// object (`makeMessageDispatcher`). Owned Global; released with the realm.
    message_dispatcher: ?*v8.ffi.Value = null,

    /// How deep this host has entered the isolate on the current stack. While
    /// it is above zero the worker's script may be running, and the realm must
    /// not be torn down under it.
    entered: u32 = 0,

    phase: Phase = .running,

    /// The timer that runs the next teardown step, while one is armed.
    teardown_timer: ?MessageDispatchTimer = null,

    /// The timer that pumps V8's posted tasks while nothing else would
    /// (`armPlatformPump`), while one is armed.
    platform_pump: ?MessageDispatchTimer = null,

    /// The owner has let go (`destroy`). The memory goes once this is set and
    /// the isolate is disposed, whichever comes last.
    owner_released: bool = false,

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
    ///
    /// The timer is set via setTimerInterface() when a worker context is set up.
    /// It remains available for the duration of the worker's script execution.
    pub fn getTimerInterface() ?runtime.TimerInterface {
        return current_worker_timer_interface;
    }

    /// Create a new V8 context for a worker
    ///
    /// This creates:
    /// 1. A new V8 isolate (separate from main thread)
    /// 2. A V8 context within that isolate, whose global object is a
    ///    DedicatedWorkerGlobalScope platform object
    /// 3. Sets up basic global scope
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy script URL
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);
        const effective_url = try getEffectiveWorkerUrl(allocator, script_url);
        errdefer allocator.free(effective_url);

        // Initialize V8 platform if not already done
        // NOTE: The main browser context should have already called
        // snapshot_loader.initializePlatformForSnapshots() which sets the
        // required V8 flags before platform init. If this is the first
        // V8 initialization, it won't support snapshot loading properly.
        v8.ffi.v8_Platform_Initialize();

        // Create V8 Isolate for this worker
        const isolate = v8.ffi.v8_Isolate_New() orelse {
            return error.V8IsolateCreationFailed;
        };
        errdefer v8.ffi.v8_Isolate_Dispose(isolate);

        // Enter the isolate temporarily to create the context. Exited before
        // returning - we re-enter when executing scripts - so the main isolate
        // stays current during Worker construction.
        v8.ffi.v8_Isolate_Enter(isolate);
        defer v8.ffi.v8_Isolate_Exit(isolate);

        // V8 requires any API call that creates a Local to be inside a
        // HandleScope ("Cannot create a handle without a HandleScope").
        const handle_scope = v8.ffi.v8_HandleScope_New(isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // HTML "run a worker" step 6: the realm's global object is a new
        // DedicatedWorkerGlobalScope. So the context is created from that
        // interface's template, which makes the global object one of its
        // platform objects, with its internal fields - Blink's
        // WorkerOrWorkletScriptController::Initialize does the same with the
        // interface template's InstanceTemplate(). A plain Context::New made a
        // bare object that faked `instanceof` with Symbol.hasInstance.
        const context = v8.ffi.v8_Context_NewWithGlobalConstructor(isolate, globalScopeTemplate(isolate)) orelse {
            return error.V8ContextCreationFailed;
        };
        errdefer v8.ffi.v8_Context_Dispose(context);

        // Enter the context for setup
        v8.ffi.v8_Context_Enter(context);
        defer v8.ffi.v8_Context_Exit(context);

        // Create runtime context for WebIDL operations
        const runtime_ctx_data = try allocator.create(runtime.ContextData);
        errdefer allocator.destroy(runtime_ctx_data);
        runtime_ctx_data.* = try runtime.ContextData.init(allocator, .{
            .engine_ctx = @ptrCast(context),
            .realm_info = .{
                .context_type = .dedicated_worker,
            },
        });

        self.* = .{
            .isolate = isolate,
            .context = context,
            .script_url = url_copy,
            .effective_url = effective_url,
            .worker_type = worker_type,
            .allocator = allocator,
            .runtime_ctx_data = runtime_ctx_data,
        };

        // Set up basic worker globals (self, globalThis)
        try self.setupWorkerGlobals();

        // Register essential WebIDL interfaces needed for worker scripts
        // This is a minimal subset needed for WPT tests
        self.registerWorkerInterfaces();

        live_contexts.append(std.heap.page_allocator, self) catch {};
        return self;
    }

    /// The DedicatedWorkerGlobalScope interface template in `isolate`, which
    /// must be entered. Templates belong to one isolate, and the registry is
    /// where every later lookup - the interface object installForScope puts on
    /// the global, a subclass's Inherit() - finds this one, so the global
    /// object and `DedicatedWorkerGlobalScope.prototype` share a template.
    fn globalScopeTemplate(isolate: *v8.ffi.Isolate) *v8.ffi.FunctionTemplate {
        const name = interfaces.DedicatedWorkerGlobalScope.Meta.name;
        if (v8.template_registry.getTemplateForIsolate(name, isolate)) |template| return template;
        const template = V8Interface(interfaces.DedicatedWorkerGlobalScope).createTemplate(isolate);
        v8.template_registry.register(name, template, isolate);
        return template;
    }

    /// Whether the worker runs tasks: not once its closing flag is set.
    pub fn runsTasks(self: *const Self) bool {
        return self.phase == .running;
    }

    /// Enter this worker's isolate and context, counting the entry.
    fn enter(self: *Self) void {
        self.entered += 1;
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
    }

    fn exit(self: *Self) void {
        v8.ffi.v8_Context_Exit(self.context);
        v8.ffi.v8_Isolate_Exit(self.isolate);
        self.entered -= 1;
    }

    /// The end of a task that ran script in this worker: a microtask
    /// checkpoint, the tasks V8 has posted to the platform for its isolate,
    /// and whatever the worker posted leaving for the page. Call with the
    /// isolate entered.
    fn endTask(self: *Self) void {
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
        _ = v8.pumpPlatformTasks(self.isolate);
        DedicatedWorker.flushPendingMessages();
        scheduleMessageDispatch(self);
        self.armPlatformPump(false);
    }

    /// How often an otherwise idle worker pumps while V8 has background work
    /// for it.
    const platform_pump_interval_ms = 1;

    /// Keep V8's posted tasks running while nothing else would.
    ///
    /// A worker's tasks run as timers on the page's loop, and each ends by
    /// pumping its isolate (`endTask`). But V8 posts some tasks from a
    /// background thread when its work there is done - an asynchronous
    /// WebAssembly compile settles its promise that way - and a worker with no
    /// timer due and no message arriving never pumped again, so the promise
    /// never settled. While V8 reports background work for the isolate, a pump
    /// stays armed: d8 keeps its message loop waiting on the same test
    /// (Shell::CompleteMessageLoop). `again` re-arms regardless - a pump that
    /// ran a task may have more to run.
    fn armPlatformPump(self: *Self, again: bool) void {
        if (self.platform_pump != null or !self.runsTasks()) return;
        if (!again and !v8.ffi.v8_Isolate_HasPendingBackgroundTasks(self.isolate)) return;
        const timer = getTimerInterface() orelse return;
        const id = timer.setTimeout(platform_pump_interval_ms, platformPumpCallback, self);
        if (id == 0) return;
        self.platform_pump = .{ .timer = timer, .id = id };
    }

    /// The pump: a task that runs what V8 has posted, then ends as every
    /// worker task does.
    fn platformPumpCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.platform_pump = null;
        if (!self.runsTasks()) return;

        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;

        self.enter();
        defer self.exit();
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Read before pumping: background work that ends between the two
        // posts its task after the pump looked, and a pending answer taken
        // first means one more round to find it.
        const pending = v8.ffi.v8_Isolate_HasPendingBackgroundTasks(self.isolate);
        const ran = v8.pumpPlatformTasks(self.isolate);
        if (ran) {
            DedicatedWorker.flushPendingMessages();
            scheduleMessageDispatch(self);
        }
        if (pending or ran) self.armPlatformPump(true);
    }

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
    /// delivered from now on. The realm and the isolate then go, from later
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
    /// the realm and isolate stay until the process ends, as they always did.
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
        if (self.entered > 0 or v8.ffi.v8_Isolate_GetCurrent() == self.isolate) {
            self.scheduleTeardown();
            return;
        }
        self.teardownRealm();
        self.disposeIsolateLater();
    }

    /// The realm's end: what "run a worker" does once the event loop exits -
    /// clear the active timers, disentangle the ports - and what Blink's
    /// WorkerOrWorkletScriptController::DisposeContextIfNeeded does on the V8
    /// side: clear the global's native info, then release the per-context
    /// data. Nothing runs in the realm again.
    fn teardownRealm(self: *Self) void {
        self.phase = .realm_gone;
        removeLive(self);
        cancelWorkerTimers(self);
        disarm(&self.platform_pump);

        {
            self.enter();
            defer self.exit();
            const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
            defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

            if (self.message_dispatcher) |dispatcher| v8.ffi.v8_Global_Dispose(dispatcher);
            self.message_dispatcher = null;

            // The global scope is freed with the realm's wrapper cache just
            // below; the global object must not point at it after.
            if (self.global_scope != null) self.bindGlobalFields(null);

            // The realm's per-context data: the callbacks its script
            // registered, its wrapper cache and every Instance in it - the
            // global scope first - and its realm. The entry is retired, so
            // `engine_ctx` reads null from here on: that is how anything
            // holding the realm across turns (a fetch) learns it has gone.
            context_manager.removeContext(self.context);
            self.global_scope = null;
            self.scope_ctx = null;

            // Fetches still in flight for this realm release their promises
            // now, while the isolate those belong to is alive.
            _ = async_fetch.sweep();
        }

        // MessagePort objects made in the realm used this, and went with the
        // wrapper cache above.
        if (self.runtime_ctx_data) |ctx_data| {
            ctx_data.deinit();
            self.allocator.destroy(ctx_data);
            self.runtime_ctx_data = null;
        }

        v8.ffi.v8_Context_Dispose(self.context);

        // What the process keeps per isolate: its templates in the registry
        // (disposed here - Globals of this isolate), its template storage and
        // its allocator in the isolate's data slots.
        v8.template_registry.clearForIsolate(self.isolate);
        v8.cleanupTemplateStorage(self.isolate, self.allocator);
        v8.isolate_allocator.deinitIsolateAllocator(self.isolate);
    }

    /// Dispose the isolate one timer after the realm is gone.
    ///
    /// A fetch whose response arrived before the realm ended has its settle
    /// task armed as a 0 ms timer on the page's loop
    /// (WindowOrWorkerGlobalScope.call_fetch). It has left the fetch list, so
    /// `async_fetch.sweep()` cannot reach it, and when it runs it finds the
    /// realm gone and releases its promise resolver - a Global in THIS
    /// isolate. Every such timer was armed before this one, so it runs first.
    /// And never from inside a page collection: v8_Isolate_Dispose frees every
    /// detached weak-callback record in the process, including the page's,
    /// whose callbacks V8 would then run on freed records.
    fn disposeIsolateLater(self: *Self) void {
        const timer = getTimerInterface() orelse return;
        const id = timer.setTimeout(0, disposeIsolateCallback, self);
        if (id == 0) return;
        self.teardown_timer = .{ .timer = timer, .id = id };
    }

    fn disposeIsolateCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.teardown_timer = null;
        v8.ffi.v8_Isolate_Dispose(self.isolate);
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
        self.dedicated_worker = null;

        if (self.phase == .running or self.phase == .closing) {
            self.phase = .closing;
            cancelWorkerTimers(self);
            disarm(&self.platform_pump);
            self.scheduleTeardown();
        }
    }

    /// The owner lets go of this object. Its memory goes once the owner has
    /// let go and the isolate is disposed, whichever comes last; a worker with
    /// no teardown ahead of it (no loop to run one on) goes now, leaving its
    /// realm and isolate to the process, as they always were.
    ///
    /// deinit() used to end in `allocator.destroy(self)`, which made its
    /// `is_deinitialized` guard read freed memory on the second of its two
    /// teardown paths. Splitting the release out gave the free one caller.
    pub fn destroy(self: *Self) void {
        self.owner_released = true;
        if (self.phase == .disposed or self.teardown_timer == null) self.free();
    }

    fn free(self: *Self) void {
        removeLive(self);
        disarm(&self.teardown_timer);
        disarm(&self.platform_pump);
        disarm(&self.message_dispatch);
        self.allocator.free(self.script_url);
        self.allocator.free(self.effective_url);
        self.allocator.destroy(self);
    }

    /// Exit the worker's V8 isolate and context
    /// Call this after script execution to return control to main isolate
    pub fn exitIsolate(self: *Self) void {
        self.exit();
    }

    /// Re-enter the worker's V8 isolate and context
    /// Call this before executing more scripts in the worker
    pub fn enterIsolate(self: *Self) void {
        self.enter();
    }

    /// Set up basic worker global scope (called during init)
    ///
    /// Sets up:
    /// - self -> globalThis
    /// - globalThis -> global object
    fn setupWorkerGlobals(self: *Self) !void {
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };
        defer v8.ffi.v8_Object_Dispose(global_obj);

        // `self` as a data property equal to the global object, as the window
        // does: testharness.js runs `(function(global_scope){...})(self)` and
        // needs `self === globalThis`.
        const self_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4) orelse {
            return error.StringCreationFailed;
        };
        defer v8.ffi.v8_String_Dispose(self_key);
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(self_key), @ptrCast(global_obj));
    }

    /// Register essential WebIDL interfaces needed in worker context
    ///
    /// This registers a minimal subset of interfaces commonly used by WPT tests:
    /// - URL, URLSearchParams (for URL manipulation)
    /// - Event, EventTarget (for event handling)
    /// - DOMException (for error handling)
    /// - WebSocket, CloseEvent, MessageEvent (for WebSocket API - Exposed in Worker per spec)
    ///
    /// Full interface registration (initializeBindings) can't be used directly
    /// because it requires the main isolate's context manager state.
    fn registerWorkerInterfaces(self: *Self) void {
        // Create HandleScope for interface registration
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Register URL interface
        const URL = V8Interface(interfaces.URL);
        URL.registerGlobal(self.isolate, self.context, "URL");

        // Register URLSearchParams interface
        const URLSearchParams = V8Interface(interfaces.URLSearchParams);
        URLSearchParams.registerGlobal(self.isolate, self.context, "URLSearchParams");

        // Register Event interface
        const Event = V8Interface(interfaces.Event);
        Event.registerGlobal(self.isolate, self.context, "Event");

        // Register EventTarget interface
        const EventTarget = V8Interface(interfaces.EventTarget);
        EventTarget.registerGlobal(self.isolate, self.context, "EventTarget");

        // Register DOMException interface
        const DOMException = V8Interface(interfaces.DOMException);
        DOMException.registerGlobal(self.isolate, self.context, "DOMException");

        // Register WebSocket interface (Exposed in Worker per WHATWG WebSocket spec)
        // WebIDL: [Exposed=(Window,Worker)] interface WebSocket : EventTarget { ... }
        const WebSocket = V8Interface(interfaces.WebSocket);
        WebSocket.registerGlobal(self.isolate, self.context, "WebSocket");

        // Register CloseEvent interface (needed for WebSocket close events)
        // WebIDL: [Exposed=(Window,Worker)] interface CloseEvent : Event { ... }
        const CloseEvent = V8Interface(interfaces.CloseEvent);
        CloseEvent.registerGlobal(self.isolate, self.context, "CloseEvent");

        // Register MessageEvent interface (needed for WebSocket message events)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessageEvent : Event { ... }
        const MessageEvent = V8Interface(interfaces.MessageEvent);
        MessageEvent.registerGlobal(self.isolate, self.context, "MessageEvent");

        // Register MessagePort interface (needed for port transfer)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessagePort : EventTarget { ... }
        const MessagePort = V8Interface(interfaces.MessagePort);
        MessagePort.registerGlobal(self.isolate, self.context, "MessagePort");

        // Register MessageChannel interface (for creating port pairs)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessageChannel { ... }
        const MessageChannel = V8Interface(interfaces.MessageChannel);
        MessageChannel.registerGlobal(self.isolate, self.context, "MessageChannel");

        // Register Worker interface (for nested workers)
        // WebIDL: [Exposed=(Window,DedicatedWorker,SharedWorker)] interface Worker : EventTarget { ... }
        // Per HTML Standard § 10.2.3: Workers can create other Workers (nested workers)
        const Worker = V8Interface(interfaces.Worker);
        Worker.registerGlobal(self.isolate, self.context, "Worker");

        // Register Blob interface (needed for blob URL creation in nested workers)
        // WebIDL: [Exposed=(Window,Worker)] interface Blob { ... }
        const Blob = V8Interface(interfaces.Blob);
        Blob.registerGlobal(self.isolate, self.context, "Blob");
    }

    /// The other half of "run a worker" step 6: the platform object behind
    /// the global object, and what V8 does not set up for a global made from
    /// an interface template.
    ///
    /// - The DedicatedWorkerGlobalScope Instance, created through its
    ///   interface in the realm's own runtime context, goes in internal field
    ///   0 of the global proxy - which the bindings read for every [Global]
    ///   member and every receiver check - and of the global object behind it
    ///   (Blink's SetNativeInfoForGlobal does both).
    /// - The realm's wrapper cache maps it to the global proxy, so handing
    ///   the scope to script (`self`, an event's currentTarget) returns the
    ///   global itself - as createWindowBoundToGlobal does for a Window.
    /// - The prototype chain: global -> DedicatedWorkerGlobalScope.prototype
    ///   -> WorkerGlobalScope.prototype -> EventTarget.prototype.
    /// - DedicatedWorkerGlobalScope's own members as own properties of the
    ///   global: WebIDL puts a [Global] interface's members on the object.
    fn bindGlobalScope(self: *Self, scope_ctx: runtime.Context) !void {
        const instance = try interfaces.DedicatedWorkerGlobalScope.init(self.allocator, scope_ctx);
        self.global_scope = instance;
        self.bindGlobalFields(instance);

        // The cache takes this Global.
        const global = v8.ffi.v8_Context_Global(self.context) orelse return error.NoGlobalObject;
        const cache_storage = scope_ctx.getV8WrapperCacheStorage() orelse {
            v8.ffi.v8_Object_Dispose(global);
            return error.NoWrapperCache;
        };
        const cache: *v8.WrapperCache = @ptrCast(@alignCast(cache_storage));
        try cache.set(instance, global, self.isolate);

        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse return error.NoGlobalObject;
        defer v8.ffi.v8_Object_Dispose(global_obj);
        self.linkGlobalPrototype(global_obj);

        const Binding = V8Interface(interfaces.DedicatedWorkerGlobalScope);
        Binding.registerPropertiesAsOwnOnObject(self.isolate, self.context, global_obj);
        Binding.registerMethodsAsOwnOnObject(self.isolate, self.context, global_obj);
    }

    /// Point internal field 0 of the global proxy, and of the global object
    /// behind it, at `instance` - or at nothing, before the instance is freed.
    fn bindGlobalFields(self: *Self, instance: ?*runtime.Instance) void {
        const global = v8.ffi.v8_Context_Global(self.context) orelse return;
        defer v8.ffi.v8_Object_Dispose(global);
        v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(instance));
        // The V1 GetPrototype on a global proxy is V8's from_javascript=false
        // path: it returns the hidden JSGlobalObject, not what script sees.
        const inner_val = v8.ffi.v8_Object_GetPrototype(global) orelse return;
        defer v8.ffi.v8_Value_Dispose(inner_val);
        const inner = v8.helpers.asObject(inner_val) orelse return;
        v8.ffi.v8_Object_SetAlignedPointerInInternalField(inner, 0, @ptrCast(instance));
    }

    /// Make DedicatedWorkerGlobalScope.prototype the global object's
    /// prototype, as script sees it.
    ///
    /// A [Global] object has an immutable prototype (WebIDL), so the global
    /// object's [[Prototype]] is fixed when the context is created - and V8
    /// fixes it to a placeholder: for a global made from a template, it
    /// builds the global object's constructor function itself, and that
    /// function's prototype is a fresh object on Object.prototype, holding
    /// only `constructor`. The placeholder is an ordinary object, so it is
    /// what gets linked, exactly as window_properties.zig does for a Window:
    ///   global -> placeholder -> DedicatedWorkerGlobalScope.prototype -> ...
    /// Its `constructor` goes, so `self.constructor` is the interface object.
    /// Only the V2 prototype calls: the V1 ones reach the hidden global object.
    fn linkGlobalPrototype(self: *Self, global: *v8.ffi.Object) void {
        const name = interfaces.DedicatedWorkerGlobalScope.Meta.name;
        const name_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, name.ptr, name.len) orelse return;
        defer v8.ffi.v8_String_Dispose(name_key);
        const interface_val = v8.ffi.v8_Object_Get(global, self.context, @ptrCast(name_key)) orelse return;
        defer v8.ffi.v8_Value_Dispose(interface_val);
        const interface_obj = v8.helpers.asObject(interface_val) orelse return;
        const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9) orelse return;
        defer v8.ffi.v8_String_Dispose(proto_key);
        const proto = v8.ffi.v8_Object_Get(interface_obj, self.context, @ptrCast(proto_key)) orelse return;
        defer v8.ffi.v8_Value_Dispose(proto);

        if (v8.ffi.v8_Object_SetPrototypeV2(global, self.context, proto)) return;
        const placeholder_val = v8.ffi.v8_Object_GetPrototypeV2(global) orelse return;
        defer v8.ffi.v8_Value_Dispose(placeholder_val);
        if (v8.ffi.v8_Value_StrictEquals(placeholder_val, proto)) return;
        const placeholder = v8.helpers.asObject(placeholder_val) orelse return;
        if (!v8.ffi.v8_Object_SetPrototypeV2(placeholder, self.context, proto)) return;
        const ctor_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "constructor", 11) orelse return;
        defer v8.ffi.v8_String_Dispose(ctor_key);
        _ = v8.ffi.v8_Object_Delete(placeholder, self.context, @ptrCast(ctor_key));
    }

    /// The function that fires a message event at this worker's global
    /// object: HTML's message port post message steps end in firing
    /// `message` at the port's owner, and a dedicated worker's implicit port
    /// belongs to its global scope - so the onmessage handler and every
    /// listener hear it. Made once, in the realm, with the realm's own
    /// MessageEvent and dispatchEvent, so script replacing either on the
    /// global changes nothing. `isTrusted` is false: a deviation, for want of
    /// an entry point that fires a trusted event (see AGENTS.md).
    fn makeMessageDispatcher(self: *Self) !void {
        const source =
            \\(function (MessageEvent, dispatchEvent, global) {
            \\  return function (data, ports) {
            \\    dispatchEvent.call(global, new MessageEvent("message", { data: data, ports: ports || [] }));
            \\  };
            \\})(MessageEvent, EventTarget.prototype.dispatchEvent, globalThis)
        ;
        const result = try self.executeScriptInternal(source);
        self.message_dispatcher = @ptrCast(@alignCast(result orelse return error.ExecutionFailed));
    }

    /// Set up full DedicatedWorkerGlobalScope with all required APIs
    ///
    /// Spec: HTML Standard § 10.2.4 DedicatedWorkerGlobalScope
    /// https://html.spec.whatwg.org/#dedicatedworkerglobalscope
    ///
    /// The global object's members come from the generated bindings: the
    /// DedicatedWorkerGlobalScope Instance behind it, and the interfaces on its
    /// prototype chain - WorkerGlobalScope's, which include every
    /// WindowOrWorkerGlobalScope member, and EventTarget's. Natives remain only
    /// where they are the one working implementation: postMessage (the bound
    /// operation does not serialize), importScripts (the bound one fetches and
    /// does not run), and the timers (the mixin's return NotImplemented).
    pub fn setupWorkerGlobalScope(self: *Self, dedicated_worker: *DedicatedWorker) !void {
        log.debug("[setupWorkerGlobalScope] self={*}, dedicated_worker={*}, agent={*}, agent.closing={}, agent.termination_state={s}", .{
            self,
            dedicated_worker,
            dedicated_worker.agent,
            dedicated_worker.agent.data.closing,
            @tagName(dedicated_worker.agent.termination_state),
        });

        self.dedicated_worker = dedicated_worker;

        // Enter worker's isolate and context for setup
        self.enter();
        defer self.exit();

        // Create HandleScope for V8 operations (required for context manager registration)
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Update our local runtime_ctx_data to have the timer from thread-local storage
        // This ensures that nested Worker constructors have access to the timer
        // Per HTML Standard § 10.2.3: Workers can create other Workers (nested workers)
        const timer_interface = WorkerV8Context.getTimerInterface();
        if (self.runtime_ctx_data) |ctx_data| {
            ctx_data.timer = timer_interface;
        }

        // CRITICAL: Register worker's V8 context with the context manager
        // This enables nested Workers to find the parent worker's context with timer support
        // when their constructor calls getOrCreateWithIsolate().
        // Per HTML Standard § 10.2.3: Workers can create other Workers (nested workers)
        //
        // The entry's runtime context is the realm's: the global scope and
        // every Instance the bindings create here point at it.
        self.scope_ctx = try v8.context_manager.getOrCreateWithExternalEventLoop(
            self.context,
            timer_interface,
            null, // Event loop not needed - workers use thread-local timers
            self.allocator,
        );

        // Record the worker's script URL as this context's document URL.
        //
        // This is the BASE URL for relative-URL resolution inside the worker.
        // Without it `new XMLHttpRequest().open("GET", "resources/x.txt")`
        // throws SyntaxError before send() is ever reached - the network was
        // never the broken part. `context_manager` is where the page URL lives
        // (its own comment says "for fetch relative URL resolution"); the window
        // path sets it and the worker path never did.
        //
        // Must come AFTER the registration above: setDocumentUrl looks the
        // context up in the manager's table and returns ContextNotFound if it
        // is not there yet.
        v8.context_manager.setDocumentUrl(self.context, self.script_url) catch |err| {
            std.log.warn("Failed to set worker document URL: {}", .{err});
        };

        // Every interface exposed in a DedicatedWorker scope, per WebIDL's
        // [Exposed]: Request, Response, Headers, TextEncoder, TextDecoder,
        // Blob, File, FileReader, the global scope interfaces themselves...
        interface_bindings.installForScope(self.isolate, self.context, .DedicatedWorker);

        // The platform object behind the global, its prototype chain and its
        // own members - after the interface objects, whose prototypes it links.
        try self.bindGlobalScope(self.scope_ctx.?);

        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };
        defer v8.ffi.v8_Object_Dispose(global_obj);

        // Set thread-local reference for callbacks to access this context
        current_worker_context = self;

        // Set up GLOBAL object for WPT tests
        // This is required by testharness.js to detect the execution context
        const global_script =
            \\self.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
        ;
        _ = try self.executeScriptInternal(global_script);

        // Set up console object (no-op implementation for workers)
        const console_script =
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
        ;
        _ = try self.executeScriptInternal(console_script);

        // Natives, where they are the one working implementation. Each is an
        // own data property of the global, shadowing the bound operation
        // further up the chain.
        //
        // postMessage() carries `self` as callback data so the callback always
        // uses the correct worker context, even for nested workers where the
        // thread-local current_worker_context might point to a different worker.
        {
            const external = v8.ffi.v8_External_New(self.isolate, @ptrCast(self)) orelse {
                return error.ExternalCreationFailed;
            };
            try self.installNative(global_obj, "postMessage", workerPostMessageCallback, @ptrCast(external), 1);
        }
        try self.installNative(global_obj, "importScripts", importScriptsCallback, null, 0);
        try self.installNative(global_obj, "setTimeout", workerSetTimeoutCallback, null, 1);
        try self.installNative(global_obj, "clearTimeout", workerClearTimeoutCallback, null, 0);
        try self.installNative(global_obj, "setInterval", workerSetIntervalCallback, null, 1);
        try self.installNative(global_obj, "clearInterval", workerClearTimeoutCallback, null, 0);
        // done() for the WPT harness: testharness.js defines its own, which
        // replaces this one when it loads.
        try self.installNative(global_obj, "done", workerDoneCallback, null, 0);

        // Polyfills for WindowOrWorkerGlobalScope attributes whose bound
        // getters have nothing to return yet (NotImplemented): crypto,
        // performance and indexedDB. They are defined as OWN data properties -
        // assigning would reach the getter-only accessors on
        // WorkerGlobalScope.prototype and, in sloppy mode, silently do nothing.
        //
        // Crypto API - Per Web Crypto spec: https://w3c.github.io/webcrypto/
        // (not cryptographically secure - Math.random).
        const crypto_script =
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
        ;
        _ = try self.executeScriptInternal(crypto_script);

        try self.makeMessageDispatcher();
    }

    /// Install `callback` as the own data property `name` of the global.
    fn installNative(
        self: *Self,
        global_obj: *v8.ffi.Object,
        comptime name: []const u8,
        callback: v8.ffi.FunctionCallback,
        data: ?*v8.ffi.Value,
        length: c_int,
    ) !void {
        const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, callback, data) orelse {
            return error.FunctionTemplateCreateFailed;
        };
        defer v8.ffi.v8_FunctionTemplate_Dispose(template);
        v8.ffi.v8_FunctionTemplate_SetLength(template, length);
        const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
            return error.FunctionCreateFailed;
        };
        defer v8.ffi.v8_Function_Dispose(func);
        const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, name.ptr, name.len) orelse {
            return error.StringCreationFailed;
        };
        defer v8.ffi.v8_String_Dispose(key);
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
    }

    /// Get the engine context pointer for WorkerContext.setEngineContext()
    pub fn getEngineContext(self: *Self) *EngineContext {
        // Cast Self pointer to opaque EngineContext
        return @ptrCast(self);
    }

    /// Get the underlying V8 context pointer
    /// Used for registering with the context manager to support nested workers
    pub fn getV8Context(self: *Self) *v8.ffi.Context {
        return self.context;
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

    /// Execute a script in this worker's context (with optional message processing)
    ///
    /// If process_messages is true, also processes any pending incoming messages
    /// after script execution, allowing the worker's onmessage handler to be invoked.
    ///
    /// For setup scripts (global scope initialization), pass process_messages=false
    /// since the onmessage handler isn't set up yet.
    fn executeScriptEx(self: *Self, source: []const u8, process_messages: bool) !?*anyopaque {
        // A worker whose closing flag is set runs no further task.
        if (!self.runsTasks()) return error.WorkerClosed;

        // Enter worker's isolate and context for script execution
        self.enter();
        defer self.exit();

        // CRITICAL: Create HandleScope for V8 handle allocation
        // V8 requires any API calls that create Local handles to be within a HandleScope.
        // Without this, v8_String_NewFromUtf8 and other handle-creating calls will crash
        // with "Cannot create a handle without a HandleScope".
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set current_worker_context so V8 callbacks (like postMessage) can access it
        // This allows workerPostMessageCallback to get the DedicatedWorker reference
        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;

        const result = try self.executeScriptInternal(source);

        // Process any incoming messages from the main thread (only if requested)
        // This allows the worker's onmessage handler (set up by the script) to run
        if (process_messages) {
            self.processIncomingMessagesInternal();
        }

        // What V8 posted while the script ran; and if it left background work
        // (an asynchronous compile), a pump to finish it.
        _ = v8.pumpPlatformTasks(self.isolate);
        self.armPlatformPump(false);

        return result;
    }

    /// Execute a script in this worker's context (processes messages after)
    ///
    /// This also processes any pending incoming messages after script execution,
    /// allowing the worker's onmessage handler to be invoked.
    pub fn executeScript(self: *Self, source: []const u8) !?*anyopaque {
        return self.executeScriptEx(source, true);
    }

    /// Execute a script without processing messages (for setup scripts)
    ///
    /// Use this for global scope initialization scripts that run before the
    /// worker's onmessage handler is set up.
    fn executeScriptNoMessages(self: *Self, source: []const u8) !?*anyopaque {
        return self.executeScriptEx(source, false);
    }

    /// Process incoming messages - internal version (already in isolate context)
    fn processIncomingMessagesInternal(self: *Self) void {
        const dedicated_worker = self.dedicated_worker orelse return;
        const inside_port = dedicated_worker.port_pair.inside_port;

        while (inside_port.message_queue.items.len > 0) {
            const msg = inside_port.message_queue.orderedRemove(0);
            // A closing worker's tasks are discarded, the message's among them.
            if (self.runsTasks()) dispatchMessageToWorkerInternal(self, msg);
            msg.deinit();
        }
    }

    /// Deliver one message the page posted: fire a MessageEvent at the global
    /// object with the message's data (`fireMessageEvent`). Call with the
    /// context entered.
    ///
    /// For v8_serialized messages (from cross-isolate ArrayBuffer transfers), we use
    /// V8's ValueDeserializer to reconstruct the ArrayBuffer in this isolate.
    fn dispatchMessageToWorkerInternal(self: *Self, msg: *workers.message_channel.QueuedMessage) void {
        const serialized = msg.data;

        // Handle v8_serialized messages (cross-isolate ArrayBuffer transfers)
        if (serialized.type == .v8_serialized) {
            self.dispatchV8SerializedMessage(serialized);
            return;
        }

        // Worker.postMessage sends a message without a transfer list as the
        // JSON of its value; parse it back in this realm. A string that is not
        // JSON is its own data.
        const json_str: []const u8 = switch (serialized.type) {
            .primitive => switch (serialized.data.primitive) {
                .string => |s| s,
                .undefined => "null",
                .null => "null",
                .boolean => |b| if (b) "true" else "false",
                .number => "0", // TODO: Proper number serialization
                .bigint => "0", // TODO: Proper bigint serialization
            },
            .string_object => serialized.data.string_object, // Boxed String
            else => return, // Can't convert complex types to simple string
        };

        // The parse hands back a Local in the caller's scope; the call below
        // takes Globals.
        const data: *v8.ffi.Value = if (v8.ffi.v8_JSON_Parse_FromBuffer(self.context, json_str.ptr, @intCast(json_str.len))) |parsed|
            v8.ffi.v8_Value_ToGlobal(self.isolate, @ptrCast(parsed)) orelse return
        else
            @ptrCast(v8.ffi.v8_String_NewFromUtf8(self.isolate, json_str.ptr, @intCast(json_str.len)) orelse return);
        defer v8.ffi.v8_Value_Dispose(data);
        self.fireMessageEvent(data, null);
    }

    /// Fire a MessageEvent carrying `data` (and `ports`, an array) at the
    /// global object, through the realm's dispatcher, then run the microtask
    /// checkpoint that ends the task. Call with the context entered.
    fn fireMessageEvent(self: *Self, data: *v8.ffi.Value, ports: ?*v8.ffi.Value) void {
        const dispatcher = self.message_dispatcher orelse return;
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse return;
        defer v8.ffi.v8_Object_Dispose(global_obj);
        const no_ports: ?*v8.ffi.Value = if (ports == null) @ptrCast(v8.ffi.v8_Array_New(self.isolate, 0)) else null;
        defer if (no_ports) |empty| v8.ffi.v8_Value_Dispose(empty);
        var args = [_]*v8.ffi.Value{ data, ports orelse no_ports.? };
        if (v8.ffi.v8_Function_Call(
            @ptrCast(dispatcher),
            self.context,
            @ptrCast(global_obj),
            2,
            &args,
        )) |result| v8.ffi.v8_Value_Dispose(result);
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }

    /// Dispatch a v8_serialized message using cross-isolate deserialization
    ///
    /// This handles messages that contain transferred ArrayBuffers. The data was
    /// serialized in the main isolate and needs to be deserialized in this worker's isolate.
    fn dispatchV8SerializedMessage(self: *Self, serialized: *workers.message_channel.SerializedValue) void {
        const v8_data = serialized.data.v8_serialized;

        // Build ArrayBufferTransferData array for deserialization
        var arraybuffer_data: [64]v8.ffi.ArrayBufferTransferData = undefined;
        const ab_count = @min(v8_data.transferred_arraybuffers.len, 64);

        for (0..ab_count) |i| {
            const transferred = v8_data.transferred_arraybuffers[i];
            arraybuffer_data[i] = .{
                .data = if (transferred.data.len > 0) transferred.data.ptr else null,
                .size = transferred.byte_length,
            };
        }

        // Deserialize using cross-isolate API in this worker's isolate
        var error_code: i32 = 0;
        const v8_value = v8.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(
            v8_data.serialized_bytes.ptr,
            v8_data.serialized_bytes.len,
            &arraybuffer_data,
            ab_count,
            &error_code,
        );

        if (v8_value == null or error_code != 0) {
            std.log.warn("[Worker] dispatchV8SerializedMessage: deserialization failed with error {}", .{error_code});
            return;
        }

        // Create ports array from transferred MessagePorts
        // Per HTML Standard § 9.4.4: create new MessagePort wrappers in destination realm
        const port_count = v8_data.transferred_ports.len;

        const ports_array: *v8.ffi.Value = if (port_count > 0) blk: {
            // Create V8 array for ports
            const arr = v8.ffi.v8_Array_New(self.isolate, @intCast(port_count));

            for (v8_data.transferred_ports, 0..) |port_data, i| {
                // Get the worker's runtime context
                const runtime_ctx = self.runtime_ctx_data orelse {
                    std.log.warn("[Worker] No runtime context for MessagePort creation", .{});
                    continue;
                };

                // Create new WebIDL MessagePort wrapper in this isolate
                // Use initWithInternal to wrap the existing internal port
                // Pass the internal port pointer (will be cast to correct type by initWithInternal)
                const port_instance = MessagePortImpl.initWithInternal(
                    self.allocator,
                    interfaces.MessagePort.State,
                    &interfaces.MessagePort.vtable,
                    runtime_ctx,
                    @ptrCast(@alignCast(port_data.internal_port)),
                ) catch {
                    std.log.warn("[Worker] Failed to create MessagePort wrapper", .{});
                    continue;
                };

                // Wrap the instance as a V8 object using template registry
                const port_v8_obj = v8.template_registry.wrapInstanceAsV8Object(
                    port_instance,
                    "MessagePort",
                    self.isolate,
                    self.context,
                ) catch {
                    std.log.warn("[Worker] Failed to wrap MessagePort as V8 object", .{});
                    continue;
                };

                // Add to array
                _ = v8.ffi.v8_Array_Set(@ptrCast(arr), self.context, @intCast(i), @ptrCast(port_v8_obj));
            }

            break :blk @ptrCast(arr);
        } else @ptrCast(v8.ffi.v8_Array_New(self.isolate, 0));
        defer v8.ffi.v8_Value_Dispose(ports_array);
        defer v8.ffi.v8_Value_Dispose(v8_value.?);

        self.fireMessageEvent(v8_value.?, ports_array);
    }

    /// Dispatch error to self.onerror handler (OnErrorEventHandler)
    ///
    /// Spec: HTML Standard § 10.1.5.1 "Report the error"
    /// https://html.spec.whatwg.org/#report-the-error
    ///
    /// The OnErrorEventHandler receives 5 arguments:
    ///   1. message (DOMString) - the error message
    ///   2. filename (USVString) - the script URL
    ///   3. lineno (unsigned long) - the line number
    ///   4. colno (unsigned long) - the column number
    ///   5. error (Error) - the Error object
    ///
    /// If the handler returns true, the error is considered handled and
    /// should NOT propagate to the parent Worker object.
    ///
    /// Returns true if the handler was called and returned true (error handled).
    /// Returns false if handler not set, not callable, returned false, or threw.
    fn dispatchSelfOnerror(
        self: *Self,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    ) bool {
        // Get the global object
        const global = v8.ffi.v8_Context_Global(self.context) orelse return false;

        // Get the "onerror" property from global (self.onerror)
        const onerror_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "onerror", 7) orelse return false;
        const onerror_value = v8.ffi.v8_Object_Get(global, self.context, @ptrCast(onerror_key)) orelse return false;

        // Check if it's a function
        if (!v8.ffi.v8_Value_IsFunction(onerror_value)) {
            return false;
        }

        // Create the 5 arguments for OnErrorEventHandler:
        // 1. message (string)
        const msg_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, message.ptr, @intCast(message.len)) orelse return false;

        // 2. filename (string)
        const filename_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, filename.ptr, @intCast(filename.len)) orelse return false;

        // 3. lineno (number)
        const lineno_num = v8.ffi.v8_Integer_New(self.isolate, @intCast(lineno));

        // 4. colno (number)
        const colno_num = v8.ffi.v8_Integer_New(self.isolate, @intCast(colno));

        // 5. error (Error object) - create an Error with the message
        const error_obj = v8.ffi.v8_Exception_ErrorInContext(self.context, msg_str) orelse return false;

        // Build args array
        var args = [5]*v8.ffi.Value{
            @ptrCast(msg_str),
            @ptrCast(filename_str),
            @ptrCast(lineno_num),
            @ptrCast(colno_num),
            error_obj,
        };

        // Call the onerror function with global as 'this'
        const onerror_fn: *v8.ffi.Function = @ptrCast(onerror_value);
        const result = v8.ffi.v8_Function_Call(onerror_fn, self.context, @ptrCast(global), 5, &args);

        // Check if result is truthy (true means error was handled)
        if (result) |r| {
            return v8.ffi.v8_Value_BooleanValue(r, self.isolate);
        }

        return false;
    }

    /// Send an error event to the parent Worker object via the callback mechanism.
    ///
    /// This schedules a WorkerErrorEvent to be dispatched on the parent thread.
    /// The main thread's event loop will dispatch the error via Worker.onerror
    /// or addEventListener('error').
    ///
    /// Spec: HTML Standard § 10.2.5 step 11
    /// "Queue a task to fire an event named error at worker."
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
            filename,
            lineno,
            colno,
            null, // error_value - V8 value doesn't cross isolate boundary safely
        ) catch return;

        // Schedule error dispatch to parent thread via timer (0ms)
        // This ensures we're in the main isolate context when dispatching
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

    /// Execute a script - internal version that assumes context is already entered
    fn executeScriptInternal(self: *Self, source: []const u8) !?*anyopaque {
        // Create V8 string from source
        const source_str = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            source.ptr,
            @intCast(source.len),
        ) orelse {
            return error.StringCreationFailed;
        };

        // Compile script using safe version
        const compile_result = v8.ffi.v8_Script_Compile_Safe(self.context, source_str);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.error_info) |err_info| {
            const err_msg = err_info.getMessage() orelse "Script compilation failed";
            const filename = err_info.getResourceName() orelse self.script_url;
            const lineno: u32 = if (err_info.line_number >= 0) @intCast(err_info.line_number) else 0;
            const colno: u32 = if (err_info.column_number >= 0) @intCast(err_info.column_number) else 0;

            std.log.err("[Worker] Script compilation failed: {s}", .{err_msg});
            if (err_info.getStackTrace()) |st| {
                std.log.err("[Worker] Stack trace: {s}", .{st});
            }

            // Dispatch to self.onerror first, then propagate to parent if not handled
            const error_handled = self.dispatchSelfOnerror(err_msg, filename, lineno, colno);
            if (!error_handled) {
                self.sendErrorToParent(err_msg, filename, lineno, colno);
            }

            return error.CompilationFailed;
        }

        const script = compile_result.script orelse return error.CompilationFailed;

        // Run script using safe version
        const run_result = v8.ffi.v8_Script_Run_Safe(self.context, script);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info) |err_info| {
            const err_msg = err_info.getMessage() orelse "Script execution failed";
            const filename = err_info.getResourceName() orelse self.script_url;
            const lineno: u32 = if (err_info.line_number >= 0) @intCast(err_info.line_number) else 0;
            const colno: u32 = if (err_info.column_number >= 0) @intCast(err_info.column_number) else 0;

            std.log.err("[Worker] Script execution failed: {s}", .{err_msg});
            if (err_info.getStackTrace()) |st| {
                std.log.err("[Worker] Stack trace: {s}", .{st});
            }

            // Dispatch to self.onerror first, then propagate to parent if not handled
            const error_handled = self.dispatchSelfOnerror(err_msg, filename, lineno, colno);
            if (!error_handled) {
                self.sendErrorToParent(err_msg, filename, lineno, colno);
            }

            return error.ExecutionFailed;
        }

        // Run microtasks after script execution
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        return @ptrCast(run_result.value);
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
    _ = source_url; // Used for error messages (TODO)
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    return self.executeScript(source);
}

/// Compile and run a module
fn compileAndRunModuleCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!void {
    _ = source_url; // TODO: Used for import resolution
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));

    // For now, execute as script. Full module support needs more V8 FFI.
    _ = try self.executeScript(source);
}

/// Run microtask checkpoint
fn runMicrotasksCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
}

/// Dispose engine context
fn disposeContextCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    self.deinit();
}

// ============================================================================
// V8 Callbacks for Worker Global Functions
// ============================================================================

// ============================================================================
// V8 Timer Callbacks
// ============================================================================

/// V8 callback for setTimeout() - schedules a one-shot timer
fn workerSetTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // Owned, and needed only to convert the delay: the timer runs in its
    // worker's own context.
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.ffi.v8_Context_Dispose(v8_context);

    // Get the callback function (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Get delay (second argument, default 0)
    var delay_ms: i64 = 0;
    if (info.v8_FunctionCallbackInfo_Length() >= 2) {
        const delay_value = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(delay_value)) {
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, v8_context);
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get the worker context
    const worker_ctx = current_worker_context orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Get the timer interface from the browser context (shares libuv event loop)
    const timer = WorkerV8Context.getTimerInterface() orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Initialize timer storage if needed
    initWorkerTimerStorage(worker_ctx.allocator);

    // Create Global handle for the callback function
    const callback_global = v8.ffi.v8_Value_ToGlobal(isolate, callback_value) orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Allocate timer context
    const timer_ctx = worker_ctx.allocator.create(WorkerTimerContext) catch {
        v8.ffi.v8_Global_Dispose(callback_global);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    timer_ctx.* = .{
        .callback_global = callback_global,
        .isolate = isolate,
        .current_timer_id = 0, // Will be updated after scheduling
        .is_interval = false,
        .interval_delay_ms = 0,
        .nesting_level = native_timer.nesting_level +| 1,
        .allocator = worker_ctx.allocator,
        .cancelled = false,
        .worker_v8_context = worker_ctx,
    };

    // Apply HTML §8.6's clamp. This was missing entirely on the worker path: a
    // nested `setTimeout(f, 0)` in a worker ran unclamped while the identical code
    // in a window was clamped to 4ms, because the clamp lived in the window's
    // binding layer rather than anywhere both could reach.
    //
    // Clamped against the CURRENT level, not the new timer's. The spec reads the
    // current nesting level in step 4, clamps in step 6, and only then increments
    // for the timer it is creating - so clamping with `timer_ctx.nesting_level`
    // (which is already current + 1) would start clamping one level too early and
    // disagree with the window path.
    const clamped_ms = native_timer.clampTimeout(delay_ms, native_timer.nesting_level);
    const delay_u64: u64 = if (clamped_ms >= 0) @intCast(clamped_ms) else 0;
    const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);

    if (timer_id == 0) {
        v8.ffi.v8_Global_Dispose(callback_global);
        worker_ctx.allocator.destroy(timer_ctx);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Update the timer_id in the context for cleanup tracking
    timer_ctx.current_timer_id = timer_id;

    // Register for tracking
    registerWorkerTimerContext(timer_id, timer_ctx);

    // Return timer ID
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

/// V8 callback for setInterval() - schedules a repeating timer
fn workerSetIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // Owned, and needed only to convert the delay: the timer runs in its
    // worker's own context.
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.ffi.v8_Context_Dispose(v8_context);

    // Get the callback function (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Get delay (second argument, default 0)
    var delay_ms: i64 = 0;
    if (info.v8_FunctionCallbackInfo_Length() >= 2) {
        const delay_value = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(delay_value)) {
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, v8_context);
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get the worker context
    const worker_ctx = current_worker_context orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Get the timer interface from the browser context (shares libuv event loop)
    const timer = WorkerV8Context.getTimerInterface() orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Initialize timer storage if needed
    initWorkerTimerStorage(worker_ctx.allocator);

    // Create Global handle for the callback function
    const callback_global = v8.ffi.v8_Value_ToGlobal(isolate, callback_value) orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Allocate timer context
    const timer_ctx = worker_ctx.allocator.create(WorkerTimerContext) catch {
        v8.ffi.v8_Global_Dispose(callback_global);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // setInterval takes the same clamp - §8.6's steps are shared by both, and the
    // repeat delay is the clamped one, or a nested `setInterval(f, 0)` would spin
    // the loop as fast as it can schedule.
    const clamped_interval_ms = native_timer.clampTimeout(delay_ms, native_timer.nesting_level);
    const delay_u64: u64 = if (clamped_interval_ms >= 0) @intCast(clamped_interval_ms) else 0;

    timer_ctx.* = .{
        .callback_global = callback_global,
        .isolate = isolate,
        .current_timer_id = 0, // Will be updated after scheduling
        .is_interval = true,
        .nesting_level = native_timer.nesting_level +| 1,
        .interval_delay_ms = delay_u64,
        .allocator = worker_ctx.allocator,
        .cancelled = false,
        .worker_v8_context = worker_ctx,
    };

    // Schedule the timer using the browser's libuv-backed timer interface
    const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);

    if (timer_id == 0) {
        v8.ffi.v8_Global_Dispose(callback_global);
        worker_ctx.allocator.destroy(timer_ctx);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Update the timer_id in the context for cleanup tracking
    timer_ctx.current_timer_id = timer_id;

    // Register for tracking
    registerWorkerTimerContext(timer_id, timer_ctx);

    // Return timer ID
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(timer_id));
    info.setReturnValue(@ptrCast(result));
}

/// V8 callback for clearTimeout() / clearInterval() - cancels a timer
fn workerClearTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get timer ID (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const id_value = info.get(0);
    if (!v8.ffi.v8_Value_IsNumber(id_value)) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const timer_id_f64 = v8.ffi.v8_Value_NumberValue(id_value, v8_context);
    if (std.math.isNan(timer_id_f64) or std.math.isInf(timer_id_f64) or timer_id_f64 < 0) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const timer_id: runtime.TimerId = @intFromFloat(timer_id_f64);

    // Clean up the timer context (this also cancels via browser_context timer interface)
    unregisterWorkerTimerContext(timer_id);

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// V8 callback for postMessage() - sends message to main thread
///
/// Spec: HTML Standard § 10.2.4.1 postMessage(message, transfer)
/// https://html.spec.whatwg.org/#dom-dedicatedworkerglobalscope-postmessage
///
/// This function:
/// 1. Gets the message argument from V8 FunctionCallbackInfo
/// 2. Serializes it to JSON using V8's JSON.stringify
/// 3. Stores the JSON string in a JSValue
/// 4. Posts it through the message port to the main thread
fn workerPostMessageCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const argc = info.v8_FunctionCallbackInfo_Length();

    if (argc < 1) return;
    const message_arg = info.get(0);

    // CRITICAL: Get WorkerV8Context from callback data, NOT from thread-local.
    // For nested workers, the thread-local current_worker_context may point to
    // the wrong worker (e.g., inner worker instead of outer worker).
    // The callback data was set when this postMessage function was created,
    // so it always points to the correct worker.
    const data = info.getData();
    // The callback data is a V8 External containing our WorkerV8Context pointer
    const worker_ctx_ptr = v8.ffi.v8_External_Value(@ptrCast(data));
    const self: ?*WorkerV8Context = if (worker_ctx_ptr) |ptr| @ptrCast(@alignCast(ptr)) else null;

    // Get required size for JSON buffer
    var dummy_buf: [1]u8 = undefined;
    const required_size = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        &dummy_buf,
        0,
    );
    if (required_size <= 0) return;

    // Allocate buffer dynamically based on required size and stringify again
    // The "complete" message from testharness.js can be quite large (9000+ bytes)
    // containing all test results, so we need dynamic allocation.
    // NOTE: `self` is now obtained from callback data (see above), not current_worker_context
    const worker_ctx = self orelse return;
    const json_buffer = worker_ctx.allocator.alloc(u8, @intCast(required_size + 1)) catch return;
    defer worker_ctx.allocator.free(json_buffer);

    const written = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        json_buffer.ptr,
        @intCast(json_buffer.len),
    );
    if (written <= 0) return;

    const json_str = json_buffer[0..@intCast(written)];
    const dedicated_worker = worker_ctx.dedicated_worker orelse return;

    // DEBUG: Log the message being posted
    const preview_len = @min(json_str.len, 50);
    log.debug("[workerPostMessageCallback] json_str len={d}, preview={s}, worker_ctx={*}, closing={}, terminated={}", .{ json_str.len, json_str[0..preview_len], worker_ctx, dedicated_worker.agent.isClosing(), dedicated_worker.agent.isTerminated() });

    // A terminated worker's messages are never delivered ("terminate a
    // worker" step 4). A closing one's are: the task that called close() runs
    // to its end, and what it posts goes out
    // (workers/interfaces/WorkerGlobalScope/close/sending-messages).
    if (dedicated_worker.agent.isTerminated() or worker_ctx.phase == .realm_gone) {
        log.debug("[workerPostMessageCallback] Agent is terminated, returning", .{});
        return;
    }

    // Serialize the JSON string for posting
    var js_value = workers.message_channel.JSValue{ .string = json_str };
    const serialized = workers.message_channel.serializeForPostMessage(
        dedicated_worker.allocator,
        &js_value,
    ) catch return;

    // Create QueuedMessage
    const msg = workers.message_channel.QueuedMessage.init(dedicated_worker.allocator, serialized, null) catch {
        serialized.deinit();
        dedicated_worker.allocator.destroy(serialized);
        return;
    };

    // Append to pending_messages for deferred dispatch
    workers.dedicated_worker.DedicatedWorker.appendPendingMessage(
        dedicated_worker.port_pair.outside_port,
        msg,
    ) catch {
        msg.deinit();
        return;
    };
}

/// V8 callback for importScripts(...urls) - loads and executes scripts synchronously
///
/// Spec: HTML Standard § 10.2.4.2 importScripts(urls)
/// https://html.spec.whatwg.org/#dom-workerglobalscope-importscripts
fn importScriptsCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse {
        std.log.warn("importScriptsCallback: no current_worker_context", .{});
        return;
    };

    // Get isolate and context from the callback info
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("importScriptsCallback: no V8 context", .{});
        return;
    };

    // Get number of arguments (URLs to import)
    const argc = info.v8_FunctionCallbackInfo_Length();
    if (argc < 1) {
        return;
    }

    // Process each URL argument
    var i: c_int = 0;
    while (i < argc) : (i += 1) {
        const arg = info.get(i);

        // Convert to string
        const str = v8.ffi.v8_Value_ToString(arg, v8_context) orelse continue;
        const len = v8.ffi.v8_String_Utf8Length(str);
        if (len == 0) continue;

        // Get URL string
        var buf: [4096]u8 = undefined;
        const actual_len = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(buf.len));
        if (actual_len <= 0) continue;

        const url = buf[0..@intCast(actual_len)];

        // Fetch the script
        // Per HTML Standard § 10.2.4.2 importScripts(urls):
        // "For each url of urls: Let urlRecord be the result of parsing url with worker global scope's url"
        // The worker's script_url is the base for resolving relative URLs
        var fetched_script = script_fetch.fetchWorkerScript(self.allocator, url, .{
            .is_import_scripts = true,
            .worker_type = .classic,
            .origin = self.script_url, // Base URL for relative path resolution
        }) catch |err| {
            std.log.warn("importScripts: failed to fetch '{s}': {}", .{ url, err });
            // Per spec, throw NetworkError on fetch failure
            // For now, just continue to next script
            continue;
        };
        defer fetched_script.deinit();

        // Execute the script synchronously. Not executeScript(): that also
        // delivers the page's queued messages when the script ends, which
        // would run the worker's message handlers in the middle of the
        // importScripts() call.
        _ = self.executeScriptNoMessages(fetched_script.source) catch |err| {
            std.log.warn("importScripts: failed to execute '{s}': {}", .{ url, err });
            continue;
        };
    }
}

/// V8 callback for done() - signals test completion (WPT testharness)
///
/// This is called by worker test scripts to signal they're done running tests.
/// The worker then posts a completion message to the main thread.
fn workerDoneCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    _ = info;
    // Note: The actual done() function in testharness.js handles posting
    // the completion message. We just need to have this function exist
    // so the worker script can call it.
}

/// Process incoming messages from the main thread
///
/// This should be called from within the worker's V8 context after
/// the worker script has set up its onmessage handler.
pub fn processIncomingMessages(worker_ctx: *WorkerV8Context) void {
    const dedicated_worker = worker_ctx.dedicated_worker orelse return;

    // A closing worker runs no further task; its messages are discarded
    // (close() step 1, "terminate a worker" step 2), and once its realm is
    // gone there is nothing to deliver them to.
    if (!worker_ctx.runsTasks()) {
        emptyPortQueue(dedicated_worker.port_pair.inside_port);
        return;
    }

    // Process messages inside worker isolate context
    {
        worker_ctx.enter();
        defer worker_ctx.exit();

        // Create HandleScope for V8 operations (required for string creation in dispatchMessageToWorkerInternal)
        const handle_scope = v8.ffi.v8_HandleScope_New(worker_ctx.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set current_worker_context for any callbacks
        const prev_context = current_worker_context;
        current_worker_context = worker_ctx;
        defer current_worker_context = prev_context;

        worker_ctx.processIncomingMessagesInternal();

        // The end of the task: V8's posted tasks, and a pump if background
        // work is left.
        _ = v8.pumpPlatformTasks(worker_ctx.isolate);
        worker_ctx.armPlatformPump(false);
    }
    // Block exits here, so we're now outside the worker isolate

    // CRITICAL: Flush pending messages AFTER exiting worker isolate
    // When worker's onmessage handler calls self.postMessage(), messages are queued
    // in pending_messages (not directly to outside_port) to avoid HandleScope issues.
    // Now that we've exited the worker isolate, flush them to the actual port.
    workers.dedicated_worker.DedicatedWorker.flushPendingMessages();
}

/// Drop every message queued on `port`.
fn emptyPortQueue(port: anytype) void {
    while (port.message_queue.items.len > 0) {
        const msg = port.message_queue.orderedRemove(0);
        msg.deinit();
    }
}

// ============================================================================
// Error Types
// ============================================================================

pub const WorkerV8Error = error{
    V8IsolateCreationFailed,
    V8ContextCreationFailed,
    NoGlobalObject,
    StringCreationFailed,
    CompilationFailed,
    ExecutionFailed,
    OutOfMemory,
    FunctionTemplateCreateFailed,
    FunctionCreateFailed,
};

// ============================================================================
// Tests
// ============================================================================

test "WorkerV8Context - struct definition" {
    // Just verify the struct can be referenced
    // Actual V8 tests require the V8 runtime
    const T = WorkerV8Context;
    try std.testing.expect(@sizeOf(T) > 0);
}
