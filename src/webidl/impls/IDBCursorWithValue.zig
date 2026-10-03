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
    engine.forgetTracedChild(instance, .{ .name = "idb.cursor.value" });
    interfaces.IDBCursor.deinit(instance);
}
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return readValue(instance);
}
// 4.9 value getter: keep identity until the cursor loads another record. The
// traced edge permits a value that refers back to the cursor to be collected.
fn readValue(instance: *runtime.Instance) !runtime.JSValue {
    const realm = dom.indexeddb.cursorValueRealm(instance);
    if (!instance.ctx.hasEngine() or !realm.hasEngine()) return error.InvalidStateError;
    if (engine.tracedValue(instance, .{ .name = "idb.cursor.value" })) |value| return value.take();
    const cursor = dom.indexeddb.cursorState(instance) orelse return error.InvalidStateError;
    const bytes = cursor.value orelse return .jsUndefined;
    const value = try engine.structuredDeserialize(realm, bytes);
    engine.traceValue(instance, value.value, .{ .name = "idb.cursor.value" });
    return value.take();
}
