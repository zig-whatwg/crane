//! CSS Typed OM 1 §4.2: an identifier string, validated only for emptiness.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

pub const State = interfaces.CSSKeywordValue.State;
pub const ImplError = error{TypeError};
pub const construction_args = .{"keyword_value"};
pub const InternalState = struct { value: []u8 };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const value = if (@hasField(@TypeOf(args), "keyword_value")) args.keyword_value else "";
    const copy = try allocator.dupe(u8, value);
    errdefer allocator.free(copy);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .value = copy };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    instance.ctx.allocator.free(internal.value);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// Constructor steps 1–2: reject the empty string, then copy its value.
pub fn call_constructor(ctx: runtime.Context, value: runtime.USVString) !*runtime.Instance {
    if (value.len == 0) return error.TypeError;
    return interfaces.CSSKeywordValue.initWith(ctx.allocator, ctx, .{ .keyword_value = value });
}

pub fn get_value(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, internal.value);
}

/// Setter steps 1–2: validate before replacing the existing string.
pub fn set_value(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    if (value.len == 0) return error.TypeError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const copy = try instance.ctx.allocator.dupe(u8, value);
    instance.ctx.allocator.free(internal.value);
    internal.value = copy;
}
