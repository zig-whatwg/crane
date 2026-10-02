//! Implementation for PageSwapEvent interface
//!
//! HTML Standard §7.2.7.4 - The PageSwapEvent interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-pageswapevent-interface
//!
//! "The activation and viewTransition attributes must return the values they
//! were initialized to." The navigation that replaces a document fires one at
//! its window ("fire the pageswap event", dom.navigation_api) with the
//! NavigationActivation of that navigation, or null; script can construct
//! one too. The objects the attributes name are kept alive for as long as
//! the event is (same_object.zig).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const PageSwapEvent = interfaces.PageSwapEvent;

pub const State = PageSwapEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The edges that keep the attributes' objects alive with the event's
/// wrapper (same_object.Traced).
pub const InternalState = struct {
    allocator: Allocator,
    activation_edge: same_object.Traced = .{ .slot = .{ .name = "activation" } },
    view_transition_edge: same_object.Traced = .{ .slot = .{ .name = "viewTransition" } },

    fn release(self: *InternalState, event: *runtime.Instance) void {
        self.activation_edge.release(event);
        self.view_transition_edge.release(event);
    }
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.navigation_objects.installPageSwapEvents(.{ .create = &createPageSwap });
}

/// Initialize instance (creates the instance): the Event part is set by the
/// constructor; until then deinit finds an empty type and no pins, so an
/// instance made only to install dom.navigation_objects can be let go.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    const state = instance.getState(StateType);
    state.base.own.type = runtime.DOMString.initEmpty();
    state.base.own._internal = null;
    state.own._internal = null;
    return instance;
}

/// dom.navigation_objects: "fire the pageswap event" step 5's event - a
/// PageSwapEvent named pageswap with its activation set to `activation` and
/// its viewTransition set to null - made in `realm`, to be dispatched
/// trusted.
fn createPageSwap(realm: runtime.Context, activation: ?*runtime.Instance) anyerror!*runtime.Instance {
    return call_constructor(realm, runtime.DOMString.initInterned("pageswap"), webidl.Opt(dictionaries.PageSwapEventInit).passed(.{ .base = .{}, .activation = activation }));
}

/// Deinitialize instance: its pins, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.release(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" for the Event part, then
/// activation and viewTransition from the dictionary.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.PageSwapEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &PageSwapEvent.vtable, ctx);
    errdefer deinit(instance);
    const state = instance.getState(State);
    const init_dict = if (eventInitDict.was_passed) eventInitDict.value else dictionaries.PageSwapEventInit{ .base = .{} };
    // What deinit reads, should anything below fail.
    state.base.own.type = runtime.DOMString.initEmpty();
    state.own._internal = null;
    state.own.activation = null;
    state.own.viewTransition = null;

    // DOM "inner event creation steps": the initialized flag, the type, and
    // each EventInit member initializing the attribute of its name.
    state.base.own.type = try @"type".clone(ctx.allocator);
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));
    state.base.own.isTrusted = false;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0; // NONE
    state.base.own.bubbles = init_dict.base.bubbles orelse false;
    state.base.own.cancelable = init_dict.base.cancelable orelse false;
    state.base.own.composed = init_dict.base.composed orelse false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{ .allocator = ctx.allocator };
    state.own._internal = internal;
    state.own.activation = init_dict.activation;
    if (init_dict.activation) |activation| internal.activation_edge.hold(instance, activation);
    state.own.viewTransition = init_dict.viewTransition;
    if (init_dict.viewTransition) |transition| internal.view_transition_edge.hold(instance, transition);

    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// "The activation attribute must return the value it was initialized to."
pub fn get_activation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.activation;
}

/// "The viewTransition attribute must return the value it was initialized
/// to." Nothing makes a ViewTransition (no rendering), so only a constructed
/// event has one.
pub fn get_viewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.viewTransition;
}
