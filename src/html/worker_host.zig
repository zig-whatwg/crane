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

// The agent cluster a dedicated worker's agent is in: its owner's.
const agent_clusters = @import("agent_clusters.zig");
const webassembly_streaming = @import("webassembly_streaming.zig");

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
        error.OperationFailed, error.ExceptionReported, error.MutedScriptError => error.OperationFailed,
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

// ============================================================================
// Animation frames (HTML 8.12) - a dedicated worker's
// ============================================================================
//
// A DedicatedWorkerGlobalScope is its own AnimationFrameProvider's target
// object, and is "supported" when its owner set contains a Document, or a
// DedicatedWorkerGlobalScope that is supported (`ownerSupportsAnimationFrames`,
// read on the owner's thread when it starts the worker). The worker event
// loop's processing model, step 6.1: when the user agent believes the worker
// would benefit from having its rendering updated, it runs the animation
// frame callbacks for the global scope, passing in now. Crane renders
// nothing; a frame is due every `animation_frame_interval_ms` while callbacks
// wait, from one timer armed only then - an idle worker pays nothing - as
// Window's frames are (src/browser/Context.zig). Each callback is the map's
// until it runs, is cancelled, or the worker's tasks are discarded (close(),
// the realm's end: `discardAnimationFrames`), which releases it: a callback
// still queued when the worker ends left its Global for the agent's life
// (lane leaks2: 2 roots under leaks --atExit over workers/).

/// ~60Hz, as a Window's: the spec leaves the rate to the user agent.
const animation_frame_interval_ms: u64 = 16;

/// An entry of a global scope's map of animation frame callbacks.
const AnimationFrameCallback = struct {
    handle: u32,
    /// OWNED.
    callback: engine.CallbackFunction,
};

/// requestAnimationFrame(callback) for the dedicated worker global scope
/// whose realm is `ctx` (HTML 8.12). Takes `callback`: the map keeps it, or
/// it is released here.
pub fn requestAnimationFrame(ctx: runtime.Context, callback: engine.CallbackFunction) error{ NotSupportedError, OutOfMemory }!u32 {
    const wctx = forScope(ctx) orelse {
        // A global scope no worker this host runs has: nothing could ever
        // run its callbacks.
        callback.release();
        return error.NotSupportedError;
    };
    return wctx.requestAnimationFrame(callback);
}

/// cancelAnimationFrame(handle) for the dedicated worker global scope whose
/// realm is `ctx` (HTML 8.12).
pub fn cancelAnimationFrame(ctx: runtime.Context, handle: u32) error{NotSupportedError}!void {
    const wctx = forScope(ctx) orelse return error.NotSupportedError;
    return wctx.cancelAnimationFrame(handle);
}

/// HTML 8.12 "supported", for the dedicated worker the realm `owner_realm`
/// starts: its owner set - that realm's global object, a Window's being its
/// associated Document - contains a Document, or a DedicatedWorkerGlobalScope
/// that is supported. Read on the owner's thread.
fn ownerSupportsAnimationFrames(owner_realm: runtime.Context) bool {
    if (owner_realm.isWindow()) return true;
    const owner = forScope(owner_realm) orelse return false;
    return owner.supportsAnimationFrames();
}

/// The frame's timer: the worker's rendering opportunity.
fn animationFrameTrampoline(data: ?*anyopaque) void {
    const self: *WorkerHost = @ptrCast(@alignCast(data orelse return));
    self.animation_frame_timer = null;
    // A closing worker runs no further task; its end releases the callbacks.
    if (!self.runsTasks() or self.realm == null) return;
    if (self.animation_frame_callbacks.items.len == 0) return;
    self.runTask(AnimationFrames.steps, self);
    // What the callbacks requested waits for the next frame.
    if (self.animation_frame_callbacks.items.len > 0) self.armAnimationFrame();
}

const AnimationFrames = struct {
    /// The worker event loop's step 6.1, as a task of the worker's realm:
    /// 6.1.1. Let now be the current high resolution time given the
    /// DedicatedWorkerGlobalScope. 6.1.2. Run the animation frame callbacks
    /// for it, passing in now.
    fn steps(data: ?*anyopaque) void {
        const self: *WorkerHost = @ptrCast(@alignCast(data orelse return));
        const realm = self.realm orelse return;
        const now = self.currentHighResolutionTime();
        // "Run the animation frame callbacks": 1. Let callbacks be target's
        // map of animation frame callbacks. 2. Let callbackHandles be the
        // result of getting the keys of callbacks. Without memory for them
        // the frame is skipped: the callbacks wait for the next one.
        const handles = self.allocator.alloc(u32, self.animation_frame_callbacks.items.len) catch return;
        defer self.allocator.free(handles);
        for (handles, self.animation_frame_callbacks.items) |*handle, entry| handle.* = entry.handle;
        // 3. For each handle in callbackHandles, if handle exists in
        // callbacks - a callback before it may have cancelled it:
        for (handles) |handle| {
            if (!self.runsTasks()) break;
            const index = self.animationFrameIndex(handle) orelse continue;
            // 3.1-3.2. Let callback be callbacks[handle]; remove it.
            const entry = self.animation_frame_callbacks.orderedRemove(index);
            defer entry.callback.release();
            // 3.3. Invoke callback with « now » and "report".
            const completion = engine.invokeCallbackFunction(realm, &entry.callback, .undefined, &.{.{ .number = now }}, .{
                .report = self.reporter(),
            }) catch continue;
            switch (completion) {
                inline else => |value| value.release(),
            }
        }
    }
};

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
    /// The settings object's time origin (HR-Time): "run a worker" step 3's
    /// unsafe worker creation time, a monotonic moment in nanoseconds, not
    /// yet coarsened (dom.global_settings `time_origin`). Null when the host
    /// recorded none.
    time_origin_ns: ?i64 = null,
    /// Whether the worker's owner - owner set[0]'s relevant settings object,
    /// the global that created it - is a secure context (HTML 8.1.3.5 step
    /// 1.2.1), read on the owner's thread when the worker started.
    owner_is_secure_context: bool = false,
    /// The owner's mixed-content restriction, read on its thread. Opaque
    /// data workers inherit it independently of secure-context status.
    owner_prohibits_mixed_security_contexts: bool = false,
    /// The owner's top-level site (dom.global_settings.topLevelSiteOf), read
    /// on the owner's thread when a dedicated or shared worker started.
    /// BORROWED from the host; null for a service worker or an owner with none.
    top_level_site: ?[]const u8 = null,
    top_level_origin: ?[]const u8 = null,
    /// The storage key's top-level site and has-cross-site-ancestor bit a
    /// DEDICATED or SHARED worker takes from its creator
    /// (`creatorStoragePartition`), read on the creator's thread. BORROWED
    /// from the host; null for a service worker, whose key is its own
    /// origin's.
    storage_top_level_site: ?[]const u8 = null,
    storage_top_level_nonce: ?u128 = null,
    origin_nonce: ?u128 = null,
    has_cross_site_ancestor: bool = false,
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
        .time_origin_ns = wctx.time_origin_ns,
        .owner_is_secure_context = wctx.owner_is_secure_context,
        .owner_prohibits_mixed_security_contexts = wctx.owner_prohibits_mixed_security_contexts,
        .top_level_site = wctx.top_level_site,
        .top_level_origin = wctx.top_level_origin,
        .storage_top_level_site = wctx.storage_top_level_site,
        .storage_top_level_nonce = wctx.storage_top_level_nonce,
        .origin_nonce = wctx.origin_nonce,
        .has_cross_site_ancestor = wctx.has_cross_site_ancestor,
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
    return fetchClassicWorkerImportedScriptWithEntry(ctx, url, null, false);
}

pub fn fetchClassicWorkerImportedScriptWithEntry(ctx: runtime.Context, url: []const u8, entry: ?*fetch_mod.internal.request.CapturedBlobEntry, captured: bool) error{ NetworkError, OutOfMemory }!ImportedScript {
    // A service worker's importScripts() runs Service Workers 6.3.2's fetch
    // hook: its script resource map, set of used scripts and update check.
    if (serviceScopeOf(ctx)) |service| return service.hooks.import_script(service.manager, service.worker_id, ctx, url, entry, captured);
    const allocator = ctx.allocator;
    const request = fetch_mod.internal.InternalRequest.init(allocator, url) catch return error.OutOfMemory;
    defer request.deinit();
    if (captured) request.setCapturedBlobEntry(entry);
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
    const content_type = response.header_list.getFirstValue("content-type") orelse "";
    if (!module_script.isJavaScriptMimeType(content_type)) return error.NetworkError;
    // HTML "fetch a classic worker-imported script" steps 7-8: a
    // successful empty response supplies zero body bytes. Fetch represents
    // that as no Body allocation; it is not a failed body consumption.
    const body = if (response.body) |b| b.data.items else "";

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
/// - a parse error included - reaches importScripts()'s caller as it was
/// thrown, and is not reported: the engine leaves the original exception
/// pending (ExceptionPending), with the location it was thrown at - an
/// uncaught one is reported at the imported script, however many
/// importScripts() calls it crossed (workers/Worker-nested-importScripts-error.html).
/// Throwing the value again from here located it at the importScripts() call.
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

    wctx.entered += 1;
    defer wctx.entered -= 1;
    engine.runClassicScriptRethrowingErrors(realm, .{ .utf8 = script.source }, script.url, record, script.muted) catch |err| switch (err) {
        // 8.2: a muted script's error is a NetworkError.
        error.MutedScriptError => return error.NetworkError,
        else => return err,
    };
}

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
    /// By-value options for this worker's initial module script graph.
    module_fetch_options: workers.ModuleFetchOptions = .{},

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

    /// The worker's creation time ("run a worker" step 3, the unsafe worker
    /// creation time: hr_time's monotonic clock, in nanoseconds), its global
    /// scope's time origin; null when the host has none (a test's: now, when
    /// its Performance is made).
    time_origin_ns: ?i64 = null,

    /// Whether the worker's owner was a secure context when it started the
    /// worker (`ScopeSettings.owner_is_secure_context`).
    owner_is_secure_context: bool = false,

    /// The creator's captured mixed-content restriction, by value.
    owner_prohibits_mixed_security_contexts: bool = false,

    /// The owner's top-level site, for a dedicated worker
    /// (`ScopeSettings.top_level_site`). OWNED.
    top_level_site: ?[]u8 = null,
    top_level_origin: ?[]u8 = null,
    /// The storage key partition taken from the creator
    /// (`ScopeSettings.storage_top_level_site`). OWNED.
    storage_top_level_site: ?[]u8 = null,
    storage_top_level_nonce: ?u128 = null,
    origin_nonce: ?u128 = null,
    has_cross_site_ancestor: bool = false,

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

    /// A service worker's: which service worker its ServiceWorkerGlobalScope
    /// is, and its owner (Service Workers "Setup ServiceWorkerGlobalScope").
    /// Null for a dedicated or shared worker.
    service: ?ServiceScope = null,

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

    /// HTML 8.12: the global scope's map of animation frame callbacks - a
    /// DedicatedWorkerGlobalScope is its own target object - in the order
    /// they were requested. Each callback OWNED until it runs, is cancelled
    /// or the worker's tasks are discarded (`discardAnimationFrames`).
    animation_frame_callbacks: std.ArrayListUnmanaged(AnimationFrameCallback) = .empty,
    /// Its animation frame callback identifier: the last handle handed out.
    animation_frame_identifier: u32 = 0,
    /// The timer manager's id of the next frame's task, armed only while
    /// callbacks wait.
    animation_frame_timer: ?runtime.TimerId = null,
    /// Whether the global scope is a "supported" AnimationFrameProvider
    /// (`ownerSupportsAnimationFrames`, for a dedicated worker).
    animation_frames_owner_supported: bool = false,

    /// The worker's module map (HTML "module map" of its settings object):
    /// keys owned, values a `*module_script.ModuleScript`, disposed with the
    /// realm.
    modules: std.StringHashMapUnmanaged(*anyopaque) = .empty,

    /// The classic scripts run in the realm - the worker's own and each
    /// importScripts() one - as the [[HostDefined]] an import() in them
    /// names: their base URLs. They live as long as the realm, since a
    /// function one defined can call import() at any time.
    classic_scripts: std.ArrayListUnmanaged(*module_script.ClassicScript) = .empty,

    /// The classic script every string timer handler runs as (one of
    /// `classic_scripts`), made on first use (`timerScript`).
    timer_script: ?*module_script.ClassicScript = null,

    /// The worker's module loader: its import()s' fetches - the module map's
    /// callback lists, HTML "fetch a single module script" steps 6-7 - and
    /// their graphs, on the worker's own event loop. Made by the first
    /// import(); destroyed at the realm's end while the realm and agent are
    /// there, before the module map's records (`disposeModules`), as a
    /// Document disposes its loader before its own. OWNED.
    module_loader: ?*module_script.AsyncModuleLoader = null,

    const Self = @This();

    /// This host's "report an exception", as the engine protocol takes it.
    fn reporter(self: *Self) engine.Reporter {
        return .{ .report = reportEngineException, .host = self };
    }

    const moduleEnvironment = WorkerModules.moduleEnvironment;
    const disposeModules = WorkerModules.disposeModules;
    const startImport = WorkerModules.startImport;
    const destroyModuleLoader = WorkerModules.destroyModuleLoader;

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
            .module_fetch_options = start.module_fetch_options,
            .policy_container = fetch_mod.internal.PolicyContainer.init(allocator),
            .timer = thread.loop.timerInterface(),
            .event_loop = thread.loop.eventLoop(),
            .browser_scope = start.browser_scope,
            .task_sink = thread.loop.sink,
            .allocator = allocator,
            .link = thread.link,
            .owner_worker = start.owner_worker,
            .cookie_jar = start.cookie_jar,
            .time_origin_ns = start.time_origin_ns,
            .owner_is_secure_context = start.owner_is_secure_context,
            .owner_prohibits_mixed_security_contexts = start.owner_prohibits_mixed_security_contexts,
            .animation_frames_owner_supported = start.owner_supports_animation_frames,
        };
        // Taken, not copied: the start's allocator is this one, and a move
        // has no failure to unwind.
        self.top_level_site = start.top_level_site;
        start.top_level_site = null;
        self.top_level_origin = start.top_level_origin;
        start.top_level_origin = null;
        self.storage_top_level_site = start.storage_top_level_site;
        self.storage_top_level_nonce = start.storage_top_level_nonce;
        self.origin_nonce = start.origin_nonce;
        start.storage_top_level_site = null;
        self.has_cross_site_ancestor = start.has_cross_site_ancestor;
        // "Obtain a worker/worklet agent" step 3: a dedicated worker's agent
        // is in its owner's agent cluster, which a WebAssembly.Module it
        // serializes is bound to and one it receives is checked against
        // (html.agent_clusters.agentClusterOf).
        self.agent_host.agent_cluster = start.agent_cluster;
        thread_host.host = self;
        hosts.append(std.heap.page_allocator, self) catch {};
        const agent = try engine.createAgent(.{
            .can_block = true,
            .from_snapshot = false,
            .hooks = &worker_hooks,
            .host = &self.agent_host,
            .allocator = allocator,
            // A collected node's teardown is queued here, for the worker's
            // loop to run between tasks (runtime.gc.DeferredTeardown).
            .deferred_teardown = &self.agent_host.deferred_teardown,
            .engine_task_sink = thread.loop.sink,
        });
        self.agent = agent;
        thread.loop.agent = agent;
        thread.loop.deferred_teardown = &self.agent_host.deferred_teardown;
        // The worker agent's fetches, which its loop pumps.
        thread.loop.fetches = &self.agent_host.fetches;
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

    /// A SERVICE worker's host, made on its own thread by its start step
    /// (`ServiceThreadHost.startSteps`): Setup ServiceWorkerGlobalScope step
    /// 8, "obtain a service worker agent" - an agent of its own, [[CanBlock]]
    /// false, in an agent cluster of its own - with this host's hooks, made
    /// with no isolate entered (so recorded as the thread's host agent, as a
    /// dedicated worker's is), published through the link, destroyed by
    /// WorkerThread after the realm's end. Whether the worker still runs.
    fn initServiceOnThread(allocator: Allocator, thread_host: *ServiceThreadHost, thread: *WorkerThread) !bool {
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
            .cookie_jar = start.cookie_jar,
            .time_origin_ns = start.time_origin_ns,
            // HTML 8.1.3.5 step 1.2 asks owner set[0], and a service worker
            // has none: Service Workers 6.1 runs every service worker in a
            // secure context (Start Register step 4 refused a script URL that
            // is not potentially trustworthy), as Blink starts each one. Its
            // realm's [SecureContext] exposure and isSecureContext still read
            // its own URL through secure_context.ofWorker.
            .owner_is_secure_context = true,
            .service = start.service,
            // Service Workers "Run Service Worker" leaves the environment's
            // top-level origin implementation-defined. A service worker's
            // storage key is its registration's (lane sw1-b11; Chromium: a
            // version's storage key is its registration's), so its top-level
            // site is that key's: it keys every request its global makes - the
            // HTTP cache's partition (Fetch 2.7-2.8), the preflight cache's
            // and authentication entries' - as Chromium keys a service worker
            // by its storage key's top-level site. (Before, lane httpcache1's
            // G7: the site of the worker's own origin, unpartitioned.) A
            // start that names no site: its own origin's. Null for an opaque
            // site, an origin with no site, or no memory: its requests then
            // share nothing.
            .top_level_site = site: {
                if (start.top_level_site) |named| {
                    if (std.mem.eql(u8, named, "null")) break :site null;
                    break :site allocator.dupe(u8, named) catch null;
                }
                const origin = fetch_mod.internal.origins.serializedOriginOf(allocator, start.script_url) catch break :site null;
                defer allocator.free(origin);
                break :site agent_clusters.siteOf(allocator, origin) catch null;
            },
            // Its storage key's partition (WorkerGlobalScope's settings):
            // the registration's top-level site and cross-site-ancestor bit.
            .storage_top_level_site = if (start.top_level_site) |named| allocator.dupe(u8, named) catch null else null,
            .has_cross_site_ancestor = start.has_cross_site_ancestor,
        };
        thread_host.host = self;
        hosts.append(std.heap.page_allocator, self) catch {};
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &worker_hooks,
            .host = &self.agent_host,
            .allocator = allocator,
            .deferred_teardown = &self.agent_host.deferred_teardown,
            .engine_task_sink = thread.loop.sink,
        });
        self.agent = agent;
        thread.loop.agent = agent;
        thread.loop.deferred_teardown = &self.agent_host.deferred_teardown;
        thread.loop.fetches = &self.agent_host.fetches;
        const runs = thread.link.publishAgent(agent);
        self.script_url = try allocator.dupe(u8, start.script_url);
        self.name = try allocator.dupe(u8, "");
        // Setup step 8.5: the script resource's policy container. Taken.
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
    // Animation frames (HTML 8.12)
    // ------------------------------------------------------------------

    /// Whether this global scope is a supported AnimationFrameProvider: a
    /// dedicated worker's whose owner set has a Document, or a supported
    /// dedicated worker global scope.
    fn supportsAnimationFrames(self: *const Self) bool {
        return self.animation_frames_owner_supported and self.shared == null and self.service == null;
    }

    /// requestAnimationFrame(callback), taking `callback`.
    fn requestAnimationFrame(self: *Self, callback: engine.CallbackFunction) error{ NotSupportedError, OutOfMemory }!u32 {
        // 1. "If this is not supported, then throw a "NotSupportedError"
        // DOMException."
        if (!self.supportsAnimationFrames()) {
            callback.release();
            return error.NotSupportedError;
        }
        // 2-3. Increment target's animation frame callback identifier by
        // one, and let handle be the result (an unsigned long).
        self.animation_frame_identifier +%= 1;
        const handle = self.animation_frame_identifier;
        // A closing worker runs no further task (its tasks are discarded):
        // the callback could never run.
        if (!self.runsTasks()) {
            callback.release();
            return handle;
        }
        // 4-5. Set callbacks[handle] to callback.
        self.animation_frame_callbacks.append(self.allocator, .{ .handle = handle, .callback = callback }) catch {
            callback.release();
            return error.OutOfMemory;
        };
        self.armAnimationFrame();
        // 6. Return handle.
        return handle;
    }

    /// cancelAnimationFrame(handle).
    fn cancelAnimationFrame(self: *Self, handle: u32) error{NotSupportedError}!void {
        // 1. "If this is not supported, then throw a "NotSupportedError"
        // DOMException."
        if (!self.supportsAnimationFrames()) return error.NotSupportedError;
        // 2-3. Remove callbacks[handle].
        const index = self.animationFrameIndex(handle) orelse return;
        const entry = self.animation_frame_callbacks.orderedRemove(index);
        entry.callback.release();
    }

    fn animationFrameIndex(self: *const Self, handle: u32) ?usize {
        for (self.animation_frame_callbacks.items, 0..) |entry, i| {
            if (entry.handle == handle) return i;
        }
        return null;
    }

    /// The next frame's timer, unless one is armed.
    fn armAnimationFrame(self: *Self) void {
        if (self.animation_frame_timer != null) return;
        const timer = self.timer orelse return;
        const id = timer.setTimeout(animation_frame_interval_ms, animationFrameTrampoline, self);
        if (id != 0) self.animation_frame_timer = id;
    }

    /// The worker's tasks are discarded (close() step 1, "terminate a
    /// worker", the realm's end): the frame's timer is cancelled, and every
    /// callback still in the map is released, never run.
    fn discardAnimationFrames(self: *Self) void {
        if (self.animation_frame_timer) |id| {
            if (self.timer) |timer| _ = timer.clearTimeout(id);
            self.animation_frame_timer = null;
        }
        for (self.animation_frame_callbacks.items) |entry| entry.callback.release();
        self.animation_frame_callbacks.clearAndFree(self.allocator);
    }

    /// HR-Time's current high resolution time given the global scope - what
    /// its performance.now() answers: the coarsened time since its time
    /// origin, in milliseconds. 0 when the global scope has none.
    fn currentHighResolutionTime(self: *const Self) f64 {
        const global_scope = self.global_scope orelse return 0;
        const performance = interfaces.WorkerGlobalScope.get_performance(global_scope) catch return 0;
        return interfaces.Performance.call_now(performance) catch 0;
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
        self.discardAnimationFrames();
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
        // From the start of the realm's end, no fetch of it reports anything
        // more: the global it would report to is going (Resource Timing marks
        // entries for the global; Blink prevents a loader's notifications
        // when the context is destroyed - FetchManager::ContextDestroyed,
        // Loader::Dispose - before it disposes the global scope). Muted only
        // at the sweep after the realm's end (its `retire`), a body the
        // realm's objects held ended its fetch in their teardown and
        // reported timing to a global scope already freed. Muted, not
        // terminated: the fetch group is terminated in that sweep, as
        // before - terminated now, with its readers alive, a body's failure
        // reaches them, and a closing worker's loop runs the drop steps of
        // the tasks they queue at once, inside the failure
        // (AgentFetches.stopReporting).
        self.agent_host.fetches.stopReporting();
        removeLive(self);
        cancelWorkerTimers(self);
        self.discardAnimationFrames();
        // "Run a worker" step 17: disentangle the worker's ports - its
        // implicit port first. Its Worker object's outside port is no longer
        // entangled; what the worker was sent and never ran goes with it.
        if (self.inside_end) |end| end.discard();
        self.inside_end = null;

        const realm = self.realm orelse return;
        // The module loader's import()s are finished now, while the realm and
        // its agent are there to finish them in - every graph canceled, its
        // import finished, every fetch detached - before the records they
        // name.
        self.destroyModuleLoader();
        // The module map goes with the settings object: its records are
        // engine handles of this agent.
        self.disposeModules();
        // So do the rejected promises tracked for its globals (the worker's
        // global scope, and any ShadowRealm's in it), and the notifications
        // queued for them: Globals of this agent, on its host.
        rejected_promises.releaseAgent(self.agent);
        // The unloading document cleanup steps other specifications define,
        // run for the worker's realm as Blink runs them for every execution
        // context that ends (the File API's: the blob URL entries the worker
        // made leave the store - "This needs a similar hook when a worker is
        // unloaded").
        @import("dom").unloading_cleanup.run(realm);
        self.realm = null;
        // The realm's per-context data - the callbacks its script registered,
        // its wrapper cache and every Instance in it, the global scope last -
        // goes with it; the realm is retired, so anything holding it across
        // turns (a fetch) reads it as gone.
        self.global_scope = null;
        engine.destroyWorkerRealm(realm, sweepFetches, &self.agent_host.fetches);
        // Nothing can call import() in the realm any more.
        self.freeClassicScripts();
    }

    /// Fetches still in flight for the realm release their promises, while the
    /// agent those belong to is alive: the worker agent's, on its host.
    fn sweepFetches(data: ?*anyopaque) void {
        const fetches: *fetch_mod.algorithms.AgentFetches = @ptrCast(@alignCast(data orelse return));
        _ = fetches.sweep();
    }

    /// This host's memory, from its thread's last step (`ThreadHost.free`),
    /// after its realm's end and its agent's - so nothing here may reach the
    /// engine: the realm's end left no timer, import or module behind.
    fn free(self: *Self) void {
        removeLive(self);
        removeHost(self);
        std.debug.assert(self.timers.count() == 0);
        self.timers.deinit(self.allocator);
        std.debug.assert(self.animation_frame_callbacks.items.len == 0);
        self.animation_frame_callbacks.deinit(self.allocator);
        if (self.shared) |*shared| shared.deinit(self.allocator);
        std.debug.assert(self.module_loader == null);
        std.debug.assert(self.modules.count() == 0);
        self.modules.deinit(self.allocator);
        self.freeClassicScripts();
        if (self.inside_end) |end| end.discard();
        self.inside_end = null;
        self.policy_container.deinit();
        self.agent_host.deinit();
        if (self.top_level_site) |site| self.allocator.free(site);
        if (self.top_level_origin) |origin| self.allocator.free(origin);
        if (self.storage_top_level_site) |site| self.allocator.free(site);
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
            // "Run a worker" step 5: a SharedWorkerGlobalScope when `is
            // shared`; Setup ServiceWorkerGlobalScope step 8.1: a
            // ServiceWorkerGlobalScope for a service worker.
            .global = if (self.service != null) .service else if (self.shared != null) .shared else .dedicated,
            .timer = self.timer,
            // The worker's own loop, which host algorithms queue their tasks
            // on.
            .event_loop = self.event_loop,
            .end_of_task = endTaskOfRealm,
            .on_realm = recordRealm,
            .data = self,
            .allocator = self.allocator,
            // HTML 8.1.3.5 for [SecureContext] exposure (WebIDL 3.3.13): the
            // owner's answer and the worker's own URL, as WorkerGlobalScope's
            // isSecureContext answers it. Out of memory: not secure.
            .secure_context = @import("secure_context.zig").ofWorker(self.allocator, self.script_url, self.owner_is_secure_context) catch false,
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
        // `performance` is the global scope's own Performance (the
        // WindowOrWorkerGlobalScope member, through WorkerGlobalScope's
        // settings), its time origin `time_origin_ns`.

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

        var env = self.moduleEnvironment() orelse return false;
        if (self.service == null) {
            // HTML "fetch a worklet/module worker script graph" step 1:
            // credentials belong to the root script and its descendants.
            env.fetch_options.credentials_mode = switch (self.module_fetch_options.credentials) {
                .omit => .omit,
                .same_origin => .same_origin,
                .include => .include,
            };
            env.fetch_options.referrer_policy = self.module_fetch_options.response_referrer_policy;
            env.static_referrer_policy = self.module_fetch_options.static_referrer_policy;
            env.script_destination = if (self.shared != null) .sharedworker else .worker;
            // Intentional browser majority: Firefox and WebKit use the
            // worker's own origin/CSP client for static descendants, while
            // Chromium follows the older outside-settings spec. Keep this
            // realm's reporters too; no creating-thread pointer is needed.
            // https://github.com/whatwg/html/issues/9571
            // Firefox: https://bugzilla.mozilla.org/show_bug.cgi?id=1841363#c3
            // WebKit: https://github.com/whatwg/html/issues/9571#issuecomment-1717229344
        }
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

    const data = engine.structuredDeserializeWithOptions(realm, message.serialized, .{ .array_buffers = message.array_buffers, .transferred = ports.items, .shared_memory = message.shared_memory }) catch {
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
    /// The constructor origin: the outside settings' origin, serialized.
    /// BORROWED for the call.
    origin: []const u8,
    /// outsideStorageKey: the outside settings' storage key for non-storage
    /// purposes, serialized (storage.StorageKey.serialize) - what the
    /// manager matches a running worker by. BORROWED for the call.
    storage_key: []const u8,
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
    /// "Run a worker" step 3, the unsafe worker creation time (hr_time's
    /// monotonic clock, nanoseconds) - taken by the constructor, as a
    /// Worker's is: a worker these steps run takes it as its global scope's
    /// time origin.
    creation_time_ns: ?i64 = null,
    /// urlRecord's blob URL entry, resolved when the constructor parsed it
    /// (workers.script_fetch.captureBlobScript): the script a worker these
    /// steps run fetches, even if the URL was revoked since. OWNED: the
    /// manager takes it whatever happens. Null for any other URL.
    blob_entry: ?workers.FetchedScript = null,
};

/// The SharedWorker constructor's step 11: "enqueue the following steps to
/// the shared worker manager". They run as a task on the owner's loop - the
/// manager's parallel queue, which here is the Browser's window thread -
/// after the constructor has returned. A worker they run starts on a thread
/// of its own; a worker they find hears its new port as a task of its own
/// loop.
pub fn connectSharedWorker(request: SharedWorkerRequest) !void {
    errdefer message_ports.discard(request.inside_end);
    errdefer if (request.blob_entry) |entry| {
        var owned = entry;
        owned.deinit();
    };
    const loop = request.owner_realm.getOptionalEventLoop() orelse return error.NoEventLoop;
    const allocator = request.owner_realm.allocator;
    const task = try allocator.create(SharedConnect);
    errdefer allocator.destroy(task);
    const url = try allocator.dupe(u8, request.url);
    errdefer allocator.free(url);
    const origin = try allocator.dupe(u8, request.origin);
    errdefer allocator.free(origin);
    const storage_key = try allocator.dupe(u8, request.storage_key);
    errdefer allocator.free(storage_key);
    const name = try allocator.dupe(u8, request.name);
    errdefer allocator.free(name);
    task.* = .{
        .worker = request.worker,
        .generation = runtime.SlabAllocator.generationOf(request.worker),
        .steps = request.steps,
        .owner_realm = request.owner_realm,
        .url = url,
        .origin = origin,
        .storage_key = storage_key,
        .name = name,
        .worker_type = request.worker_type,
        .credentials = request.credentials,
        .extended_lifetime = request.extended_lifetime,
        .inside_end = request.inside_end,
        .creation_time_ns = request.creation_time_ns,
        .blob_entry = request.blob_entry,
        .allocator = allocator,
    };
    // Pending activity until the steps end: whatever script holds, the
    // SharedWorker is there for its `error` event. Taken before the task is
    // queued, with nothing fallible after it: a loop can drop the task before
    // queueTask returns (it cannot allocate the entry), and the drop's
    // `finish` releases this hold - taken after, it was never released.
    engine.keepPlatformObjectAlive(request.worker);
    // A loop that will not run the task drops it: `drop` frees it.
    loop.queueTask(.{ .callback = SharedConnect.run, .context = task, .drop = SharedConnect.drop });
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
    /// outsideStorageKey (SharedWorkerRequest.storage_key). OWNED.
    storage_key: []const u8,
    name: []const u8,
    worker_type: WorkerType,
    credentials: workers.RequestCredentials,
    extended_lifetime: bool,
    /// Null once a worker's loop has taken it.
    inside_end: ?*anyopaque,
    creation_time_ns: ?i64,
    /// urlRecord's blob URL entry (SharedWorkerRequest.blob_entry). OWNED.
    blob_entry: ?workers.FetchedScript,
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
        if (self.blob_entry) |*entry| entry.deinit();
        self.allocator.free(self.url);
        self.allocator.free(self.origin);
        self.allocator.free(self.storage_key);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    fn ownerWorker(self: *const SharedConnect) OwnerWorker {
        return .{ .instance = self.worker, .generation = self.generation, .steps = self.steps };
    }

    fn connect(self: *SharedConnect) void {
        const manager = SharedWorkerManager.of(self.owner_realm) orelse return self.fireError();
        // outsideStorageKey: the full key, so a creator under another
        // top-level site (or with a cross-site ancestor) never joins this
        // partition's worker - Chromium and Gecko key shared workers so.
        const key: SharedWorkerManager.Key = .{ .storage_key = self.storage_key, .url = self.url, .name = self.name };
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
        // 7. The worker's environment, as its reserved client until its
        // realm adopts it (Service Workers 2.5.2). Released unless the
        // worker's thread takes it.
        var reserved_client = @import("dom").service_worker_clients.reserve(self.owner_realm, .shared_worker, self.url);
        defer @import("dom").service_worker_clients.release(reserved_client);
        // 12. Fetch a classic worker script, or - for a module worker - the
        // root of its module worker script graph (the rest is fetched in the
        // worker's realm). A failed fetch is a null script: onComplete 1.
        var fetched = workers.fetchWorkerScript(allocator, self.url, .{
            .worker_type = self.worker_type,
            // HTML classic-worker fetch step 1 ignores the credentials
            // option; worklet/module-worker graph steps 1-2 forward it.
            .credentials = if (self.worker_type == .module) switch (self.credentials) {
                .omit => .omit,
                .same_origin => .same_origin,
                .include => .include,
            } else .same_origin,
            .requesting_origin = self.origin,
            .referrer_source = creatorReferrerSource(self.owner_realm),
            // A blob: script's blob is in the outside settings' Browser's
            // blob URL store.
            .blob_url_store = @ptrCast(@import("dom").browser_state.blobURLStoreOf(self.owner_realm)),
            // The outside settings' Browser's network.
            .network = @import("dom").browser_state.networkOf(self.owner_realm),
            // The script response's cookies belong to the creator's jar,
            // before the new shared worker receives that same borrowed jar.
            .cookie_jar = creatorCookieJar(self.owner_realm),
            .shared = true,
            // The outside settings' policy container: its CSP decides
            // whether the script may be fetched at all.
            .policy_container = creatorPolicyContainer(self.owner_realm),
            // Its violations are reported to the outside settings' global.
            .csp_violation_reporter = @import("dom").csp_violations.reporterForRealm(self.owner_realm),
            // A blob: script is urlRecord's blob URL entry's blob, resolved
            // when the constructor parsed it - revoked since or not.
            .blob_entry = if (self.blob_entry) |*entry| entry else null,
            .reserved_client = reserved_client,
            .service_worker = @import("dom").service_worker_clients.routeOfReserved(reserved_client),
        }) catch return self.fireError();
        defer fetched.deinit();

        // Save enum values before moving the response's policy container.
        const module_fetch_options: workers.ModuleFetchOptions = .{
            .credentials = self.credentials,
            .response_referrer_policy = if (fetched.policy_container) |policy| policy.referrer_policy else .empty,
            .static_referrer_policy = if (creatorPolicyContainer(self.owner_realm)) |policy| policy.referrer_policy else .empty,
        };

        // The global scope's policy container, from the response - or the
        // creator's, for a data: or blob: script. Fails closed: a clone that
        // cannot be made is the start's failure, never a worker without its
        // creator's policies.
        const policy_container = workerPolicyContainer(allocator, &fetched, self.owner_realm) catch return self.fireError();
        var start: WorkerStart = .{
            .source = fetched.source,
            .script_url = fetched.final_url,
            .worker_type = self.worker_type,
            .module_fetch_options = module_fetch_options,
            // 8. The global scope's name (its SharedScope has it too).
            .name = self.name,
            .policy_container = policy_container,
            .cookie_jar = creatorCookieJar(self.owner_realm),
            .owner_realm = self.owner_realm,
            .owner_worker = self.ownerWorker(),
            .inside_end = null,
            // 3. The unsafe worker creation time: the global scope's time
            // origin.
            .time_origin_ns = self.creation_time_ns,
            .service_worker_client = reserved_client,
        };
        defer if (start.policy_container) |*container| container.deinit();
        defer if (start.shared) |*shared| shared.deinit(allocator);
        // 10. The constructor key, type and credentials.
        start.shared = sharedScopeOf(allocator, self) catch return self.fireError();

        startSharedWorker(allocator, &start, manager, key, self.inside_end.?) catch |err| {
            log.debug("the shared worker's thread did not start: {}", .{err});
            return self.fireError();
        };
        // The worker's thread took the reserved client.
        reserved_client = start.service_worker_client;
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
    start.service_worker_client = null;
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
/// response's. A new container when neither can be had: an owner whose
/// global has no policy container to give.
///
/// Fails closed: a clone that cannot be allocated is OutOfMemory, and the
/// caller fails the worker's start (an `error` event at the Worker or
/// SharedWorker). It used to fall back to a NEW container - no CSP list, the
/// default referrer policy - so a data: or blob: worker whose creator's
/// container could not be cloned ran without its creator's policies (lane
/// leaks2; tests/html/worker_policy_container_oom_test.zig).
pub fn workerPolicyContainer(allocator: Allocator, fetched: *workers.FetchedScript, owner_realm: runtime.Context) error{OutOfMemory}!fetch_mod.internal.PolicyContainer {
    const PolicyContainer = fetch_mod.internal.PolicyContainer;
    // Step 2: the response's, when a network fetch made one. Upgrade
    // Insecure Requests 3.3: a worker inherits its creator's insecure
    // requests policy ("set up a worker environment settings object").
    if (fetched.takePolicyContainer()) |container| {
        var result = container;
        if (creatorPolicyContainer(owner_realm)) |owner| {
            if (owner.upgradesInsecureRequests()) result.inherited_upgrade_insecure_requests = true;
            // UIR 3.3 also inherits navigation tuples. Omitting that copy
            // here is unobservable: their sole reader (4.1 step 2.4) handles
            // navigation requests, which a dedicated/shared worker cannot
            // issue. Local workers below still clone the whole container.
        }
        return result;
    }
    // Step 1: "If workerGlobalScope's url is local but its scheme is not
    // "blob"": a clone of its owner's - the one owner a dedicated worker,
    // or a shared worker's creator, has.
    if (creatorPolicyContainer(owner_realm)) |owner| return owner.clone(allocator);
    return PolicyContainer.init(allocator);
}

/// The outside settings' referrer source. BORROWED on the creating
/// thread for the synchronous root-script fetch only. A srcdoc Window's
/// settings hook resolves its ancestor source, as requestClient does.
pub fn creatorReferrerSource(realm: runtime.Context) ?[]const u8 {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const settings = @import("dom").global_settings.of(global) orelse return null;
    return if (settings.referrer_source) |source_of| source_of(global) else realm.documentUrl();
}

/// The policy container of the global whose realm is `realm`: the
/// worker's creator's settings object's.
pub fn creatorPolicyContainer(realm: runtime.Context) ?*const fetch_mod.internal.PolicyContainer {
    // A creator realm whose record, global or settings cannot be found has a
    // policy container nobody can read: the unavailable one, which blocks
    // every CSP decision - never null, which a data: or blob: worker took as
    // "no policy" (lane leaks6). A global that keeps no container (no hook,
    // or a hook answering null - a Window not yet given a document) is still
    // null.
    const unavailable = &fetch_mod.internal.PolicyContainer.unavailable;
    const record = realm.getRealm() orelse return unavailable;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return unavailable));
    const settings = @import("dom").global_settings.of(global) orelse return unavailable;
    const container_of = settings.policy_container orelse return null;
    return container_of(global);
}

/// The cookie jar of the global whose realm is `realm`: the worker's
/// creator's settings object's.
/// Whether the global of `realm` - a worker's owner - is a secure context.
fn ownerIsSecureContext(realm: runtime.Context) bool {
    const record = realm.getRealm() orelse return false;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return false));
    const settings = @import("dom").global_settings.of(global) orelse return false;
    return settings.is_secure_context(global);
}

/// A worker creator's mixed-content answer, read only on its own thread.
/// A nested data worker captures its owner's already-inherited restriction.
fn ownerProhibitsMixedSecurityContexts(realm: runtime.Context) error{OutOfMemory}!bool {
    const record = realm.getRealm() orelse return false;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return false));
    const settings = @import("dom").global_settings.of(global) orelse return false;
    const prohibits = settings.prohibits_mixed_security_contexts orelse return false;
    return try prohibits(global);
}

/// The owner's top-level site (Fetch "determine the network partition key"),
/// read in its realm on its thread and copied with `allocator` to cross to
/// the worker's. A nested worker's owner is a worker realm, whose answer is
/// the site it captured in turn. Shared workers use the creator's partition,
/// as their storage-key-based identity does.
fn ownerTopLevelSite(allocator: Allocator, realm: runtime.Context) error{OutOfMemory}!?[]u8 {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const site = (try @import("dom").global_settings.topLevelSiteOf(global)) orelse return null;
    defer global.ctx.allocator.free(site);
    return try allocator.dupe(u8, site);
}

/// A dedicated worker's settings snapshot, copied on its owner's thread.
/// The caller owns the result; failure cannot publish a partial snapshot.
pub fn creatorTopLevelOrigin(allocator: Allocator, realm: runtime.Context) error{OutOfMemory}!?[]u8 {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const origin = (try @import("dom").global_settings.topLevelOriginOf(global)) orelse return null;
    defer global.ctx.allocator.free(origin);
    return try allocator.dupe(u8, origin);
}

/// The storage key partition a dedicated or shared worker takes from its
/// creator - the realm `realm`, on its thread: its key's top-level site
/// (dom.global_settings.storageKeyForNonStoragePurposesOf), copied with
/// `allocator`, and HTML's "has cross-site ancestry": "1. If outside
/// settings's has cross-site ancestor is true, then return true. 2. If
/// worker global scope's url's scheme is "data", then return true. 3. Return
/// false." A dedicated worker's top-level origin is its owner's (HTML); a
/// shared worker's is implementation-defined, and Chromium keys a shared
/// worker by its creator's storage key - which SharedWorker matching
/// compares too. A creator with no key gives none (the worker then keys by
/// its own origin's site).
fn creatorStoragePartition(allocator: Allocator, realm: runtime.Context, script_url: []const u8) error{OutOfMemory}!struct { top_level_site: ?[]u8, has_cross_site_ancestor: bool, top_level_nonce: ?u128 = null, origin_nonce: ?u128 = null } {
    const is_data = std.ascii.startsWithIgnoreCase(script_url, "data:");
    const record = realm.getRealm() orelse return .{ .top_level_site = null, .has_cross_site_ancestor = is_data };
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return .{ .top_level_site = null, .has_cross_site_ancestor = is_data }));
    const key = (try @import("dom").global_settings.storageKeyForNonStoragePurposesOf(global)) orelse
        return .{ .top_level_site = null, .has_cross_site_ancestor = is_data };
    return .{
        .top_level_site = try allocator.dupe(u8, key.top_level_site),
        .has_cross_site_ancestor = key.has_cross_site_ancestor or is_data,
        .top_level_nonce = key.top_level_nonce,
        // HTML worker settings: data: creates a fresh opaque origin; a
        // blob: worker inherits the creator's captured opaque identity.
        .origin_nonce = if (is_data) null else key.origin_nonce,
    };
}

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
    // HTML 8.1.6.2 HostEnsureCanCompileStrings, 8.1.6.3 HostGetCodeForEval
    // and the WebAssembly JS API's HostEnsureCanCompileWasmBytes, as a
    // window agent's (browser/Browser.zig window_agent_hooks): eval,
    // Function and WebAssembly compilation in a worker are checked against
    // its global scope's CSP list, and Trusted Types' default policy runs
    // over a string first. Without them a worker compiled anything.
    .ensureCanCompileStrings = code_generation.hooks.ensureCanCompileStrings,
    .getCodeForEval = code_generation.hooks.getCodeForEval,
    .ensureCanCompileWasmBytes = code_generation.hooks.ensureCanCompileWasmBytes,
    .agentClusterOf = @import("agent_clusters.zig").agentClusterOf,
    .crossOriginIsolatedCapability = @import("agent_clusters.zig").crossOriginIsolatedCapability,
    // WebAssembly Web API 2: compileStreaming and instantiateStreaming
    // ([Exposed=(Window,Worker)]), as a window agent's.
    .compilePotentialWebAssemblyResponse = if (webassembly_streaming.supported) webassembly_streaming.compilePotentialWebAssemblyResponse else null,
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
    const self: *WorkerHost = @alignCast(@fieldParentPtr("agent_host", agent_host));
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
    const self: *WorkerHost = @alignCast(@fieldParentPtr("agent_host", agent_host));
    // Only the worker's own realm has its settings object.
    if (self.realm != realm or !self.runsTasks())
        return finishImportWithTypeError(realm, request, "import() in a worker that has ended");
    // Steps 1-2: settingsObject is the current settings object - this
    // worker's. "If settingsObject's global object implements
    // WorkletGlobalScope or ServiceWorkerGlobalScope and loadState is
    // undefined" - an import() call, or a dependency of the module it
    // imports - "perform FinishLoadingImportedModule(referrer,
    // moduleRequest, payload, ThrowCompletion(a new TypeError))" and
    // return: nothing is resolved or fetched, and the TypeError settles the
    // promise within the current microtask checkpoint (the engine's
    // ContinueDynamicImport). Every import() a service worker makes ends
    // here; its static imports are its module graph's, loaded by Update and
    // Run Service Worker (the module worker script graph), not by this
    // hook.
    if (self.service != null)
        return finishImportWithTypeError(realm, request, "import() is not allowed in a ServiceWorkerGlobalScope");
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
    // Steps 5-6: fetchOptions - the default classic script fetch options,
    // or the new descendant script fetch options for referencingScript's;
    // step 14's referrer is referencingScript's base URL, "client" without
    // one.
    const referencing: ?struct { options: module_script.FetchOptions, url: []const u8 } = switch (referrer) {
        .module => |host_defined| if (module_script.scriptOf(host_defined)) |script| .{ .options = script.descendantFetchOptions(), .url = script.base_url } else null,
        .script => |host_defined| .{ .options = module_script.classicScriptOf(host_defined).descendantFetchOptions(), .url = base_url },
        .realm => null,
    };

    // Steps 7.1.4-7.1.5 (for the one request an import() makes): module type
    // allowed - "css" only where CSSStyleSheet is exposed, which a worker's
    // global is not - or a TypeError.
    const module_type = module_script.moduleTypeFromAttribute(type_attribute) orelse
        return finishImportWithTypeError(realm, request, "Unsupported module type");
    if (!env.moduleTypeAllowed(module_type)) return finishImportWithTypeError(realm, request, "Unsupported module type");

    // Steps 8-9: resolve a module specifier, or reject with its TypeError.
    const url = module_script.resolve(&env, specifier, base_url) orelse
        return finishImportWithTypeError(realm, request, "Failed to resolve module specifier");
    defer realm.allocator.free(url);

    // Step 14: fetch a single imported module script. A worker's goes
    // through its module loader, as a Window's does (a service worker's
    // never gets here: step 2): the request starts now (a blob: URL
    // revoked right after import() still loads), joins a fetch of the same
    // URL in flight, and a failure leaves no module map entry. The import
    // finishes from a task of the worker's loop - or from a microtask, when
    // the whole graph is in the module map already.
    var options: module_script.FetchOptions = if (referencing) |r| r.options else .{};
    options.integrity = env.resolveIntegrity(url);
    self.startImport(url, module_type, options, if (referencing) |r| r.url else "", request) catch
        return finishImportWithTypeError(realm, request, "Failed to start module fetch");
}

/// An import() its worker's module loader is loading: the engine request,
/// finished by exactly one of `done` and `gone`, which free this.
const LoaderImport = struct {
    host: *WorkerHost,
    request: *engine.ImportRequest,

    /// The graph's onComplete: FinishLoadingImportedModule with its record
    /// - ContinueDynamicImport (link, evaluate, settle) is the engine's - or
    /// with its error to rethrow, or a TypeError for a null graph.
    fn done(context: *anyopaque, result: ?*module_script.ModuleScript) void {
        const self: *LoaderImport = @ptrCast(@alignCast(context));
        const host = self.host;
        const request = self.request;
        host.allocator.destroy(self);
        const realm = host.realm orelse return finishImport(request, .{ .failure = runtime.JSValue.jsUndefined });
        const graph = result orelse return finishImportWithTypeError(realm, request, "Failed to fetch dynamically imported module");
        if (graph.error_to_rethrow) |reason| return finishImport(request, .{ .failure = reason.value });
        const record = graph.record orelse return finishImportWithTypeError(realm, request, "Failed to load dynamically imported module");
        finishImport(request, .{ .module = record });
    }

    /// The loader canceled the graph - the worker is ending, or its loop
    /// dropped the graph's task: finishing releases the request's owners
    /// while the agent lives; nothing observes the rejection.
    fn gone(context: *anyopaque) void {
        const self: *LoaderImport = @ptrCast(@alignCast(context));
        const request = self.request;
        self.host.allocator.destroy(self);
        finishImport(request, .{ .failure = runtime.JSValue.jsUndefined });
    }
};

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
            // A service worker keeps the modules its graph imports in its
            // script resource map (ServiceHooks.module_fetched).
            .fetched = if (self.service != null) .{ .context = self, .run = &serviceModuleFetched } else null,
            // HTML "fetch a module worker script graph": the graph's
            // descendants are fetched with the worker's destination. A
            // service worker's environment serves only its static graph
            // (its import() rejects, HostLoadImportedModule step 2), so its
            // modules are "serviceworker" requests (Chrome; Safari at
            // install - soft-update-fetch-metadata's module case, wpt.fyi
            // 23b0b89b1a). For dedicated/shared workers this default serves
            // import(); executeModuleScript sets "worker"/"sharedworker"
            // for the initial static graph (HTML fetch-module-worker-graph
            // step 1's destination; Gecko TYPE_INTERNAL_WORKER_STATIC_MODULE
            // and WebKit WorkerModuleScriptLoader::load do the same).
            .script_destination = if (self.service != null) .serviceworker else .script,
        };
    }

    /// module_script.Environment.fetched for a service worker: a good
    /// response for a module its graph imported is handed to the manager
    /// (ServiceHooks.module_fetched); a network error, a status that is not
    /// an ok status or a MIME type that is not JavaScript is not kept (a bad
    /// import script response, which an update would ignore).
    fn serviceModuleFetched(context: *anyopaque, url: []const u8, response: *const fetch_mod.internal.InternalResponse) void {
        const self: *WorkerHost = @ptrCast(@alignCast(context));
        const service = self.service orelse return;
        const hook = service.hooks.module_fetched orelse return;
        if (response.response_type == .@"error" or response.status < 200 or response.status > 299) return;
        const content_type = response.header_list.getFirstValue("Content-Type") orelse return;
        if (!module_script.isJavaScriptMimeType(content_type)) return;
        const body = if (response.body) |b| b.getBytes() else "";
        hook(service.manager, service.worker_id, url, content_type, body);
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

    /// The worker's module loader, made on first use.
    fn moduleLoader(self: *WorkerHost) ?*module_script.AsyncModuleLoader {
        if (self.module_loader) |loader| return loader;
        const env = moduleEnvironment(self) orelse return null;
        const global_scope = self.global_scope orelse return null;
        const loader = module_script.AsyncModuleLoader.create(env, global_scope) catch return null;
        self.module_loader = loader;
        return loader;
    }

    /// Start loading the graph of an import() of `url` through the module
    /// loader; `request` is finished by the graph's end (LoaderImport).
    /// `referrer` BORROWED for the call.
    fn startImport(self: *WorkerHost, url: []const u8, module_type: module_script.ModuleType, options: module_script.FetchOptions, referrer: []const u8, request: *engine.ImportRequest) !void {
        const loader = moduleLoader(self) orelse return error.OutOfMemory;
        const pending = try self.allocator.create(LoaderImport);
        pending.* = .{ .host = self, .request = request };
        // On success the client owns `pending`: done or gone frees it, maybe
        // before this returns (a task dropped at once by a closing worker).
        loader.startWithReferrer(url, module_type, null, options, referrer, .{
            .context = pending,
            .done = LoaderImport.done,
            .gone = LoaderImport.gone,
            .settle_cached_in_microtask = true,
        }) catch |err| {
            self.allocator.destroy(pending);
            return err;
        };
    }

    /// The realm's end: every graph of the loader canceled - its import
    /// finished (`LoaderImport.gone`) - and every fetch detached, then the
    /// loader freed. Queued payloads stay their tasks' until those run or
    /// are dropped (AsyncModuleLoader).
    fn destroyModuleLoader(self: *WorkerHost) void {
        const loader = self.module_loader orelse return;
        self.module_loader = null;
        loader.destroy();
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
    /// The module graph's options, copied as enum values only.
    module_fetch_options: workers.ModuleFetchOptions = .{},
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
    /// "Run a worker" step 3, the unsafe worker creation time (hr_time's
    /// monotonic clock, nanoseconds): the global scope's time origin.
    time_origin_ns: ?i64 = null,
    /// A shared worker's constructor key, type and credentials ("run a
    /// worker" step 10); null for a dedicated worker. Taken on success.
    shared: ?SharedScope = null,
    /// The worker's reserved client (dom.service_worker_clients), which its
    /// realm adopts as it becomes a service worker client. Taken on success.
    service_worker_client: ?*anyopaque = null,
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
    start.service_worker_client = null;
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
        module_fetch_options: workers.ModuleFetchOptions,
        name: []u8,
        policy_container: ?fetch_mod.internal.PolicyContainer,
        cookie_jar: ?*CookieJar,
        browser_scope: ?*runtime.BrowserScope,
        owner_worker: OwnerWorker,
        inside_end: ?*port_channels.End,
        time_origin_ns: ?i64,
        /// Whether the owner is a secure context, read on its thread.
        owner_is_secure_context: bool,
        /// The owner's mixed-content answer, read on that same thread.
        owner_prohibits_mixed_security_contexts: bool,
        /// Whether a dedicated worker's global scope will be a supported
        /// AnimationFrameProvider, read on the owner's thread
        /// (`ownerSupportsAnimationFrames`).
        owner_supports_animation_frames: bool = false,
        shared: ?SharedScope,
        /// The agent cluster of a DEDICATED worker's agent: its owner's
        /// ("obtain a worker/worklet agent" step 3 - isTopLevel is false, so
        /// the agent is in outside settings' agent cluster), read on the
        /// owner's thread (html.agent_clusters.ofRealm). 0 for a shared
        /// worker, whose agent starts a cluster of its own (isTopLevel), or
        /// when the owner's is not known.
        agent_cluster: u64,
        /// A DEDICATED worker's owner's top-level site, read on the owner's
        /// thread (dom.global_settings.topLevelSiteOf). OWNED; null for a
        /// shared worker: HTML leaves its top-level origin to the user agent,
        /// and Crane does not partition SharedWorker matching.
        top_level_site: ?[]u8,
        top_level_origin: ?[]u8,
        /// The storage key partition a dedicated or shared worker takes from
        /// its creator, read on the creator's thread
        /// (`creatorStoragePartition`). OWNED.
        storage_top_level_site: ?[]u8 = null,
        storage_top_level_nonce: ?u128 = null,
        origin_nonce: ?u128 = null,
        has_cross_site_ancestor: bool = false,
        /// The worker's reserved client, until its realm adopts it.
        service_worker_client: ?*anyopaque,
    };

    fn create(allocator: Allocator, start: *const WorkerStart) !*ThreadHost {
        const source = try allocator.dupe(u8, start.source);
        errdefer allocator.free(source);
        const script_url = try allocator.dupe(u8, start.script_url);
        errdefer allocator.free(script_url);
        const name = try allocator.dupe(u8, start.name);
        errdefer allocator.free(name);
        // Fetch 2.7/2.8: both worker kinds use their creator's network
        // partition. Chromium SharedWorkerHost::ComputeIsolationInfoForNetworkRequest
        // likewise derives it from the worker's creator-keyed StorageKey.
        // A missing site means no cache, not a common unpartitioned cache.
        const top_level_site = try ownerTopLevelSite(allocator, start.owner_realm);
        errdefer if (top_level_site) |site| allocator.free(site);
        const top_level_origin = if (start.shared == null) try creatorTopLevelOrigin(allocator, start.owner_realm) else null;
        errdefer if (top_level_origin) |origin| allocator.free(origin);
        const owner_prohibits_mixed_security_contexts = try ownerProhibitsMixedSecurityContexts(start.owner_realm);
        // On the creator's thread, in its realm: the storage key partition
        // the worker takes - a shared worker's too (`creatorStoragePartition`).
        const storage_partition = try creatorStoragePartition(allocator, start.owner_realm, start.script_url);
        errdefer if (storage_partition.top_level_site) |site| allocator.free(site);
        const self = try allocator.create(ThreadHost);
        self.* = .{
            .allocator = allocator,
            .start = .{
                .source = source,
                .script_url = script_url,
                .worker_type = start.worker_type,
                .module_fetch_options = start.module_fetch_options,
                .name = name,
                .policy_container = start.policy_container,
                .cookie_jar = start.cookie_jar,
                .browser_scope = start.owner_realm.browser_scope,
                .owner_worker = start.owner_worker,
                .inside_end = start.inside_end,
                .time_origin_ns = start.time_origin_ns,
                // On the owner's thread, in its realm: HTML 8.1.3.5 step
                // 1.2.1 asks owner set[0]'s relevant settings object.
                .owner_is_secure_context = ownerIsSecureContext(start.owner_realm),
                .owner_prohibits_mixed_security_contexts = owner_prohibits_mixed_security_contexts,
                // On the owner's thread: HTML 8.12's "supported" asks the
                // owner set.
                .owner_supports_animation_frames = start.shared == null and ownerSupportsAnimationFrames(start.owner_realm),
                .shared = start.shared,
                // On the owner's thread, in its realm: the owner's agent
                // cluster, for a dedicated worker.
                .agent_cluster = if (start.shared == null) agent_clusters.ofRealm(start.owner_realm) else 0,
                .top_level_site = top_level_site,
                .top_level_origin = top_level_origin,
                .storage_top_level_site = storage_partition.top_level_site,
                .storage_top_level_nonce = storage_partition.top_level_nonce,
                .origin_nonce = storage_partition.origin_nonce,
                .has_cross_site_ancestor = storage_partition.has_cross_site_ancestor,
                .service_worker_client = start.service_worker_client,
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
        self.start.service_worker_client = null;
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
        if (self.start.top_level_site) |site| self.allocator.free(site);
        self.start.top_level_site = null;
        if (self.start.top_level_origin) |origin| self.allocator.free(origin);
        self.start.top_level_origin = null;
        if (self.start.storage_top_level_site) |site| self.allocator.free(site);
        self.start.storage_top_level_site = null;
        @import("dom").service_worker_clients.release(self.start.service_worker_client);
        self.start.service_worker_client = null;
    }

    /// The worker's realm is a service worker client: it takes the reserved
    /// client its script's fetch went with (dom.service_worker_clients).
    fn becomeServiceWorkerClient(self: *ThreadHost, worker_host: *WorkerHost) void {
        const reserved = self.start.service_worker_client;
        self.start.service_worker_client = null;
        const realm = worker_host.realm orelse return @import("dom").service_worker_clients.release(reserved);
        const global = worker_host.global_scope orelse return @import("dom").service_worker_clients.release(reserved);
        const settings = @import("dom").global_settings.of(global) orelse return @import("dom").service_worker_clients.release(reserved);
        const origin = settings.origin(global) catch return @import("dom").service_worker_clients.release(reserved);
        defer realm.allocator.free(origin);
        @import("dom").service_worker_clients.created(realm, .{
            .kind = if (self.start.shared != null or worker_host.shared != null) .shared_worker else .dedicated_worker,
            .creation_url = self.start.script_url,
            .origin = origin,
            .secure_context = realm.secure_context,
            .reserved = reserved,
        });
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
        // Service Workers 2.5.2: the worker is a service worker client from
        // here - before its script runs - adopting its reserved client.
        self.becomeServiceWorkerClient(worker_host);
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
// Service workers (Service Workers "Run Service Worker" and "Setup
// ServiceWorkerGlobalScope") - html's third kind of worker
// ============================================================================

/// What a service worker's ServiceWorkerGlobalScope is made with: which
/// service worker it is, in which registration, and the owner of both - the
/// Browser's service worker manager (src/service_worker), opaque here: html
/// never imports it; it reaches html through these hooks.
pub const ServiceScope = struct {
    worker_id: u64,
    registration_id: u64,
    /// The service worker manager. BORROWED: it outlives every service
    /// worker thread (the Browser's end joins them before its scope ends).
    manager: *anyopaque,
    hooks: *const ServiceHooks,
};

/// The manager's steps a service worker's thread runs, on that thread.
pub const ServiceHooks = struct {
    /// Run Service Worker step 9: the script has been evaluated - `ok` false
    /// when it was not, or threw (its start status an abrupt completion), or
    /// its global scope could not be set up. `global` is the worker's
    /// ServiceWorkerGlobalScope (null when none was made), on this thread for
    /// the call: whose event listeners make the service worker's set of
    /// event types to handle.
    evaluated: *const fn (manager: *anyopaque, worker_id: u64, ok: bool, global: ?*runtime.Instance) void,
    /// importScripts() in the service worker (Service Workers 6.3.2): the
    /// fetch hook's steps - answered from its script resource map, or
    /// fetched and recorded there. NetworkError for a network error.
    /// The parsed entry is borrowed for the call; a fetch request retains
    /// its own reference. The stored-resource branch need not read it.
    import_script: *const fn (manager: *anyopaque, worker_id: u64, ctx: runtime.Context, url: []const u8, entry: ?*fetch_mod.internal.request.CapturedBlobEntry, captured: bool) error{ NetworkError, OutOfMemory }!ImportedScript,
    /// A module service worker's graph fetched the module script at `url`
    /// (a good response: `content_type`, `body` BORROWED for the call): the
    /// manager keeps it in the worker's script resource map while the worker
    /// is parsed or installing (Registry.addModuleScript).
    module_fetched: ?*const fn (manager: *anyopaque, worker_id: u64, url: []const u8, content_type: []const u8, body: []const u8) void = null,
};

/// The service worker scope of the realm `ctx`, when it is a service
/// worker's: through its realm record's kind (any other realm answers null
/// there), then its agent's host - a service worker's agent is its
/// WorkerHost's (`agent_host`).
pub fn serviceScopeOf(ctx: runtime.Context) ?ServiceScope {
    const record = ctx.getRealm() orelse return null;
    if (record.info.context_type != .service_worker) return null;
    const host = serviceHostOf(ctx) orelse return null;
    return host.service;
}

fn serviceHostOf(ctx: runtime.Context) ?*WorkerHost {
    const agent = ctx.agent orelse return null;
    const agent_host: *html_core.agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    const host: *WorkerHost = @alignCast(@fieldParentPtr("agent_host", agent_host));
    if (host.service == null) return null;
    return host;
}

/// What a service worker's thread starts with (Run Service Worker steps
/// 7-9): its script resource, its global scope's settings and its owner -
/// the Browser's service worker job thread, whose loop hears the worker's
/// end.
pub const ServiceWorkerStart = struct {
    /// The script resource (the main script's body). BORROWED (copied).
    source: []const u8,
    /// The service worker's script url: its global scope's URL and API base
    /// URL. BORROWED (copied).
    script_url: []const u8,
    worker_type: WorkerType,
    /// The script resource's policy container (Setup step 8.5). Taken on
    /// success.
    policy_container: ?fetch_mod.internal.PolicyContainer,
    /// The user agent's cookie jar (Browser-lifetime, locked).
    cookie_jar: ?*CookieJar,
    /// The Browser's scope: the worker's realm carries it, and its
    /// WorkerRegistry ends the worker's thread with the Browser.
    browser_scope: ?*runtime.BrowserScope,
    /// The inbox of the loop the worker's end is posted to (WorkerThread
    /// step g): the job thread's. The worker's thread is registered as owned
    /// by it, so the job thread's end ends the worker first.
    owner_sink: *runtime.TaskSink,
    /// What runs there at the worker's end. Taken on success.
    owner: WorkerThread.Owner,
    service: ServiceScope,
    /// Setup step 1, the unsafe creation time (hr_time's monotonic clock,
    /// nanoseconds): the global scope's time origin.
    time_origin_ns: ?i64 = null,
    /// Its registration's storage key's partition (registrations are
    /// partitioned by storage key, lane sw1-b11): the top-level site,
    /// serialized ("null" for an opaque one), and "has cross-site ancestor"
    /// - its global's storage key's, and the top-level site its requests are
    /// keyed by. BORROWED (copied). Null: none named - the script URL's own
    /// origin's site, with no cross-site ancestor.
    top_level_site: ?[]const u8 = null,
    has_cross_site_ancestor: bool = false,
};

/// A service worker started on a thread of its own.
pub const StartedServiceWorker = struct {
    /// The caller's reference to the worker's link: terminate it with
    /// `terminate()`, and `release()` it once its end has reached the owner
    /// (`endServiceWorkerLink`).
    link: *WorkerLink,
    /// The worker's thread host, for `postServiceTask`. Dereferenced only
    /// on the worker's thread.
    handle: *anyopaque,
};

/// Start a service worker on a thread of its own: a link whose owner's loop
/// is the job thread's (`start.owner_sink`), registered with the Browser's
/// WorkerRegistry - the Browser's end terminates and joins it - and a
/// WorkerThread whose host makes a ServiceWorkerGlobalScope realm, runs the
/// script and reports through `start.service.hooks`. On success
/// `start.policy_container` is taken, and the thread owns `start.owner`.
pub fn startServiceWorker(allocator: Allocator, start: *ServiceWorkerStart) !StartedServiceWorker {
    const registry: ?*WorkerRegistry = if (start.browser_scope) |scope| scope.of(WorkerRegistry) catch null else null;
    const link = try WorkerLink.create(allocator, start.owner_sink);
    errdefer link.release();
    if (registry) |r| try r.register(link);
    errdefer if (registry) |r| r.unregister(link);
    const thread_host = try ServiceThreadHost.create(allocator, start);
    errdefer thread_host.destroyUnstarted();
    try WorkerThread.spawn(allocator, link, thread_host.asHost(), start.owner, registry);
    start.policy_container = null;
    return .{ .link = link, .handle = thread_host };
}

/// A service worker's end has reached its owner's loop: join its thread and
/// forget it in the Browser's WorkerRegistry. The caller then releases its
/// reference.
pub fn endServiceWorkerLink(browser_scope: ?*runtime.BrowserScope, link: *WorkerLink) void {
    link.join();
    if (browser_scope) |scope| if (scope.existing(WorkerRegistry)) |registry| registry.unregister(link);
}

/// A task of a service worker's realm, posted to its loop
/// (`postServiceTask`).
pub const ServiceTask = struct {
    /// On the worker's thread, as a task of its realm (its agent entered,
    /// ended the worker's way): `realm` and its global scope.
    run: *const fn (data: ?*anyopaque, realm: runtime.Context, global_scope: *runtime.Instance) void,
    /// The task will never run - the worker is closing, or ended. Any
    /// thread; no engine.
    drop: *const fn (data: ?*anyopaque) void,
    data: ?*anyopaque,
};

/// Post `task` to the service worker `handle` (`StartedServiceWorker`)
/// whose link is `link`. A worker that is ending drops it.
pub fn postServiceTask(allocator: Allocator, link: *WorkerLink, handle: *anyopaque, task: ServiceTask) void {
    const box = allocator.create(ServiceTaskBox) catch return task.drop(task.data);
    box.* = .{ .allocator = allocator, .thread_host = @ptrCast(@alignCast(handle)), .task = task };
    // A closed sink drops it.
    _ = link.worker_sink.post(.{ .run = ServiceTaskBox.run, .drop = ServiceTaskBox.drop, .data = box });
}

const ServiceTaskBox = struct {
    allocator: Allocator,
    /// Read only by `run`, on the worker's thread, while its loop runs.
    thread_host: *ServiceThreadHost,
    task: ServiceTask,
    ran: bool = false,

    fn run(data: ?*anyopaque) void {
        const self: *ServiceTaskBox = @ptrCast(@alignCast(data.?));
        defer {
            if (!self.ran) self.task.drop(self.task.data);
            self.allocator.destroy(self);
        }
        const host = self.thread_host.host orelse return;
        if (!host.runsTasks()) return;
        host.runTask(steps, self);
    }

    fn steps(data: ?*anyopaque) void {
        const self: *ServiceTaskBox = @ptrCast(@alignCast(data.?));
        const host = self.thread_host.host orelse return;
        const realm = host.realm orelse return;
        const global_scope = host.global_scope orelse return;
        self.ran = true;
        self.task.run(self.task.data, realm, global_scope);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ServiceTaskBox = @ptrCast(@alignCast(data.?));
        self.task.drop(self.task.data);
        self.allocator.destroy(self);
    }
};

/// The worker host's part of a service worker's thread (WorkerThread.Host):
/// Run Service Worker steps 7-9 - Setup ServiceWorkerGlobalScope and the
/// script - then the realm's end, and the host's memory.
const ServiceThreadHost = struct {
    allocator: Allocator,
    start: Start,
    /// The worker's host, once its start step made it.
    host: ?*WorkerHost = null,

    const Start = struct {
        source: []u8,
        script_url: []u8,
        worker_type: WorkerType,
        policy_container: ?fetch_mod.internal.PolicyContainer,
        cookie_jar: ?*CookieJar,
        browser_scope: ?*runtime.BrowserScope,
        time_origin_ns: ?i64,
        service: ServiceScope,
        /// ServiceWorkerStart.top_level_site, copied. OWNED.
        top_level_site: ?[]u8,
        has_cross_site_ancestor: bool,
    };

    fn create(allocator: Allocator, start: *const ServiceWorkerStart) !*ServiceThreadHost {
        const source = try allocator.dupe(u8, start.source);
        errdefer allocator.free(source);
        const script_url = try allocator.dupe(u8, start.script_url);
        errdefer allocator.free(script_url);
        const top_level_site: ?[]u8 = if (start.top_level_site) |site| try allocator.dupe(u8, site) else null;
        errdefer if (top_level_site) |site| allocator.free(site);
        const self = try allocator.create(ServiceThreadHost);
        self.* = .{
            .allocator = allocator,
            .start = .{
                .source = source,
                .script_url = script_url,
                .worker_type = start.worker_type,
                .policy_container = start.policy_container,
                .cookie_jar = start.cookie_jar,
                .browser_scope = start.browser_scope,
                .time_origin_ns = start.time_origin_ns,
                .service = start.service,
                .top_level_site = top_level_site,
                .has_cross_site_ancestor = start.has_cross_site_ancestor,
            },
        };
        return self;
    }

    /// A thread host whose thread never started: what it copied goes; the
    /// policy container stays the caller's.
    fn destroyUnstarted(self: *ServiceThreadHost) void {
        self.start.policy_container = null;
        self.freeStart();
        self.allocator.destroy(self);
    }

    fn freeStart(self: *ServiceThreadHost) void {
        self.allocator.free(self.start.source);
        self.allocator.free(self.start.script_url);
        if (self.start.top_level_site) |site| self.allocator.free(site);
        self.start.top_level_site = null;
        if (self.start.policy_container) |*container| container.deinit();
        self.start.policy_container = null;
    }

    fn asHost(self: *ServiceThreadHost) WorkerThread.Host {
        return .{ .data = self, .start = startSteps, .end_realm = endRealm, .free = free };
    }

    /// Run Service Worker steps 7-9 on the worker's thread. False when the
    /// worker does not run: terminated before it started, or failed - its
    /// start status is reported either way.
    fn startSteps(data: ?*anyopaque, thread: *WorkerThread) bool {
        const self: *ServiceThreadHost = @ptrCast(@alignCast(data.?));
        const service = self.start.service;
        const ok = self.run(thread) catch |err| blk: {
            log.debug("a service worker did not start: {}", .{err});
            break :blk false;
        };
        // Step 9.7: its start status, for its owner. A worker whose script
        // was not evaluated, or threw, does not stay: its owner terminates it.
        const global: ?*runtime.Instance = if (self.host) |h| h.global_scope else null;
        service.hooks.evaluated(service.manager, service.worker_id, ok, global);
        return ok;
    }

    fn run(self: *ServiceThreadHost, thread: *WorkerThread) !bool {
        // 8, "obtain a service worker agent": the agent, on this thread.
        if (!try WorkerHost.initServiceOnThread(self.allocator, self, thread)) return false;
        const worker_host = self.host.?;
        // 8.1-8.7: the realm, its global a new ServiceWorkerGlobalScope, its
        // URL, type and policy container the service worker's.
        try worker_host.setupWorkerGlobalScope();
        switch (self.start.worker_type) {
            // 9.4: run the classic script. An abrupt completion - a throw, a
            // parse error, an abort - fails the start (Update step 16).
            .classic => {
                worker_host.executeScript(self.start.source) catch return false;
                if (worker_host.own_script_parse_failed) return false;
            },
            // 9.5: run the module script; a rejected evaluation fails it.
            .module => if (!worker_host.executeModuleScript(self.start.script_url, self.start.source)) return false,
        }
        // The source is not needed again.
        self.allocator.free(self.start.source);
        self.start.source = &.{};
        return true;
    }

    /// The realm's end, with the agent alive and the loop's tasks dropped.
    fn endRealm(data: ?*anyopaque, _: *WorkerThread) void {
        const self: *ServiceThreadHost = @ptrCast(@alignCast(data.?));
        const worker_host = self.host orelse return;
        worker_host.teardownRealm();
        worker_host.timer = null;
    }

    /// After the agent's end: the host's memory and the thread host's.
    fn free(data: ?*anyopaque) void {
        const self: *ServiceThreadHost = @ptrCast(@alignCast(data.?));
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

// The HTML module root is not V8-linked. The linked tests/html target runs
// these two owner-local harnesses; production exports no test operation.
pub const worker_origin_oom_test_cases = if (@import("builtin").is_test) struct {
    pub fn startup() !void {
        const Harness = struct {
            const settings = @import("dom").global_settings;
            const methods = .{};
            const vtable: runtime.VTable = .{ .name = "pm2-startup-global", .deinit = null, .methods_ptr = &methods };

            fn owns(global: *runtime.Instance) bool {
                return std.mem.eql(u8, global.vtable.name, "pm2-startup-global");
            }

            fn origin(global: *runtime.Instance) anyerror!runtime.USVString {
                return global.ctx.allocator.dupe(u8, "https://owner.example.test");
            }

            fn topOrigin(global: *runtime.Instance) error{OutOfMemory}!?[]u8 {
                return try global.ctx.allocator.dupe(u8, "https://top.example.test:8443");
            }

            fn secure(_: *runtime.Instance) bool {
                return true;
            }

            fn isolated(_: *runtime.Instance) bool {
                return false;
            }

            fn errorReported(_: *runtime.Instance, _: *const ErrorReport.Info) void {}
            fn ended(_: *runtime.Instance) void {}

            fn allocationScenario(allocator: Allocator, realm: runtime.Context, global: *runtime.Instance) !void {
                const saved_allocator = realm.allocator;
                realm.allocator = allocator;
                defer realm.allocator = saved_allocator;
                const start: WorkerStart = .{
                    .source = "postMessage('ready')",
                    .script_url = "https://owner.example.test/worker.js",
                    .worker_type = .classic,
                    .name = "pm2",
                    .policy_container = null,
                    .cookie_jar = null,
                    .owner_realm = realm,
                    .owner_worker = .{
                        .instance = global,
                        .generation = 0,
                        .steps = &.{ .error_reported = errorReported, .start_failed = ended, .ended = ended },
                    },
                    .inside_end = null,
                };
                const host = try ThreadHost.create(allocator, &start);
                defer host.destroyUnstarted();
                try std.testing.expectEqualStrings("https://top.example.test:8443", host.start.top_level_origin.?);
            }
        };
        // Native settings only: no V8 realm, thread or running worker.
        // The supplied immutable hook accepts only this test's global kind.
        Harness.settings.install(.{
            .owns = Harness.owns,
            .origin = Harness.origin,
            .is_secure_context = Harness.secure,
            .cross_origin_isolated = Harness.isolated,
            .top_level_origin = Harness.topOrigin,
        });
        var realm = try runtime.ContextData.init(std.testing.allocator, .{});
        defer realm.deinit();
        var native_state: u8 = 0;
        var global: runtime.Instance = .{ .vtable = &Harness.vtable, .state = &native_state, .ctx = &realm };
        const record = try runtime.Realm.init(std.testing.allocator, .{ .context_type = .window, .global_object = &global });
        defer record.deinit();
        realm.setRealm(record);
        defer realm.clearRealm();
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.allocationScenario, .{ &realm, &global });
        std.debug.print("pm2 worker startup owns its top-level origin across every allocation failure: passed\n", .{});
    }

    pub fn scopeCopies() !void {
        const Harness = struct {
            fn allocationScenario(allocator: Allocator, realm: runtime.Context) !void {
                const scope = try interfaces.WorkerGlobalScope.init(allocator, realm);
                defer interfaces.WorkerGlobalScope.deinit(scope);
                const settings = @import("dom").global_settings;
                const site = (try settings.topLevelSiteOf(scope)).?;
                defer realm.allocator.free(site);
                const origin = (try settings.topLevelOriginOf(scope)).?;
                defer realm.allocator.free(origin);
                try std.testing.expectEqualStrings("https://example.test", site);
                try std.testing.expectEqualStrings("https://top.example.test:8443", origin);
            }

            fn body() !void {
                const allocator = std.testing.allocator;
                interfaces.process_hooks.startHooksForTest();
                runtime.initializeRuntime(allocator);
                defer runtime.deinitializeRuntime();
                var realm = try runtime.ContextData.init(allocator, .{});
                defer realm.deinit();
                const site = try allocator.dupe(u8, "https://example.test");
                defer allocator.free(site);
                const origin = try allocator.dupe(u8, "https://top.example.test:8443");
                defer allocator.free(origin);
                // Only scopeSettings reads this host. It never starts an agent,
                // task sink, loop or thread; those fields are deliberately unused.
                var host: WorkerHost = .{
                    .agent = undefined,
                    .agent_host = undefined,
                    .realm = &realm,
                    .script_url = "https://worker.example.test/worker.js",
                    .worker_type = .classic,
                    .policy_container = fetch_mod.internal.PolicyContainer.init(allocator),
                    .timer = null,
                    .task_sink = undefined,
                    .allocator = allocator,
                    .event_loop = undefined,
                    .link = undefined,
                    .owner_is_secure_context = true,
                    .top_level_site = site,
                    .top_level_origin = origin,
                };
                defer host.policy_container.deinit();
                try live_contexts.append(std.heap.page_allocator, &host);
                defer removeLive(&host);
                try std.testing.checkAllAllocationFailures(allocator, allocationScenario, .{&realm});
            }
        };
        try Harness.body();
        std.debug.print("pm2 hosted worker scope unwinds its own state when a settings copy fails: passed\n", .{});
    }
} else struct {};
