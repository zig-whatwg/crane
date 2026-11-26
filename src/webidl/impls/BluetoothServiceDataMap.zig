//! Web Bluetooth: `interface BluetoothServiceDataMap { readonly maplike<UUID, DataView>; }`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.BluetoothServiceDataMap.State;

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    entries: webidl.maplike.View([]const u8, *anyopaque),
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .entries = .initEmpty() };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.allocator.destroy(internal);
}

pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.View([]const u8, *anyopaque) {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.entries;
}
