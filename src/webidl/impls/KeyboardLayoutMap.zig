//! Keyboard Map: `interface KeyboardLayoutMap { readonly maplike<DOMString, DOMString>; }`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.KeyboardLayoutMap.State;

pub const InternalState = struct {
    entries: webidl.maplike.MapEntries([]const u8, []const u8),
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .entries = .init(allocator) };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    const allocator = internal.entries.allocator;
    internal.entries.deinit();
    allocator.destroy(internal);
}

pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.MapEntries([]const u8, []const u8) {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.entries;
}
