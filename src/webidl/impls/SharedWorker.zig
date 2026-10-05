//! Implementation for SharedWorker interface
//!
//! Spec: HTML Standard § 10.2.6.4 Shared workers and the SharedWorker
//! interface
//! https://html.spec.whatwg.org/multipage/workers.html#shared-workers-and-the-sharedworker-interface
//!
//! The constructor's own steps are here: the options, the URL, the outside
//! port. Step 11 - the shared worker manager's steps, which find a running
//! SharedWorkerGlobalScope or run a new worker on a thread of its own -
//! belongs to the worker host (src/html/worker_host.zig), which runs every
//! worker's agent. What the worker's start does at this object - `error`
//! when it cannot start, the end of the object's pending activity when it
//! has - comes back as a task of this object's loop (`owner_steps`).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const SharedWorker = interfaces.SharedWorker;

// A SharedWorker is an EventTarget: made and ended through EventTarget's
// interface, its event handlers in EventTarget's map (dom.event_handlers).
const event_handlers = @import("dom").event_handlers;

// Keeping the port's wrapper alive for as long as this object.
const same_object = @import("same_object.zig");

// URL parsing and origins, for steps 3-5 and the constructor origin.
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const url_origin = @import("origin");

// The channel the port pair is made of. The outside port is a new
// MessagePort made on one end (no IDL member makes a port on a given end:
// MessagePort's `message_ports` hook does); the worker host makes the inside
// port on the other the same way.
const port_channels = @import("dom").port_channels;
const message_ports = @import("dom").message_ports;

/// The worker host: "run a worker", and the shared worker manager.
const worker_host = @import("html").worker_host;
const workers = @import("html_core").workers;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;

pub const State = SharedWorker.State;

pub const ImplError = error{
    NotImplemented,
    SyntaxError,
    OutOfMemory,
};

/// The SharedWorker's own state.
pub const InternalState = struct {
    /// HTML: the SharedWorker's port - outsidePort, a new MessagePort in the
    /// constructor's realm (steps 6-7). The worker's side of the channel is
    /// the inside port the `connect` event carries.
    port: *runtime.Instance,
    /// Keeps `port`'s wrapper alive for as long as this object's:
    /// `worker.port.onmessage = f` leaves nothing in script holding the port.
    /// An edge, not a root (same_object.Traced); Blink traces `port_` from
    /// SharedWorker::Trace.
    port_edge: same_object.Traced = .{ .slot = .{ .name = "port" } },
    allocator: std.mem.Allocator,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // "Destroy a document" step 8: the Document leaves every shared worker's
    // owner set, and a worker whose owner set empties is closed.
    @import("dom").unloading_cleanup.install(&worker_host.sharedWorkerOwnerGone);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Whatever pending-activity hold is left on it goes with it.
    engine.releasePlatformObject(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.port_edge.release(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
}

/// The SharedWorker(scriptURL, options) constructor steps.
///
/// Spec: HTML Standard § 10.2.6.4
/// https://html.spec.whatwg.org/multipage/workers.html#dom-sharedworker
pub fn call_constructor(ctx: runtime.Context, scriptURL: typedefs.TrustedScriptURLOrUSVString, options: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    const allocator = ctx.allocator;
    // 1. "Let compliantScriptURL be the result of invoking the get trusted
    // type compliant string algorithm with TrustedScriptURL, this's relevant
    // global object, scriptURL, "SharedWorker constructor", and "script"."
    const compliant_script_url = try @import("dom").trusted_types.compliantStringForRealm(allocator, .script_url, ctx, scriptURL, "SharedWorker constructor");
    defer allocator.free(compliant_script_url);

    const instance = try init(allocator, State, &SharedWorker.vtable, ctx);
    errdefer deinit(instance);

    // 2. If options is a DOMString, it is a WorkerOptions whose name is
    // options; otherwise it is the dictionary.
    var worker_options = try convertOptions(ctx, options);
    defer worker_options.deinit(allocator);

    // 3-5. outsideSettings is this's relevant settings object; urlRecord is
    // compliantScriptURL encoding-parsed relative to it; failure throws a
    // "SyntaxError" DOMException.
    const base_url = apiBaseURL(instance);
    defer if (base_url) |b| allocator.free(b);
    const url_record = resolveScriptURL(allocator, compliant_script_url, base_url) catch |err| switch (err) {
        error.SyntaxError => return error.SyntaxError,
        else => |e| return e,
    };
    defer allocator.free(url_record);

    // 6-7. outsidePort: a new MessagePort in outsideSettings' realm, this's
    // port. Its channel's other end waits for the worker's realm, where it
    // becomes the inside port (manager step 5.5, or "run a worker").
    const channel = try port_channels.Channel.create(allocator);
    const inside_end = channel.end(1);
    var inside_end_owned = true;
    errdefer if (inside_end_owned) inside_end.discard();
    // `adopt` takes the outside end whatever happens.
    const outside_port = try message_ports.adopt(ctx, channel.end(0));
    const internal = try allocator.create(InternalState);
    internal.* = .{ .port = outside_port, .allocator = allocator };
    instance.getState(State).own._internal = internal;
    internal.port_edge.hold(instance, outside_port);

    // 9. outsideStorageKey: obtain a storage key for non-storage purposes,
    // given outsideSettings - its origin, here, serialized (Crane has no
    // storage partitioning, so the key is the origin).
    const origin = try serializedOriginOf(allocator, base_url);
    defer allocator.free(origin);

    // 8, 10-11. Enqueue the manager's steps: they find a running
    // SharedWorkerGlobalScope for (origin, urlRecord, name) or run a new
    // worker, and fire `connect` - or `error` at this object.
    inside_end_owned = false;
    try worker_host.connectSharedWorker(.{
        .worker = instance,
        .steps = &owner_steps,
        .owner_realm = ctx,
        .url = url_record,
        .origin = origin,
        .name = worker_options.name,
        .worker_type = worker_options.worker_type,
        .credentials = worker_options.credentials,
        .extended_lifetime = worker_options.extended_lifetime,
        .inside_end = @ptrCast(inside_end),
        // "Run a worker" step 3, should the steps run one: the unsafe worker
        // creation time.
        .creation_time_ns = @intCast(@import("hr_time").MonotonicClock.unsafeCurrentTime()),
    });

    return instance;
}

/// What the shared worker manager's steps, and the start of the worker they
/// ran, do at this object - on its own realm's loop, each after a check of
/// its slab generation (html.worker_host.OwnerSteps).
const owner_steps: worker_host.OwnerSteps = .{
    .error_reported = errorReported,
    .start_failed = startFailed,
    .started = started,
    .ended = ended,
};

/// A shared worker's errors stay in it ("report an exception" step 7 is a
/// dedicated worker's): never called.
fn errorReported(_: *runtime.Instance, _: *const worker_host.ErrorReport.Info) void {}

/// "Run a worker" onComplete step 1.1, and the manager's step 4.1: "queue a
/// global task on the DOM manipulation task source given worker's relevant
/// global object to fire an event named error at worker" - a plain Event,
/// not cancelable. Then the object's pending activity ends.
fn startFailed(worker: *runtime.Instance) void {
    defer engine.releasePlatformObject(worker);
    engine.runTaskInRealm(worker.ctx, fireErrorSteps, worker) catch {};
}

fn fireErrorSteps(data: ?*anyopaque) void {
    const worker: *runtime.Instance = @ptrCast(@alignCast(data orelse return));
    const event = interfaces.Event.call_constructor(
        worker.ctx,
        runtime.DOMString.initInterned("error"),
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(worker, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// The worker this object ran has started: no `error` can come from its
/// start any more, and its pending activity ends.
fn started(worker: *runtime.Instance) void {
    engine.releasePlatformObject(worker);
}

/// A shared worker's end tells its SharedWorkers nothing.
fn ended(_: *runtime.Instance) void {}

/// SharedWorkerOptions, as the constructor's step 2 leaves it. `name` OWNED.
const Options = struct {
    name: []const u8,
    worker_type: WorkerType = .classic,
    credentials: RequestCredentials = .same_origin,
    /// SharedWorkerOptions' own member (HTML, 2025): the worker's extended
    /// lifetime. The pinned IDL (specs/idl) predates it and types the
    /// argument (DOMString or WorkerOptions); this conversion follows the
    /// current dictionary, SharedWorkerOptions : WorkerOptions.
    extended_lifetime: bool = false,

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

/// The (DOMString or WorkerOptions) argument, converted as WebIDL converts a
/// union with a dictionary in it (3.2.24): undefined, null or an object is
/// the dictionary; anything else is converted to a DOMString, which step 2
/// makes the name. An omitted argument is the dictionary's defaults.
fn convertOptions(ctx: runtime.Context, options: webidl.Opt(runtime.JSValue)) !Options {
    const allocator = ctx.allocator;
    if (!options.wasPassed()) return .{ .name = try allocator.dupe(u8, "") };
    const value = options.getValue();
    switch (engine.typeOf(ctx, value)) {
        .undefined, .null => return .{ .name = try allocator.dupe(u8, "") },
        .object => return convertWorkerOptions(ctx, value),
        else => return .{ .name = try engine.convertToDOMString(ctx, value, allocator) },
    }
}

/// WebIDL's dictionary conversion of `value`, an object, to
/// SharedWorkerOptions: its members - the inherited dictionary's first
/// (WorkerOptions: credentials, name, type), then its own (extendedLifetime),
/// each set in lexicographic order - each Get, then converted, or its default
/// when undefined. An enumeration value that is not one of the enum's throws
/// a TypeError.
fn convertWorkerOptions(ctx: runtime.Context, value: runtime.JSValue) !Options {
    const allocator = ctx.allocator;
    var result: Options = .{ .name = try allocator.dupe(u8, "") };
    errdefer result.deinit(allocator);

    if (try memberString(ctx, value, "credentials")) |text| {
        defer allocator.free(text);
        result.credentials = RequestCredentials.fromString(text) orelse return error.TypeError;
    }
    if (try memberString(ctx, value, "name")) |text| {
        allocator.free(result.name);
        result.name = text;
    }
    if (try memberString(ctx, value, "type")) |text| {
        defer allocator.free(text);
        result.worker_type = WorkerType.fromString(text) orelse return error.TypeError;
    }
    // SharedWorkerOptions' own member: boolean, ToBoolean of the value.
    if (try engine.getPropertyBoolean(ctx, value, "extendedLifetime")) |extended| result.extended_lifetime = extended;
    return result;
}

/// Get(`object`, `member`) converted to a DOMString, or null when it is
/// undefined (the member is not present). OWNED (`ctx.allocator`).
fn memberString(ctx: runtime.Context, object: runtime.JSValue, member: []const u8) !?[]u8 {
    const got = try engine.getProperty(ctx, object, member);
    defer got.release();
    if (engine.typeOf(ctx, got.value) == .undefined) return null;
    return try engine.convertToDOMString(ctx, got.value, ctx.allocator);
}

/// `script_url` encoding-parsed relative to `api_base_url` and serialized.
/// OWNED (`allocator`). SyntaxError when it does not parse.
/// Deviation, stated (encoding-parse-utf8): the query is encoded as UTF-8, not with the document's encoding - queued.
fn resolveScriptURL(allocator: std.mem.Allocator, script_url: []const u8, api_base_url: ?[]const u8) error{ SyntaxError, OutOfMemory }![]const u8 {
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

/// The relevant settings object's API base URL, for the instance a
/// constructor just made in it: a window's document's base URL, read through
/// the Document's `baseURI`; a worker's is its script URL, which its realm
/// records as its document URL. OWNED by `instance.ctx.allocator`.
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

/// `instance`'s relevant global object, when it is a Window.
fn relevantWindow(instance: *runtime.Instance) ?*runtime.Instance {
    const record = instance.ctx.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// Getter for port: "The port getter steps are to return this's port."
pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.port;
}

// The AbstractWorker mixin's event handler IDL attribute (HTML §8.1.8.1): its
// value lives in EventTarget's event handler map, where the host's `error`
// event finds it.

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return event_handlers.get(typedefs.EventHandler, instance, "error");
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try event_handlers.set(typedefs.EventHandler, instance, "error", value);
}
