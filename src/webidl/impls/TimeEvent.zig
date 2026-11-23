//! Implementation for TimeEvent interface (SVG Animations 2 5.1, from SMIL
//! Animation 6.2): beginEvent, endEvent and repeatEvent, which the timing
//! model raises at an animation element (dom.smil.document_animations), and
//! initTimeEvent for one made by script.
//!
//! `view` is kept as UIEvent keeps its: a pointer for the event's own
//! realm's Window (every event the engine fires: the Window outlives it),
//! and a traced edge to the WindowProxy for another realm's
//! (initTimeEvent(type, frame.contentWindow)).
//!
//! https://svgwg.org/specs/animations/#InterfaceTimeEvent

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const TimeEvent = interfaces.TimeEvent;

pub const State = TimeEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The facts the timing model gives an event it makes: its view and detail.
pub const construction_args = .{ "time_view", "time_detail" };

pub const InternalState = struct {
    view: ?*runtime.Instance = null,
    /// Another realm's view: the Window it named, beside a traced edge to
    /// its WindowProxy (`view_slot`).
    view_window: ?runtime.window_holders.Link = null,
    detail: i32 = 0,
};

const view_slot: engine.TracedSlot = .{ .name = "time-event:view" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
    if (@hasField(@TypeOf(args), "time_view")) setView(instance, internal, args.time_view);
    if (@hasField(@TypeOf(args), "time_detail")) internal.detail = args.time_detail;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.view_window != null) engine.forgetTracedChild(instance, view_slot);
    runtime.arenaOf(instance).destroy(InternalState, internal);
    state.own._internal = null;
}

/// Set the view, keeping another realm's WindowProxy by a traced edge
/// (UIEvent's setView, for the same reasons).
fn setView(instance: *runtime.Instance, internal: *InternalState, view: ?*runtime.Instance) void {
    if (internal.view_window != null) {
        engine.forgetTracedChild(instance, view_slot);
        internal.view_window = null;
    }
    internal.view = view;
    const window = view orelse return;
    if (window.ctx == instance.ctx) return;
    internal.view_window = runtime.window_holders.Link.of(window);
    engine.traceValue(instance, .{ .instance = window }, view_slot);
}

/// Getter for view: "the Window from which the event was generated".
pub fn get_view(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;
    if (internal.view_window) |link| {
        if (engine.tracedValue(instance, view_slot)) |held| {
            defer held.release();
            if (engine.convertToPlatformObject(instance.ctx, held.value)) |window| return window;
        }
        return link.get();
    }
    return internal.view;
}

/// Getter for detail: for a repeatEvent, the repeat iteration.
pub fn get_detail(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.detail;
}

/// initTimeEvent(typeArg, viewArg, detailArg): "may only be called before
/// the TimeEvent has been dispatched"; it initializes the event's type (a
/// TimeEvent neither bubbles nor can be canceled), view and detail - as
/// Gecko's TimeEvent::InitTimeEvent does, the one browser that has the
/// interface (dom/events/TimeEvent.cpp: InitEvent(type, false, false)).
pub fn call_initTimeEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32)) anyerror!void {
    if (dom.event_construction.dispatchFlag(instance)) return;
    try interfaces.Event.call_initEvent(instance, typeArg, webidl.Opt(bool).passed(false), webidl.Opt(bool).passed(false));
    const internal = getInternal(instance) orelse return;
    setView(instance, internal, if (viewArg.was_passed) viewArg.value else null);
    internal.detail = if (detailArg.was_passed) detailArg.value else 0;
}
