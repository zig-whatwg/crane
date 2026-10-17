//! Implementation for WindowClient interface
//!
//! Spec: Service Workers 4.2 Client (WindowClient)
//! https://w3c.github.io/ServiceWorker/#windowclient-interface
//!
//! A Client whose service worker client is a window. Create Window Client
//! gives it its visibility state, focus state and ancestor origins array as
//! the window's own event loop read them (src/service_worker/realm.zig); the
//! Client part owns that state and this part borrows it (the destruction
//! chain ends this part first). focus() and navigate() are the service_worker
//! module's.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const engine = @import("engine");
const service_worker = @import("service_worker");
const WindowClient = interfaces.WindowClient;

pub const State = WindowClient.State;

pub const ImplError = error{
    NotImplemented,
};

/// Its window data, BORROWED from the Client part's state.
pub const construction_args = .{"window_client"};

pub const InternalState = struct {
    window: *const service_worker.manager.WindowData,
    /// The ancestor origins array ([SameObject]), made on first read.
    ancestor_origins: ?engine.Owned = null,
    allocator: std.mem.Allocator,
};

/// WindowClient's own construction steps: the generated chain runs Client's
/// first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "window_client")) return;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .window = args.window_client, .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// WindowClient's own teardown: the generated chain runs Client's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.ancestor_origins) |array| array.release();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

/// Getter for visibilityState (4.2.7): its visibility state. The IDL type is
/// DocumentVisibilityState (service-workers.idl used to name an undefined
/// VisibilityState, which bound as a JSValue).
pub fn get_visibilityState(instance: *runtime.Instance) anyerror!enums.DocumentVisibilityState {
    const internal = try internalOf(instance);
    return if (internal.window.visible) ._visible_ else ._hidden_;
}

/// Getter for focused (4.2.8): its focus state.
pub fn get_focused(instance: *runtime.Instance) anyerror!bool {
    return (try internalOf(instance)).window.focused;
}

/// Getter for ancestorOrigins (4.2.9): its ancestor origins array - a
/// frozen array, the same one every time.
pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    if (internal.ancestor_origins == null) {
        const origins = internal.window.ancestor_origins;
        const values = try internal.allocator.alloc(runtime.JSValue, origins.len);
        defer internal.allocator.free(values);
        for (origins, values) |origin, *value| value.* = runtime.JSValue.fromStringRef(origin);
        internal.ancestor_origins = try engine.createFrozenArray(instance.ctx, values);
    }
    // The object keeps its array; the binding gets a hold of its own.
    return (try engine.retainValue(instance.ctx, internal.ancestor_origins.?.value)).take();
}

/// Operation: focus (4.2.10).
pub fn call_focus(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.focusClient(instance);
}

/// Operation: navigate (4.2.11).
pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString) anyerror!runtime.JSValue {
    var id = try interfaces.Client.get_id(instance);
    defer id.deinit(instance.ctx.allocator);
    return service_worker.realm.navigateClient(instance, id.asSlice(), url);
}
