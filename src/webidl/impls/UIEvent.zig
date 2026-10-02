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
//! `view` is stored as a pointer, as MouseEvent and PointerEvent store it: a
//! Window outlives every event made in its own realm. An event handed another
//! realm's Window (`{ view: frame.contentWindow }`) and kept past that frame's
//! end would read a freed Window; see lane-forms-handoff.md.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const UIEvent = interfaces.UIEvent;

pub const State = UIEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// UIEvent keeps nothing beyond its generated fields.
pub const InternalState = struct {};

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
    state.own.view = init_dict.view;
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
    state.own.view = if (viewArg.was_passed) viewArg.value else null;
    state.own.detail = if (detailArg.was_passed) detailArg.value else 0;
}
