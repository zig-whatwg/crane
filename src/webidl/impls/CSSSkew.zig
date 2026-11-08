//! CSS Typed OM 1 4.4: CSSSkew - skew(), with ax and ay angle slots. Always 2D: its is2D
//! setter does nothing (CSSTransformComponent).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSSkew.State;
pub const ImplError = error{TypeError};
pub const construction_args = .{"transform_slots"};
pub const InternalState = typed_om.TransformLinks;

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = try typed_om.TransformLinks.init(instance, args.transform_slots);
    instance.getState(State).own._internal = internal;
    internal.trace(instance);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.deinit(instance);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// CSSSkew(ax, ay): 1. If ax or ay do not match <angle>, throw a TypeError.
/// 2. Return a new CSSSkew with them and is2D true.
pub fn call_constructor(ctx: runtime.Context, ax: *runtime.Instance, ay: *runtime.Instance) !*runtime.Instance {
    if (!try typed_om.numericMatches(ax, .angle) or !try typed_om.numericMatches(ay, .angle)) return error.TypeError;
    return interfaces.CSSSkew.initWith(ctx.allocator, ctx, .{ .transform_is_2d = true, .transform_slots = @as([]const *runtime.Instance, &.{ ax, ay }) });
}

fn slot(instance: *runtime.Instance, index: usize) !*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.get(index);
}

/// The setters check what the constructor does (Blink's skew setters throw
/// a TypeError for a value that is not an <angle>).
fn put(instance: *runtime.Instance, index: usize, value: *runtime.Instance) !void {
    if (!try typed_om.numericMatches(value, .angle)) return error.TypeError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try internal.set(instance, index, value);
}

pub fn get_ax(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return slot(instance, 0);
}
pub fn get_ay(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return slot(instance, 1);
}
pub fn set_ax(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    return put(instance, 0, value);
}
pub fn set_ay(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    return put(instance, 1, value);
}
