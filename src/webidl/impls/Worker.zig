//! Implementation for Worker interface
//!
//! Spec: HTML Standard § 10.2.6.3 Dedicated workers and the Worker interface
//! https://html.spec.whatwg.org/multipage/workers.html#dedicated-workers-and-the-worker-interface
//!
//! A Worker object is its owner's side of a dedicated worker, which runs on a
//! thread of its own (docs/instances.md, "Decisions"): its agent, realm and
//! event loop are made, run and ended there (html.worker_host,
//! html.WorkerThread). What the object holds:
//!
//! - its outside port: one end of a dom.port_channels Channel whose other end
//!   is the worker's implicit port. Worker.postMessage is the outside port's
//!   postMessage - serialized here, queued at the implicit port, delivered by
//!   the worker's loop - and what the worker posts arrives at this end and is
//!   fired at this object by a task of its own realm's loop;
//! - the worker's link (html.WorkerLink): "terminate a worker" through it
//!   aborts the worker's script from this thread, and the worker's end comes
//!   back through it as a task that joins the thread.
//!
//! A Worker has pending activity (Blink's DedicatedWorker::HasPendingActivity)
//! from its construction until its worker has ended and what it posted has
//! been delivered: script may drop it at once - `new Worker(url).onmessage =
//! f` - and the worker still runs. Every task the worker posts for it carries
//! its slab generation, checked before use. When its realm ends, its worker
//! is terminated (`endWorkersOf`), and when it is freed, it lets go of both.

const std = @import("std");
const log = std.log.scoped(.worker);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const Worker = interfaces.Worker;
const MessageEvent = interfaces.MessageEvent;

// The constructor parses the script URL (the URL Standard's API parser), and
// the blob-URL check needs the outside settings' origin.
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const url_origin = @import("origin");

// The worker script fetch and the options' types.
const workers = @import("html_core").workers;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;

// The worker host: the HTML half of "run a worker", on the worker's thread.
const html = @import("html");
const worker_host = html.worker_host;

// The implicit ports' channel, whose ends cross threads.
const port_channels = dom.port_channels;
const End = port_channels.End;

pub const State = Worker.State;

pub const ImplError = error{
    NotImplemented,
    WorkerCreationFailed,
    InvalidURL,
    OutOfMemory,
    PostMessageFailed,
};

/// A Worker's own state, on its owner's thread.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The constructor's pending-activity keep is held: released once, by
    /// whichever of the worker's end, terminate() before a start, the start
    /// failure task and deinit comes first (the keep is counted).
    kept_alive: bool = false,
    /// The worker's link - the owner side's reference - while the worker was
    /// started: null when its script could not be fetched or its thread did
    /// not start.
    link: ?*html.WorkerLink = null,
    /// The outside port: this Worker's end of the implicit channel, bound to
    /// this object on its realm's loop. Discarded with the object.
    outside: ?*End = null,
    /// terminate() was called: what the worker posts is discarded from now
    /// on (Blink: a messaging proxy asked to terminate delivers nothing).
    terminated: bool = false,
    /// The worker's end has reached this object: its pending activity ends
    /// once what the worker posted has been delivered.
    ended: bool = false,
    /// The worker's failure to start reached this object, and its `error`
    /// waits in a task of this loop (`startFailed`): the pending activity
    /// lasts until it has fired.
    error_queued: bool = false,
    /// A task that enables the outside port once the Worker's page is fully
    /// active again waits in its realm's loop (`EnableWhenActive`).
    enable_queued: bool = false,

    pub fn deinit(self: *InternalState) void {
        // The owner lets go: a worker still running is terminated (it is no
        // longer actively needed), and the link and the port go.
        if (self.link) |link| {
            _ = link.terminate();
            link.release();
        }
        self.link = null;
        if (self.outside) |end| end.discard();
        self.outside = null;
    }
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.unloading_cleanup.install(&endWorkersOf);
    // A page the back/forward cache keeps keeps its dedicated workers,
    // suspended while it is cached (HTML "run a worker" step 8: a worker
    // whose owner Document is not fully active is suspendable) and resumed
    // when it is shown again; evicted, its unloading cleanup terminates them
    // (`endWorkersOf`). Chrome (DedicatedWorker::ContextLifecycleStateChanged:
    // kFrozen -> Freeze, kRunning -> Resume), Firefox and Safari all keep
    // such a page: back-forward-cache/eligibility/dedicated-worker.html
    // passes in all three on wpt.fyi (stable, 2026-11-15/16). A lock its
    // worker holds is the lock manager's to resolve on contention
    // (LockManager's contention hook), not a reason to keep the page out.
    dom.bfcache.installStoreStep(&worker_host.suspendDedicatedWorkersOf);
    dom.bfcache.installRestoreStep(&worker_host.resumeDedicatedWorkersOf);
}

/// An unloading document cleanup step: the realm `realm` ends - its document
/// is destroyed, or its worker has ended - and every worker whose Worker
/// object lives in it is no longer actively needed: "terminate a worker"
/// (HTML 10.2.3; Blink's DedicatedWorker::ContextDestroyed terminates its
/// worker). Their ends reach `realm`'s loop, or are dropped with it.
fn endWorkersOf(realm: runtime.Context) void {
    const registry = html.WorkerRegistry.existingOf(realm) orelse return;
    registry.terminateOwnedByRealm(realm);
}

/// Initialize instance: a Worker is an EventTarget, so its EventTarget state
/// comes first (through the interface).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Whatever pending-activity hold is left on it goes with it.
    releasePendingActivity(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
}

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// HTML "encoding-parsing a URL" given `script_url`, relative to the outside
/// settings, serialized (the constructor's "Let urlRecord/workerURL be the
/// result of encoding-parsing a URL given compliantScriptURL, relative to
/// outsideSettings"): a window's settings parse against its document's base
/// URL and encode the query with its document's character encoding - the
/// one helper every document URL goes through, dom.encoding_parse - and a
/// worker's against its API base URL, in UTF-8. OWNED (`allocator`).
/// SyntaxError for failure.
fn encodingParseScriptURL(instance: *runtime.Instance, allocator: std.mem.Allocator, script_url: []const u8, api_base_url: ?[]const u8) error{ SyntaxError, OutOfMemory }![]const u8 {
    if (relevantWindow(instance)) |window| {
        if (interfaces.Window.get_document(window) catch null) |document| {
            const serialized = (try @import("dom").encoding_parse.encodingParseAndSerialize(document, script_url)) orelse
                return error.SyntaxError;
            defer document.ctx.allocator.free(serialized);
            return allocator.dupe(u8, serialized);
        }
    }
    return @import("dom").encoding_parse.encodingParseAndSerializeUtf8(allocator, script_url, api_base_url);
}

/// The outside settings' origin, serialized - "this's relevant settings
/// object"'s, as its global's kind answers it (dom.global_settings): a
/// sandboxed or otherwise opaque-origin document's is "null", whatever its
/// URL. The origin of `api_base_url` only where the global's kind answers
/// nothing. OWNED (`allocator`).
fn outsideSettingsOrigin(instance: *runtime.Instance, allocator: std.mem.Allocator, api_base_url: ?[]const u8) ![]u8 {
    if (instance.ctx.getRealm()) |record| if (record.global_object) |object| {
        const global: *runtime.Instance = @ptrCast(@alignCast(object));
        if (@import("dom").global_settings.of(global)) |settings| {
            if (settings.origin(global)) |origin| {
                defer global.ctx.allocator.free(origin);
                return allocator.dupe(u8, origin);
            } else |err| if (err == error.OutOfMemory) return error.OutOfMemory;
        }
    };
    return serializedOriginOf(allocator, api_base_url);
}

/// The outside settings' storage key for non-storage purposes, serialized
/// (dom.global_settings): BORROWED from `instance`'s relevant global, which
/// outlives the constructor; null where its kind keeps none.
fn outsideSettingsStorageKey(instance: *runtime.Instance) error{OutOfMemory}!?[]const u8 {
    const record = instance.ctx.getRealm() orelse return null;
    const object = record.global_object orelse return null;
    return @import("dom").global_settings.serializedStorageKeyOf(@ptrCast(@alignCast(object)));
}

/// The outside settings' origin, serialized: the origin of `api_base_url`,
/// or "null" (an opaque origin) without one. OWNED (`allocator`).
fn serializedOriginOf(allocator: std.mem.Allocator, api_base_url: ?[]const u8) ![]u8 {
    const base = api_base_url orelse return allocator.dupe(u8, "null");
    var record = api_parser.parseURL(allocator, base, null) catch return allocator.dupe(u8, "null");
    defer record.deinit();
    const origin = try url_origin.getOrigin(allocator, &record);
    defer origin.deinit(allocator);
    return origin.serialize(allocator);
}

/// The current settings object's API base URL, for the instance a constructor
/// just made in it: a window's document's base URL, read through the
/// Document's `baseURI`; a worker's is its script URL, which its realm
/// records as its document URL. OWNED by `instance.ctx.allocator`. The same
/// lookup WebSocket's and Request's constructors make.
fn apiBaseURL(instance: *runtime.Instance) ?[]u8 {
    const ctx = instance.ctx;
    if (relevantWindow(instance)) |window| {
        const document = interfaces.Window.get_document(window) catch null;
        if (document) |d| {
            const base = interfaces.Node.get_baseURI(d) catch null;
            if (base) |b| {
                if (b.len > 0) return @constCast(b);
                d.ctx.allocator.free(b);
            }
        }
    }
    if (ctx.documentUrl()) |document_url| {
        if (document_url.len > 0) return ctx.allocator.dupe(u8, document_url) catch null;
    }
    return null;
}

/// `instance`'s relevant global object, when it is a Window: its relevant
/// realm's global object, from the realm record.
fn relevantWindow(instance: *runtime.Instance) ?*runtime.Instance {
    const record = instance.ctx.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// Constructor: new Worker(scriptURL, options)
///
/// Spec: https://html.spec.whatwg.org/multipage/workers.html#dom-worker
pub fn call_constructor(instance: *runtime.Instance, scriptURL: typedefs.TrustedScriptURLOrUSVString, options: webidl.Opt(dictionaries.WorkerOptions)) !void {
    const ctx = instance.ctx;
    // 1. "Let compliantScriptURL be the result of invoking the get trusted
    // type compliant string algorithm with TrustedScriptURL, this's relevant
    // global object, scriptURL, "Worker constructor", and "script"."
    const compliant_script_url = try dom.trusted_types.compliantStringForRealm(ctx.allocator, .script_url, ctx, scriptURL, "Worker constructor");
    defer ctx.allocator.free(compliant_script_url);

    // The WorkerOptions dictionary: type ("classic" or "module"),
    // credentials (for a module worker's fetches) and name.
    var worker_type = WorkerType.classic;
    var credentials = RequestCredentials.same_origin;
    var name: []const u8 = "";
    if (options.wasPassed()) {
        const opts = options.getValue();
        if (opts.type) |t| worker_type = switch (t) {
            ._classic_ => .classic,
            ._module_ => .module,
        };
        if (opts.credentials) |c| credentials = switch (c) {
            ._omit_ => .omit,
            ._same_origin_ => .same_origin,
            ._include_ => .include,
        };
        if (opts.name) |n| name = n.asSlice();
    }

    // 2-4. "Let outsideSettings be this's relevant settings object. Let
    // workerURL be the result of encoding-parsing a URL given
    // compliantScriptURL, relative to outsideSettings. If workerURL is
    // failure, then throw a "SyntaxError" DOMException." Relative to its API
    // base URL - a window's document's URL, a worker's script URL.
    const base_url = apiBaseURL(instance);
    defer if (base_url) |b| ctx.allocator.free(b);
    const worker_url = try encodingParseScriptURL(instance, ctx.allocator, compliant_script_url, base_url);
    defer ctx.allocator.free(worker_url);
    // The outside settings' origin: the script request's (its fetch is
    // same-origin with it) and the blob-URL store's same-origin check's.
    const requesting_origin = try outsideSettingsOrigin(instance, ctx.allocator, base_url);
    defer ctx.allocator.free(requesting_origin);
    // And its storage key for non-storage purposes: what a blob: script's
    // blob is obtained for (File API 8.3.2), BORROWED from the global - a
    // worker made in a frame of another partition gets no blob.
    const requesting_storage_key = try outsideSettingsStorageKey(instance);

    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{ .allocator = ctx.allocator };
    instance.getState(State).own._internal = internal;

    // 5-7. "Let outsidePort be a new MessagePort in outsideSettings's realm.
    // Set outsidePort's message event target to this. Set this's outside
    // port to outsidePort." The outside port is not script-visible: it is
    // this object's end of a fresh channel, bound to this object on its
    // realm's loop. Its other end becomes the worker's implicit port ("run a
    // worker" onComplete 3-5: entangled with it), handed to the worker's
    // thread.
    const channel = try port_channels.Channel.create(ctx.allocator);
    internal.outside = channel.end(0);
    var inside_end: ?*End = channel.end(1);
    defer if (inside_end) |end| end.discard();
    if (ctx.task_sink) |sink| {
        channel.end(0).bind(.{
            .sink = sink,
            .receiver = instance,
            .generation = runtime.SlabAllocator.generationOf(instance),
            .hooks = &outside_port_hooks,
        });
        // "Run a worker" step 11 enables the outside port's queue only after
        // the worker's script has run. Deviation, stated: every engine
        // delivers a worker's message as soon as it is posted - Blink's
        // DedicatedWorkerObjectProxy::PostMessageToWorkerObject posts to the
        // parent's task runner at once, Gecko's WorkerPrivate::
        // PostMessageToParent dispatches to the parent at once - and so does
        // Crane: a worker that posts and then spins its first script forever
        // is heard.
        channel.end(0).enable();
    }

    // Pending activity from now until the worker has ended (see the file's
    // header); the binding wraps the object after this returns, and the
    // wrapper takes the hold then.
    keepPendingActivity(instance);

    // "Run a worker" step 3: the unsafe worker creation time - the unsafe
    // shared current time, hr_time's monotonic clock (a Window's time origin
    // is taken from the same clock) - the worker global scope's time origin.
    const creation_time_ns: i64 = @intCast(@import("hr_time").MonotonicClock.unsafeCurrentTime());

    // 9. "Run a worker" in parallel: the worker's thread starts now and the
    // constructor returns; its script is fetched by that thread
    // (html.worker_host ThreadHost.fetchScript), never by this one, so
    // nothing here waits for it - and nothing its arrival does (the owner's
    // embedder policy check and its COEP report, or `error`) happens inside
    // this task. A data: URL, or a blob: URL whose blob URL entry is
    // captured now, as the URL parser captures it when the constructor
    // parses the URL (Blink resolves a blob: worker URL in
    // DedicatedWorker::Start, WebKit keeps it with URLKeepingBlobAlive), is
    // answered here with no network, and the thread starts with it in hand.
    // "Run a worker" step 7: the worker's environment exists before its
    // script is fetched - here, as its reserved client, which Handle Fetch
    // may make controlled and the worker's realm adopts (Service Workers
    // 2.5.2). Released unless the worker's thread takes it.
    var reserved_client = dom.service_worker_clients.reserve(ctx, .dedicated_worker, worker_url);
    defer dom.service_worker_clients.release(reserved_client);
    const owner_worker: worker_host.OwnerWorker = .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .steps = &owner_steps,
    };
    var fetch_options: workers.script_fetch.WorkerScriptFetchOptions = .{
        .worker_type = worker_type,
        // HTML classic-worker fetch step 1 always uses same-origin. The
        // worklet/module-worker graph's steps 1-2 use the credentials
        // option for the root fetch.
        .credentials = if (worker_type == .module) switch (credentials) {
            .omit => .omit,
            .same_origin => .same_origin,
            .include => .include,
        } else .same_origin,
        .requesting_origin = requesting_origin,
        .requesting_storage_key = requesting_storage_key,
        .referrer_source = worker_host.creatorReferrerSource(ctx),
        // A blob: script's blob is in the outside settings' Browser's blob
        // URL store.
        .blob_url_store = @ptrCast(dom.browser_state.blobURLStoreOf(ctx)),
        // The outside settings' Browser's network.
        .network = dom.browser_state.networkOf(ctx),
        // Its cookie jar is needed by the script fetch itself, as well as
        // by the worker global that receives it after the response.
        .cookie_jar = creatorCookieJar(ctx),
        // The outside settings' policy container: its CSP decides whether
        // the script may be fetched at all.
        .policy_container = worker_host.creatorPolicyContainer(ctx),
        // Its violations are reported to the outside settings' global.
        .csp_violation_reporter = dom.csp_violations.reporterForRealm(ctx),
        .reserved_client = reserved_client,
        .service_worker = dom.service_worker_clients.routeOfReserved(reserved_client),
        // The outside settings' user agent override, which the request
        // copies: the worker's thread fetches it.
        .user_agent_override = html.user_agent_override.ofRealm(ctx),
    };
    var start: worker_host.WorkerStart = .{
        .source = "",
        .script_url = worker_url,
        .worker_type = worker_type,
        .module_fetch_options = .{
            .credentials = credentials,
            .static_referrer_policy = if (worker_host.creatorPolicyContainer(ctx)) |policy| policy.referrer_policy else .empty,
        },
        .name = name,
        .policy_container = null,
        // The worker shares its creator's cookie jar - the user agent's.
        .cookie_jar = creatorCookieJar(ctx),
        .owner_realm = ctx,
        .owner_worker = owner_worker,
        .inside_end = inside_end,
        .time_origin_ns = creation_time_ns,
        .service_worker_client = reserved_client,
    };
    defer if (start.policy_container) |*container| container.deinit();
    // What the worker's thread did not take goes with the constructor.
    defer if (start.request) |request| request.deinit();
    defer if (start.csp_relay) |relay| relay.destroy();
    var fetched: ?workers.FetchedScript = null;
    defer if (fetched) |*script| script.deinit();
    if (workers.script_fetch.fetchesFromNetwork(worker_url)) {
        // The request is made now, from the outside settings; the worker's
        // thread fetches it, and the violations it finds come back here
        // through a relay to this realm's global.
        const sink = ctx.task_sink orelse {
            queueStartFailure(instance);
            return;
        };
        start.csp_relay = try worker_host.CspRelay.create(ctx.allocator, sink, owner_worker);
        fetch_options.csp_violation_reporter = start.csp_relay.?.reporter();
        fetch_options.timing_reporter = start.csp_relay.?.timingReporter();
        start.request = workers.script_fetch.workerScriptRequest(ctx.allocator, worker_url, fetch_options) catch |err| {
            log.debug("the worker's script request could not be made: {}", .{err});
            queueStartFailure(instance);
            return;
        };
    } else {
        fetched = workers.fetchWorkerScript(ctx.allocator, worker_url, fetch_options) catch |err| {
            // onComplete 1: script is null - a network error, a status that
            // is not ok, a MIME type that is not JavaScript - so `error` is
            // fired at the worker, once, and nothing runs.
            log.debug("worker script fetch failed: {}", .{err});
            queueStartFailure(instance);
            return;
        };
        start.source = fetched.?.source;
        start.script_url = fetched.?.final_url;
        start.module_fetch_options.response_referrer_policy = if (fetched.?.policy_container) |policy| policy.referrer_policy else .empty;
        // "Initialize a worker global scope's policy container" - this
        // realm's global's, for a data: or blob: script. It fails closed: a
        // clone of this realm's container that cannot be made fails the
        // start (`error` at the worker), and the worker never runs without
        // the policies it inherits.
        start.policy_container = worker_host.workerPolicyContainer(ctx.allocator, &fetched.?, ctx) catch |err| {
            log.debug("the worker's policy container could not be made: {}", .{err});
            queueStartFailure(instance);
            return;
        };
    }
    internal.link = worker_host.startDedicatedWorker(ctx.allocator, &start) catch |err| {
        log.debug("the worker's thread did not start: {}", .{err});
        queueStartFailure(instance);
        return;
    };
    // The thread took the implicit port, the reserved client and the
    // request with its relay.
    inside_end = start.inside_end;
    reserved_client = start.service_worker_client;
}

// Event handler IDL attributes (HTML § 8.1.8.1): their values live in
// EventTarget's event handler map, where firing `message` or `error` at this
// Worker finds them - in order with every listener.

/// Operation: terminate
///
/// Spec: "The terminate() method steps are to terminate a worker given
/// this's worker." Steps 1-3 reach the worker's thread through its link
/// (the closing flag, its loop woken to discard its tasks, the script
/// running in it aborted - from this thread, while the worker's thread may be
/// inside it). Step 4, here: "empty the port message queue of the port that
/// the worker's implicit port is entangled with" - this object's outside
/// port - and nothing the worker posts is delivered from now on. The
/// worker's end reaches this object later, as a task, and its pending
/// activity ends then.
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    if (internal.terminated) return;
    internal.terminated = true;
    if (internal.link) |link| {
        _ = link.terminate();
    } else {
        // Never started: no end will come.
        releasePendingActivity(instance);
    }
    if (internal.outside) |end| {
        end.clearQueue();
        // A notification already posted finds nothing.
        end.unbind();
    }
}

/// Operation: postMessage(message, transfer)
///
/// Spec: "act as if, when invoked, it immediately invoked the respective
/// postMessage(message, transfer) ... on this's outside port" - the message
/// port post message steps with options «[ "transfer" → transfer ]».
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const allocator = instance.ctx.allocator;
    const objects = try engine.convertToSequenceOfObjects(instance.ctx, transfer, allocator);
    defer {
        for (objects) |object| object.release();
        allocator.free(objects);
    }
    const list = try allocator.alloc(runtime.JSValue, objects.len);
    defer allocator.free(list);
    for (objects, list) |object, *item| item.* = object.value;
    return postMessageSteps(instance, message, list);
}

/// Operation: postMessage(message, options)
pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!void {
    const transfer: []const runtime.JSValue = if (options.wasPassed()) (options.getValue().transfer orelse &.{}) else &.{};
    return postMessageSteps(instance, message, transfer);
}

/// The message port post message steps for the outside port: serialize with
/// transfer in this realm - whatever the worker's state: a transferred
/// ArrayBuffer is detached, a transferred port shipped - then add the
/// message to the implicit port's queue, which the worker's loop delivers.
/// A worker that has ended is no longer entangled (its realm's end
/// disentangled its implicit port): the message is dropped ("If targetPort is
/// null ... return"), and so is one a terminated worker never runs.
fn postMessageSteps(instance: *runtime.Instance, message: runtime.JSValue, transfer: []const runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const end = internal.outside orelse return;
    const port_message = try worker_host.serializePortMessage(instance.ctx, message, transfer, instance.ctx.allocator);
    end.post(port_message);
}

// ============================================================================
// What the worker sends its Worker object, on the Worker's own loop
// ============================================================================

/// The outside port's receiver: this Worker, on its realm's loop.
const outside_port_hooks: port_channels.ReceiverHooks = .{
    .deliver = deliverHook,
    .closed = closedHook,
};

/// The Worker, if `receiver` is still the object its port was bound to: a
/// collected Worker's slot can be reissued.
fn liveReceiver(receiver: *anyopaque, generation: u64) ?*runtime.Instance {
    const worker: *runtime.Instance = @ptrCast(@alignCast(receiver));
    if (runtime.SlabAllocator.generationOf(worker) != generation) return null;
    return worker;
}

/// One task of the outside port's message queue: the message port post
/// message steps' step 7 with this Worker as the message event target - a
/// task of its realm (`runTaskInRealm`: a nested worker's Worker lives in a
/// worker's realm, whose task has an end of its own).
fn deliverHook(receiver: *anyopaque, generation: u64, delivery: *port_channels.Delivery) void {
    const worker = liveReceiver(receiver, generation) orelse return;
    const internal = getInternal(worker) orelse return;
    if (internal.terminated) {
        if (delivery.next()) |message| message.destroy();
        return;
    }
    // The port message queue's task is a task of the Worker's relevant
    // global: while that Window's Document is not fully active - the
    // back/forward cache keeps the page, and the worker posted this before
    // its suspension took effect - it is not runnable. The message stays
    // queued at the outside port, and a global task naming the Window
    // enables the port again when it runs: at the page's restore, or never
    // (dropped with the page).
    if (dom.document_activity.inactiveWindowOf(worker) != null) return EnableWhenActive.queue(worker, internal);
    var task: Delivery = .{ .worker = worker, .delivery = delivery };
    engine.runTaskInRealm(worker.ctx, Delivery.steps, &task) catch {};
    // The last message of a worker that has ended: nothing is pending now.
    releaseWhenIdle(worker);
}

/// The outside port's queue waits while the Worker's page is not fully
/// active: a global task naming its Window that enables the port again -
/// port_channels.End.enable notifies the queue's owner when messages wait -
/// once the event loop runs it, at the page's restore. One at a time per
/// Worker; a message arriving meanwhile only waits behind it.
const EnableWhenActive = struct {
    worker: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn queue(worker: *runtime.Instance, internal: *InternalState) void {
        if (internal.enable_queued) return;
        const self = internal.allocator.create(EnableWhenActive) catch return;
        self.* = .{ .worker = worker, .generation = runtime.SlabAllocator.generationOf(worker), .allocator = internal.allocator };
        if (!dom.document_activity.queuedUntilFullyActive(worker, run, drop, self)) {
            // Fully active after all (or no loop): enable now.
            internal.allocator.destroy(self);
            if (internal.outside) |end| enableIfEnabled(end);
            return;
        }
        internal.enable_queued = true;
    }

    fn run(data: ?*anyopaque) void {
        const self: *EnableWhenActive = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.worker) != self.generation) return;
        const internal = getInternal(self.worker) orelse return;
        internal.enable_queued = false;
        if (internal.outside) |end| enableIfEnabled(end);
    }

    /// Never run: the page left the cache to be destroyed, or the loop
    /// ended. The Worker, if it is still there, may queue another.
    fn drop(data: ?*anyopaque) void {
        const self: *EnableWhenActive = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.worker) != self.generation) return;
        const internal = getInternal(self.worker) orelse return;
        internal.enable_queued = false;
    }
};

/// Notify the outside port again of what waits there - only once its queue
/// is enabled ("run a worker" step 11 enables it): `End.enable` on a queue
/// not yet enabled would enable it early.
fn enableIfEnabled(end: *End) void {
    if (end.state().enabled) end.enable();
}

const Delivery = struct {
    worker: *runtime.Instance,
    delivery: *port_channels.Delivery,

    fn steps(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data orelse return));
        const message = self.delivery.next() orelse return;
        defer message.destroy();
        worker_host.deliverPortMessage(self.worker.ctx, self.worker, message, fireAtWorker);
    }
};

/// The implicit port was disentangled - the worker's realm ended. A Worker
/// hears no `close`: its end arrives as a task of its own.
fn closedHook(_: *anyopaque, _: u64) void {}

/// Fire a MessageEvent at the Worker `target`, made in `realm`. `data` is
/// borrowed: the event keeps its own.
fn fireAtWorker(
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
    const event = MessageEvent.call_constructor(
        realm,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent: trusted (DOM 2.10).
    _ = dom.fire_event.dispatchTrusted(target, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// What the worker's tasks do at this Worker (html.worker_host.OwnerSteps).
const owner_steps: worker_host.OwnerSteps = .{
    .error_reported = errorReported,
    .start_failed = startFailed,
    .ended = workerEnded,
};

/// HTML "report an exception" step 7, for the worker's global scope, when
/// the error went unhandled there: "Let notHandled be the result of firing
/// an event named error at workerObject, using ErrorEvent, with the
/// cancelable attribute initialized to true, and additional attributes
/// initialized according to errorInfo" - `error` null: the exception value
/// does not reach the owner's realm. "If notHandled is true, then report
/// exception for workerObject's relevant global object with omitError set to
/// true": the owner's global hears it - window.onerror, or, for a nested
/// worker, the outer worker's global scope and so its Worker in turn.
fn errorReported(worker: *runtime.Instance, report: *const worker_host.ErrorReport.Info) void {
    const internal = getInternal(worker) orelse return;
    if (internal.terminated) return;
    var fire = ErrorFire{ .worker = worker, .info = report };
    engine.runTaskInRealm(worker.ctx, ErrorFire.steps, &fire) catch {};
}

const ErrorFire = struct {
    worker: *runtime.Instance,
    info: *const worker_host.ErrorReport.Info,

    fn steps(data: ?*anyopaque) void {
        const self: *ErrorFire = @ptrCast(@alignCast(data orelse return));
        const worker = self.worker;
        const init_dict = dictionaries.ErrorEventInit{
            .base = .{ .cancelable = true },
            .message = runtime.DOMString.initInterned(self.info.message),
            .filename = self.info.filename,
            .lineno = self.info.lineno,
            .colno = self.info.colno,
            .@"error" = runtime.JSValue.jsNull,
        };
        const event = interfaces.ErrorEvent.call_constructor(
            worker.ctx,
            runtime.DOMString.initInterned("error"),
            webidl.Opt(dictionaries.ErrorEventInit).passed(init_dict),
        ) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        const not_handled = dom.fire_event.dispatchTrusted(worker, event) catch true;
        event.releaseIfUnwrapped(generation);
        if (!not_handled) return;
        const record = worker.ctx.getRealm() orelse return;
        const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
        const info: runtime.ErrorInfo = .{
            .message = self.info.message,
            .filename = self.info.filename,
            .lineno = self.info.lineno,
            .colno = self.info.colno,
            .error_value = null,
        };
        _ = html.report_exception.reportErrorInfo(global, &info, .{ .omit_error = true });
    }
};

/// "Run a worker" onComplete step 1.1: "queue a global task on the DOM
/// manipulation task source given worker's relevant global object to fire
/// an event named error at worker" - a plain Event, not cancelable. (A
/// worker terminated first hears nothing.)
///
/// From the worker's thread it arrives as a task of this loop, and fires
/// from a task of its own queued here - behind the securitypolicyviolation
/// task a CSP violation of the worker's script request queued, which came
/// first through the same loop (worker_host.CspRelay): securitypolicyviolation
/// before `error`, as when the script was fetched on this thread.
fn startFailed(worker: *runtime.Instance) void {
    const internal = getInternal(worker) orelse return;
    if (internal.terminated) return;
    const loop = worker.ctx.getOptionalEventLoop() orelse return fireStartFailure(worker);
    const task = internal.allocator.create(ErrorEventTask) catch return fireStartFailure(worker);
    task.* = .{ .worker = worker, .generation = runtime.SlabAllocator.generationOf(worker), .allocator = internal.allocator };
    internal.error_queued = true;
    queueGlobalTask(worker, loop, .{ .callback = ErrorEventTask.run, .context = task, .drop = ErrorEventTask.drop });
}

/// Fire the start failure's `error` at the worker now (a plain Event, not
/// cancelable), unless it was terminated.
fn fireStartFailure(worker: *runtime.Instance) void {
    const internal = getInternal(worker) orelse return;
    if (internal.terminated) return;
    engine.runTaskInRealm(worker.ctx, fireErrorEventSteps, worker) catch {};
}

/// `startFailed`'s queued `error`: fired unless the Worker has gone or was
/// terminated since.
const ErrorEventTask = struct {
    worker: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *ErrorEventTask = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.worker) != self.generation) return;
        const internal = getInternal(self.worker) orelse return;
        internal.error_queued = false;
        fireStartFailure(self.worker);
        // The worker's end may have come meanwhile: nothing is pending now.
        releaseWhenIdle(self.worker);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ErrorEventTask = @ptrCast(@alignCast(data.?));
        self.allocator.destroy(self);
    }
};

fn fireErrorEventSteps(data: ?*anyopaque) void {
    const worker: *runtime.Instance = @ptrCast(@alignCast(data orelse return));
    const event = interfaces.Event.call_constructor(
        worker.ctx,
        runtime.DOMString.initInterned("error"),
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = dom.fire_event.dispatchTrusted(worker, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// The worker has ended - its thread is joined. Its Worker's pending
/// activity ends once what the worker posted has been delivered.
fn workerEnded(worker: *runtime.Instance) void {
    const internal = getInternal(worker) orelse return;
    internal.ended = true;
    releaseWhenIdle(worker);
}

/// Blink's DedicatedWorker::HasPendingActivity() turning false: the worker
/// has ended, and nothing it posted waits to be delivered (a terminated
/// worker's messages never are). Then a Worker script no longer references
/// is collected like any other object. Always after a dispatch, never inside
/// one: a handler that drops the last reference must not have its Worker
/// collected under the dispatch.
fn releaseWhenIdle(worker: *runtime.Instance) void {
    const internal = getInternal(worker) orelse return;
    if (!internal.ended or internal.error_queued) return;
    if (!internal.terminated) {
        if (internal.outside) |end| {
            const state = end.state();
            if (state.enabled and state.queued > 0) return;
        }
    }
    releasePendingActivity(worker);
}

/// "Run a worker" onComplete step 1, from the constructor: the worker never
/// runs, and `error` is fired at it from "a global task on the DOM
/// manipulation task source" of its realm. Its pending activity ends with
/// that task. On the realm's own event loop - a window's, or a worker's own
/// for a nested worker - the queue the fetch's CSP violation report went to
/// first (securitypolicyviolation before `error`, as the worker-src tests
/// count). A bare realm with none (a unit test's) fires nothing.
fn queueStartFailure(instance: *runtime.Instance) void {
    const loop = instance.ctx.getOptionalEventLoop() orelse return releasePendingActivity(instance);
    const task = instance.ctx.allocator.create(StartFailure) catch return releasePendingActivity(instance);
    task.* = .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .allocator = instance.ctx.allocator,
    };
    queueGlobalTask(instance, loop, .{ .callback = StartFailure.run, .context = task, .drop = StartFailure.drop });
}

/// HTML "queue a global task" given `instance`'s relevant global, on `loop`
/// (its realm's): a Window's names the Window as the task's document, so the
/// window loop runs it only while the Window's Document is fully active -
/// it waits while the back/forward cache keeps the page and is dropped
/// with it. A worker's realm has no Document: its loop runs every task.
fn queueGlobalTask(instance: *runtime.Instance, loop: runtime.EventLoop, task: runtime.EventLoopTask) void {
    var global_task = task;
    if (instance.ctx.isWindow()) {
        if (instance.ctx.getRealm()) |record| if (record.global_object) |object| {
            const global: *runtime.Instance = @ptrCast(@alignCast(object));
            global_task.document = global;
            global_task.document_generation = runtime.SlabAllocator.generationOf(global);
        };
    }
    loop.queueTask(global_task);
}

const StartFailure = struct {
    instance: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *StartFailure = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return;
        fireStartFailure(self.instance);
        releasePendingActivity(self.instance);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *StartFailure = @ptrCast(@alignCast(data.?));
        self.allocator.destroy(self);
    }
};

/// Take the engine's pending-activity hold on a Worker, once.
fn keepPendingActivity(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (internal.kept_alive) return;
    internal.kept_alive = true;
    engine.keepPlatformObjectAlive(instance);
}

/// End it, if it is held (idempotent).
fn releasePendingActivity(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (!internal.kept_alive) return;
    internal.kept_alive = false;
    engine.releasePlatformObject(instance);
}

/// The cookie jar of the global whose realm is `realm`: the worker's
/// creator's settings object's.
fn creatorCookieJar(realm: runtime.Context) ?*@import("cookiestore").CookieJar {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return @import("dom").global_settings.cookieJarOf(global);
}
