//! Implementation for UIEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-uievent
//!
//! ```idl
//! [Exposed=Window]
//! interface UIEvent : Event {
//!   constructor(DOMString type, optional UIEventInit eventInitDict = {});
//!   readonly attribute Window? view;
//!   readonly attribute long detail;
//! };
//! dictionary UIEventInit : EventInit {
//!   Window? view = null;
//!   long detail = 0;
//! };
//! // Legacy (UI Events 8.1 and 8.2):
//! partial interface UIEvent {
//!   undefined initUIEvent(DOMString typeArg, optional boolean bubblesArg = false,
//!       optional boolean cancelableArg = false, optional Window? viewArg = null,
//!       optional long detailArg = 0);
//!   readonly attribute unsigned long which;
//! };
//! partial dictionary UIEventInit { unsigned long which = 0; };
//! ```
//!
//! The UIEvent members live in the generated state's own fields, which every
//! subclass (MouseEvent, PointerEvent, KeyboardEvent, ...) writes through its
//! own constructor; the getters here read them for all of them.
//!
//! `view` is stored as a pointer: a Window outlives every event made in its
//! own realm. An event handed another realm's Window
//! (`{ view: frame.contentWindow }`) keeps that view's WindowProxy instead
//! (`setView`), and reads the Window through it.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const event_construction = @import("dom").event_construction;
const UIEvent = interfaces.UIEvent;

pub const State = UIEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// What UIEvent keeps beyond its generated fields, made only for a view of
/// another realm (`setView`).
pub const InternalState = struct {
    /// The Window the view named when set, with its generation
    /// (runtime.window_holders.Link), beside a traced edge from this event
    /// to the view's WindowProxy (`view_slot`).
    view_window: ?runtime.window_holders.Link = null,
};

/// The member a UIEvent keeps another realm's view (its WindowProxy) in
/// (engine.traceValue).
const view_slot: engine.TracedSlot = .{ .name = "view" };

/// Set `instance`'s view, keeping another realm's as its WindowProxy.
///
/// A WindowProxy holder keeps the PROXY, never the Window it showed then
/// (lane winslot1, kind 4; the integrator's ruling of 2026-10-25 on the
/// three-browser probe, tmp/analysis/integrator-probes-1025n): after the
/// view's frame navigates, `view` is the same proxy showing the new
/// document, and after its iframe is removed, the same proxy, closed -
/// Firefox 158's behaviour, the majority mechanism by mechanism (Chrome 155
/// answers null after a navigation, Safari 27 after a removal). WebKit's
/// UIEvent keeps `RefPtr<WindowProxy> m_view`. The edge is traced, never a
/// root: a removed frame's realm lives exactly as long as the event. A view
/// of the event's own realm - every event the engine fires - needs none:
/// the event goes with that realm, which keeps its Window while it lives.
fn setView(instance: *runtime.Instance, view: ?*runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    if (state.own._internal) |internal| if (internal.view_window != null) {
        engine.forgetTracedChild(instance, view_slot);
        internal.view_window = null;
    };
    state.own.view = view;
    const window = view orelse return;
    if (window.ctx == instance.ctx) return;
    const internal = state.own._internal orelse blk: {
        const made = runtime.arenaOf(instance).create(InternalState) catch return;
        made.* = .{};
        state.own._internal = made;
        break :blk made;
    };
    internal.view_window = runtime.window_holders.Link.of(window);
    engine.traceValue(instance, .{ .instance = window }, view_slot);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // UIEventInit's members, for every subclass (dom.event_construction).
    event_construction.installUIEvent(.{ .initialize = &initializeMembers });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.Event.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: UIEvent owns nothing; the Event part owns the type
/// string and the flags.
pub fn deinit(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| if (state.own._internal) |internal| {
        if (internal.view_window != null) engine.forgetTracedChild(instance, view_slot);
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    };
    interfaces.Event.deinit(instance);
}

/// UIEvent's event constructing steps for an event whose Event part has
/// just been initialized: "for each member -> value of dictionary: if event
/// has an attribute whose identifier is member, initialize that attribute
/// to value" - view, detail and the legacy which. For UIEvent's own
/// constructor and, through dom.event_construction, each interface
/// inheriting from it.
fn initializeMembers(instance: *runtime.Instance, init_dict: event_construction.UIEventInit) void {
    const state = instance.stateAs(State) orelse return;
    setView(instance, init_dict.view);
    state.own.detail = init_dict.detail;
    state.own.which = init_dict.which;
    state.own.sourceCapabilities = null;
}

/// Constructor: DOM "inner event creation steps", then UIEventInit's members.
/// Spec: https://dom.spec.whatwg.org/#concept-event-constructor
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.UIEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &UIEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.UIEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    initializeMembers(instance, event_construction.uiEventInitFrom(dict));
    return instance;
}

/// Getter for view: "the view attribute must return the value it was
/// initialized to".
pub fn get_view(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.stateAs(State) orelse return null;
    // Another realm's view: the proxy the event keeps, as the Window it
    // shows now (`setView`); with no edge to read, the Window it named,
    // while that is still the one.
    if (state.own._internal) |internal| if (internal.view_window) |link| {
        if (engine.tracedValue(instance, view_slot)) |held| {
            defer held.release();
            if (engine.convertToPlatformObject(instance.ctx, held.value)) |window| return window;
        }
        return link.get();
    };
    return state.own.view;
}

/// Getter for detail
pub fn get_detail(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.stateAs(State) orelse return 0;
    return state.own.detail;
}

/// Getter for which (legacy): the value it was initialized to, 0 by default.
pub fn get_which(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.stateAs(State) orelse return 0;
    return state.own.which;
}

/// Getter for sourceCapabilities (InputDeviceCapabilities): no input device
/// is ever described, so always null.
pub fn get_sourceCapabilities(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: initUIEvent (legacy)
/// Spec: https://w3c.github.io/uievents/#dom-uievent-inituievent
///
/// "1. If this's dispatch flag is set, then return. 2. Initialize this with
/// typeArg, bubblesArg and cancelableArg. 3. Set view to viewArg and detail
/// to detailArg."
pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32)) anyerror!void {
    if (event_construction.dispatchFlag(instance)) return;
    try interfaces.Event.call_initEvent(instance, typeArg, bubblesArg, cancelableArg);
    const state = instance.stateAs(State) orelse return;
    setView(instance, if (viewArg.was_passed) viewArg.value else null);
    state.own.detail = if (detailArg.was_passed) detailArg.value else 0;
}
