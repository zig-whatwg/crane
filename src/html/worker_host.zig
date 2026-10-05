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
//! - its event loop. A DEDICATED worker runs on a thread of its own
//!   (docs/instances.md, "Decisions"; html/worker_thread.zig): its agent, its
//!   realm and this host are made on that thread, its tasks and timers run on
//!   the thread's WorkerEventLoop, and its end runs there synchronously once
//!   its loop stops (`startDedicatedWorker`, `ThreadHost`). A SHARED worker
//!   still runs its tasks as timers on its creator's loop (until workers
//!   batch 2 moves it to a thread of its own too), each ended the worker's
//!   way (`endTask`) - a microtask checkpoint, the engine's posted tasks;
//! - its timers (§ 8.6), messages in both directions (a dedicated worker's
//!   implicit port is one end of a dom.port_channels Channel, whose other end
//!   is its Worker object's outside port), errors reported to its global
//!   scope and then to its Worker object;
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

// The implicit ports' channel, whose ends cross threads.
const port_channels = @import("dom").port_channels;
const PortMessage = port_channels.PortMessage;

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

/// Release a timer context and the handler it holds.
fn freeWorkerTimer(ctx: *WorkerTimerContext) void {
    ctx.callback.release();
    ctx.allocator.destroy(ctx);
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
/// `scopeSettings` and the realm hooks: a dedicated worker's thread has its
/// one; its creator's thread has every shared worker. Freed when it empties,
/// so a worker thread that ends leaves nothing of it.
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

/// Every worker host on this thread whose memory has not gone (`free`):
/// what `endWorkersOn` looks through. `live_contexts` is not enough: a worker
/// leaves it with its realm, and its agent goes one timer later.
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

/// The end of the event loop whose timers are `timers`: its owner, the
/// Browser, is ending, and nothing armed on the loop will fire again. Every
/// worker on it ends now - HTML "terminate a worker" for one still running,
/// then what "run a worker" does once the worker's event loop has exited:
/// the realm goes, then the agent.
///
/// A shared worker's steps are timers on its owner's loop, and so is its end
/// (`scheduleTeardown`); a dedicated worker's thread is ended and joined by
/// the Browser's WorkerRegistry first, and has no step on this loop. A Browser that ended with a worker still running
/// let the Worker object go in its page's teardown, which armed the end, and
/// then dropped the loop with the end unfired: the worker's realm, its agent
/// and this host - every classic script the realm ran - stayed until the
/// process did. That was every worker test run alone, and the last file of
/// each sweep process.
///
/// WHERE this is called matters. The owner calls it BEFORE its page's
/// teardown, while the page realm is alive and entered - the conditions the
/// timer path runs these steps in. Not from inside the page's teardown (the
/// rule `scheduleTeardown` keeps), and not after it: the page realm exits the
/// page isolate when it ends, and a worker agent ended with no isolate
/// entered was read as the thread's host agent, taking the thread's context
/// manager and templates down under the page (protocol_agents.endAgent now
/// records which agent is the host when it is made). The Worker objects then
/// let go in the page's teardown and find their hosts disposed, so `destroy`
/// frees them.
pub fn endWorkersOn(timers: runtime.TimerInterface) void {
    while (nextToEnd(timers)) |host| host.endWithLoop();
    dropSharedConnectsOn(timers);
}

/// A worker on the loop `timers` that has not ended: one whose tasks run on
/// it, or with a teardown step armed there.
fn nextToEnd(timers: runtime.TimerInterface) ?*WorkerHost {
    for (hosts.items) |host| {
        if (host.phase == .disposed) continue;
        // Its script on the stack would be torn down under it. The owner
        // ending its loop is not running a task, so none is; if one were,
        // the worker stays, as it did before.
        if (host.entered > 0 or engine.hasRunningScript(host.agent)) continue;
        const armed_here = if (host.teardown_timer) |armed| armed.timer.ctx == timers.ctx else false;
        const runs_here = if (host.timer) |own| own.ctx == timers.ctx else false;
        if (armed_here or runs_here) return host;
    }
    return null;
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

/// A `connect` task armed on a shared worker's loop, with its timer id.
const ArmedConnect = struct {
    task: *ConnectTask,
    id: runtime.TimerId,
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
    /// Per-agent state shared by the HTML checkpoint hooks and IndexedDB.
    agent_host: html_core.agent_host.AgentHost,

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

    /// The timers the worker's tasks run on. A dedicated worker's are its
    /// own thread's loop's (WorkerEventLoop.timerInterface). A shared
    /// worker's are its creator's loop's: its tasks - timers, message
    /// delivery, fetch settling, its end - are timers there, recorded when
    /// the worker is made, from the creator's realm.
    timer: ?runtime.TimerInterface,

    /// The worker's Browser scope (its creator's), and the cross-thread inbox
    /// of the loop its tasks run on - a dedicated worker's own loop's, a
    /// shared worker's creator's. The worker's realm carries both
    /// (ContextData.browser_scope, .task_sink): a MessagePort made in it
    /// binds its channel end to that inbox, and a Worker made in it is owned
    /// through it. BORROWED.
    browser_scope: ?*runtime.BrowserScope = null,
    task_sink: ?*runtime.TaskSink = null,

    /// Allocator. Thread-safe: a dedicated worker's messages are freed on
    /// the other thread.
    allocator: Allocator,

    /// A dedicated worker's own event loop (WorkerEventLoop.eventLoop), which
    /// its realm records for host algorithms that queue tasks. Null for a
    /// shared worker.
    event_loop: ?runtime.EventLoop = null,

    /// A dedicated worker on a thread of its own: what this host shares with
    /// its owner's thread (the worker side's reference is the thread's, not
    /// this host's). Null for a shared worker. Its state is the closing flag
    /// of the worker's global scope.
    link: ?*WorkerLink = null,

    /// A dedicated worker's implicit port: its end of the channel whose other
    /// end is its Worker object's outside port ("run a worker" onComplete
    /// steps 3-5). Bound to this host on the worker's loop - its messages are
    /// fired at the global scope - from setup until the realm's end, which
    /// discards it ("run a worker" step 17: disentangle the worker's ports).
    inside_end: ?*port_channels.End = null,

    /// The worker's creation time in milliseconds since the epoch ("run a
    /// worker" step 3), its global scope's time origin; null when the host
    /// has none (a shared worker: now, when its global scope is made).
    time_origin_ms: ?f64 = null,

    /// A dedicated worker's Worker object, as its owner's tasks find it: an
    /// address and slab generation, never dereferenced on this thread - an
    /// error report carries them to the owner's loop
    /// (`sendErrorToParent`), which checks the generation there.
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

    /// The timer that runs the next teardown step, while one is armed.
    teardown_timer: ?MessageDispatchTimer = null,

    /// The timer that pumps the engine's posted tasks while nothing else
    /// would (`armPlatformPump`), while one is armed.
    platform_pump: ?MessageDispatchTimer = null,

    /// A shared worker's manager has let go. Its memory goes once this is set
    /// and the agent is disposed.
    owner_released: bool = false,

    /// A shared worker's: what its SharedWorkerGlobalScope was made with,
    /// which the shared worker manager matches a SharedWorker constructor
    /// against. Null for a dedicated worker.
    shared: ?SharedScope = null,

    /// A shared worker's `connect` events whose tasks are armed and have not
    /// run: discarded with the worker's other tasks.
    pending_connects: std.ArrayListUnmanaged(ArmedConnect) = .empty,

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

    /// import()s whose fetch task is queued and has not run: each holds an
    /// engine request that must be finished while the agent lives.
    pending_imports: std.ArrayListUnmanaged(*DynamicImportTask) = .empty,

    const Self = @This();

    /// A SHARED worker for `script_url`, on its creator's thread: "run a
    /// worker" step 4, obtain a shared worker agent with this host's hooks
    /// (`worker_hooks`). The realm follows when the global scope is set up.
    ///
    /// `creator` is the realm that made the worker: its timers are the loop
    /// the worker's tasks run on, and its scope and inbox the worker realm's.
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
        creator: runtime.Context,
    ) !*Self {
        const timer = creator.getOptionalTimer();
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // The hooks share an AgentHost, embedded before the agent exists.
        self.agent_host = html_core.agent_host.AgentHost.init(allocator);
        errdefer self.agent_host.deinit();
        const agent = try engine.createAgent(.{
            .can_block = true,
            .from_snapshot = false,
            .hooks = &worker_hooks,
            .host = &self.agent_host,
        });
        self.* = .{
            .agent = agent,
            .agent_host = self.agent_host,
            .script_url = url_copy,
            .worker_type = worker_type,
            .policy_container = fetch_mod.internal.PolicyContainer.init(allocator),
            .timer = timer,
            .browser_scope = creator.browser_scope,
            .task_sink = creator.task_sink,
            .allocator = allocator,
        };
        live_contexts.append(std.heap.page_allocator, self) catch {};
        hosts.append(std.heap.page_allocator, self) catch {};
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
    /// close() in its script, or (a dedicated worker's) "terminate a worker"
    /// from its owner's thread.
    pub fn runsTasks(self: *const Self) bool {
        if (self.phase != .running) return false;
        const link = self.link orelse return true;
        return link.runsTasks();
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
    /// checkpoint. A shared worker, whose tasks are timers on its creator's
    /// loop, also runs the tasks the engine has posted for its agent, and
    /// keeps a pump armed while background work is left; a dedicated
    /// worker's own loop does both every turn. Call with the agent entered.
    fn endTask(self: *Self) void {
        if (self.realm != null) engine.performMicrotaskCheckpoint(self.agent) catch {};
        if (self.link != null) return;
        _ = engine.runEngineTasks(self.agent);
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
        const timer = self.timer orelse return;
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
    // A shared worker's connections
    // ------------------------------------------------------------------

    /// A new inside port on `end` - a MessagePort of this worker's realm,
    /// entangled with its SharedWorker's outsidePort - and a task on the
    /// worker's loop to fire `connect` at its global scope carrying it: the
    /// shared worker manager's steps 5.5-5.7, and "run a worker" onComplete
    /// steps 3, 5 and 13. Takes `end`.
    fn connectPort(self: *Self, end: *anyopaque) void {
        const realm = self.realm orelse return message_ports.discard(end);
        const timer = self.timer orelse return message_ports.discard(end);
        if (!self.runsTasks()) return message_ports.discard(end);
        const port = message_ports.receive(realm, end) catch return;
        const generation = runtime.SlabAllocator.generationOf(port);
        const task = self.allocator.create(ConnectTask) catch {
            port.releaseIfUnwrapped(generation);
            return;
        };
        task.* = .{ .host = self, .port = port, .generation = generation };
        const id = timer.setTimeout(0, ConnectTask.run, task);
        if (id == 0) {
            self.allocator.destroy(task);
            port.releaseIfUnwrapped(generation);
            return;
        }
        self.pending_connects.append(self.allocator, .{ .task = task, .id = id }) catch {};
    }

    /// `task` has run: it is no longer armed.
    fn forgetConnect(self: *Self, task: *ConnectTask) void {
        for (self.pending_connects.items, 0..) |armed, i| {
            if (armed.task == task) {
                _ = self.pending_connects.swapRemove(i);
                return;
            }
        }
    }

    /// Discard the `connect` tasks not yet run, and the ports they carried.
    fn cancelConnects(self: *Self) void {
        const timer = self.timer orelse return;
        for (self.pending_connects.items) |armed| {
            _ = timer.clearTimeout(armed.id);
            armed.task.port.releaseIfUnwrapped(armed.task.generation);
            self.allocator.destroy(armed.task);
        }
        self.pending_connects.clearRetainingCapacity();
    }

    // ------------------------------------------------------------------
    // The end of a worker
    // ------------------------------------------------------------------

    /// HTML "terminate a worker" for a SHARED worker, on its creator's
    /// thread (a failed start, or the end of its creator's loop): 1. set the
    /// closing flag, 2. discard the worker's tasks. Step 3 has nothing to
    /// abort - its script runs on this thread, so it cannot be running - and
    /// step 4 is a dedicated worker's. The realm and the agent then go, from
    /// later tasks (`scheduleTeardown`). A dedicated worker is terminated
    /// through its link (WorkerLink.terminate), from its owner's thread.
    pub fn terminate(self: *Self) void {
        if (self.phase == .realm_gone or self.phase == .disposed) return;
        self.phase = .closing;
        cancelWorkerTimers(self);
        self.cancelConnects();
        disarm(&self.platform_pump);
        self.scheduleTeardown();
    }

    /// WorkerGlobalScope close(), from the worker's own script: 1. discard
    /// the tasks queued for the worker's agent, 2. set the closing flag. The
    /// task that called it runs to its end, and what it posts is delivered
    /// (workers/interfaces/WorkerGlobalScope/close/sending-messages); then
    /// the realm goes - a dedicated worker's at its thread's end, once its
    /// loop sees the flag; a shared worker's from a later timer.
    fn closeFromScript(self: *Self) void {
        if (self.phase != .running) return;
        self.phase = .closing;
        cancelWorkerTimers(self);
        self.cancelConnects();
        disarm(&self.platform_pump);
        if (self.link) |link| {
            // The loop runs no further task; its end discards them.
            _ = link.requestClose();
            return;
        }
        self.scheduleTeardown();
    }

    /// Arm the next teardown step. Every step runs from a timer on the page's
    /// loop, never from the call that ended the worker: that call may be the
    /// worker's own script (close()), a Worker collected inside a page GC's
    /// weak callbacks, or the page's own teardown. A loop that is ending runs
    /// the steps itself first (`endWorkersOn`). With no loop to run them on,
    /// the realm and agent stay until the process ends, as they always did.
    fn scheduleTeardown(self: *Self) void {
        if (self.teardown_timer != null or self.phase == .realm_gone or self.phase == .disposed) return;
        const timer = self.timer orelse return;
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
        forgetSharedScope(self);
        cancelWorkerTimers(self);
        self.cancelConnects();
        disarm(&self.platform_pump);
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

    /// Dispose the agent one timer after the realm is gone.
    ///
    /// A fetch whose response arrived before the realm ended has its settle
    /// task armed as a 0 ms timer on the page's loop
    /// (WindowOrWorkerGlobalScope.call_fetch). It has left the fetch list, so
    /// `async_fetch.sweep()` cannot reach it, and when it runs it finds the
    /// realm gone and releases its promise resolver - a handle of THIS agent.
    /// Every such timer was armed before this one, so it runs first.
    fn disposeAgentLater(self: *Self) void {
        const timer = self.timer orelse return;
        const id = timer.setTimeout(0, disposeAgentCallback, self);
        if (id == 0) return;
        self.teardown_timer = .{ .timer = timer, .id = id };
    }

    fn disposeAgentCallback(context_ptr: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context_ptr orelse return));
        self.teardown_timer = null;
        self.disposeAgent();
    }

    /// The agent's end; then this host's memory, if the owner has let go.
    fn disposeAgent(self: *Self) void {
        engine.destroyAgent(self.agent);
        self.phase = .disposed;
        if (self.owner_released) self.free();
    }

    /// This worker's end, now rather than from timers: the loop they would
    /// run on is ending (`endWorkersOn`). Each step leaves the next phase, so
    /// the worker ends disposed - and freed, if its owner has let it go.
    ///
    /// The fetch settle timers `disposeAgentLater` lets run first are dropped
    /// with the loop, unfired: each keeps its resolver, a handle of this
    /// agent, and nothing releases it once the agent is gone.
    fn endWithLoop(self: *Self) void {
        // HTML "terminate a worker": what the worker posted is not delivered.
        if (self.phase == .running) self.terminate();
        disarm(&self.teardown_timer);
        if (self.phase == .closing) self.teardownRealm();
        if (self.phase == .realm_gone) self.disposeAgent();
    }

    /// This host's memory, after its agent's end: a shared worker's from
    /// `disposeAgent`, a dedicated worker's from its thread's last step
    /// (`ThreadHost.free`), on the thread that made it.
    fn free(self: *Self) void {
        removeLive(self);
        removeHost(self);
        // Every timer goes with its global; a worker with no teardown ahead
        // of it still has them here.
        cancelWorkerTimers(self);
        self.timers.deinit(self.allocator);
        forgetSharedScope(self);
        if (self.shared) |*shared| shared.deinit(self.allocator);
        self.cancelConnects();
        self.pending_connects.deinit(self.allocator);
        disarm(&self.teardown_timer);
        disarm(&self.platform_pump);
        // A worker with no teardown ahead of it (no loop to run one on) still
        // has its realm and agent: what they hold of this host goes now.
        self.finishPendingImports();
        self.pending_imports.deinit(self.allocator);
        self.disposeModules();
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
            // A dedicated worker's own loop, which host algorithms queue
            // their tasks on; a shared worker's tasks are its creator's
            // loop's timers.
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

        // A shared worker, whose tasks are its creator's timers: what the
        // engine posted while the script ran, and if it left background work
        // (an asynchronous compile), a pump to finish it. A dedicated
        // worker's loop does both every turn.
        if (self.link == null) {
            _ = engine.runEngineTasks(self.agent);
            self.armPlatformPump(false);
        }
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
        if (self.link == null) {
            _ = engine.runEngineTasks(self.agent);
            self.armPlatformPump(false);
        }
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
        const owner = self.owner_worker orelse return;
        const link = self.link orelse return;
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
        const sink = self.task_sink orelse return;
        end.bind(.{ .sink = sink, .receiver = self, .generation = 0, .hooks = &inside_port_hooks });
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
        return runtime.JSValue.fromNumber(@floatFromInt(self.setTimer(args, false)));
    }

    fn setIntervalSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.fromNumber(0)));
        return runtime.JSValue.fromNumber(@floatFromInt(self.setTimer(args, true)));
    }

    /// clearTimeout() and clearInterval(): remove this's map of setTimeout
    /// and setInterval IDs[id] - the same map for both.
    fn clearTimerSteps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Self = @ptrCast(@alignCast(data orelse return runtime.JSValue.jsUndefined));
        if (args.len < 1) return runtime.JSValue.jsUndefined;
        const id = switch (args[0]) {
            .number => |n| n,
            else => return runtime.JSValue.jsUndefined,
        };
        if (std.math.isNan(id) or std.math.isInf(id) or id < 0) return runtime.JSValue.jsUndefined;
        self.clearTimer(@intFromFloat(id));
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

        const timer = self.timer orelse return 0;
        // Room for the entry first: a timer armed and then not tracked could
        // be neither cleared nor freed with its global.
        self.timers.ensureUnusedCapacity(self.allocator, 1) catch return 0;

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
        timer_ctx.id = self.takeTimerId();
        self.timers.putAssumeCapacityNoClobber(timer_ctx.id, timer_ctx);
        return @intCast(timer_ctx.id);
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
// Shared workers (HTML § 10.2.6.4): the shared worker manager
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

    fn deinit(self: *SharedScope, allocator: Allocator) void {
        allocator.free(self.constructor_origin);
        allocator.free(self.constructor_url);
        allocator.free(self.name);
    }
};

/// HTML's shared worker manager's list of SharedWorkerGlobalScopes: every
/// shared worker this thread runs whose realm has not gone. One per user
/// agent in the spec; one per thread here, which is not observably different
/// (the spec allows one per origin).
threadlocal var shared_scopes: std.ArrayListUnmanaged(*WorkerHost) = .empty;

fn forgetSharedScope(host: *WorkerHost) void {
    for (shared_scopes.items, 0..) |scope, i| {
        if (scope == host) {
            _ = shared_scopes.swapRemove(i);
            return;
        }
    }
}

/// A SharedWorker constructor's step 11 inputs.
pub const SharedWorkerRequest = struct {
    /// The SharedWorker - "worker". It has pending activity until the
    /// manager's steps end, so an `error` event can still reach it.
    worker: *runtime.Instance,
    /// The outside settings' realm: the SharedWorker's relevant realm, whose
    /// loop runs the manager's steps and whose global the worker's creator is.
    owner_realm: runtime.Context,
    /// urlRecord, serialized. BORROWED for the call.
    url: []const u8,
    /// outsideStorageKey, and the constructor origin: the outside settings'
    /// origin, serialized. BORROWED for the call.
    origin: []const u8,
    /// options["name"], ["type"] and ["credentials"]. `name` BORROWED.
    name: []const u8,
    worker_type: WorkerType,
    credentials: workers.RequestCredentials,
    /// The other end of outsidePort's channel, which becomes the inside
    /// port - a MessagePort of the worker's realm. OWNED: the manager takes
    /// it whatever happens, including when this returns an error.
    inside_end: *anyopaque,
};

/// The SharedWorker constructor's step 11: "enqueue the following steps to
/// the shared worker manager". They run as a task on the owner's loop - the
/// manager's parallel queue, which here is the one thread - after the
/// constructor has returned: finding the worker, or running one, enters
/// another agent, which script on the stack must not see.
pub fn connectSharedWorker(request: SharedWorkerRequest) !void {
    errdefer message_ports.discard(request.inside_end);
    const timer = request.owner_realm.getOptionalTimer() orelse return error.NoEventLoop;
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
        .owner_realm = request.owner_realm,
        .timer = timer,
        .url = url,
        .origin = origin,
        .name = name,
        .worker_type = request.worker_type,
        .credentials = request.credentials,
        .inside_end = request.inside_end,
        .allocator = allocator,
    };
    if (request.owner_realm.getOptionalEventLoop()) |loop| {
        // A window's loop drops a task it will not run: `drop` frees it.
        loop.queueTask(.{ .callback = SharedConnect.run, .context = task, .drop = SharedConnect.drop });
    } else {
        // A worker's realm runs its tasks as timers, which are dropped
        // unfired when their loop ends: `endWorkersOn` frees them.
        const id = timer.setTimeout(0, SharedConnect.run, task);
        if (id == 0) return error.NoEventLoop;
        armed_shared_connects.append(std.heap.page_allocator, .{ .task = task, .timer = timer, .id = id }) catch {};
    }
    // Pending activity until the steps end: whatever script holds, the
    // SharedWorker is there for its `error` event.
    engine.keepPlatformObjectAlive(request.worker);
}

/// Manager steps armed as timers (a SharedWorker made in a worker's realm)
/// that have not run.
threadlocal var armed_shared_connects: std.ArrayListUnmanaged(struct {
    task: *SharedConnect,
    timer: runtime.TimerInterface,
    id: runtime.TimerId,
}) = .empty;

/// Free the manager steps armed on the loop `timers`, which is ending.
fn dropSharedConnectsOn(timers: runtime.TimerInterface) void {
    var i: usize = 0;
    while (i < armed_shared_connects.items.len) {
        const armed = armed_shared_connects.items[i];
        if (armed.timer.ctx != timers.ctx) {
            i += 1;
            continue;
        }
        _ = armed_shared_connects.swapRemove(i);
        _ = armed.timer.clearTimeout(armed.id);
        armed.task.finish();
    }
}

/// The manager's steps for one SharedWorker, as a task on its owner's loop.
const SharedConnect = struct {
    worker: *runtime.Instance,
    generation: u64,
    owner_realm: runtime.Context,
    timer: runtime.TimerInterface,
    url: []const u8,
    origin: []const u8,
    name: []const u8,
    worker_type: WorkerType,
    credentials: workers.RequestCredentials,
    /// Null once a MessagePort has taken it.
    inside_end: ?*anyopaque,
    /// The SharedWorker's pending activity has passed to an `error` task.
    hold_passed: bool = false,
    allocator: Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *SharedConnect = @ptrCast(@alignCast(data orelse return));
        for (armed_shared_connects.items, 0..) |armed, i| {
            if (armed.task == self) {
                _ = armed_shared_connects.swapRemove(i);
                break;
            }
        }
        defer self.finish();
        // The SharedWorker went with its realm: nothing to connect.
        if (runtime.SlabAllocator.generationOf(self.worker) != self.generation) return;
        self.steps();
    }

    /// The loop ended with the task queued: the steps never run.
    fn drop(data: ?*anyopaque) void {
        const self: *SharedConnect = @ptrCast(@alignCast(data orelse return));
        self.finish();
    }

    /// The steps' end: the inside end, unless a port took it, and the
    /// SharedWorker's pending activity.
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

    fn steps(self: *SharedConnect) void {
        // 1-2. workerGlobalScope: the scope whose storage key (origin) equals
        // outsideStorageKey, whose closing flag is false, whose constructor
        // URL equals urlRecord and whose name equals options["name"].
        const found: ?*WorkerHost = for (shared_scopes.items) |host| {
            const shared = host.shared orelse continue;
            if (!host.runsTasks()) continue;
            if (!std.mem.eql(u8, shared.constructor_origin, self.origin)) continue;
            if (!std.mem.eql(u8, shared.constructor_url, self.url)) continue;
            if (!std.mem.eql(u8, shared.name, self.name)) continue;
            break host;
        } else null;

        // 3. No user agent configuration disallows the connection.
        if (found) |host| {
            const shared = host.shared.?;
            // 4. A type or credentials mismatch: `error` at worker.
            if (shared.worker_type != self.worker_type or shared.credentials != self.credentials) {
                self.fireError();
                return;
            }
            // 5.1-5.3: a secure context mismatch fires `error` too. Crane's
            // settings objects record no secure context yet, so outside and
            // inside settings of one origin never differ here.
            // 5.4-5.7: associate, a new inside port entangled with
            // outsidePort, and a `connect` event carrying it.
            host.connectPort(self.takeInsideEnd());
            return;
        }

        // 6. Otherwise, run a worker.
        self.runSharedWorker();
    }

    fn takeInsideEnd(self: *SharedConnect) *anyopaque {
        const end = self.inside_end.?;
        self.inside_end = null;
        return end;
    }

    /// "Run a worker" with `is shared` true.
    fn runSharedWorker(self: *SharedConnect) void {
        const allocator = self.allocator;
        // 12. Fetch a classic worker script, or - for a module worker - the
        // root of its module worker script graph (the rest is fetched in the
        // worker's realm, below). A failed fetch is a null script.
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

        // 4. The agent: a shared worker agent, [[CanBlock]] false in the
        // spec - the engine's default blocks, which only Atomics.wait sees.
        const host = WorkerHost.init(allocator, fetched.final_url, self.worker_type, self.owner_realm) catch return self.fireError();
        // The manager owns the worker: its memory goes when its agent does.
        host.owner_released = true;
        host.cookie_jar = creatorCookieJar(self.owner_realm);
        // Its policy container, before any of its script runs.
        host.setPolicyContainer(workerPolicyContainer(allocator, &fetched, self.owner_realm));
        // 10. The constructor origin, URL, type and credentials; 8. the name.
        host.shared = sharedScopeOf(allocator, self) catch {
            host.phase = .disposed;
            engine.destroyAgent(host.agent);
            host.free();
            return self.fireError();
        };
        shared_scopes.append(std.heap.page_allocator, host) catch {};

        // 5-7. The realm, whose global object is a SharedWorkerGlobalScope.
        host.setupWorkerGlobalScope() catch {
            host.terminate();
            return self.fireError();
        };
        // onComplete 3, 5 and 13: the inside port, entangled with outsidePort,
        // for the `connect` event queued once the script has run.
        const inside_end = self.takeInsideEnd();
        switch (self.worker_type) {
            // onComplete 10: run the classic script. An exception it throws
            // is reported to the worker's global scope; the worker runs on.
            .classic => {
                host.executeScript(fetched.source) catch |err| log.debug("shared worker script: {}", .{err});
                // onComplete 1: a script that did not parse has an error to
                // rethrow - `error` at the worker, and its settings are
                // discarded.
                if (host.own_script_parse_failed) {
                    message_ports.discard(inside_end);
                    host.terminate();
                    return self.fireError();
                }
            },
            // A module worker's graph: onComplete 1 - a null script, or one
            // with an error to rethrow, fires `error` at the worker, and the
            // inside settings are discarded. Else run the module script.
            .module => if (!host.executeModuleScript(self.url, fetched.source)) {
                message_ports.discard(inside_end);
                host.terminate();
                return self.fireError();
            },
        }
        host.connectPort(inside_end);
    }

    /// Queue a global task on the owner's loop to fire `error` at worker
    /// (the manager's step 4.1; onComplete 1.1).
    fn fireError(self: *SharedConnect) void {
        const task = self.allocator.create(SharedWorkerError) catch return;
        task.* = .{
            .worker = self.worker,
            .generation = self.generation,
            .owner_realm = self.owner_realm,
            .allocator = self.allocator,
        };
        if (self.timer.setTimeout(0, SharedWorkerError.run, task) == 0) {
            self.allocator.destroy(task);
            return;
        }
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
    };
}

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

/// A task that fires `error` at a SharedWorker: a plain Event, not
/// cancelable, at the object in its own realm.
const SharedWorkerError = struct {
    worker: *runtime.Instance,
    generation: u64,
    owner_realm: runtime.Context,
    allocator: Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *SharedWorkerError = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.worker) != self.generation) return;
        defer engine.releasePlatformObject(self.worker);
        engine.runTaskInRealm(self.owner_realm, fire, self) catch {};
    }

    fn fire(data: ?*anyopaque) void {
        const self: *SharedWorkerError = @ptrCast(@alignCast(data orelse return));
        const event = interfaces.Event.call_constructor(
            self.owner_realm,
            runtime.DOMString.initInterned("error"),
            webidl.Opt(dictionaries.EventInit).notPassed(),
        ) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        _ = fire_event.dispatchTrusted(self.worker, event) catch {};
        event.releaseIfUnwrapped(generation);
    }
};

/// A `connect` event for a shared worker's global scope, waiting for its
/// task: the inside port it carries.
const ConnectTask = struct {
    host: *WorkerHost,
    port: *runtime.Instance,
    generation: u64,

    fn run(data: ?*anyopaque) void {
        const self: *ConnectTask = @ptrCast(@alignCast(data orelse return));
        const host = self.host;
        defer host.allocator.destroy(self);
        host.forgetConnect(self);
        if (!host.runsTasks()) return;
        if (runtime.SlabAllocator.generationOf(self.port) != self.generation) return;
        host.runTask(fire, self);
    }

    /// Fire `connect` at the global scope, using MessageEvent, with data the
    /// empty string and ports and source the inside port.
    fn fire(data: ?*anyopaque) void {
        const self: *ConnectTask = @ptrCast(@alignCast(data orelse return));
        const host = self.host;
        const realm = host.realm orelse return;
        const global_scope = host.global_scope orelse return;
        const ports = [_]*runtime.Instance{self.port};
        const init_dict = dictionaries.MessageEventInit{
            .base = .{},
            .data = runtime.JSValue.fromStringRef(""),
            .ports = &ports,
            .source = .{ .message_port = self.port },
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
        const timer = self.timer orelse return error.NoEventLoop;
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
// A dedicated worker on a thread of its own
// ============================================================================

/// A Worker object, as its worker's tasks for it find it: its address and
/// slab generation - checked on the owner's thread before every use, since a
/// collected Worker's slot can be reissued - and its owner side's steps. The
/// worker's thread never dereferences it.
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

/// What a worker's tasks do at its Worker object, on the Worker's thread -
/// the Worker impl's steps (its state is its own).
pub const OwnerSteps = struct {
    /// HTML "report an exception" step 7: an error the worker's global scope
    /// did not handle - fire an ErrorEvent at the Worker.
    error_reported: *const fn (worker: *runtime.Instance, report: *const ErrorReport.Info) void,
    /// "Run a worker" onComplete step 1.1: the worker could not start (its
    /// module graph failed, or its realm could not be made) - fire `error`.
    start_failed: *const fn (worker: *runtime.Instance) void,
    /// The worker has ended: its thread is joined, its link unregistered.
    ended: *const fn (worker: *runtime.Instance) void,
};

/// A task of the Worker's loop, posted by its worker: an error it reported,
/// or its failure to start. Its strings are owned (the worker's allocator,
/// which is thread-safe).
pub const ErrorReport = struct {
    allocator: Allocator,
    owner: OwnerWorker,
    kind: enum { exception, start_failed },
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
        const self = try allocator.create(ErrorReport);
        self.* = .{
            .allocator = allocator,
            .owner = owner,
            .kind = .start_failed,
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

/// "Run a worker" for a dedicated worker, as its Worker constructor hands
/// it over (step 9: "run this step in parallel"). The constructor fetched the
/// script - it must, before it returns: a blob URL revoked right after
/// `new Worker(url)` still runs - so the thread starts with it in hand.
pub const DedicatedWorkerStart = struct {
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
};

/// Start a dedicated worker on a thread of its own: a link shared with the
/// owner's thread (`owner_realm`'s loop hears the worker through its sink),
/// registered with the Browser's WorkerRegistry, and a WorkerThread whose
/// host is `ThreadHost`. The owner's reference to the link, which it ends
/// with `terminate()` and `release()`. On success `start.policy_container`
/// and `start.inside_end` are taken (null); on failure the caller still
/// holds them, and nothing runs.
pub fn startDedicatedWorker(allocator: Allocator, start: *DedicatedWorkerStart) !*WorkerLink {
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

/// The owner's side of a worker's end: a task of the Worker's loop once the
/// worker's thread is at its last instruction (WorkerThread.Owner).
const OwnerEnd = struct {
    allocator: Allocator,
    owner: OwnerWorker,
    registry: ?*WorkerRegistry,

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
        if (self.owner.live()) |worker| self.owner.steps.ended(worker);
    }

    /// The end never reaches the owner: its loop ended first (an outer
    /// worker's end, which has joined this thread already; the Browser's,
    /// which joins every thread first). A thread not yet joined stays
    /// registered for whoever joins it.
    fn dropped(data: ?*anyopaque, link: *WorkerLink) void {
        const self: *OwnerEnd = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (link.hasThread()) return;
        if (self.registry) |registry| registry.unregister(link);
    }
};

/// The worker host's part of a dedicated worker's thread
/// (WorkerThread.Host): "run a worker" from step 4 on, the realm's end, and
/// the host's memory - all on the worker's thread.
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
    };

    fn create(allocator: Allocator, start: *const DedicatedWorkerStart) !*ThreadHost {
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
            },
        };
        return self;
    }

    /// A thread host whose thread never started: what it copied goes; what
    /// it would have taken stays the caller's.
    fn destroyUnstarted(self: *ThreadHost) void {
        self.start.policy_container = null;
        self.start.inside_end = null;
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
        // DedicatedWorkerGlobalScope, and the host's built-ins on it.
        worker_host.setupWorkerGlobalScope() catch {
            self.reportStartFailure(thread.link);
            return false;
        };
        // onComplete 3-5: the inside port, its message event target the
        // global scope, entangled with the Worker's outside port (they are
        // one channel already) - bound to this thread's loop.
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
            // rethrow, fires `error` at the Worker, and the worker's settings
            // are discarded.
            .module => if (!worker_host.executeModuleScript(self.start.script_url, self.start.source)) {
                self.reportStartFailure(thread.link);
                return false;
            },
        }
        // The source is not needed again.
        self.allocator.free(self.start.source);
        self.start.source = &.{};

        // onComplete 12: enable the implicit port's message queue - what the
        // owner posted before now is delivered from the next turn on. (Step
        // 11, the outside port's queue, is enabled by the Worker
        // constructor: see Worker.zig.)
        if (worker_host.inside_end) |end| end.enable();
        return true;
    }

    /// Post "run a worker" onComplete 1.1 to the Worker's loop.
    fn reportStartFailure(self: *ThreadHost, link: *WorkerLink) void {
        const report = ErrorReport.startFailed(self.allocator, self.start.owner_worker) catch return;
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
