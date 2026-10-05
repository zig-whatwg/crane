//! The worker host: the HTML half of "run a worker".
//!
//! Spec: HTML Standard § 10.2.4 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! A worker is an agent and a realm in it whose global object is a
//! DedicatedWorkerGlobalScope or a SharedWorkerGlobalScope. The ENGINE half -
//! making the agent and the realm, binding the global object, running script,
//! the engine's own posted tasks, the realm's end - is the JavaScript
//! engine's, and this file reaches it only through the engine protocol
//! (`@import("engine")`; AGENTS.md, "The engine boundary"; V8's side is
//! src/runtime/engines/v8/worker_realm.zig). What is here is the worker as
//! HTML describes it:
//!
//! - its event loop. Every worker - dedicated or shared - runs on a thread
//!   of its own (docs/instances.md, "Decisions"; html/worker_thread.zig): its
//!   agent, its realm and this host are made on that thread, its tasks and
//!   timers run on the thread's WorkerEventLoop, and its end runs there
//!   synchronously once its loop stops (`startDedicatedWorker`, the shared
//!   worker manager's `startSharedWorker`, `ThreadHost`);
//! - its timers (§ 8.6), messages in both directions (a dedicated worker's
//!   implicit port is one end of a dom.port_channels Channel, whose other end
//!   is its Worker object's outside port; a shared worker's ports arrive
//!   through `connect`), errors reported to its global scope and then to its
//!   Worker object;
//! - the shared worker manager's steps (§ 10.2.6.4), with the Browser's
//!   SharedWorkerManager (shared_worker_manager.zig): the worker a
//!   SharedWorker constructor connects to, or runs, and its owner set;
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
// The request a script fetch builds, populated from its client.
const script_request = @import("script_request.zig");
const fetch_mod = @import("fetch");

// Unhandled promise rejections: HostPromiseRejectionTracker and "notify about
// rejected promises", for the worker's global as for a window's.
const rejected_promises = @import("rejected_promises.zig");

// Firing an event at a target from outside EventTarget's hierarchy, and the
// MessagePort transfer steps.
const fire_event = @import("dom").fire_event;
const message_ports = @import("dom").message_ports;

// A string timer handler's checks at the call: Trusted Types' "get trusted
// type compliant string", and CSP's EnsureCSPDoesNotBlockStringCompilation
// over the global scope's CSP list.
const trusted_types = @import("dom").trusted_types;
const code_generation = @import("code_generation.zig");

// A realm's fetches in flight, released when the realm goes.
const async_fetch = @import("fetch").algorithms.async_fetch;

// Worker types from html_core
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerType = workers.WorkerType;

// A dedicated worker on a thread of its own: the link both threads share,
// the thread's body and loop, and the Browser's registry of live workers.
const WorkerLink = @import("worker_link.zig").WorkerLink;
const WorkerThread = @import("worker_thread.zig").WorkerThread;
const WorkerEventLoop = @import("worker_event_loop.zig").WorkerEventLoop;
const WorkerRegistry = @import("worker_registry.zig").WorkerRegistry;

/// HTML's shared worker manager: a supplement of the Browser's scope.
pub const SharedWorkerManager = @import("shared_worker_manager.zig").SharedWorkerManager;

// The implicit ports' channel, whose ends cross threads.
const port_channels = @import("dom").port_channels;
const PortMessage = port_channels.PortMessage;

// ============================================================================
// Timers (HTML § 8.6)
// ============================================================================

// The timer nesting level and the § 8.6 clamp are the window's too
// (runtime.timer): a worker's task saves and restores the level around its
// callback, so the page's tasks, which never run inside it, keep theirs.

/// What a timer runs: the timer initialization steps' `handler` after step 1.
const TimerHandler = union(enum) {
    /// A Function, invoked with the timer's arguments (step 10.7). OWNED,
    /// with its callback context.
    function: engine.CallbackFunction,
    /// A string, compiled as a classic script when the timer fires (step
    /// 10.8) - what step 1's Trusted Types check left of the handler. OWNED
    /// (the timer's allocator).
    string: []u8,
};

/// setTimeout()'s and setInterval()'s `handler` as WebIDL converts it: a
/// member of the TimerHandler union, (DOMString or Function or
/// TrustedScript).
const ConvertedHandler = union(enum) {
    /// BORROWED: the call's argument.
    function: runtime.JSValue,
    /// BORROWED: the call's argument.
    trusted_script: *runtime.Instance,
    /// What ToString made of the argument. OWNED.
    string: []u8,

    fn deinit(self: ConvertedHandler, allocator: Allocator) void {
        switch (self) {
            .string => |text| allocator.free(text),
            .function, .trusted_script => {},
        }
    }
};

/// WebIDL 3.2.24, an ECMAScript value to the TimerHandler union, in the
/// union algorithm's order: a platform object that implements TrustedScript
/// (step 4), then a callable - the Function member (step 10) - and anything
/// else converted to the DOMString member by ToString (step 15), which runs
/// script and can throw (a Symbol is a TypeError).
fn convertTimerHandler(realm: runtime.Context, value: runtime.JSValue, allocator: Allocator) runtime.EngineError!ConvertedHandler {
    if (engine.convertToPlatformObject(realm, value)) |instance| {
        if (trusted_types.dataOf(instance, .script) != null) return .{ .trusted_script = instance };
    }
    if (engine.isCallable(realm, value)) return .{ .function = value };
    const text = engine.convertToDOMString(realm, value, allocator) catch |err| return engineError(err);
    return .{ .string = text };
}

/// An engine operation's error as a built-in function's steps return it:
/// what the operation threw stays pending, and its TypeError is thrown.
fn engineError(err: engine.Error) runtime.EngineError {
    return switch (err) {
        error.ExceptionPending => error.ExceptionPending,
        error.TypeError => error.TypeError,
        error.OutOfMemory => error.OutOfMemory,
        error.DataCloneError => error.DataCloneError,
        error.NotSupported => error.NotSupported,
        error.OperationFailed, error.ExceptionReported => error.OperationFailed,
    };
}

/// One active timer.
const WorkerTimerContext = struct {
    /// The timer's handler (OWNED).
    handler: TimerHandler,
    /// The timer's `arguments` (each OWNED), for a Function handler; empty
    /// for a string, which runs none.
    arguments: []engine.Owned = &.{},
    /// The id script holds: HTML's key in the global's map of setTimeout and
    /// setInterval IDs, and its key in its host's `timers`. It names the
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

/// Release a timer context, the handler it holds and its arguments.
fn freeWorkerTimer(ctx: *WorkerTimerContext) void {
    switch (ctx.handler) {
        .function => |function| function.release(),
        .string => |source| ctx.allocator.free(source),
    }
    for (ctx.arguments) |argument| argument.release();
    ctx.allocator.free(ctx.arguments);
    ctx.allocator.destroy(ctx);
}

/// WebIDL's conversion of a `long` (ConvertToInt(V, 32, "signed"), steps
/// 5-12) from the Number ToNumber gave: NaN and the infinities are 0, the
/// integer part is taken modulo 2^32 and read as two's complement - so 2^32
/// is 0, as a Window's timeout is (the V8 adapter's ToInt32).
pub fn convertToLong(number: f64) i32 {
    if (std.math.isNan(number) or std.math.isInf(number)) return 0;
    const modulo = @mod(@trunc(number), 4294967296.0);
    const unsigned: u32 = @intFromFloat(modulo);
    return @bitCast(unsigned);
}

/// Cancel and free every timer `owner` armed: HTML "terminate a worker" step 2
/// and close() step 1 discard the worker's tasks, and a timer is one. A timer
/// whose callback is on the stack is only marked: its trampoline owns it until
/// the callback returns, and frees it.
fn cancelWorkerTimers(owner: *WorkerHost) void {
    var ids: std.ArrayListUnmanaged(runtime.TimerId) = .empty;
    defer ids.deinit(owner.allocator);
    var iter = owner.timers.keyIterator();
    while (iter.next()) |id| ids.append(owner.allocator, id.*) catch {};
    for (ids.items) |id| owner.clearTimer(id);
}

/// Every worker on this thread whose realm is still there, for
/// `scopeSettings` and the realm hooks: a worker's thread has its one. Freed
/// when it empties, so a worker thread that ends leaves nothing of it.
threadlocal var live_contexts: std.ArrayListUnmanaged(*WorkerHost) = .empty;

fn removeLive(wctx: *WorkerHost) void {
    for (live_contexts.items, 0..) |live, i| {
        if (live == wctx) {
            _ = live_contexts.swapRemove(i);
            break;
        }
    }
    if (live_contexts.items.len == 0) live_contexts.clearAndFree(std.heap.page_allocator);
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
    /// The WorkerGlobalScope's policy container (HTML 7.1.6), which its
    /// settings object hands to every request it makes. BORROWED from the
    /// host, which owns it for as long as the worker lives.
    policy_container: ?*const fetch_mod.internal.PolicyContainer = null,
};

/// The settings for a global scope created in the realm whose runtime
/// context is `ctx`, if that is a worker this host runs.
pub fn scopeSettings(ctx: runtime.Context) ?ScopeSettings {
    const wctx = forScope(ctx) orelse return null;
    return .{
        .url = wctx.script_url,
        .worker_type = wctx.worker_type,
        .name = if (wctx.shared) |shared| shared.name else wctx.name,
        .cookie_jar = wctx.cookie_jar,
        .policy_container = &wctx.policy_container,
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
    WorkerHost.reportException(wctx, info);
}

/// The worker's end of a task, as its realm's `end_of_task`: what
/// `finishTaskIn` does, found by the realm instead of the agent.
pub fn endTaskOfRealm(ctx: runtime.Context) void {
    const wctx = forScope(ctx) orelse return;
    wctx.endTask();
}

/// DedicatedWorkerGlobalScope close() for the global scope whose realm's
/// runtime context is `ctx`.
pub fn closeScope(ctx: runtime.Context) void {
    const wctx = forScope(ctx) orelse return;
    wctx.closeFromScript();
}

/// The closing flag of the worker global scope whose realm is `ctx`: true
/// once close() or "terminate a worker" has set it (the host's phase leaves
/// `running`). Null when no worker this host runs has that realm. The flag
/// lives here, not in WorkerGlobalScope's own state, which neither path sets.
pub fn scopeClosing(ctx: runtime.Context) ?bool {
    const wctx = forScope(ctx) orelse return null;
    return !wctx.runsTasks();
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

/// A classic script importScripts() fetched: what "fetch a classic
/// worker-imported script" returns, for `runImportedScript`.
pub const ImportedScript = struct {
    allocator: Allocator,
    /// The source text, UTF-8 (a leading BOM stripped). Owned.
    source: []u8,
    /// The response's URL - after redirects. Owned.
    url: []u8,
    /// The script's muted errors: its response was CORS-cross-origin.
    muted: bool,

    pub fn deinit(self: *ImportedScript) void {
        self.allocator.free(self.source);
        self.allocator.free(self.url);
    }
};

/// HTML "fetch a classic worker-imported script" given `url` (parsed) and
/// the settings object of the worker whose realm is `ctx`.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-classic-worker-imported-script
/// "Let request be a new request whose URL is url, client is settingsObject,
///  destination is "script", initiator type is "other", parser metadata is
///  "not parser-inserted", and whose use-URL-credentials flag is set." Its
///  mode is a new request's, "no-cors", so a script from another origin
///  loads - with muted errors. "Unlike other algorithms in this section, the
///  fetching process is synchronous here."
/// Then, on the response's unsafe response - an opaque response's own status
/// and headers (Crane's fetch hands back the internal response, marked with
/// its filter type): "If any of the following are true: bodyBytes is null or
/// failure; response's status is not an ok status; or the result of
/// extracting a MIME type from response's header list is not a JavaScript
/// MIME type, then throw a "NetworkError" DOMException."
pub fn fetchClassicWorkerImportedScript(ctx: runtime.Context, url: []const u8) error{ NetworkError, OutOfMemory }!ImportedScript {
    const allocator = ctx.allocator;
    const request = fetch_mod.internal.InternalRequest.init(allocator, url) catch return error.OutOfMemory;
    defer request.deinit();
    request.destination = .script;
    request.initiator_type = .other;
    request.use_url_credentials = true;
    // "client is settingsObject": what Fetch reads from it.
    script_request.populateRequestFromClient(request, ctx) catch return error.OutOfMemory;

    var fetched = fetch_mod.algorithms.fetch(allocator, request, .{}) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.NetworkError,
    };
    defer fetched.timing_info.deinit();
    const response = fetched.response;
    defer response.deinit();

    if (response.response_type == .@"error") return error.NetworkError;
    if (response.status < 200 or response.status >= 300) return error.NetworkError;
    const body = if (response.body) |b| b.data.items else return error.NetworkError;
    const content_type = response.header_list.getFirstValue("content-type") orelse "";
    if (!module_script.isJavaScriptMimeType(content_type)) return error.NetworkError;

    // "Let sourceText be the result of UTF-8 decoding bodyBytes": a leading
    // BOM goes; the engine replaces what is not UTF-8.
    const text = if (std.mem.startsWith(u8, body, "\xEF\xBB\xBF")) body[3..] else body;
    const source = try allocator.dupe(u8, text);
    errdefer allocator.free(source);
    return .{
        .allocator = allocator,
        .source = source,
        .url = try allocator.dupe(u8, response.url() orelse url),
        // "Let mutedErrors be true if response was CORS-cross-origin."
        .muted = response.response_type == .@"opaque" or response.response_type == .opaqueredirect,
    };
}

/// "Import scripts into worker global scope" step 6.2: run the classic
/// script `script` in the worker whose realm is `ctx`, with rethrow errors
/// true.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-classic-script
/// "If evaluationStatus is an abrupt completion: If rethrow errors is true and
///  script's muted errors is false: Clean up after running script with
///  settings. Rethrow evaluationStatus.[[Value]]. If rethrow errors is true
///  and script's muted errors is true: Clean up after running script with
///  settings. Throw a "NetworkError" DOMException." So what the script throws
/// - a parse error included - reaches importScripts()'s caller, and is not
/// reported: the engine's report hands the value here, and it is thrown
/// again once the engine has cleaned up (ExceptionPending).
///
/// importScripts() is called from script: the execution context stack is not
/// empty, so "clean up after running script" performs no microtask
/// checkpoint.
pub fn runImportedScript(ctx: runtime.Context, script: *const ImportedScript) anyerror!void {
    const wctx = forScope(ctx) orelse return error.InvalidStateError;
    if (!wctx.runsTasks()) return;
    const realm = wctx.realm orelse return error.InvalidStateError;
    // "Create a classic script" step 4: a script with muted errors has
    // about:blank as its base URL - its response's URL is not to be exposed,
    // an import() in it included.
    const record = try wctx.classicScript(if (script.muted) "about:blank" else script.url);

    var rethrow: Rethrow = .{ .realm = realm };
    defer if (rethrow.value) |value| value.release();
    wctx.entered += 1;
    defer wctx.entered -= 1;
    engine.runClassicScript(realm, .{ .utf8 = script.source }, script.url, record, rethrow.reporter()) catch |err| switch (err) {
        error.ExceptionReported => {},
        else => return err,
    };

    if (rethrow.thrown) {
        if (script.muted) return error.NetworkError;
        const value = rethrow.value orelse return error.NetworkError;
        try engine.throwValue(realm, value.value);
        return error.ExceptionPending;
    }
}

/// The engine's "report an exception" for a script run with rethrow errors
/// true: nothing is reported; the thrown value is kept for the caller.
const Rethrow = struct {
    realm: runtime.Context,
    thrown: bool = false,
    /// OWNED.
    value: ?engine.Owned = null,

    fn reporter(self: *Rethrow) engine.Reporter {
        return .{ .report = keep, .host = self };
    }

    fn keep(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Rethrow = @ptrCast(@alignCast(host orelse return));
        self.thrown = true;
        if (self.value) |old| old.release();
        self.value = engine.retainValue(self.realm, info.error_value) catch null;
    }
};

fn forScope(ctx: runtime.Context) ?*WorkerHost {
    for (live_contexts.items) |live| {
        if (live.realm == ctx) return live;
    }
    return null;
}

/// Every worker host on this thread whose memory has not gone (`free`): a
/// worker's thread has its one, until the thread's last step. What a module
/// evaluation's settling reaction checks its host against
/// (`PendingModuleEvaluation`). Freed when it empties.
threadlocal var hosts: std.ArrayListUnmanaged(*WorkerHost) = .empty;

fn removeHost(wctx: *WorkerHost) void {
    for (hosts.items, 0..) |host, i| {
        if (host == wctx) {
            _ = hosts.swapRemove(i);
            break;
        }
    }
    // A worker thread's one host is gone: nothing of the list outlives it.
    if (hosts.items.len == 0) hosts.clearAndFree(std.heap.page_allocator);
}

/// Timer callback trampoline - invoked by the timer manager
fn workerTimerTrampoline(context_ptr: ?*anyopaque) void {
    const ctx: *WorkerTimerContext = @ptrCast(@alignCast(context_ptr orelse return));
    const wctx = ctx.worker_host;

    // Cancelled while armed, or its worker has closed: a discarded task (HTML
    // close() step 1, "terminate a worker" step 2). Free it - this is the last
    // time the timer system will reference this context.
    if (ctx.cancelled or !wctx.runsTasks()) {
        _ = wctx.timers.remove(ctx.id);
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
        if (wctx.timer) |timer| {
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
            _ = wctx.timers.remove(ctx.id);
            freeWorkerTimer(ctx);
            return;
        }
    }

    // A one-shot that has run, or a repeat that was cancelled: the timer
    // manager has already dropped it, so nothing will hand it back.
    _ = wctx.timers.remove(ctx.id);
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

    // A task of the worker's realm: its agent entered from the page's loop,
    // and ended the worker's way (`endTaskOfRealm`).
    wctx.runTask(TimerCall.steps, ctx);
}

const TimerCall = struct {
    /// The timer's task, steps 10.7-10.8.
    fn steps(data: ?*anyopaque) void {
        const ctx: *WorkerTimerContext = @ptrCast(@alignCast(data orelse return));
        const wctx = ctx.worker_host;
        const realm = wctx.realm orelse return;
        switch (ctx.handler) {
            // 10.7: "invoke handler given arguments and "report", and with
            // callback this value set to thisArg" - the global.
            .function => |*function| {
                const arguments = wctx.allocator.alloc(runtime.JSValue, ctx.arguments.len) catch return;
                defer wctx.allocator.free(arguments);
                for (arguments, ctx.arguments) |*argument, owned| argument.* = owned.value;
                const completion = engine.invokeCallbackFunction(realm, function, .global_this, arguments, .{
                    .report = wctx.reporter(),
                }) catch return;
                switch (completion) {
                    inline else => |value| value.release(),
                }
            },
            .string => |source| wctx.runTimerString(realm, source),
        }
    }
};

/// Where a worker is in its life, as its host sees it.
///
/// HTML "run a worker" runs the worker's event loop until its global scope's
/// closing flag is set; then the realm goes, and with it the agent - on the
/// worker's thread, in WorkerThread's order. The closing flag itself is the
/// link's (`runsTasks`): "terminate a worker" sets it from another thread.
const Phase = enum {
    /// Running tasks.
    running,
    /// close() set the closing flag: no further task runs. The realm is
    /// still there; the thread ends it once its loop stops.
    closing,
    /// The realm is gone: the engine released it. The agent goes next.
    realm_gone,
};

/// The worker a Worker object runs: its agent and realm (through the engine
/// protocol), its event loop's tasks, its life.
pub const WorkerHost = struct {
    /// The worker's agent - its own, separate from its owner's - made with
    /// this host's hooks (`worker_hooks`).
    agent: *runtime.Agent,
    /// Per-agent state shared by the HTML checkpoint hooks and IndexedDB.
    agent_host: html_core.agent_host.AgentHost,

    /// The worker's realm: its runtime context, which every Instance created
    /// in it points at - the global scope first. Null until the global scope
    /// is set up (`setupWorkerGlobalScope`) and again once the realm is gone.
    realm: ?runtime.Context = null,

    /// The realm's global object's platform object: its
    /// DedicatedWorkerGlobalScope or SharedWorkerGlobalScope. The realm owns
    /// it, and frees it when the realm goes.
    global_scope: ?*runtime.Instance = null,

    /// The worker's script URL, absolute: the URL its global scope reports
    /// as its own ("run a worker" step 9 - HTML takes the response's URL) and
    /// the one importScripts() resolves against. Owned.
    script_url: []const u8,
    /// A dedicated worker's global scope's name ("run a worker" step 8:
    /// options["name"]). Owned; empty for a shared worker, whose name is in
    /// `shared`.
    name: []const u8 = "",
    /// The user agent's cookie jar, from the global that created this
    /// worker (BORROWED: the Browser outlives its workers). The worker's
    /// global scope takes it through `scopeSettings`.
    cookie_jar: ?*CookieJar = null,

    /// Worker type (classic or module)
    worker_type: WorkerType,

    /// The worker global scope's policy container: a new one until "run a
    /// worker" gives it the one "initialize a worker global scope's policy
    /// container" chose (`setPolicyContainer`). Owned.
    policy_container: fetch_mod.internal.PolicyContainer,

    /// The timers the worker's tasks run on: its own thread's loop's
    /// (WorkerEventLoop.timerInterface). Null once the realm has ended: the
    /// loop ends next.
    timer: ?runtime.TimerInterface,

    /// The worker's Browser scope (its creator's), and the cross-thread inbox
    /// of its own loop. The worker's realm carries both
    /// (ContextData.browser_scope, .task_sink): a MessagePort made in it
    /// binds its channel end to that inbox, and a Worker made in it is owned
    /// through it. BORROWED.
    browser_scope: ?*runtime.BrowserScope = null,
    task_sink: *runtime.TaskSink,

    /// Allocator. Thread-safe: a worker's messages are freed on the other
    /// thread.
    allocator: Allocator,

    /// The worker's own event loop (WorkerEventLoop.eventLoop), which its
    /// realm records for host algorithms that queue tasks.
    event_loop: runtime.EventLoop,

    /// What this host shares with its owner's thread (the worker side's
    /// reference is the thread's, not this host's). Its state is the
    /// closing flag of the worker's global scope.
    link: *WorkerLink,

    /// A dedicated worker's implicit port: its end of the channel whose other
    /// end is its Worker object's outside port ("run a worker" onComplete
    /// steps 3-5). Bound to this host on the worker's loop - its messages are
    /// fired at the global scope - from setup until the realm's end, which
    /// discards it ("run a worker" step 17: disentangle the worker's ports).
    inside_end: ?*port_channels.End = null,

    /// The worker's creation time in milliseconds since the epoch ("run a
    /// worker" step 3), its global scope's time origin; null when the host
    /// has none (a test's: now, when its global scope is made).
    time_origin_ms: ?f64 = null,

    /// The worker object that ran the worker - a dedicated worker's Worker,
    /// a shared worker's first SharedWorker - as its owner's tasks find it:
    /// an address and slab generation, never dereferenced on this thread. An
    /// error report carries them to the owner's loop (`sendErrorToParent`,
    /// `ThreadHost.reportStartFailure`), which checks the generation there.
    owner_worker: ?OwnerWorker = null,

    /// How deep this host has run script in the worker on the current stack.
    /// While it is above zero the worker's script may be running, and the
    /// realm must not be torn down under it.
    entered: u32 = 0,

    phase: Phase = .running,

    /// "In error reporting mode" for the global scope (HTML "report an
    /// exception"): an error reported while one is being reported goes no
    /// further.
    reporting_error: bool = false,

    /// The worker's own classic script is running ("run a worker"
    /// onComplete step 10), and whether it failed to PARSE: a script whose
    /// error to rethrow is non-null takes onComplete step 1 instead - a plain
    /// `error` at the worker object, nothing reported at the global scope,
    /// nothing run.
    running_own_script: bool = false,
    own_script_parse_failed: bool = false,

    /// A shared worker's: what its SharedWorkerGlobalScope was made with
    /// ("run a worker" steps 8 and 10). Null for a dedicated worker. OWNED.
    shared: ?SharedScope = null,

    /// The built-in functions this host defines on the global object. The
    /// engine reads them on every call, so they live as long as this does.
    builtins: [5]runtime.BuiltinFunction = undefined,

    /// The global's map of setTimeout and setInterval IDs (HTML 8.6): its
    /// active timers, keyed by the id its script holds. Each global has its
    /// own, and clearTimeout(id) removes this global's entry and nothing in
    /// any other - it used to be one map for every worker on the thread, so a
    /// worker clearing an id it never armed cancelled another worker's timer.
    timers: std.AutoHashMapUnmanaged(runtime.TimerId, *WorkerTimerContext) = .empty,

    /// The next id this global's script is handed: greater than zero, and
    /// never one in `timers` (timer initialization step 2). Its own counter,
    /// not the timer manager's: an interval's manager id changes on every
    /// repeat, and the id script holds must not.
    next_timer_id: runtime.TimerId = 1,

    /// The worker's module map (HTML "module map" of its settings object):
    /// keys owned, values a `*module_script.ModuleScript` or
    /// `module_script.fetch_failed`, disposed with the realm.
    modules: std.StringHashMapUnmanaged(*anyopaque) = .empty,

    /// The classic scripts run in the realm - the worker's own and each
    /// importScripts() one - as the [[HostDefined]] an import() in them
    /// names: their base URLs. They live as long as the realm, since a
    /// function one defined can call import() at any time.
    classic_scripts: std.ArrayListUnmanaged(*module_script.ClassicScript) = .empty,

    /// The classic script every string timer handler runs as (one of
    /// `classic_scripts`), made on first use (`timerScript`).
    timer_script: ?*module_script.ClassicScript = null,

    /// import()s whose fetch task is queued and has not run: each holds an
    /// engine request that must be finished while the agent lives.
    pending_imports: std.ArrayListUnmanaged(*DynamicImportTask) = .empty,

    const Self = @This();

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

    /// A DEDICATED worker's host, made on the worker's own thread by its
    /// start step (`ThreadHost.start`): "run a worker" step 4, obtain a
    /// dedicated worker agent - [[CanBlock]] true - with this host's hooks.
    /// It is made here with no isolate entered, so the engine records it as
    /// this thread's host agent: its end takes down this thread's engine
    /// state, which is the worker's alone (lesson: an agent's role is
    /// recorded when it is made). The agent is published through the link -
    /// from then on the owner can abort script in it - and is the thread's:
    /// WorkerThread destroys it after the realm's end, then this host is
    /// freed (`free`). `thread_host.host` is set before anything can fail,
    /// so a host half made is freed the same way. Whether the worker still
    /// runs: false when it was terminated before its agent existed.
    fn initOnThread(allocator: Allocator, thread_host: *ThreadHost, thread: *WorkerThread) !bool {
        const start = &thread_host.start;
        const self = try allocator.create(Self);
        self.* = .{
            .agent = undefined,
            .agent_host = html_core.agent_host.AgentHost.init(allocator),
            .script_url = "",
            .worker_type = start.worker_type,
            .policy_container = fetch_mod.internal.PolicyContainer.init(allocator),
            .timer = thread.loop.timerInterface(),
            .event_loop = thread.loop.eventLoop(),
            .browser_scope = start.browser_scope,
            .task_sink = thread.loop.sink,
            .allocator = allocator,
            .link = thread.link,
            .owner_worker = start.owner_worker,
            .cookie_jar = start.cookie_jar,
            .time_origin_ms = start.time_origin_ms,
        };
        thread_host.host = self;
        hosts.append(std.heap.page_allocator, self) catch {};
        const agent = try engine.createAgent(.{
            .can_block = true,
            .from_snapshot = false,
            .hooks = &worker_hooks,
            .host = &self.agent_host,
            .allocator = allocator,
        });
        self.agent = agent;
        thread.loop.agent = agent;
        const runs = thread.link.publishAgent(agent);
        self.script_url = try allocator.dupe(u8, start.script_url);
        self.name = try allocator.dupe(u8, start.name);
        // A shared worker's constructor key, type and credentials. Taken.
        self.shared = start.shared;
        start.shared = null;
        // "Run a worker" onComplete: the global scope's policy container,
        // chosen when the script was fetched. Taken.
        if (start.policy_container) |container| {
            self.setPolicyContainer(container);
            start.policy_container = null;
        }
        live_contexts.append(std.heap.page_allocator, self) catch {};
        return runs;
    }

    /// Whether the worker runs tasks: not once its closing flag is set -
    /// close() in its script, or "terminate a worker" from another thread
    /// (its owner, its owner set emptying, the Browser's end).
    pub fn runsTasks(self: *const Self) bool {
        if (self.phase != .running) return false;
        return self.link.runsTasks();
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
    /// checkpoint. (The worker's own loop runs the engine's posted tasks
    /// every turn.) Call with the agent entered.
    fn endTask(self: *Self) void {
        if (self.realm != null) engine.performMicrotaskCheckpoint(self.agent) catch {};
    }

    // ------------------------------------------------------------------
    // A shared worker's connections
    // ------------------------------------------------------------------

    /// A new inside port on `end` - a MessagePort of this worker's realm,
    /// entangled with its SharedWorker's outside port - and `connect` fired
    /// at the global scope carrying it: the shared worker manager's steps
    /// 5.5-5.7, and "run a worker" onComplete steps 3, 5 and 13. A task of
    /// the worker's own loop (`Connect`), so a closing worker discards it.
    /// Takes `end`.
    fn connectInsidePort(self: *Self, end: *anyopaque) void {
        if (!self.runsTasks() or self.realm == null) return message_ports.discard(end);
        var task: ConnectEvent = .{ .host = self, .end = end };
        self.runTask(ConnectEvent.steps, &task);
        // The task did not run (its realm could not be entered).
        if (task.end) |left| message_ports.discard(left);
    }

    const ConnectEvent = struct {
        host: *Self,
        /// Null once a port took it.
        end: ?*anyopaque,

        /// Fire `connect` at the global scope, using MessageEvent, with data
        /// the empty string and ports and source the new inside port.
        fn steps(data: ?*anyopaque) void {
            const self: *ConnectEvent = @ptrCast(@alignCast(data orelse return));
            const realm = self.host.realm orelse return;
            const global_scope = self.host.global_scope orelse return;
            const end = self.end orelse return;
            self.end = null;
            // A new MessagePort in the inside settings' realm on the end
            // (it takes the end whatever happens).
            const port = message_ports.receive(realm, end) catch return;
            const ports = [_]*runtime.Instance{port};
            const init_dict = dictionaries.MessageEventInit{
                .base = .{},
                .data = runtime.JSValue.fromStringRef(""),
                .ports = &ports,
                .source = .{ .message_port = port },
            };
            const event = interfaces.MessageEvent.call_constructor(
                realm,
                runtime.DOMString.initInterned("connect"),
                webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
            ) catch return;
            const generation = runtime.SlabAllocator.generationOf(event);
            _ = fire_event.dispatchTrusted(global_scope, event) catch {};
            event.releaseIfUnwrapped(generation);
        }
    };

    // ------------------------------------------------------------------
    // The end of a worker
    // ------------------------------------------------------------------

    /// WorkerGlobalScope close(), from the worker's own script: 1. discard
    /// the tasks queued for the worker's agent, 2. set the closing flag. The
    /// task that called it runs to its end, and what it posts is delivered
    /// (workers/interfaces/WorkerGlobalScope/close/sending-messages); then
    /// the realm goes, at its thread's end, once its loop sees the flag.
    fn closeFromScript(self: *Self) void {
        if (self.phase != .running) return;
        self.phase = .closing;
        cancelWorkerTimers(self);
        // The loop runs no further task; its end discards them.
        _ = self.link.requestClose();
    }

    /// The realm's end, on the worker's thread once its loop has stopped
    /// (WorkerThread step c, `ThreadHost.endRealm`): what "run a worker" does
    /// once the event loop exits - clear the active timers, disentangle the
    /// ports - and the engine's end of the realm (`destroyWorkerRealm`).
    /// Nothing runs in the realm again.
    fn teardownRealm(self: *Self) void {
        self.phase = .realm_gone;
        removeLive(self);
        cancelWorkerTimers(self);
        // "Run a worker" step 17: disentangle the worker's ports - its
        // implicit port first. Its Worker object's outside port is no longer
        // entangled; what the worker was sent and never ran goes with it.
        if (self.inside_end) |end| end.discard();
        self.inside_end = null;

        const realm = self.realm orelse return;
        // The import()s still waiting for their fetch task are discarded with
        // the worker's other tasks: their requests are finished now, while
        // the realm and its agent are there to finish them in.
        self.finishPendingImports();
        // The module map goes with the settings object: its records are
        // engine handles of this agent.
        self.disposeModules();
        // So do the rejected promises tracked for its global, and the
        // notifications queued for it: Globals of this agent.
        if (self.global_scope) |global_scope| rejected_promises.forgetGlobal(global_scope);
        // The unloading document cleanup steps other specifications define,
        // run for the worker's realm as Blink runs them for every execution
        // context that ends (the File API's: the blob URL entries the worker
        // made leave the store - "This needs a similar hook when a worker is
        // unloaded").
        @import("dom").unloading_cleanup.run(realm);
        self.realm = null;
        // The realm's per-context data - the callbacks its script registered,
        // its wrapper cache and every Instance in it, the global scope first -
        // goes with it; the realm is retired, so anything holding it across
        // turns (a fetch) reads it as gone.
        self.global_scope = null;
        engine.destroyWorkerRealm(realm, sweepFetches, null);
        // Nothing can call import() in the realm any more.
        self.freeClassicScripts();
    }

    /// Fetches still in flight for the realm release their promises, while the
    /// agent those belong to is alive.
    fn sweepFetches(_: ?*anyopaque) void {
        _ = async_fetch.sweep();
    }

    /// This host's memory, from its thread's last step (`ThreadHost.free`),
    /// after its realm's end and its agent's - so nothing here may reach the
    /// engine: the realm's end left no timer, import or module behind.
    fn free(self: *Self) void {
        removeLive(self);
        removeHost(self);
        std.debug.assert(self.timers.count() == 0);
        self.timers.deinit(self.allocator);
        if (self.shared) |*shared| shared.deinit(self.allocator);
        std.debug.assert(self.pending_imports.items.len == 0);
        self.pending_imports.deinit(self.allocator);
        std.debug.assert(self.modules.count() == 0);
        self.modules.deinit(self.allocator);
        self.freeClassicScripts();
        if (self.inside_end) |end| end.discard();
        self.inside_end = null;
        self.policy_container.deinit();
        self.agent_host.deinit();
        self.allocator.free(self.script_url);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Give the worker global scope `container` (taken), replacing its new
    /// one: HTML "initialize a worker global scope's policy container", done
    /// by "run a worker" before the script runs.
    pub fn setPolicyContainer(self: *Self, container: fetch_mod.internal.PolicyContainer) void {
        self.policy_container.deinit();
        self.policy_container = container;
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
    pub fn setupWorkerGlobalScope(self: *Self) !void {
        const made = try engine.createWorkerRealm(self.agent, &.{
            .url = self.script_url,
            // "Run a worker" step 5: a SharedWorkerGlobalScope when `is shared`.
            .global = if (self.shared != null) .shared else .dedicated,
            .timer = self.timer,
            // The worker's own loop, which host algorithms queue their tasks
            // on.
            .event_loop = self.event_loop,
            .end_of_task = endTaskOfRealm,
            .on_realm = recordRealm,
            .data = self,
            .allocator = self.allocator,
        });
        self.global_scope = made.global_scope;

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

        // Only performance still needs a bootstrap fallback: WorkerGlobalScope
        // has no native performance getter. Its crypto and indexedDB accessors
        // already supply native objects (WebIDL 3.7.6); never shadow them.
        // Its time origin is the worker's creation time ("run a worker" step
        // 3, the unsafe worker creation time - taken by the Worker
        // constructor, before the worker's thread starts) when the host has
        // it, else now.
        var origin_buffer: [64]u8 = undefined;
        const time_origin: []const u8 = if (self.time_origin_ms) |ms|
            std.fmt.bufPrint(&origin_buffer, "{d}", .{ms}) catch "Date.now()"
        else
            "Date.now()";
        const performance_setup = try std.fmt.allocPrint(self.allocator,
            \\(function() {{
            \\  function define(name, value) {{
            \\    Object.defineProperty(globalThis, name, {{ value: value, writable: true, enumerable: true, configurable: true }});
            \\  }}
            \\  // Performance API - https://w3c.github.io/hr-time/
            \\  var timeOrigin = {s};
            \\  define('performance', {{
            \\    timeOrigin: timeOrigin,
            \\    now: function() {{ return Date.now() - timeOrigin; }},
            \\    toJSON: function() {{ return {{ timeOrigin: this.timeOrigin }}; }}
            \\  }});
            \\}})();
        , .{time_origin});
        defer self.allocator.free(performance_setup);
        try self.runSetupScript(performance_setup);
    }

    /// `createWorkerRealm`'s `on_realm`: the realm exists, and its global
    /// scope - which reads this worker's settings as it is made
    /// (`scopeSettings`) - does not yet.
    fn recordRealm(data: ?*anyopaque, realm: runtime.Context) void {
        const self: *Self = @ptrCast(@alignCast(data orelse return));
        self.realm = realm;
        realm.browser_scope = self.browser_scope;
        realm.task_sink = self.task_sink;
        installRealmHooks(realm);
    }

    /// Run one of the host's own setup scripts in the realm. It is no
    /// script of the worker's: an import() from it names no referrer.
    fn runSetupScript(self: *Self, source: []const u8) !void {
        const realm = self.realm orelse return error.NoRealm;
        try engine.runClassicScript(realm, .{ .utf8 = source }, "", null, self.reporter());
        try engine.performMicrotaskCheckpoint(self.agent);
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
        self.timer_script = null;
    }

    /// "Run a worker" onComplete step 10 for a classic worker: run the
    /// classic script `source` - the worker's own, its base URL the worker's
    /// URL - then "clean up after running script" (a microtask checkpoint).
    pub fn executeScript(self: *Self, source: []const u8) !void {
        // A worker whose closing flag is set runs no further task.
        if (!self.runsTasks()) return error.WorkerClosed;

        self.running_own_script = true;
        defer self.running_own_script = false;
        try self.runScript(source, self.script_url, true);
    }

    /// "Run a worker" for a module worker, from "obtain script" on: fetch a
    /// module worker script graph - the root's response (`source`, fetched
    /// from `url`) already in hand, its URL the worker's - and onComplete:
    /// "If script is null or if script's error to rethrow is non-null", the
    /// worker fails - false, and the caller queues `error` at the worker
    /// object; otherwise "run the module script script", then the incoming
    /// messages, as a classic worker's script does.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/workers.html#run-a-worker
    pub fn executeModuleScript(self: *Self, url: []const u8, source: []const u8) bool {
        if (!module_script.supported) return false;
        if (!self.runsTasks()) return false;

        const env = self.moduleEnvironment() orelse return false;
        const graph = module_script.moduleWorkerScriptGraph(&env, url, self.script_url, source) orelse return false;
        if (graph.error_to_rethrow != null) return false;

        self.runModuleScript(&env, graph);
        return true;
    }

    /// HTML "run a module script" for the worker: evaluate between "prepare
    /// to run script" and "clean up after running script"; "upon rejection
    /// of evaluationPromise with reason, report an exception given by
    /// reason" for the worker's global scope.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
    /// "Upon rejection" is a reaction: even for a graph whose evaluation
    /// promise is already rejected, the report is a microtask queued after
    /// the ones the evaluation queued, and runs in step 9's checkpoint
    /// (microtasks/evaluation-order-1-throw-static-import: "body",
    /// "microtask", then "global-error").
    fn runModuleScript(self: *Self, env: *const module_script.Environment, script: *module_script.ModuleScript) void {
        const realm = self.realm orelse return;
        self.entered += 1;
        defer self.entered -= 1;
        // Step 5: prepare to run script.
        const scope = engine.prepareToRunScript(realm) catch return;
        // Step 9: clean up after running script - the microtask checkpoint.
        defer engine.cleanUpAfterRunningScript(scope);
        switch (module_script.run(env, script)) {
            .ok => {},
            // Steps 6-7 settled the evaluation promise with a rejection (an
            // error to rethrow, or a synchronous throw): step 8's reaction.
            .report => |exception| {
                defer exception.release();
                const promise = engine.createRejectedPromise(realm, exception.value) catch
                    return self.reportValue(realm, exception.value);
                defer promise.release();
                self.reportRejectionLater(realm, promise.value);
            },
            .pending => |promise| {
                defer promise.release();
                self.reportRejectionLater(realm, promise.value);
            },
        }
    }

    /// "Report an exception" `value` (BORROWED) for the worker's global
    /// scope, with the error information the engine extracts from it.
    fn reportValue(self: *Self, realm: runtime.Context, value: runtime.JSValue) void {
        const info = engine.extractErrorInformation(realm, value, self.allocator) catch return;
        defer self.allocator.free(info.message);
        defer self.allocator.free(info.filename);
        const runtime_info: runtime.ErrorInfo = .{
            .message = info.message,
            .filename = info.filename,
            .lineno = info.lineno,
            .colno = info.colno,
            .error_value = info.error_value,
        };
        reportException(self, &runtime_info);
    }

    /// Step 8: react to the evaluation promise, and report the reason if it
    /// rejects - while this host, held by address, is still a live one.
    fn reportRejectionLater(self: *Self, realm: runtime.Context, promise: runtime.JSValue) void {
        // c_allocator: the reaction can outlive this host.
        const pending = std.heap.c_allocator.create(PendingModuleEvaluation) catch return;
        pending.* = .{ .host = self, .realm = realm };
        engine.reactToPromise(realm, promise, &PendingModuleEvaluation.steps, pending) catch {
            std.heap.c_allocator.destroy(pending);
        };
    }

    /// HTML "report an exception" for the worker's global scope, as
    /// runClassicScript and invokeCallbackFunction hand it over: fire `error`
    /// at the global scope (cancelable - `self.onerror` returning true, or a
    /// listener's preventDefault(), handles it); if not handled, the worker's
    /// Worker object hears it, with `error` null.
    fn reportEngineException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        // The worker's own script did not parse: "run a worker" onComplete
        // step 1, which its caller takes - not "report an exception".
        if (host) |h| {
            const self: *Self = @ptrCast(@alignCast(h));
            if (self.running_own_script and info.parse_error) {
                self.own_script_parse_failed = true;
                return;
            }
        }
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

    /// HTML "report an exception" step 7, for a dedicated worker's global
    /// scope when the error went unhandled there: "queue a global task on
    /// the DOM manipulation task source given workerObject's relevant global
    /// object" to fire an ErrorEvent at the Worker object, with the error's
    /// message, filename, line and column, and `error` null - the value stays
    /// in this realm. The task goes to the Worker's own loop (the link's
    /// owner sink); a shared worker has no Worker object to tell.
    fn sendErrorToParent(
        self: *Self,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    ) void {
        // Step 7 is a DedicatedWorkerGlobalScope's: a shared worker's errors
        // stay in it, whatever SharedWorker ran it.
        if (self.shared != null) return;
        const owner = self.owner_worker orelse return;
        const link = self.link;
        const report = ErrorReport.create(self.allocator, owner, .{
            .message = message,
            .filename = if (filename.len > 0) filename else self.script_url,
            .lineno = lineno,
            .colno = colno,
        }) catch {
            log.debug("out of memory reporting a worker's error to its owner; dropped", .{});
            return;
        };
        // A closed sink - the owner's loop has ended - drops it.
        _ = link.owner_sink.post(.{ .run = ErrorReport.run, .drop = ErrorReport.drop, .data = report });
    }

    // ------------------------------------------------------------------
    // Messages: a dedicated worker's implicit port
    // ------------------------------------------------------------------

    /// What the implicit port does with what reaches it, on the worker's own
    /// loop: its message event target is the global scope ("run a worker"
    /// onComplete step 4.1).
    const inside_port_hooks: port_channels.ReceiverHooks = .{
        .deliver = deliverToScope,
        .closed = insidePortClosed,
    };

    /// Bind the implicit port to this host on the worker's loop - its
    /// messages wait in its queue until it is enabled ("run a worker"
    /// onComplete step 12, after the script has run).
    fn bindInsidePort(self: *Self) void {
        const end = self.inside_end orelse return;
        end.bind(.{ .sink = self.task_sink, .receiver = self, .generation = 0, .hooks = &inside_port_hooks });
    }

    /// One task of the implicit port's message queue: the message port post
    /// message steps' step 7 - deserialized into the worker's realm, its
    /// transferred ports received there, and `message` fired at the global
    /// scope (or `messageerror`). A closing worker's tasks are discarded. The
    /// host outlives the binding: its realm's end discards the port first.
    fn deliverToScope(receiver: *anyopaque, _: u64, delivery: *port_channels.Delivery) void {
        const self: *Self = @ptrCast(@alignCast(receiver));
        if (!self.runsTasks()) return;
        var task: ScopeDelivery = .{ .host = self, .delivery = delivery };
        self.runTask(ScopeDelivery.steps, &task);
    }

    /// The Worker object's outside port was disentangled - its Worker went
    /// away. The implicit port is not script-visible: no event.
    fn insidePortClosed(_: *anyopaque, _: u64) void {}

    const ScopeDelivery = struct {
        host: *Self,
        delivery: *port_channels.Delivery,

        fn steps(data: ?*anyopaque) void {
            const self: *ScopeDelivery = @ptrCast(@alignCast(data orelse return));
            const realm = self.host.realm orelse return;
            const global_scope = self.host.global_scope orelse return;
            const message = self.delivery.next() orelse return;
            defer message.destroy();
            deliverPortMessage(realm, global_scope, message, fireMessageEvent);
        }
    };

    /// DedicatedWorkerGlobalScope postMessage(): the message port post
    /// message steps for the implicit port - serialized with transfer in the
    /// worker's realm (its transferred ports shipped), and queued at the
    /// Worker object's outside port, whose loop delivers it. A closing
    /// worker's messages still go: the task that called close() runs to its
    /// end (workers/interfaces/WorkerGlobalScope/close/sending-messages); a
    /// terminated one's are emptied by its owner ("terminate a worker" step
    /// 4) and discarded by its Worker object.
    fn postMessageToOwner(self: *Self, message: runtime.JSValue, transfer: []const runtime.JSValue) !void {
        const realm = self.realm orelse return;
        const end = self.inside_end orelse return;
        const port_message = try serializePortMessage(realm, message, transfer, self.allocator);
        end.post(port_message);
    }

    fn setTimeoutSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.fromNumber(0)));
        return runtime.JSValue.fromNumber(@floatFromInt(try self.setTimer(args, false)));
    }

    fn setIntervalSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.fromNumber(0)));
        return runtime.JSValue.fromNumber(@floatFromInt(try self.setTimer(args, true)));
    }

    /// clearTimeout() and clearInterval(): remove this's map of setTimeout
    /// and setInterval IDs[id] - the same map for both. `optional long id =
    /// 0` converts as WebIDL does - ToNumber, which can run script and
    /// throw, then modulo 2^32 - so "5" is 5; an id no timer has (zero, a
    /// negative one) names nothing.
    fn clearTimerSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.jsUndefined));
        if (args.len < 1 or args[0] == .undefined) return runtime.JSValue.jsUndefined;
        const realm = self.realm orelse return runtime.JSValue.jsUndefined;
        const id = convertToLong(engine.convertToUnrestrictedDouble(realm, args[0]) catch |err| return engineError(err));
        if (id > 0) self.clearTimer(@intCast(id));
        return runtime.JSValue.jsUndefined;
    }

    /// Remove `id` from this global's timers: cancel the timer and free it,
    /// unless its callback is on the stack - the running trampoline then
    /// frees it on return. An id this global never armed is no entry here,
    /// whoever else armed it.
    ///
    /// The timer is cleared from the manager before it is freed: a context
    /// freed while still armed would fire into workerTimerTrampoline, which
    /// reads it. A fired one-shot is already out of the map, so a context
    /// found here and not executing is never handed back.
    fn clearTimer(self: *Self, id: runtime.TimerId) void {
        const ctx = self.timers.get(id) orelse return;
        ctx.cancelled = true;
        if (ctx.executing) return;
        if (self.timer) |timer| _ = timer.clearTimeout(ctx.current_timer_id);
        _ = self.timers.remove(id);
        freeWorkerTimer(ctx);
    }

    /// Timer initialization step 2: an id greater than zero that is not
    /// already in this global's map.
    fn takeTimerId(self: *Self) runtime.TimerId {
        while (true) {
            const id = self.next_timer_id;
            // Script sees the id as a u32 (setTimer's return): wrap there.
            self.next_timer_id = if (id >= std.math.maxInt(u32)) 1 else id + 1;
            if (id != 0 and !self.timers.contains(id)) return id;
        }
    }

    /// done() for the WPT harness, which defines its own when it loads.
    fn doneSteps(_: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        return runtime.JSValue.jsUndefined;
    }

    /// setTimeout() and setInterval(): WebIDL's conversion of their
    /// arguments - `TimerHandler handler, optional long timeout = 0, any...
    /// arguments` - then the timer initialization steps (HTML § 8.6) with no
    /// previousId. The new timer's id, or 0 when none was armed. The
    /// conversions run script (a handler's toString(), a timeout's
    /// valueOf()), so they happen here, at the call, in the order WebIDL
    /// gives, and what they throw reaches the caller.
    fn setTimer(self: *Self, args: []const runtime.JSValue, repeat: bool) runtime.EngineError!u32 {
        const realm = self.realm orelse return 0;
        const global = self.global_scope orelse return 0;
        // `handler` is not optional: "not enough arguments" is a TypeError.
        if (args.len < 1) return error.TypeError;

        // `handler`: TimerHandler, (DOMString or Function or TrustedScript),
        // by WebIDL's union conversion (3.2.24): a platform object that is a
        // TrustedScript (step 4), then a callable (step 10), else the string
        // ToString makes of it (step 15).
        var handler: ConvertedHandler = try convertTimerHandler(realm, args[0], self.allocator);
        defer handler.deinit(self.allocator);

        // `timeout`: optional long, 0 when undefined or not passed.
        var timeout: i32 = 0;
        if (args.len >= 2 and args[1] != .undefined) {
            timeout = convertToLong(engine.convertToUnrestrictedDouble(realm, args[1]) catch |err| return engineError(err));
        }

        // Step 1: a handler that is not a Function, and no previousId: "Set
        // handler to the result of invoking the get trusted type compliant
        // string algorithm with TrustedScript, global, handler, sink, and
        // "script"", the sink being "WorkerGlobalScope setTimeout" or
        // "WorkerGlobalScope setInterval" - a TrustedScript's data, or the
        // default policy's value, or a TypeError where Trusted Types are
        // required. The default policy runs script.
        var source: ?[]u8 = null;
        errdefer if (source) |text| self.allocator.free(text);
        switch (handler) {
            .function => {},
            .trusted_script, .string => {
                const sink: []const u8 = if (repeat) "WorkerGlobalScope setInterval" else "WorkerGlobalScope setTimeout";
                const input: trusted_types.Input = switch (handler) {
                    .trusted_script => |instance| .{ .object = instance },
                    .string => |text| .{ .string = text },
                    .function => unreachable,
                };
                source = trusted_types.getCompliantString(self.allocator, .script, global, input, sink, trusted_types.script_sink_group) catch |err| return switch (err) {
                    error.TypeError => error.TypeError,
                    error.ExceptionPending => error.ExceptionPending,
                    error.OutOfMemory => error.OutOfMemory,
                    else => error.OperationFailed,
                };
                // Not in the spec, stated: step 10.8.2's CSP check runs here,
                // at the call, as the window's does (src/browser/Context.zig
                // initializeTimer cites the three engines - Blink's
                // DOMTimer, Gecko's SetTimeoutOrInterval, WebKit's
                // setTimeout, each `return 0` after reporting - and the
                // lesson "a spec step no engine runs breaks tests that never
                // test it"). The worker's CSP list is its global scope's
                // policy container's: an enforced policy that blocks the
                // string reports its violation at the global scope and the
                // call returns 0, scheduling nothing and reporting no
                // exception; a report-only one reports and the timer is set.
                if (!code_generation.timerHandlerAllowed(global, source.?)) {
                    self.allocator.free(source.?);
                    source = null;
                    return 0;
                }
            },
        }

        const timer = self.timer orelse {
            if (source) |text| self.allocator.free(text);
            source = null;
            return 0;
        };
        // Room for the entry first: a timer armed and then not tracked could
        // be neither cleared nor freed with its global.
        try self.timers.ensureUnusedCapacity(self.allocator, 1);

        const timer_ctx = try self.allocator.create(WorkerTimerContext);
        errdefer self.allocator.destroy(timer_ctx);
        timer_ctx.* = .{
            .handler = undefined,
            .id = 0, // Given once the timer is armed
            .current_timer_id = 0, // Updated after scheduling
            .is_interval = repeat,
            .interval_delay_ms = 0,
            .nesting_level = runtime.timer.nesting_level +| 1,
            .allocator = self.allocator,
            .cancelled = false,
            .worker_host = self,
        };
        switch (handler) {
            // The handler as a callback function, with the incumbent realm -
            // the worker's, whose built-in this is - as its callback
            // context; and `arguments`, each kept for every run.
            .function => |function| {
                const kept = try self.allocator.alloc(engine.Owned, args.len -| 2);
                var retained: usize = 0;
                errdefer {
                    for (kept[0..retained]) |argument| argument.release();
                    self.allocator.free(kept);
                }
                for (kept, 2..) |*argument, i| {
                    argument.* = engine.retainValue(realm, args[i]) catch |err| return engineError(err);
                    retained += 1;
                }
                const retained_function = engine.retainValue(realm, function) catch |err| return engineError(err);
                timer_ctx.handler = .{ .function = .{
                    .function = retained_function,
                    .context = engine.incumbentRealm() orelse realm,
                } };
                timer_ctx.arguments = kept;
            },
            // A string runs no arguments.
            .trusted_script, .string => {
                timer_ctx.handler = .{ .string = source.? };
                source = null;
            },
        }

        // Steps 3-6: the timeout, 0 when negative, and HTML §8.6's clamp
        // against the CURRENT nesting level: the spec reads it in step 4,
        // clamps in step 6, and only then increments for the timer it is
        // creating (steps 11-12).
        const clamped_ms = runtime.timer.clampTimeout(@max(timeout, 0), runtime.timer.nesting_level);
        const delay_u64: u64 = if (clamped_ms >= 0) @intCast(clamped_ms) else 0;
        timer_ctx.interval_delay_ms = delay_u64;

        const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);
        if (timer_id == 0) {
            freeWorkerTimer(timer_ctx);
            return 0;
        }
        timer_ctx.current_timer_id = timer_id;
        timer_ctx.id = self.takeTimerId();
        self.timers.putAssumeCapacityNoClobber(timer_ctx.id, timer_ctx);
        return @intCast(timer_ctx.id);
    }

    /// The timer task's step 10.8 for a string handler `source` whose CSP
    /// check passed at the call (setTimer): create a classic script with the
    /// default script fetch options and the settings object's API base URL -
    /// the worker's URL - and run it, its exception reported for the global
    /// scope.
    ///
    /// Step 10.8.5 would take the INITIATING script's base URL and fetch
    /// options instead (the active script when setTimeout was called): the
    /// engine protocol has no "active script" (GetActiveScriptOrModule) yet,
    /// and a window's string timer (src/browser/Context.zig runTimerSteps)
    /// takes its API base URL the same way. The two differ only for an
    /// import() inside the string when the script that called setTimeout
    /// came from importScripts().
    fn runTimerString(self: *Self, realm: runtime.Context, source: []const u8) void {
        const script = self.timerScript() catch return;
        engine.runClassicScript(realm, .{ .utf8 = source }, self.script_url, script, self.reporter()) catch |err| switch (err) {
            // Reported for the global scope already.
            error.ExceptionReported => {},
            else => log.debug("a timer's string handler did not run: {}", .{err}),
        };
    }

    /// The classic script every string timer handler runs as - its base URL
    /// the worker's API base URL, its fetch options the defaults - made on
    /// first use and kept with the realm's other classic scripts, since a
    /// function the string defined can call import() at any time.
    fn timerScript(self: *Self) !*module_script.ClassicScript {
        if (self.timer_script) |script| return script;
        const script = try self.classicScript(self.script_url);
        self.timer_script = script;
        return script;
    }
};

/// The message port post message steps' steps 2-5 for a worker's implicit
/// port or a Worker's outside port, from either side: serialize `message`
/// with `transfer` in `realm` (StructuredSerializeWithTransfer), running the
/// transfer steps of every MessagePort in `transfer` - each ships its channel
/// end. OWNED (`PortMessage.destroy`, or posted to an end, which takes it).
pub fn serializePortMessage(
    realm: runtime.Context,
    message: runtime.JSValue,
    transfer: []const runtime.JSValue,
    allocator: Allocator,
) !*PortMessage {
    var result = try engine.structuredSerializeWithTransfer(realm, message, transfer, transferablePort, null, allocator);
    // What the message does not take: the platform object list, or all of
    // it on failure.
    defer result.deinit(allocator);

    // The transfer steps for each MessagePort: its end - queue and
    // entanglement - is the data holder. An end shipped and then not taken
    // by a message is discarded (its peer hears `close`).
    var ends: std.ArrayListUnmanaged(*port_channels.End) = .empty;
    defer {
        for (ends.items) |shipped| shipped.discard();
        ends.deinit(allocator);
    }
    try ends.ensureTotalCapacity(allocator, result.platform_objects.len);
    for (result.platform_objects) |port| {
        const shipped = message_ports.ship(port) orelse return error.DataCloneError;
        ends.appendAssumeCapacity(@ptrCast(@alignCast(shipped)));
    }
    const owned = try ends.toOwnedSlice(allocator);
    return PortMessage.create(allocator, &result, owned) catch |err| {
        for (owned) |shipped| shipped.discard();
        allocator.free(owned);
        return err;
    };
}

/// The message port post message steps' step 7 at `target` in `realm`, for
/// a message that reached a worker's implicit port or a Worker's outside
/// port: the transferred ports received into `realm` (their
/// transfer-receiving steps), StructuredDeserializeWithTransfer, and
/// `message` fired - or `messageerror`, when it does not deserialize. Call
/// with `realm` entered. The message's ends are taken; the message is the
/// caller's to destroy.
pub fn deliverPortMessage(
    realm: runtime.Context,
    target: *runtime.Instance,
    message: *PortMessage,
    fire: *const fn (realm: runtime.Context, target: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, ports: []const *runtime.Instance) void,
) void {
    const allocator = message.allocator;
    var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer ports.deinit(allocator);
    const ends = message.takeEnds();
    defer allocator.free(ends);
    for (ends) |end| {
        const port = message_ports.receive(realm, @ptrCast(end)) catch continue;
        ports.append(allocator, port) catch continue;
    }

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
// Shared workers (HTML § 10.2.6.4): the shared worker manager's steps
// ============================================================================

/// What a shared worker's SharedWorkerGlobalScope was made with ("run a
/// worker" steps 8 and 10), and what the manager matches a constructor
/// against. Every slice OWNED.
pub const SharedScope = struct {
    /// The constructor origin: the outside settings' origin, serialized.
    constructor_origin: []const u8,
    /// The constructor URL: urlRecord, serialized.
    constructor_url: []const u8,
    /// The global scope's name: options["name"].
    name: []const u8,
    /// The global scope's type and credentials: options["type"] and
    /// options["credentials"].
    worker_type: WorkerType,
    credentials: workers.RequestCredentials,
    /// The global scope's extended lifetime: options["extendedLifetime"].
    extended_lifetime: bool = false,

    fn options(self: *const SharedScope) SharedWorkerManager.Options {
        return .{ .worker_type = self.worker_type, .credentials = self.credentials, .extended_lifetime = self.extended_lifetime };
    }

    fn deinit(self: *SharedScope, allocator: Allocator) void {
        allocator.free(self.constructor_origin);
        allocator.free(self.constructor_url);
        allocator.free(self.name);
    }
};

/// A SharedWorker constructor's step 11 inputs.
pub const SharedWorkerRequest = struct {
    /// The SharedWorker - "worker". It has pending activity until the
    /// manager's steps end - or, when they run a worker, until that worker
    /// has started or failed to - so an `error` event can still reach it.
    worker: *runtime.Instance,
    /// What the worker's tasks do at `worker`, on its thread (the
    /// SharedWorker impl's steps).
    steps: *const OwnerSteps,
    /// The outside settings' realm: the SharedWorker's relevant realm, whose
    /// loop runs the manager's steps and whose Document joins the worker's
    /// owner set.
    owner_realm: runtime.Context,
    /// urlRecord, serialized. BORROWED for the call.
    url: []const u8,
    /// outsideStorageKey, and the constructor origin: the outside settings'
    /// origin, serialized. BORROWED for the call.
    origin: []const u8,
    /// options["name"], ["type"], ["credentials"] and ["extendedLifetime"].
    /// `name` BORROWED.
    name: []const u8,
    worker_type: WorkerType,
    credentials: workers.RequestCredentials,
    extended_lifetime: bool = false,
    /// The other end of outsidePort's channel, which becomes the inside
    /// port - a MessagePort of the worker's realm. OWNED: the manager takes
    /// it whatever happens, including when this returns an error.
    inside_end: *anyopaque,
    /// "Run a worker" step 3, the unsafe worker creation time, in
    /// milliseconds since the epoch - taken by the constructor, as a
    /// Worker's is: a worker these steps run takes it as its global scope's
    /// time origin.
    creation_time_ms: ?f64 = null,
};

/// The SharedWorker constructor's step 11: "enqueue the following steps to
/// the shared worker manager". They run as a task on the owner's loop - the
/// manager's parallel queue, which here is the Browser's window thread -
/// after the constructor has returned. A worker they run starts on a thread
/// of its own; a worker they find hears its new port as a task of its own
/// loop.
pub fn connectSharedWorker(request: SharedWorkerRequest) !void {
    errdefer message_ports.discard(request.inside_end);
    const loop = request.owner_realm.getOptionalEventLoop() orelse return error.NoEventLoop;
    const allocator = request.owner_realm.allocator;
    const task = try allocator.create(SharedConnect);
    errdefer allocator.destroy(task);
    const url = try allocator.dupe(u8, request.url);
    errdefer allocator.free(url);
    const origin = try allocator.dupe(u8, request.origin);
    errdefer allocator.free(origin);
    const name = try allocator.dupe(u8, request.name);
    errdefer allocator.free(name);
    task.* = .{
        .worker = request.worker,
        .generation = runtime.SlabAllocator.generationOf(request.worker),
        .steps = request.steps,
        .owner_realm = request.owner_realm,
        .url = url,
        .origin = origin,
        .name = name,
        .worker_type = request.worker_type,
        .credentials = request.credentials,
        .extended_lifetime = request.extended_lifetime,
        .inside_end = request.inside_end,
        .creation_time_ms = request.creation_time_ms,
        .allocator = allocator,
    };
    // A loop that will not run the task drops it: `drop` frees it.
    loop.queueTask(.{ .callback = SharedConnect.run, .context = task, .drop = SharedConnect.drop });
    // Pending activity until the steps end: whatever script holds, the
    // SharedWorker is there for its `error` event.
    engine.keepPlatformObjectAlive(request.worker);
}

/// "Destroy a document" step 8 - "remove document from the owner set of
/// each WorkerGlobalScope object whose set contains document" - as an
/// unloading document cleanup step (the SharedWorker impl installs it): a
/// shared worker whose owner set this empties is closed (the manager's
/// "closing orphan workers") - one with an extended lifetime once the
/// extended lifetime shared worker timeout has passed, from a timer of the
/// ending realm's loop (a window realm's is its Browser's window loop, where
/// the manager's steps run). Every realm's end runs it, on its own thread; a
/// worker's realm owns no shared worker, and finds nothing.
pub fn sharedWorkerOwnerGone(realm: runtime.Context) void {
    const manager = SharedWorkerManager.existingOf(realm) orelse return;
    var extended: std.ArrayListUnmanaged(SharedWorkerManager.Orphan) = .empty;
    defer extended.deinit(manager.allocator);
    const closed = manager.removeOwner(realm, &extended);
    if (closed > 0) log.debug("{d} shared worker(s) closed: their owner set emptied", .{closed});
    for (extended.items) |orphan| ExtendedOrphan.arm(manager, realm, orphan);
}

/// A shared worker in extended lifetime: its timer, on its Browser's window
/// loop. Holds a link reference; the manager outlives the loop (the
/// Browser's scope ends after its event loop), so a timer never fired is
/// dropped while the manager is there.
const ExtendedOrphan = struct {
    manager: *SharedWorkerManager,
    orphan: SharedWorkerManager.Orphan,

    /// Arm the timeout for `orphan` (taken). With no loop to arm it on, the
    /// worker is closed now - the earliest the spec allows.
    fn arm(manager: *SharedWorkerManager, realm: runtime.Context, orphan: SharedWorkerManager.Orphan) void {
        const timer = realm.getOptionalTimer() orelse return closeNow(manager, orphan);
        const self = manager.allocator.create(ExtendedOrphan) catch return closeNow(manager, orphan);
        self.* = .{ .manager = manager, .orphan = orphan };
        if (timer.setTimeoutOwned(SharedWorkerManager.extended_lifetime_timeout_ms, fire, self, drop) == 0) {
            manager.allocator.destroy(self);
            closeNow(manager, orphan);
        }
    }

    fn closeNow(manager: *SharedWorkerManager, orphan: SharedWorkerManager.Orphan) void {
        _ = manager.closeIfStillOrphaned(orphan.link, orphan.epoch);
        orphan.link.release();
    }

    /// The timeout has passed: closed, unless a Document connected since.
    fn fire(data: ?*anyopaque) void {
        const self: *ExtendedOrphan = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const orphan = self.orphan;
        manager.allocator.destroy(self);
        closeNow(manager, orphan);
    }

    /// Never fired: its loop ended (the Browser's end, which terminates
    /// every worker itself).
    fn drop(data: ?*anyopaque) void {
        const self: *ExtendedOrphan = @ptrCast(@alignCast(data.?));
        const link = self.orphan.link;
        self.manager.allocator.destroy(self);
        link.release();
    }
};

/// The manager's steps for one SharedWorker, as a task on its owner's loop.
const SharedConnect = struct {
    worker: *runtime.Instance,
    generation: u64,
    steps: *const OwnerSteps,
    owner_realm: runtime.Context,
    url: []const u8,
    origin: []const u8,
    name: []const u8,
    worker_type: WorkerType,
    credentials: workers.RequestCredentials,
    extended_lifetime: bool,
    /// Null once a worker's loop has taken it.
    inside_end: ?*anyopaque,
    creation_time_ms: ?f64,
    /// The SharedWorker's pending activity has passed to an `error` task, or
    /// to the start of the worker these steps ran.
    hold_passed: bool = false,
    allocator: Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *SharedConnect = @ptrCast(@alignCast(data orelse return));
        defer self.finish();
        // The SharedWorker went with its realm: nothing to connect.
        if (runtime.SlabAllocator.generationOf(self.worker) != self.generation) return;
        self.connect();
    }

    /// The loop ended with the task queued: the steps never run.
    fn drop(data: ?*anyopaque) void {
        const self: *SharedConnect = @ptrCast(@alignCast(data orelse return));
        self.finish();
    }

    /// The steps' end: the inside end, unless a worker's loop took it, and
    /// the SharedWorker's pending activity.
    fn finish(self: *SharedConnect) void {
        if (self.inside_end) |end| message_ports.discard(end);
        if (!self.hold_passed and runtime.SlabAllocator.generationOf(self.worker) == self.generation) {
            engine.releasePlatformObject(self.worker);
        }
        self.allocator.free(self.url);
        self.allocator.free(self.origin);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    fn ownerWorker(self: *const SharedConnect) OwnerWorker {
        return .{ .instance = self.worker, .generation = self.generation, .steps = self.steps };
    }

    fn connect(self: *SharedConnect) void {
        const manager = SharedWorkerManager.of(self.owner_realm) orelse return self.fireError();
        const key: SharedWorkerManager.Key = .{ .storage_key = self.origin, .url = self.url, .name = self.name };
        // 1-2. workerGlobalScope: the scope whose constructor storage key
        // equals outsideStorageKey, whose closing flag is false, whose
        // constructor URL equals urlRecord and whose name equals
        // options["name"] - and 5.8, the relevant owner to add (this
        // Document) joins its owner set.
        const options: SharedWorkerManager.Options = .{
            .worker_type = self.worker_type,
            .credentials = self.credentials,
            .extended_lifetime = self.extended_lifetime,
        };
        const found = manager.connect(key, options, self.owner_realm) catch
            return self.fireError();
        if (found) |worker| {
            defer worker.link.release();
            // 3. No user agent configuration disallows the connection.
            // 4. A type, credentials or extended lifetime mismatch: `error`
            // at worker.
            if (!worker.matched) return self.fireError();
            // 5.1-5.3: a secure context mismatch fires `error` too. Crane's
            // settings objects record no secure context yet, so outside and
            // inside settings of one origin never differ here.
            // 5.4-5.7: associate, a new inside port entangled with
            // outsidePort, and a `connect` event carrying it - as a task of
            // the worker's own loop, on its thread.
            postConnect(self.allocator, worker.link, worker.host, self.takeInsideEnd());
            return;
        }
        // 6. Otherwise, run a worker.
        self.runSharedWorker(manager, key);
    }

    fn takeInsideEnd(self: *SharedConnect) *anyopaque {
        const end = self.inside_end.?;
        self.inside_end = null;
        return end;
    }

    /// "Run a worker" with `is shared` true: the script fetched here, on the
    /// creator's thread (its CSP violations are the outside settings'
    /// global's to report), then the worker started on a thread of its own.
    fn runSharedWorker(self: *SharedConnect, manager: *SharedWorkerManager, key: SharedWorkerManager.Key) void {
        const allocator = self.allocator;
        // 12. Fetch a classic worker script, or - for a module worker - the
        // root of its module worker script graph (the rest is fetched in the
        // worker's realm). A failed fetch is a null script: onComplete 1.
        var fetched = workers.fetchWorkerScript(allocator, self.url, .{
            .worker_type = self.worker_type,
            .requesting_origin = self.origin,
            .shared = true,
            // The outside settings' policy container: its CSP decides
            // whether the script may be fetched at all.
            .policy_container = creatorPolicyContainer(self.owner_realm),
            // Its violations are reported to the outside settings' global.
            .csp_violation_reporter = @import("dom").csp_violations.reporterForRealm(self.owner_realm),
        }) catch return self.fireError();
        defer fetched.deinit();

        var start: WorkerStart = .{
            .source = fetched.source,
            .script_url = fetched.final_url,
            .worker_type = self.worker_type,
            // 8. The global scope's name (its SharedScope has it too).
            .name = self.name,
            // The global scope's policy container, from the response - or
            // the creator's, for a data: or blob: script.
            .policy_container = workerPolicyContainer(allocator, &fetched, self.owner_realm),
            .cookie_jar = creatorCookieJar(self.owner_realm),
            .owner_realm = self.owner_realm,
            .owner_worker = self.ownerWorker(),
            .inside_end = null,
            // 3. The unsafe worker creation time: the global scope's time
            // origin.
            .time_origin_ms = self.creation_time_ms,
        };
        defer if (start.policy_container) |*container| container.deinit();
        defer if (start.shared) |*shared| shared.deinit(allocator);
        // 10. The constructor key, type and credentials.
        start.shared = sharedScopeOf(allocator, self) catch return self.fireError();

        startSharedWorker(allocator, &start, manager, key, self.inside_end.?) catch |err| {
            log.debug("the shared worker's thread did not start: {}", .{err});
            return self.fireError();
        };
        // The worker's loop has the inside end now, and the SharedWorker's
        // pending activity is the worker's start's: its outcome - started,
        // or `error` - ends it (`OwnerSteps.started`, `.start_failed`).
        self.inside_end = null;
        self.hold_passed = true;
    }

    /// Queue a global task on the owner's loop to fire `error` at worker
    /// (the manager's step 4.1; onComplete 1.1) - on the loop's own task
    /// queue, behind the CSP violation a blocked fetch reported there.
    fn fireError(self: *SharedConnect) void {
        const loop = self.owner_realm.getOptionalEventLoop() orelse return;
        const report = ErrorReport.startFailed(self.allocator, self.ownerWorker()) catch return;
        loop.queueTask(.{ .callback = ErrorReport.run, .context = report, .drop = ErrorReport.drop });
        // The SharedWorker's pending activity is the error task's now: it
        // ends when the event has fired. (A hold is a flag, not a count.)
        self.hold_passed = true;
    }
};

fn sharedScopeOf(allocator: Allocator, connect: *const SharedConnect) !SharedScope {
    const origin = try allocator.dupe(u8, connect.origin);
    errdefer allocator.free(origin);
    const url = try allocator.dupe(u8, connect.url);
    errdefer allocator.free(url);
    return .{
        .constructor_origin = origin,
        .constructor_url = url,
        .name = try allocator.dupe(u8, connect.name),
        .worker_type = connect.worker_type,
        .credentials = connect.credentials,
        .extended_lifetime = connect.extended_lifetime,
    };
}

/// Start a shared worker on a thread of its own: a link whose owner's loop is
/// the creator's (the Browser's window loop, which hears the worker's start
/// and end), registered with the Browser's WorkerRegistry - its end joins
/// every worker thread - and with its shared worker manager under `key`, its
/// owner set the creator's Document; then its first `connect`, on
/// `inside_end`, posted to its loop, where it waits until the script has run
/// ("run a worker" onComplete 13). On success `start.policy_container`,
/// `start.shared` and `inside_end` are taken; on failure the caller still
/// holds them, and nothing runs.
fn startSharedWorker(
    allocator: Allocator,
    start: *WorkerStart,
    manager: *SharedWorkerManager,
    key: SharedWorkerManager.Key,
    inside_end: *anyopaque,
) !void {
    const owner_sink = start.owner_realm.task_sink orelse return error.NoEventLoop;
    const registry = WorkerRegistry.of(start.owner_realm);
    const link = try WorkerLink.create(allocator, owner_sink);
    // The registry's, the manager's and the thread's references keep it; a
    // shared worker has no object holding an owner side of its own. Its
    // `owner_realm` stays null: no realm's end terminates it - its owner
    // set's emptying does (`sharedWorkerOwnerGone`).
    defer link.release();
    if (registry) |r| try r.register(link);
    errdefer if (registry) |r| r.unregister(link);

    const shared = start.shared orelse return error.NotShared;
    const thread_host = try ThreadHost.create(allocator, start);
    errdefer thread_host.destroyUnstarted();
    const owner_end = try allocator.create(OwnerEnd);
    errdefer allocator.destroy(owner_end);
    owner_end.* = .{ .allocator = allocator, .owner = start.owner_worker, .registry = registry, .manager = manager };

    try manager.add(key, shared.options(), link, thread_host, start.owner_realm);
    errdefer manager.remove(link);

    try WorkerThread.spawn(allocator, link, thread_host.asHost(), owner_end.asOwner(), registry);
    // The thread has them now.
    start.policy_container = null;
    start.shared = null;
    postConnect(allocator, link, thread_host, inside_end);
}

/// Post the manager's steps 5.5-5.7 (or "run a worker" onComplete 3, 5 and
/// 13) to the shared worker's loop: a new inside port on `end` (taken) and
/// `connect` at its global scope. A worker already ending drops it, and the
/// end is discarded - its SharedWorker's port hears `close`.
fn postConnect(allocator: Allocator, link: *WorkerLink, host: *anyopaque, end: *anyopaque) void {
    const task = allocator.create(Connect) catch return message_ports.discard(end);
    task.* = .{ .allocator = allocator, .thread_host = @ptrCast(@alignCast(host)), .end = end };
    // A closed sink drops it.
    _ = link.worker_sink.post(.{ .run = Connect.run, .drop = Connect.drop, .data = task });
}

/// A `connect` for a shared worker, as a task of its loop: the channel end
/// that becomes its inside port.
const Connect = struct {
    allocator: Allocator,
    /// The worker's thread host: read only by `run`, on the worker's thread,
    /// while its loop runs (the host goes after the loop has ended, and a
    /// task never run is dropped, not run).
    thread_host: *ThreadHost,
    end: *anyopaque,

    fn run(data: ?*anyopaque) void {
        const self: *Connect = @ptrCast(@alignCast(data.?));
        const end = self.end;
        const thread_host = self.thread_host;
        self.allocator.destroy(self);
        const host = thread_host.host orelse return message_ports.discard(end);
        host.connectInsidePort(end);
    }

    /// Never run: the worker is ending. Any thread: the end is discarded
    /// (thread-safe), no engine touched.
    fn drop(data: ?*anyopaque) void {
        const self: *Connect = @ptrCast(@alignCast(data.?));
        const end = self.end;
        self.allocator.destroy(self);
        message_ports.discard(end);
    }
};

/// HTML "initialize a worker global scope's policy container" for a worker
/// whose script `fetched` is, created by the global whose realm is
/// `owner_realm`: a clone of the owner's for a local URL (a data: or blob:
/// script - for blob:, "create a policy container from a fetch response"
/// step 1 takes its blob URL entry's environment's, which is the creator's
/// here: the blob store answers only the creator's origin), else the
/// response's. A new container when neither can be had.
pub fn workerPolicyContainer(allocator: Allocator, fetched: *workers.FetchedScript, owner_realm: runtime.Context) fetch_mod.internal.PolicyContainer {
    const PolicyContainer = fetch_mod.internal.PolicyContainer;
    // Step 2: the response's, when a network fetch made one. Upgrade
    // Insecure Requests 3.3: a worker inherits its creator's insecure
    // requests policy ("set up a worker environment settings object").
    if (fetched.takePolicyContainer()) |container| {
        var result = container;
        if (creatorPolicyContainer(owner_realm)) |owner| {
            if (owner.upgradesInsecureRequests()) result.inherited_upgrade_insecure_requests = true;
        }
        return result;
    }
    // Step 1: "If workerGlobalScope's url is local but its scheme is not
    // "blob"": a clone of its owner's - the one owner a dedicated worker,
    // or a shared worker's creator, has.
    if (creatorPolicyContainer(owner_realm)) |owner| return owner.clone(allocator) catch PolicyContainer.init(allocator);
    return PolicyContainer.init(allocator);
}

/// The policy container of the global whose realm is `realm`: the
/// worker's creator's settings object's.
pub fn creatorPolicyContainer(realm: runtime.Context) ?*const fetch_mod.internal.PolicyContainer {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const settings = @import("dom").global_settings.of(global) orelse return null;
    const container_of = settings.policy_container orelse return null;
    return container_of(global);
}

/// The cookie jar of the global whose realm is `realm`: the worker's
/// creator's settings object's.
fn creatorCookieJar(realm: runtime.Context) ?*CookieJar {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return @import("dom").global_settings.cookieJarOf(global);
}

// ============================================================================
// import() in a worker - the agent's host hooks
// ============================================================================

/// A worker agent's host hooks (HTML "obtain a dedicated/shared worker
/// agent", which `WorkerHost.initOnThread` does): HostLoadImportedModule for
/// import() and HostGetImportMetaProperties for the modules it loads. The
/// hooks' `host` is the WorkerHost. (Only an engine with modules calls them.)
const worker_hooks: engine.HostHooks = .{
    .loadImportedModule = if (module_script.supported) loadImportedModule else null,
    .importMetaUrl = if (module_script.supported) module_script.importMetaUrl else null,
    .importMetaResolve = if (module_script.supported) importMetaResolve else null,
    // HTML 8.1.6.4 HostPromiseRejectionTracker, and "perform a microtask
    // checkpoint" step 5 - the unhandledrejection and rejectionhandled events
    // at the worker's global scope. A worker agent had neither, so no worker
    // ever heard one.
    .promiseRejectionTracker = rejected_promises.hooks.promiseRejectionTracker,
    .afterMicrotaskCheckpoint = @import("microtask_checkpoint.zig").afterMicrotaskCheckpoint,
};

/// A worker's module evaluation promise, waiting to settle. Its host
/// is read only while it is still on this thread's `hosts` list, and its
/// realm is the same one.
const PendingModuleEvaluation = struct {
    host: *WorkerHost,
    realm: runtime.Context,

    const steps: engine.PromiseReactionSteps = .{
        .fulfilled = settled,
        .rejected = rejected,
        .dropped = dropped,
    };

    fn liveHost(self: *const PendingModuleEvaluation) ?*WorkerHost {
        for (hosts.items) |host| {
            if (host == self.host and host.realm == self.realm and host.runsTasks()) return host;
        }
        return null;
    }

    fn settled(data: ?*anyopaque, _: runtime.JSValue) void {
        dropped(data);
    }

    /// Fulfilled, or ended without a step (the realm ended first): freed.
    fn dropped(data: ?*anyopaque) void {
        const self: *PendingModuleEvaluation = @ptrCast(@alignCast(data orelse return));
        std.heap.c_allocator.destroy(self);
    }

    fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
        const self: *PendingModuleEvaluation = @ptrCast(@alignCast(data orelse return));
        defer std.heap.c_allocator.destroy(self);
        const host = self.liveHost() orelse return;
        host.reportValue(self.realm, reason);
    }
};

/// HTML HostGetImportMetaProperties steps 4-6 in a worker -
/// `HostHooks.importMetaResolve`: resolve a module specifier against
/// `base_url` in the worker whose realm is `realm` (a worker global's import
/// map is empty). OWNED (`allocator`), or null for the TypeError.
fn importMetaResolve(host: ?*anyopaque, realm: runtime.Context, base_url: []const u8, specifier: []const u8, allocator: Allocator) ?[]u8 {
    const agent_host: *html_core.agent_host.AgentHost = @ptrCast(@alignCast(host orelse return null));
    const self: *WorkerHost = @fieldParentPtr("agent_host", agent_host);
    if (self.realm != realm) return null;
    const env = self.moduleEnvironment() orelse return null;
    const url = module_script.resolve(&env, specifier, base_url) orelse return null;
    defer env.context_instance.ctx.allocator.free(url);
    return allocator.dupe(u8, url) catch null;
}

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
    const agent_host: *html_core.agent_host.AgentHost = @ptrCast(@alignCast(host orelse
        return finishImportWithTypeError(realm, request, "import() is not supported here")));
    const self: *WorkerHost = @fieldParentPtr("agent_host", agent_host);
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
    /// The fetch task ran, and finished the request.
    finished: bool = false,
};

fn runDynamicImport(context_ptr: ?*anyopaque) void {
    const task: *DynamicImportTask = @ptrCast(@alignCast(context_ptr orelse return));
    const self = task.host;
    self.forgetImport(task);
    defer self.freeImport(task);

    // A worker whose closing flag is set runs no further task: the import is
    // discarded, and its request finished to release what it holds.
    if (!self.runsTasks()) return finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });

    self.runTask(dynamicImportSteps, task);
    // runTask runs nothing in a realm that has gone: the request is finished
    // either way.
    if (!task.finished) finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });
}

/// The fetch task was discarded with the worker's other tasks (its closing
/// flag is set): it stays on its host's `pending_imports`, whose realm's end
/// finishes its request while the agent lives (`finishPendingImports`).
fn droppedDynamicImport(_: ?*anyopaque) void {}

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
            // CSSStyleSheet is not exposed in a worker: a CSS module request
            // is a TypeError, and nothing is fetched for it.
            .css_allowed = false,
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
        // A task of the worker's loop; a closing worker's is dropped at once,
        // and stays pending for the realm's end.
        self.event_loop.queueTask(.{ .callback = runDynamicImport, .context = task, .drop = droppedDynamicImport });
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

    /// Discard the import()s whose fetch task has not run - the realm ends
    /// after the loop dropped its tasks - and finish each one's request,
    /// which rejects a promise nothing will observe, so the engine's hold on
    /// it ends while the agent is alive.
    fn finishPendingImports(self: *WorkerHost) void {
        while (self.pending_imports.pop()) |task| {
            finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });
            self.freeImport(task);
        }
    }
};

// ============================================================================
// A worker on a thread of its own
// ============================================================================

/// A worker object - a Worker, or the SharedWorker that ran a shared worker
/// - as its worker's tasks for it find it: its address and slab generation -
/// checked on the owner's thread before every use, since a collected
/// object's slot can be reissued - and its owner side's steps. The worker's
/// thread never dereferences it.
pub const OwnerWorker = struct {
    instance: *runtime.Instance,
    generation: u64,
    steps: *const OwnerSteps,

    /// The Worker, if it is still the object this was made for. Owner's
    /// thread only.
    fn live(self: OwnerWorker) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// What a worker's tasks do at its worker object, on the object's thread -
/// the Worker or SharedWorker impl's steps (its state is its own).
pub const OwnerSteps = struct {
    /// HTML "report an exception" step 7: an error a dedicated worker's
    /// global scope did not handle - fire an ErrorEvent at the Worker.
    error_reported: *const fn (worker: *runtime.Instance, report: *const ErrorReport.Info) void,
    /// "Run a worker" onComplete step 1.1: the worker could not start (its
    /// script is null or did not parse, its realm could not be made) - fire
    /// `error`; also the shared worker manager's step 4.1.
    start_failed: *const fn (worker: *runtime.Instance) void,
    /// The worker's script has run: it started. Null when the object does
    /// not need to hear it (a Worker hears its end instead).
    started: ?*const fn (worker: *runtime.Instance) void = null,
    /// The worker has ended: its thread is joined, its link unregistered.
    ended: *const fn (worker: *runtime.Instance) void,
};

/// A task of the worker object's loop, posted by its worker: an error it
/// reported, its start, or its failure to start. Its strings are owned (the
/// worker's allocator, which is thread-safe).
pub const ErrorReport = struct {
    allocator: Allocator,
    owner: OwnerWorker,
    kind: enum { exception, start_failed, started },
    info: Info,

    pub const Info = struct {
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    };

    fn create(allocator: Allocator, owner: OwnerWorker, info: Info) Allocator.Error!*ErrorReport {
        const message = try allocator.dupe(u8, info.message);
        errdefer allocator.free(message);
        const filename = try allocator.dupe(u8, info.filename);
        errdefer allocator.free(filename);
        const self = try allocator.create(ErrorReport);
        self.* = .{
            .allocator = allocator,
            .owner = owner,
            .kind = .exception,
            .info = .{ .message = message, .filename = filename, .lineno = info.lineno, .colno = info.colno },
        };
        return self;
    }

    fn startFailed(allocator: Allocator, owner: OwnerWorker) Allocator.Error!*ErrorReport {
        return outcome(allocator, owner, .start_failed);
    }

    fn started(allocator: Allocator, owner: OwnerWorker) Allocator.Error!*ErrorReport {
        return outcome(allocator, owner, .started);
    }

    fn outcome(allocator: Allocator, owner: OwnerWorker, kind: @FieldType(ErrorReport, "kind")) Allocator.Error!*ErrorReport {
        const self = try allocator.create(ErrorReport);
        self.* = .{
            .allocator = allocator,
            .owner = owner,
            .kind = kind,
            .info = .{ .message = "", .filename = "", .lineno = 0, .colno = 0 },
        };
        return self;
    }

    /// On the owner's thread.
    fn run(data: ?*anyopaque) void {
        const self: *ErrorReport = @ptrCast(@alignCast(data.?));
        defer destroy(self);
        const worker = self.owner.live() orelse return;
        switch (self.kind) {
            .exception => self.owner.steps.error_reported(worker, &self.info),
            .start_failed => self.owner.steps.start_failed(worker),
            .started => if (self.owner.steps.started) |started_steps| started_steps(worker),
        }
    }

    /// Never run: its owner's loop has ended. Any thread.
    fn drop(data: ?*anyopaque) void {
        destroy(@ptrCast(@alignCast(data.?)));
    }

    fn destroy(self: *ErrorReport) void {
        self.allocator.free(self.info.message);
        self.allocator.free(self.info.filename);
        self.allocator.destroy(self);
    }
};

/// "Run a worker", as its worker object's side hands it over: a dedicated
/// worker's Worker constructor (step 9: "run this step in parallel"), or the
/// shared worker manager's steps. The script is fetched first - the Worker
/// constructor must, before it returns: a blob URL revoked right after
/// `new Worker(url)` still runs - so the thread starts with it in hand.
pub const WorkerStart = struct {
    /// The classic script's source, or a module graph's root's. BORROWED
    /// (copied).
    source: []const u8,
    /// The script's response URL: the worker global scope's URL. BORROWED
    /// (copied).
    script_url: []const u8,
    worker_type: WorkerType,
    /// options["name"]. BORROWED (copied).
    name: []const u8,
    /// The global scope's policy container, as "initialize a worker global
    /// scope's policy container" chose it. Taken on success.
    policy_container: ?fetch_mod.internal.PolicyContainer,
    /// The user agent's cookie jar, the creating global's (Browser-lifetime,
    /// locked).
    cookie_jar: ?*CookieJar,
    /// The Worker object's realm - the worker's owner.
    owner_realm: runtime.Context,
    owner_worker: OwnerWorker,
    /// The implicit port: the end of the Worker's channel that its global
    /// scope receives on. Taken on success.
    inside_end: ?*port_channels.End,
    /// "Run a worker" step 3, the unsafe worker creation time, in
    /// milliseconds since the epoch: the global scope's time origin.
    time_origin_ms: ?f64 = null,
    /// A shared worker's constructor key, type and credentials ("run a
    /// worker" step 10); null for a dedicated worker. Taken on success.
    shared: ?SharedScope = null,
};

/// Start a dedicated worker on a thread of its own: a link shared with the
/// owner's thread (`owner_realm`'s loop hears the worker through its sink),
/// registered with the Browser's WorkerRegistry, and a WorkerThread whose
/// host is `ThreadHost`. The owner's reference to the link, which it ends
/// with `terminate()` and `release()`. On success `start.policy_container`
/// and `start.inside_end` are taken (null); on failure the caller still
/// holds them, and nothing runs.
pub fn startDedicatedWorker(allocator: Allocator, start: *WorkerStart) !*WorkerLink {
    // The owner's loop's inbox: where the worker's messages, errors and end
    // go. A realm with none (no event loop made it) runs no worker.
    const owner_sink = start.owner_realm.task_sink orelse return error.NoEventLoop;
    const registry = WorkerRegistry.of(start.owner_realm);
    const link = try WorkerLink.create(allocator, owner_sink);
    errdefer link.release();
    link.owner_realm = start.owner_realm;
    if (registry) |r| try r.register(link);
    errdefer if (registry) |r| r.unregister(link);

    const thread_host = try ThreadHost.create(allocator, start);
    errdefer thread_host.destroyUnstarted();
    const owner_end = try allocator.create(OwnerEnd);
    errdefer allocator.destroy(owner_end);
    owner_end.* = .{ .allocator = allocator, .owner = start.owner_worker, .registry = registry };

    try WorkerThread.spawn(allocator, link, thread_host.asHost(), owner_end.asOwner(), registry);
    // The thread has them now.
    start.policy_container = null;
    start.inside_end = null;
    return link;
}

/// The owner's side of a worker's end: a task of the owner's loop once the
/// worker's thread is at its last instruction (WorkerThread.Owner). A shared
/// worker's owner's loop is its creator's - the Browser's window loop - and
/// its end also leaves the shared worker manager.
const OwnerEnd = struct {
    allocator: Allocator,
    owner: OwnerWorker,
    registry: ?*WorkerRegistry,
    manager: ?*SharedWorkerManager = null,

    fn asOwner(self: *OwnerEnd) WorkerThread.Owner {
        return .{ .data = self, .ended = ended, .drop = dropped };
    }

    /// The owner's thread: join the worker's thread, forget it, and tell the
    /// Worker - whose pending activity can end now.
    fn ended(data: ?*anyopaque, link: *WorkerLink) void {
        const self: *OwnerEnd = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        link.join();
        if (self.registry) |registry| registry.unregister(link);
        if (self.manager) |manager| manager.remove(link);
        if (self.owner.live()) |worker| self.owner.steps.ended(worker);
    }

    /// The end never reaches the owner: its loop ended first (an outer
    /// worker's end, which has joined this thread already; the Browser's,
    /// which joins every thread first). A thread not yet joined stays
    /// registered for whoever joins it.
    fn dropped(data: ?*anyopaque, link: *WorkerLink) void {
        const self: *OwnerEnd = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        // Closing or ended: no constructor matches it any more.
        if (self.manager) |manager| manager.remove(link);
        if (link.hasThread()) return;
        if (self.registry) |registry| registry.unregister(link);
    }
};

/// The worker host's part of a worker's thread (WorkerThread.Host): "run a
/// worker" from step 4 on, the realm's end, and the host's memory - all on
/// the worker's thread.
const ThreadHost = struct {
    allocator: Allocator,
    start: Start,
    /// The worker's host, once its start step made it.
    host: ?*WorkerHost = null,

    /// What the thread starts with: the owner's inputs, copied.
    const Start = struct {
        source: []u8,
        script_url: []u8,
        worker_type: WorkerType,
        name: []u8,
        policy_container: ?fetch_mod.internal.PolicyContainer,
        cookie_jar: ?*CookieJar,
        browser_scope: ?*runtime.BrowserScope,
        owner_worker: OwnerWorker,
        inside_end: ?*port_channels.End,
        time_origin_ms: ?f64,
        shared: ?SharedScope,
    };

    fn create(allocator: Allocator, start: *const WorkerStart) !*ThreadHost {
        const source = try allocator.dupe(u8, start.source);
        errdefer allocator.free(source);
        const script_url = try allocator.dupe(u8, start.script_url);
        errdefer allocator.free(script_url);
        const name = try allocator.dupe(u8, start.name);
        errdefer allocator.free(name);
        const self = try allocator.create(ThreadHost);
        self.* = .{
            .allocator = allocator,
            .start = .{
                .source = source,
                .script_url = script_url,
                .worker_type = start.worker_type,
                .name = name,
                .policy_container = start.policy_container,
                .cookie_jar = start.cookie_jar,
                .browser_scope = start.owner_realm.browser_scope,
                .owner_worker = start.owner_worker,
                .inside_end = start.inside_end,
                .time_origin_ms = start.time_origin_ms,
                .shared = start.shared,
            },
        };
        return self;
    }

    /// A thread host whose thread never started: what it copied goes; what
    /// it would have taken stays the caller's.
    fn destroyUnstarted(self: *ThreadHost) void {
        self.start.policy_container = null;
        self.start.inside_end = null;
        self.start.shared = null;
        self.freeStart();
        self.allocator.destroy(self);
    }

    fn freeStart(self: *ThreadHost) void {
        self.allocator.free(self.start.source);
        self.allocator.free(self.start.script_url);
        self.allocator.free(self.start.name);
        if (self.start.policy_container) |*container| container.deinit();
        self.start.policy_container = null;
        if (self.start.inside_end) |end| end.discard();
        self.start.inside_end = null;
        if (self.start.shared) |*shared| shared.deinit(self.allocator);
        self.start.shared = null;
    }

    fn asHost(self: *ThreadHost) WorkerThread.Host {
        return .{ .data = self, .start = startSteps, .end_realm = endRealm, .free = free };
    }

    /// "Run a worker" steps 4-13 on the worker's thread. False when the
    /// worker does not run: terminated before it started, or failed.
    fn startSteps(data: ?*anyopaque, thread: *WorkerThread) bool {
        const self: *ThreadHost = @ptrCast(@alignCast(data.?));
        // 4. The agent, on this thread.
        const runs = WorkerHost.initOnThread(self.allocator, self, thread) catch {
            self.reportStartFailure(thread.link);
            return false;
        };
        const worker_host = self.host.?;
        // The implicit port, until the realm's end.
        worker_host.inside_end = self.start.inside_end;
        self.start.inside_end = null;
        if (!runs) return false;

        // 5-9. The realm, whose global object is a new
        // DedicatedWorkerGlobalScope - or SharedWorkerGlobalScope, when
        // `is shared` - and the host's built-ins on it.
        worker_host.setupWorkerGlobalScope() catch {
            self.reportStartFailure(thread.link);
            return false;
        };
        // onComplete 3-5 for a dedicated worker: the inside port, its message
        // event target the global scope, entangled with the Worker's outside
        // port (they are one channel already) - bound to this thread's loop.
        // (A shared worker's inside ports arrive with each `connect`.)
        worker_host.bindInsidePort();

        // onComplete 10: run the script.
        switch (self.start.worker_type) {
            // An exception it throws is reported to the global scope, then
            // the Worker; the worker runs on.
            .classic => {
                worker_host.executeScript(self.start.source) catch |err| log.debug("worker script: {}", .{err});
                // onComplete 1: a script that did not parse has an error to
                // rethrow - `error` at the Worker, and the worker runs nothing.
                if (worker_host.own_script_parse_failed) {
                    self.reportStartFailure(thread.link);
                    return false;
                }
            },
            // onComplete 1: a module graph that is null, or has an error to
            // rethrow, fires `error` at the worker object, and the worker's
            // settings are discarded. A shared worker's graph is keyed by its
            // constructor URL.
            .module => {
                const url = if (worker_host.shared) |shared| shared.constructor_url else self.start.script_url;
                if (!worker_host.executeModuleScript(url, self.start.source)) {
                    self.reportStartFailure(thread.link);
                    return false;
                }
            },
        }
        // The source is not needed again.
        self.allocator.free(self.start.source);
        self.start.source = &.{};
        // The worker started: its SharedWorker's pending activity can end.
        if (worker_host.shared != null) self.reportStarted(thread.link);

        // onComplete 12: enable the implicit port's message queue - what the
        // owner posted before now is delivered from the next turn on. (Step
        // 11, the outside port's queue, is enabled by the Worker
        // constructor: see Worker.zig.)
        if (worker_host.inside_end) |end| end.enable();
        return true;
    }

    /// Post "run a worker" onComplete 1.1 to the worker object's loop.
    fn reportStartFailure(self: *ThreadHost, link: *WorkerLink) void {
        const report = ErrorReport.startFailed(self.allocator, self.start.owner_worker) catch return;
        // A closed sink - the owner's loop has ended - drops it.
        _ = link.owner_sink.post(.{ .run = ErrorReport.run, .drop = ErrorReport.drop, .data = report });
    }

    /// Post the worker's start - its script has run - to the worker object's
    /// loop.
    fn reportStarted(self: *ThreadHost, link: *WorkerLink) void {
        const report = ErrorReport.started(self.allocator, self.start.owner_worker) catch return;
        // A closed sink - the owner's loop has ended - drops it.
        _ = link.owner_sink.post(.{ .run = ErrorReport.run, .drop = ErrorReport.drop, .data = report });
    }

    /// The realm's end, with the agent alive and the loop's tasks dropped
    /// (WorkerThread step c): "run a worker" steps 16-17 and the engine's end
    /// of the realm.
    fn endRealm(data: ?*anyopaque, _: *WorkerThread) void {
        const self: *ThreadHost = @ptrCast(@alignCast(data.?));
        const worker_host = self.host orelse return;
        worker_host.teardownRealm();
        // The loop - its timers - ends next: nothing may reach them after.
        worker_host.timer = null;
    }

    /// After the agent's end: the host's memory and the thread host's, on
    /// the worker's thread.
    fn free(data: ?*anyopaque) void {
        const self: *ThreadHost = @ptrCast(@alignCast(data.?));
        if (self.host) |worker_host| worker_host.free();
        self.freeStart();
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WorkerHost - struct definition" {
    const T = WorkerHost;
    try std.testing.expect(@sizeOf(T) > 0);
}
