//! CSS Typed OM 1 4.4: CSSRotate - rotate(), rotateX/Y/Z() and rotate3d() -
//! with x, y and z (the axis, <number>s) and angle slots.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSRotate.State;
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

/// CSSRotate(angle): 1. If angle doesn't match <angle>, throw a TypeError.
/// 2. x and y new unit values of (0, "number"), z of (1, "number"), is2D
/// true. CSSRotate(x, y, z, angle): 1. the angle check; 2. rectify x, y and
/// z as numberish values; 3. throw a TypeError unless each matches
/// <number>; 4. is2D false.
pub fn call_constructor(ctx: runtime.Context, args: interfaces.CSSRotate.ConstructorArgs) !*runtime.Instance {
    var holds = typed_om.SlotHolds.init(ctx);
    defer holds.deinit();
    switch (args) {
        .CSSNumericValue => |angle| {
            if (!try typed_om.numericMatches(angle, .angle)) return error.TypeError;
            try holds.keep(try typed_om.unitSlot(ctx, 0, "number"), true);
            try holds.keep(try typed_om.unitSlot(ctx, 0, "number"), true);
            try holds.keep(try typed_om.unitSlot(ctx, 1, "number"), true);
            try holds.keep(angle, false);
            return interfaces.CSSRotate.initWith(ctx.allocator, ctx, .{ .transform_is_2d = true, .transform_slots = holds.values() });
        },
        .CSSNumberish_CSSNumberish_CSSNumberish_CSSNumericValue => |a| {
            if (!try typed_om.numericMatches(a.angle, .angle)) return error.TypeError;
            for ([_]typedefs.CSSNumberish{ a.x, a.y, a.z }) |v| try holds.keep(try typed_om.numberishSlot(ctx, v), v == .double);
            try holds.keep(a.angle, false);
            return interfaces.CSSRotate.initWith(ctx.allocator, ctx, .{ .transform_is_2d = false, .transform_slots = holds.values() });
        },
    }
}

fn slot(instance: *runtime.Instance, index: usize) !*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.get(index);
}

/// "The x, y, and z attributes must, on setting to a new value val,
/// rectify a numberish value from val and set the corresponding internal
/// slot to the result of that." A value that is not a <number> throws a
/// TypeError, as the constructor's step 3 and Blink's CSSRotate::setX do.
fn putAxis(instance: *runtime.Instance, index: usize, value: typedefs.CSSNumberish) !void {
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
pub fn get_angle(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return slot(instance, 3);
}
pub fn set_x(instance: *runtime.Instance, value: typedefs.CSSNumberish) anyerror!void {
    return putAxis(instance, 0, value);
}
pub fn set_y(instance: *runtime.Instance, value: typedefs.CSSNumberish) anyerror!void {
    return putAxis(instance, 1, value);
}
pub fn set_z(instance: *runtime.Instance, value: typedefs.CSSNumberish) anyerror!void {
    return putAxis(instance, 2, value);
}
/// The angle setter checks as the constructor does (Blink CSSRotate::
/// setAngle throws a TypeError for a value that is not an <angle>).
pub fn set_angle(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    if (!try typed_om.numericMatches(value, .angle)) return error.TypeError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try internal.set(instance, 3, value);
}
