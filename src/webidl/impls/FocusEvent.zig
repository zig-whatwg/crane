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
const KeptInstance = @import("dom").custom_elements.KeptInstance;
const FocusEvent = interfaces.FocusEvent;

pub const State = FocusEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The event keeps its related target alive: an edge from the event's
/// wrapper (engine.traceChild, `related_target_slot`), drawn when the target
/// is set and ended in deinit - so a target that keeps its event (`el.e = e`)
/// is collected with it once script holds neither. Blink: Event::Trace visits
/// the related target (FocusEvent is a UIEvent); WebKit: FocusEvent's
/// RefPtr<EventTarget> m_relatedTarget.
///
/// `related_target` is the native pointer beside the edge, with its slab
/// generation and its realm (KeptInstance): only the teardown net. The edge
/// keeps the target while the event lives, so it reads as the target; once a
/// realm's teardown has freed it - Crane frees a realm's Instances when the
/// realm ends, whatever still points at them (engine_protocol.zig, Instance)
/// - it reads null, never a freed or reissued object.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    related_target: ?KeptInstance = null,
};

const related_target_slot: engine.TracedSlot = .{ .name = "relatedTarget" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance: the UIEvent part, then FocusEvent's own state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its own state, then the UIEvent part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // An event freed without ever being wrapped (dispatched to no
        // listener, then releaseIfUnwrapped) lets the hold waiting for its
        // wrapper go; a collected one's edge went with the wrapper.
        if (internal.related_target != null) engine.forgetTracedChild(instance, related_target_slot);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
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

/// Set the related target the event reports, and keep it: the edge from the
/// event to it replaces the one to the target it had.
fn setRelatedTarget(instance: *runtime.Instance, target: ?*runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (target) |t| {
        internal.related_target = KeptInstance.of(t);
        engine.traceChild(instance, t, related_target_slot);
    } else if (internal.related_target != null) {
        internal.related_target = null;
        engine.forgetTracedChild(instance, related_target_slot);
    }
}

/// Getter for relatedTarget: the value it was initialized to. The event's
/// edge keeps it; null only past its realm's teardown (the net above).
pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const kept = internal.related_target orelse return null;
    return kept.get();
}
