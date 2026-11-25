//! Implementation for Touch interface (Touch Events, "Touch Interface"): one
//! touch point - immutable once made, from a TouchInit (script's, or the
//! user agent's for a touch point the input layer reports, html.user_input).
//!
//! Its target is kept the browsers' way: Blink's Touch holds
//! `Member<EventTarget> target_` (traced), so it is an edge from the touch's
//! wrapper (engine.traceChild, slot "target"), held strongly while the touch
//! is unwrapped. The pointer beside it carries the target's generation and
//! realm (KeptInstance): only the teardown net.
//!
//! Retargeting (Touch Events, "Retargeting"; DOM 2.2 "touch target list"):
//! a touch listed in a TouchEvent (dom.touch_points.adopt) reads its target
//! from that event's touch target list while the event is dispatched - the
//! entry dispatch retargeted against the current path item (DOM "invoke"
//! step 5) - and its unadjusted target otherwise. Gecko retargets each
//! Touch's target per chain item the same way
//! (EventTargetChainItem::RetargetTouchTargets).
//!
//! Spec: https://w3c.github.io/touch-events/#touch-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const dom = @import("dom");
const KeptInstance = dom.custom_elements.KeptInstance;
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const Touch = interfaces.Touch;

pub const State = Touch.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
};

/// The touch point's attributes, as made (immutable), and where it is
/// listed for retargeting.
pub const InternalState = struct {
    identifier: i32 = 0,
    /// The unadjusted target, kept by the edge in slot "target".
    target: ?KeptInstance = null,
    target_drawn: bool = false,
    screen_x: f64 = 0,
    screen_y: f64 = 0,
    client_x: f64 = 0,
    client_y: f64 = 0,
    page_x: f64 = 0,
    page_y: f64 = 0,
    radius_x: f32 = 0,
    radius_y: f32 = 0,
    rotation_angle: f32 = 0,
    force: f32 = 0,
    altitude_angle: f64 = 0,
    azimuth_angle: f64 = 0,
    touch_type: enums.TouchType = ._direct_,
    /// The TouchEvent whose touch target list holds this touch's target,
    /// and at which index (dom.touch_points.adopt); never a hold.
    event: ?KeptInstance = null,
    index: u32 = 0,
};

const target_slot: engine.TracedSlot = .{ .name = "target" };

const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The process-wide hook: Touch's steps with no IDL member.
pub fn installHooks() void {
    dom.touch_points.install(.{ .unadjusted_target = &unadjustedTarget, .adopt = &adopt });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the touch's own storage, never its target. A
/// touch freed without ever being wrapped lets the hold waiting for its
/// wrapper go; a collected one's edge went with the wrapper.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    if (internal.target_drawn) engine.forgetTracedChild(instance, target_slot);
    instance.ctx.allocator.destroy(internal);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor: "constructor(TouchInit touchInitDict)" - every attribute
/// from the dictionary, its defaults where a member is absent.
pub fn call_constructor(instance: *runtime.Instance, touchInitDict: dictionaries.TouchInit) !void {
    // The generated constructor made `instance` (WebIDL 3.7.1 step 1.8)
    // and frees it whole when a step fails (lane ctor1).
    const ctx = instance.ctx;
    const state = instance.stateAs(State) orelse return error.InvalidState;
    const internal = try ctx.allocator.create(InternalState);
    const d = touchInitDict;
    internal.* = .{
        .identifier = d.identifier,
        .target = KeptInstance.of(d.target),
        .screen_x = d.screenX orelse 0,
        .screen_y = d.screenY orelse 0,
        .client_x = d.clientX orelse 0,
        .client_y = d.clientY orelse 0,
        .page_x = d.pageX orelse 0,
        .page_y = d.pageY orelse 0,
        .radius_x = d.radiusX orelse 0,
        .radius_y = d.radiusY orelse 0,
        .rotation_angle = d.rotationAngle orelse 0,
        .force = d.force orelse 0,
        .altitude_angle = d.altitudeAngle orelse 0,
        .azimuth_angle = d.azimuthAngle orelse 0,
        .touch_type = d.touchType orelse ._direct_,
    };
    state.own._internal = internal;
    engine.traceChild(instance, d.target, target_slot);
    internal.target_drawn = true;
}

/// dom.touch_points.unadjustedTarget.
fn unadjustedTarget(touch: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(touch) orelse return null;
    const kept = internal.target orelse return null;
    return kept.get();
}

/// dom.touch_points.adopt.
fn adopt(touch: *runtime.Instance, event: *runtime.Instance, index: u32) void {
    const internal = getInternal(touch) orelse return;
    internal.event = KeptInstance.of(event);
    internal.index = index;
}

/// Getter for identifier
pub fn get_identifier(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.identifier;
}

/// Getter for target: the unadjusted target retargeted against the target
/// of the TouchEvent being dispatched, while one that lists this touch is.
pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const unadjusted = (internal.target orelse return error.InvalidState).get() orelse return error.InvalidState;
    const event = (internal.event orelse return unadjusted).get() orelse return unadjusted;
    const state = dom.event_dispatch.of(event) orelse return unadjusted;
    if (!state.dispatch_flag) return unadjusted;
    const list = state.touch_target_list.toSlice();
    if (internal.index >= list.len) return unadjusted;
    return list[internal.index];
}

/// Getter for screenX
pub fn get_screenX(instance: *runtime.Instance) anyerror!f64 {
    return (getInternal(instance) orelse return 0).screen_x;
}

/// Getter for screenY
pub fn get_screenY(instance: *runtime.Instance) anyerror!f64 {
    return (getInternal(instance) orelse return 0).screen_y;
}

/// Getter for clientX
pub fn get_clientX(instance: *runtime.Instance) anyerror!f64 {
    return (getInternal(instance) orelse return 0).client_x;
}

/// Getter for clientY
pub fn get_clientY(instance: *runtime.Instance) anyerror!f64 {
    return (getInternal(instance) orelse return 0).client_y;
}

/// Getter for pageX
pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
    return (getInternal(instance) orelse return 0).page_x;
}

/// Getter for pageY
pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
    return (getInternal(instance) orelse return 0).page_y;
}

/// Getter for radiusX
pub fn get_radiusX(instance: *runtime.Instance) anyerror!f32 {
    return (getInternal(instance) orelse return 0).radius_x;
}

/// Getter for radiusY
pub fn get_radiusY(instance: *runtime.Instance) anyerror!f32 {
    return (getInternal(instance) orelse return 0).radius_y;
}

/// Getter for rotationAngle
pub fn get_rotationAngle(instance: *runtime.Instance) anyerror!f32 {
    return (getInternal(instance) orelse return 0).rotation_angle;
}

/// Getter for force
pub fn get_force(instance: *runtime.Instance) anyerror!f32 {
    return (getInternal(instance) orelse return 0).force;
}

/// Getter for altitudeAngle (a float attribute over a double member).
pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f32 {
    return @floatCast((getInternal(instance) orelse return 0).altitude_angle);
}

/// Getter for azimuthAngle (a float attribute over a double member).
pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f32 {
    return @floatCast((getInternal(instance) orelse return 0).azimuth_angle);
}

/// Getter for touchType
pub fn get_touchType(instance: *runtime.Instance) anyerror!enums.TouchType {
    return (getInternal(instance) orelse return ._direct_).touch_type;
}
