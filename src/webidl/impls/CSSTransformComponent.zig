//! CSS Typed OM 1 4.4: CSSTransformComponent, the base of the transform
//! components. It holds is2D; its subclasses hold their slots
//! (dom.style.typed_om.TransformLinks). toMatrix() and the stringifier
//! dispatch on the subclass through the generated interfaces
//! (dom.style.typed_om.componentToMatrix, serializeTransformComponent).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

pub const State = interfaces.CSSTransformComponent.State;
pub const ImplError = error{TypeError};
pub const construction_args = .{"transform_is_2d"};
pub const InternalState = struct { is_2d: bool };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .is_2d = if (@hasField(@TypeOf(args), "transform_is_2d")) args.transform_is_2d else true };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.is_2d;
}

/// "The is2D attribute of a CSSSkew, CSSSkewX, or CSSSkewY object must, on
/// setting, do nothing" ("skew() ... always represent 2D transforms"), and
/// "the is2D attribute of a CSSPerspective object must, on setting, do
/// nothing" (perspective() is always 3D).
pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
    if (instance.stateAs(interfaces.CSSSkew.State) != null or instance.stateAs(interfaces.CSSSkewX.State) != null or
        instance.stateAs(interfaces.CSSSkewY.State) != null or instance.stateAs(interfaces.CSSPerspective.State) != null) return;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    internal.is_2d = value;
}

/// toMatrix(): a new DOMMatrix of this component's equivalent 4x4 matrix,
/// with this component's is2D; a TypeError for a length not compatible
/// with px.
pub fn call_toMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return dom.style.typed_om.componentToMatrix(instance);
}

/// 6.6: serialize the component as the function its class and is2D name.
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    return dom.style.typed_om.serializeTransformComponent(instance);
}
