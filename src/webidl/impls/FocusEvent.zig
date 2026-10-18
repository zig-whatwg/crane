//! Implementation for FocusEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-focusevent
//!
//! ```idl
//! [Exposed=Window]
//! interface FocusEvent : UIEvent {
//!   constructor(DOMString type, optional FocusEventInit eventInitDict = {});
//!   readonly attribute EventTarget? relatedTarget;
//! };
//! dictionary FocusEventInit : UIEventInit {
//!   EventTarget? relatedTarget = null;
//! };
//! ```

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
const event_dispatch = @import("dom").event_dispatch;
const FocusEvent = interfaces.FocusEvent;

pub const State = FocusEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// FocusEvent keeps no state of its own: its relatedTarget is the event's
/// (DOM 2.2 "relatedTarget"), which dispatch retargets path item by path
/// item, so the attribute reads the event's dispatch state
/// (dom.event_dispatch), and the event keeps what it holds - an edge from
/// its wrapper, so a target that keeps its event (`el.e = e`) is collected
/// with it once script holds neither. Blink: Event::Trace visits the related
/// target (FocusEvent is a UIEvent); WebKit: FocusEvent's
/// RefPtr<EventTarget> m_relatedTarget.
pub const InternalState = struct {};

/// Initialize instance: the UIEvent part.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the UIEvent part, whose Event teardown ends the
/// relatedTarget's edge.
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.UIEvent.deinit(instance);
}

/// Constructor: inner event creation steps, UIEventInit's members, then
/// relatedTarget.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.FocusEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &FocusEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.FocusEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{} } };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base.base));
    event_construction.initializeUIEvent(instance, event_construction.uiEventInitFrom(dict.base));
    setRelatedTarget(instance, dict.relatedTarget);
    return instance;
}

/// Initialize the event's relatedTarget to `target`, and keep it: the edge
/// from the event to it replaces the one to the target it had.
fn setRelatedTarget(instance: *runtime.Instance, target: ?*runtime.Instance) void {
    const state = event_dispatch.of(instance) orelse return;
    state.setRelatedTarget(instance, target);
}

/// Getter for relatedTarget: "return this's relatedTarget" - the event's
/// (UI Events; DOM 2.2), retargeted while it is dispatched.
pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = event_dispatch.of(instance) orelse return null;
    return state.relatedTarget();
}
