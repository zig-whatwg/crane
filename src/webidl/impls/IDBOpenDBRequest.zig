//! IndexedDB open request, with IDBRequest state initialized through its interface.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const storage = @import("storage");
pub const State = interfaces.IDBOpenDBRequest.State;
pub const ImplError = error{InvalidStateError};
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    open_request: ?*storage.indexeddb.IDBOpenDBRequest = null,
};
pub fn installHooks() void {
    dom.indexeddb.installOpenRequests(.{ .attach = attachRequest });
}
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
        if (internal.open_request) |request| {
            if (request.base.result) |result| switch (result) {
                .database => |db| {
                    db.deinit();
                    internal.allocator.destroy(db);
                },
                else => {},
            };
            request.deinit();
            internal.allocator.destroy(request);
        }
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.IDBRequest.deinit(instance);
}
fn attachRequest(instance: *runtime.Instance, request: *storage.indexeddb.IDBOpenDBRequest) void {
    const internal = instance.getState(State).own._internal.?;
    std.debug.assert(internal.open_request == null);
    internal.open_request = request;
}
pub fn get_onblocked(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "blocked");
}
pub fn get_onupgradeneeded(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "upgradeneeded");
}
pub fn set_onblocked(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "blocked", value);
}
pub fn set_onupgradeneeded(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "upgradeneeded", value);
}
