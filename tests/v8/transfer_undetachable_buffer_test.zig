//! A transfer list holding an ArrayBuffer that cannot be detached - a
//! WebAssembly.Memory's - through the serializer every postMessage uses
//! (structured_serialization.zig, v8_Value_StructuredSerializeWithTransfer).
//!
//! HTML StructuredSerializeWithTransfer step 5.4.3 performs
//! DetachArrayBuffer, which throws a TypeError when the buffer's
//! [[ArrayBufferDetachKey]] is not undefined. V8's ArrayBuffer::Detach on such
//! a buffer is a fatal CHECK ("Only detachable ArrayBuffers can be detached"):
//! MessagePort.postMessage("x", [memory.buffer]) aborted the process. The
//! serializer now refuses it with a TypeError before anything is detached, so
//! a failed transfer leaves every buffer of the list attached.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const allocator = std.testing.allocator;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?*runtime.ContextData = null;

fn setup() !void {
    if (realm_once != null) return;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    ffi.v8_Isolate_SetMicrotasksPolicy(i, @intFromEnum(ffi.MicrotasksPolicy.Explicit));
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    const r = try runtime.Realm.init(std.heap.page_allocator, .{ .engine_realm = context, .agent = @ptrCast(i) });
    const d = try std.heap.page_allocator.create(runtime.ContextData);
    d.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context, .realm = r });
    ffi.v8_Context_Enter(context);
    isolate_once = i;
    context_once = context;
    realm_once = d;

    // `serialize(value, list)`: StructuredSerializeWithTransfer of `value` with
    // `list` as the transfer list, as MessagePort.postMessage runs it from
    // script - a throw is left pending for the script; true on success.
    const template = ffi.v8_FunctionTemplate_New(i, serializeCallback, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    try setGlobal("serialize", @ptrCast(function));
}

fn eval(code: []const u8) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context_once.?, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context_once.?, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn setGlobal(name: []const u8, handle: *anyopaque) !void {
    const global = ffi.v8_Context_Global(context_once.?) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context_once.?, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

fn noPlatformObjects(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

fn serializeCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const realm = realm_once.?;
    const value_handle = info.get(0);
    defer ffi.v8_Global_Dispose(value_handle);
    const list_handle = info.get(1);
    defer ffi.v8_Global_Dispose(list_handle);
    // The transfer list as the binding converts it: sequence<object>.
    const list = v8.webidl_conversions.convertToSequenceOfObjects(realm, .{ .handle = .{ .ptr = @ptrCast(list_handle) } }, allocator) catch return;
    defer {
        for (list) |item| v8.engine.v8ReleaseValue(item);
        allocator.free(list);
    }
    var result = v8.structured_serialization.structuredSerializeWithTransfer(realm, .{ .handle = .{ .ptr = @ptrCast(value_handle) } }, list, noPlatformObjects, null, allocator) catch |err| {
        // ExceptionPending: the TypeError is the script's to see.
        if (err != error.ExceptionPending) {
            const message = ffi.v8_String_NewFromUtf8(info.getIsolate(), "unexpected", 10) orelse return;
            defer ffi.v8_String_Dispose(message);
            const exception = ffi.v8_Exception_Error(message) orelse return;
            defer ffi.v8_Global_Dispose(exception);
            ffi.v8_Isolate_ThrowException(info.getIsolate(), exception);
        }
        return;
    };
    result.deinit(allocator);
    const yes = ffi.v8_Boolean_New(info.getIsolate(), true) orelse return;
    defer ffi.v8_Value_Dispose(@ptrCast(yes));
    info.setReturnValue(@ptrCast(yes));
}

test "a WebAssembly.Memory's buffer in the transfer list is a TypeError, and it stays attached" {
    try setup();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const buffer = new WebAssembly.Memory({ initial: 1 }).buffer;
        \\  try { serialize("x", [buffer]); return -1; }
        \\  catch (e) { return e instanceof TypeError && buffer.byteLength === 65536 ? 1 : 0; }
        \\})()
    ));
}

test "a failed transfer leaves every buffer of the list attached" {
    try setup();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const plain = new ArrayBuffer(8);
        \\  const memory = new WebAssembly.Memory({ initial: 1 }).buffer;
        \\  try { serialize({ plain }, [plain, memory]); return -1; }
        \\  catch (e) { return e instanceof TypeError && plain.byteLength === 8 && memory.byteLength === 65536 ? 1 : 0; }
        \\})()
    ));
}

test "a detachable buffer still transfers" {
    try setup();
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const plain = new ArrayBuffer(8);
        \\  return serialize({ plain }, [plain]) === true && plain.byteLength === 0 ? 1 : 0;
        \\})()
    ));
}
