//! Implementation for NavigationPrecommitController interface
//!
//! HTML Standard §7.2.6.10.2 - The NavigationPrecommitController interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-navigationprecommitcontroller-interface
//!
//! What a precommit handler is given: its navigate event, whose destination
//! it can redirect() and whose handler list it can addHandler() to. The
//! navigation API makes one (dom.navigation_objects, which this installs);
//! both methods act on what the navigation that fired the event keeps - its
//! interception state, its destination, its API method tracker - so they
//! hand their arguments to it (dom.navigation_api), which performs the
//! event's shared checks and the steps after them.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const NavigationPrecommitController = interfaces.NavigationPrecommitController;

pub const State = NavigationPrecommitController.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// "Each NavigationPrecommitController has a NavigateEvent event", kept
/// alive with it.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    event: ?*runtime.Instance = null,
    /// Kept by this object's wrapper (an edge: same_object.Traced).
    event_edge: same_object.Traced = .{ .slot = .{ .name = "event" } },
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.navigation_objects.installControllers(.{ .create = &create });
}

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.event_edge.release(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// dom.navigation_objects: "a new NavigationPrecommitController created in
/// navigation's relevant realm, whose event is event".
fn create(realm: runtime.Context, event: *runtime.Instance) anyerror!*runtime.Instance {
    const instance = try interfaces.NavigationPrecommitController.init(realm.allocator, realm);
    errdefer runtime.Instance.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.event = event;
    internal.event_edge.hold(instance, event);
    return instance;
}

/// addHandler(handler): steps 2-4 are the navigation's (see the file
/// comment); step 1 is an assertion.
pub fn call_addHandler(instance: *runtime.Instance, handler: callbacks.NavigationInterceptHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const event = internal.event orelse return error.InvalidStateError;
    try dom.navigation_api.addHandler(event, @ptrCast(handler));
}

/// redirect(url, options): steps 2-12 are the navigation's (see the file
/// comment); step 1 is an assertion.
pub fn call_redirect(instance: *runtime.Instance, url: runtime.USVString, options: webidl.Opt(dictionaries.NavigationNavigateOptions)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const event = internal.event orelse return error.InvalidStateError;
    const opts: ?dictionaries.NavigationNavigateOptions = if (options.was_passed) options.value else null;
    try dom.navigation_api.redirect(event, .{
        .url = url,
        .history = if (opts) |o| if (o.history) |h| switch (h) {
            ._push_ => .push,
            ._replace_ => .replace,
            ._auto_ => null,
        } else null else null,
        .state = if (opts) |o| o.state else null,
        .info = if (opts) |o| o.base.info else null,
    });
}
