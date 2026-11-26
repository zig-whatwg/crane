//! WebGPU: `interface WGSLLanguageFeatures { readonly setlike<DOMString>; }`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.WGSLLanguageFeatures.State;

pub const InternalState = struct {
    values: webidl.setlike.Strings,
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .values = .init(allocator) };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    const allocator = internal.values.allocator;
    internal.values.deinit();
    allocator.destroy(internal);
}

pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.Strings {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.values;
}
