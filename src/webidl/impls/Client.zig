//! Implementation for Client interface
//!
//! Spec: Service Workers 4.2 Client
//! https://w3c.github.io/ServiceWorker/#client-interface
//!
//! A service worker's view of one of its clients - a window, a dedicated or
//! a shared worker. A service worker's realm (src/service_worker/realm.zig,
//! Create Client / Create Window Client) makes it from what the Browser's
//! manager knows of the client, as a construction argument this impl owns:
//! its id, creation URL, type and frame type. Each get() and matchAll() and
//! each message event makes new ones ([NewObject]). postMessage() reaches the
//! client's container through the manager.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const service_worker = @import("service_worker");
const Client = interfaces.Client;

pub const State = Client.State;

pub const ImplError = error{
    NotImplemented,
};

/// The client it represents: a holder of the object's state, which this
/// impl takes (the holder is set to null) - so a construction that fails
/// before it took it leaves it with the caller, and one that fails after
/// frees it with the destruction chain.
pub const construction_args = .{"client"};

pub const InternalState = struct {
    /// OWNED.
    client: *service_worker.objects.ClientObject,
    allocator: std.mem.Allocator,
};

/// Client's own construction steps.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "client")) return;
    const holder: *?*service_worker.objects.ClientObject = args.client;
    const client = holder.* orelse return;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .client = client, .allocator = allocator };
    holder.* = null;
    instance.getState(State).own._internal = internal;
}

/// Client's own teardown.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.client.destroy();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn clientOf(instance: *runtime.Instance) !*service_worker.objects.ClientObject {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.client;
}

/// Getter for url (4.2.1): the client's creation URL, serialized.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    return instance.ctx.allocator.dupe(u8, (try clientOf(instance)).url);
}

/// Getter for frameType (4.2.2).
pub fn get_frameType(instance: *runtime.Instance) anyerror!enums.FrameType {
    return switch ((try clientOf(instance)).frame_type) {
        .auxiliary => ._auxiliary_,
        .@"top-level" => ._top_level_,
        .nested => ._nested_,
        .none => ._none_,
    };
}

/// Getter for id (4.2.3): the client's id.
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // The object's own copy, which outlives the call.
    return runtime.DOMString.initInterned(&(try clientOf(instance)).id);
}

/// Getter for type (4.2.4): "window" for a window client, "worker" for a
/// dedicated worker client, "sharedworker" for a shared worker client.
pub fn get_type(instance: *runtime.Instance) anyerror!enums.ClientType {
    return switch ((try clientOf(instance)).kind) {
        .window => ._window_,
        .dedicated_worker => ._worker_,
        .shared_worker => ._sharedworker_,
        // A service worker's global is no client; the kind is never given
        // to a Client.
        .service_worker => ._window_,
    };
}

/// Getter for lifecycleState (Page Lifecycle's partial Client): a client
/// is never frozen here - nothing freezes a page.
pub fn get_lifecycleState(instance: *runtime.Instance) anyerror!enums.ClientLifecycleState {
    _ = try clientOf(instance);
    return ._active_;
}

/// Operation: postMessage(message, transfer) (4.2.5): postMessage(message,
/// options) with options["transfer"] = transfer.
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
    return service_worker.realm.postMessageToClient(instance, try clientOf(instance), message, list);
}

/// Operation: postMessage(message, options) (4.2.6).
pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!void {
    const transfer: []const runtime.JSValue = if (options.wasPassed()) (options.getValue().transfer orelse &.{}) else &.{};
    return service_worker.realm.postMessageToClient(instance, try clientOf(instance), message, transfer);
}
