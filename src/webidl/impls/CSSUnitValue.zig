//! CSS Typed OM 1 §4.3.3: one numeric value in an existing CSS unit.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = @import("css");

pub const State = interfaces.CSSUnitValue.State;
pub const ImplError = error{TypeError};
pub const construction_args = .{"numeric_value"};
pub const InternalState = struct { number: css.math_values.Numeric };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .number = if (@hasField(@TypeOf(args), "numeric_value")) args.numeric_value else .{ .value = 0, .unit = .number } };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// Constructor steps 1–2: validate the unit, then create its numeric leaf.
pub fn call_constructor(ctx: runtime.Context, value: f64, unit: runtime.USVString) !*runtime.Instance {
    const parsed = css.typed_om.numeric.parseUnit(unit) orelse return error.TypeError;
    return interfaces.CSSUnitValue.initWith(ctx.allocator, ctx, .{ .numeric_value = css.math_values.Numeric{ .value = value, .unit = parsed } });
}

pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.number.value;
}

pub fn get_unit(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, @tagName(internal.number.unit));
}

pub fn set_value(instance: *runtime.Instance, value: f64) anyerror!void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    internal.number.value = value;
}
