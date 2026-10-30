//! CSS Typed OM 1 §4.3.4: immutable, traced numeric operands.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");

pub const State = interfaces.CSSMathMax.State;
pub const ImplError = error{ TypeError, SyntaxError, RangeError };
pub const InternalState = dom.style.typed_om.NumericLinks;
pub const construction_args = .{"numeric_operands"};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const values: []const *runtime.Instance = if (@hasField(@TypeOf(args), "numeric_operands")) args.numeric_operands else &.{};
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = try dom.style.typed_om.numericLinks(instance, values);
    instance.getState(State).own._internal = internal;
    dom.style.typed_om.traceNumericLinks(instance, values);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    dom.style.typed_om.dropNumericLinks(instance, internal.*);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

pub fn call_constructor(ctx: runtime.Context, args: []const typedefs.CSSNumberish) !*runtime.Instance {
    return dom.style.typed_om.constructMath(ctx, .max, args);
}

pub fn get_values(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return dom.style.typed_om.numericLink(internal.*, 0);
}
