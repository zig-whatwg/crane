//! IndexedDB open request, with IDBRequest state initialized through its interface.
//!
//! Its open or delete operation lives in its factory's ConnectionTask and in
//! the Browser's IndexedDB server (src/storage/indexeddb/server.zig): the
//! request itself keeps no native state beyond its IDBRequest's.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
pub const State = interfaces.IDBOpenDBRequest.State;
pub const ImplError = error{InvalidStateError};
pub const InternalState = struct {
    allocator: std.mem.Allocator,
};
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.IDBRequest.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const state = instance.getState(State);
    state.own._internal = null;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.IDBRequest.deinit(instance);
}
