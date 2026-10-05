//! HTML 4.8.11.1: a media error's code and optional diagnostic message.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const hooks = @import("dom").media_elements;
pub const State = interfaces.MediaError.State;
pub const InternalState = struct {};

pub fn installHooks() void {
    hooks.installMediaError(create);
}
fn create(ctx: runtime.Context, code: hooks.ErrorCode) !*runtime.Instance {
    // "Create a MediaError": create in the relevant realm, set code/message.
    const instance = try interfaces.MediaError.init(ctx.allocator, ctx);
    instance.getState(State).own.code = @intFromEnum(code);
    return instance;
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    const state = instance.getState(State);
    state.own.code = 1;
    state.own.message = .initEmpty();
    state.own._internal = null;
    return instance;
}
pub fn deinit(_: *runtime.Instance) void {}
pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
    return instance.getState(State).own.code;
}
pub fn get_message(_: *runtime.Instance) anyerror!runtime.DOMString {
    // No details beyond the code: the spec requires the empty string.
    return .initEmpty();
}
