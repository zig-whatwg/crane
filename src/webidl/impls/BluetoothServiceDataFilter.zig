//! Web Bluetooth Scanning: `interface BluetoothServiceDataFilter { readonly maplike<UUID, BluetoothDataFilter>; }`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.BluetoothServiceDataFilter.State;

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    entries: webidl.maplike.PlatformObjects,
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

pub fn call_constructor(instance: *runtime.Instance, init_data: webidl.Opt(runtime.JSValue)) !void {
    _ = instance;
    _ = init_data;
}

pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.PlatformObjects {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.entries;
}
