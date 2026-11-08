//! CSS Typed OM 1 4.4: CSSScale - scale(), scaleX/Y/Z() and scale3d() -
//! with x, y and z <number> slots.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSScale.State;
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

/// CSSScale(x, y, z): 1. rectify x, y and z (if passed) as numberish values;
/// 2. throw a TypeError unless each matches <number>; 3-5. z as given and
/// is2D false, or a new unit value of (1, "number") and is2D true.
pub fn call_constructor(ctx: runtime.Context, x: typedefs.CSSNumberish, y: typedefs.CSSNumberish, z: webidl.Opt(typedefs.CSSNumberish)) !*runtime.Instance {
    var holds = typed_om.SlotHolds.init(ctx);
    defer holds.deinit();
    try holds.keep(try typed_om.numberishSlot(ctx, x), x == .double);
    try holds.keep(try typed_om.numberishSlot(ctx, y), y == .double);
    if (z.was_passed) {
        try holds.keep(try typed_om.numberishSlot(ctx, z.value), z.value == .double);
    } else try holds.keep(try typed_om.unitSlot(ctx, 1, "number"), true);
    return interfaces.CSSScale.initWith(ctx.allocator, ctx, .{ .transform_is_2d = !z.was_passed, .transform_slots = holds.values() });
}

fn slot(instance: *runtime.Instance, index: usize) !*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.get(index);
}

/// "On setting to a new value val, rectify a numberish value from val and
/// set the corresponding internal slot"; a value that is not a <number>
/// throws a TypeError (the constructor's step 2; Blink CSSScale::setX).
fn put(instance: *runtime.Instance, index: usize, value: typedefs.CSSNumberish) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    var holds = typed_om.SlotHolds.init(instance.ctx);
    defer holds.deinit();
    const rectified = try typed_om.numberishSlot(instance.ctx, value);
    try holds.keep(rectified, value == .double);
    try internal.set(instance, index, rectified);
}

pub fn get_x(instance: *runtime.Instance) anyerror!typedefs.CSSNumberish {
    return .{ .cssnumeric_value = try slot(instance, 0) };
}
pub fn get_y(instance: *runtime.Instance) anyerror!typedefs.CSSNumberish {
    return .{ .cssnumeric_value = try slot(instance, 1) };
}
pub fn get_z(instance: *runtime.Instance) anyerror!typedefs.CSSNumberish {
    return .{ .cssnumeric_value = try slot(instance, 2) };
}
pub fn set_x(instance: *runtime.Instance, value: typedefs.CSSNumberish) anyerror!void {
    return put(instance, 0, value);
}
pub fn set_y(instance: *runtime.Instance, value: typedefs.CSSNumberish) anyerror!void {
    return put(instance, 1, value);
}
pub fn set_z(instance: *runtime.Instance, value: typedefs.CSSNumberish) anyerror!void {
    return put(instance, 2, value);
}
