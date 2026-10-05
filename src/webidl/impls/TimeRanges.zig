//! HTML 4.8.11.14: snapshots of empty ranges for resources with no decoded data.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
pub const State = interfaces.TimeRanges.State;
pub const InternalState = struct {};
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    instance.getState(State).own.length = 0;
    instance.getState(State).own._internal = null;
    return instance;
}
pub fn deinit(_: *runtime.Instance) void {}
pub fn get_length(_: *runtime.Instance) anyerror!u32 {
    return 0;
}
pub fn call_start(_: *runtime.Instance, _: u32) anyerror!f64 {
    // start(index), step 1: every index is >= the empty range list's size.
    return error.IndexSizeError;
}
pub fn call_end(_: *runtime.Instance, _: u32) anyerror!f64 {
    // end(index), step 1.
    return error.IndexSizeError;
}
