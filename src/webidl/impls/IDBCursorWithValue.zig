//! IndexedDB value cursor: parent owns cursor state and native storage.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
pub const State = interfaces.IDBCursorWithValue.State;
pub const ImplError = error{InvalidStateError};
pub const InternalState = struct {};
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    return interfaces.IDBCursor.initWithState(allocator, StateType, vtable, ctx);
}
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.IDBCursor.deinit(instance);
}
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return readValue(instance);
}
// Q12 accepted interim: rebuild on every read until REALMS3 ON MAIN. No
// strong result root: a script value can contain a cycle back to its cursor.
fn readValue(instance: *runtime.Instance) !runtime.JSValue {
    const cursor = dom.indexeddb.cursorState(instance) orelse return error.InvalidStateError;
    const bytes = cursor.value orelse return .jsUndefined;
    return (try engine.structuredDeserialize(instance.ctx, bytes)).take();
}
