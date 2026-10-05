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

/// `script_url` encoding-parsed relative to `api_base_url` and serialized:
/// the Worker constructor's steps 3-4, given the outside settings' API base
/// URL. OWNED (`allocator`). SyntaxError when it does not parse - a relative
/// URL with no base among them.
/// Deviation, stated (encoding-parse-utf8): the query is encoded as UTF-8, not with the document's encoding - queued.
pub fn resolveScriptURL(allocator: std.mem.Allocator, script_url: []const u8, api_base_url: ?[]const u8) error{ SyntaxError, OutOfMemory }![]const u8 {
    var base_record: ?@import("url_record").URLRecord = null;
    defer if (base_record) |*b| b.deinit();
    if (api_base_url) |base| base_record = api_parser.parseURL(allocator, base, null) catch null;
    var record = api_parser.parseURL(allocator, script_url, if (base_record) |*b| b else null) catch
        return error.SyntaxError;
    defer record.deinit();
    return url_serializer.serialize(allocator, &record, false) catch error.OutOfMemory;
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
pub fn call_constructor(ctx: runtime.Context, scriptURL: typedefs.TrustedScriptURLOrUSVString, options: webidl.Opt(dictionaries.WorkerOptions)) !*runtime.Instance {
    // 1. "Let compliantScriptURL be the result of invoking the get trusted
    // type compliant string algorithm with TrustedScriptURL, this's relevant
    // global object, scriptURL, "Worker constructor", and "script"."
    const compliant_script_url = try dom.trusted_types.compliantStringForRealm(ctx.allocator, .script_url, ctx, scriptURL, "Worker constructor");
    defer ctx.allocator.free(compliant_script_url);

    const instance = try init(ctx.allocator, State, &Worker.vtable, ctx);
    errdefer deinit(instance);

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
    const worker_url = try resolveScriptURL(ctx.allocator, compliant_script_url, base_url);
    defer ctx.allocator.free(worker_url);
    // Its origin, for the blob-URL store's same-origin check.
    const requesting_origin = try serializedOriginOf(ctx.allocator, base_url);
    defer ctx.allocator.free(requesting_origin);

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

    // 9. "Run a worker" in parallel. Its fetch happens here, before the
    // constructor returns - a blob URL revoked right after `new Worker(url)`
    // still runs (Blink starts the fetch in the constructor too); the rest
    // runs on the worker's own thread.
    var fetched = workers.fetchWorkerScript(ctx.allocator, worker_url, .{
        .worker_type = worker_type,
        .requesting_origin = requesting_origin,
        // The outside settings' policy container: its CSP decides whether
        // the script may be fetched at all.
        .policy_container = worker_host.creatorPolicyContainer(ctx),
        // Its violations are reported to the outside settings' global.
        .csp_violation_reporter = dom.csp_violations.reporterForRealm(ctx),
    }) catch |err| {
        // onComplete 1: script is null - a network error, a status that is
        // not ok, a MIME type that is not JavaScript - so `error` is fired at
        // the worker, once, and nothing runs.
        log.debug("worker script fetch failed: {}", .{err});
        queueStartFailure(instance);
        return instance;
    };
    defer fetched.deinit();

    var start: worker_host.DedicatedWorkerStart = .{
        .source = fetched.source,
        .script_url = fetched.final_url,
        .worker_type = worker_type,
        .name = name,
        // "Initialize a worker global scope's policy container", from the
        // response - or this realm's global's, for a data: or blob: script.
        .policy_container = worker_host.workerPolicyContainer(ctx.allocator, &fetched, ctx),
        // The worker shares its creator's cookie jar - the user agent's.
        .cookie_jar = creatorCookieJar(ctx),
        .owner_realm = ctx,
        .owner_worker = .{
            .instance = instance,
            .generation = runtime.SlabAllocator.generationOf(instance),
            .steps = &owner_steps,
        },
        .inside_end = inside_end,
    };
    defer if (start.policy_container) |*container| container.deinit();
    internal.link = worker_host.startDedicatedWorker(ctx.allocator, &start) catch |err| {
        log.debug("the worker's thread did not start: {}", .{err});
        queueStartFailure(instance);
        return instance;
    };
    // The thread took the implicit port.
    inside_end = start.inside_end;
    return instance;
}

// Event handler IDL attributes (HTML § 8.1.8.1): their values live in
// EventTarget's event handler map, where firing `message` or `error` at this
// Worker finds them - in order with every listener.

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "error");
}

pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "message");
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "messageerror");
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "error", value);
}

pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "message", value);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "messageerror", value);
}

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
    var task: Delivery = .{ .worker = worker, .delivery = delivery };
    engine.runTaskInRealm(worker.ctx, Delivery.steps, &task) catch {};
    // The last message of a worker that has ended: nothing is pending now.
    releaseWhenIdle(worker);
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
/// the error went unhandled there: "fire an event named error at
/// workerObject, using ErrorEvent, with the cancelable attribute initialized
/// to true, and additional attributes initialized according to errorInfo" -
/// `error` null: the exception value does not reach the owner's realm.
///
/// TODO(workers): "If notHandled is true, then report exception for
/// workerObject's relevant global object with omitError set to true" - the
/// owner's own error event. Not yet: the owner's global does not hear it.
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
        _ = dom.fire_event.dispatchTrusted(worker, event) catch {};
        event.releaseIfUnwrapped(generation);
    }
};

/// "Run a worker" onComplete step 1.1: "queue a global task on the DOM
/// manipulation task source given worker's relevant global object to fire
/// an event named error at worker" - a plain Event, not cancelable. (A
/// worker terminated first hears nothing.)
fn startFailed(worker: *runtime.Instance) void {
    const internal = getInternal(worker) orelse return;
    if (internal.terminated) return;
    engine.runTaskInRealm(worker.ctx, fireErrorEventSteps, worker) catch {};
}

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
    if (!internal.ended) return;
    if (!internal.terminated) {
        if (internal.outside) |end| {
            const state = end.state();
            if (state.enabled and state.queued > 0) return;
        }
    }
    releasePendingActivity(worker);
}

/// "Run a worker" onComplete step 1, from the constructor: the worker never
/// runs, and `error` is fired at it from a task of its realm's loop. Its
/// pending activity ends with that task.
fn queueStartFailure(instance: *runtime.Instance) void {
    const sink = instance.ctx.task_sink orelse return releasePendingActivity(instance);
    const task = instance.ctx.allocator.create(StartFailure) catch return releasePendingActivity(instance);
    task.* = .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .allocator = instance.ctx.allocator,
    };
    _ = sink.post(.{ .run = StartFailure.run, .drop = StartFailure.drop, .data = task });
}

const StartFailure = struct {
    instance: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *StartFailure = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return;
        startFailed(self.instance);
        releasePendingActivity(self.instance);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *StartFailure = @ptrCast(@alignCast(data.?));
        self.allocator.destroy(self);
    }
};

/// Take the engine's pending-activity hold on a Worker.
fn keepPendingActivity(instance: *runtime.Instance) void {
    engine.keepPlatformObjectAlive(instance);
}

/// End it (idempotent).
fn releasePendingActivity(instance: *runtime.Instance) void {
    engine.releasePlatformObject(instance);
}

/// The cookie jar of the global whose realm is `realm`: the worker's
/// creator's settings object's.
fn creatorCookieJar(realm: runtime.Context) ?*@import("cookiestore").CookieJar {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return @import("dom").global_settings.cookieJarOf(global);
}
