//! CSS Typed OM 1 §4.3: immutable unit types and numeric operations.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSNumericValue.State;
pub const ImplError = error{ TypeError, SyntaxError, RangeError };
pub const InternalState = struct { typ: css.math_values.Type };
pub const construction_args = .{"numeric_type"};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const typ = if (@hasField(@TypeOf(args), "numeric_type")) args.numeric_type else if (@hasField(@TypeOf(args), "numeric_value")) css.math_values.Type.one(args.numeric_value.unit.base()) else css.math_values.Type{};
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .typ = typ };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

pub fn call_type(instance: *runtime.Instance) anyerror!dictionaries.CSSNumericType {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return dom.style.typed_om.numericDictionary(internal.typ);
}

pub fn call_equals(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!bool {
    return dom.style.typed_om.numericEquals(instance, values);
}
pub fn call_add(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!*runtime.Instance {
    return dom.style.typed_om.arithmetic(instance, .sum, values, false);
}
pub fn call_sub(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!*runtime.Instance {
    return dom.style.typed_om.arithmetic(instance, .sum, values, true);
}
pub fn call_mul(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!*runtime.Instance {
    return dom.style.typed_om.arithmetic(instance, .product, values, false);
}
pub fn call_div(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!*runtime.Instance {
    return dom.style.typed_om.arithmetic(instance, .product, values, true);
}
pub fn call_min(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!*runtime.Instance {
    return dom.style.typed_om.arithmetic(instance, .min, values, false);
}
pub fn call_max(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) anyerror!*runtime.Instance {
    return dom.style.typed_om.arithmetic(instance, .max, values, false);
}
pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyerror!*runtime.Instance {
    return dom.style.typed_om.numericTo(instance, unit);
}
pub fn call_toSum(instance: *runtime.Instance, units: []const runtime.USVString) anyerror!*runtime.Instance {
    return dom.style.typed_om.numericToSum(instance, units);
}
pub fn call_static_parse(instance: *runtime.Instance, text: runtime.USVString) anyerror!*runtime.Instance {
    return dom.style.typed_om.parseNumeric(instance.ctx, text);
}
