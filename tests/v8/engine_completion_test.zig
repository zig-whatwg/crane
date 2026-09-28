//! engine.completionOf - ECMAScript Completion(...), as V8 implements it: run
//! the steps; if they leave an exception pending, hand the thrown value back
//! OWNED with nothing pending; null on a normal completion.
//!
//! What the Streams size algorithm needs (WritableStreamDefaultController
//! GetChunkSize step 3): converting the size callback's result can throw, and
//! the spec wants that as an abrupt completion to error the stream with - not
//! an exception left pending for whatever script runs next.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var data_once: ?*runtime.ContextData = null;

fn realm() !runtime.Context {
    if (data_once) |d| return d;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    ffi.v8_Isolate_SetMicrotasksPolicy(i, @intFromEnum(ffi.MicrotasksPolicy.Explicit));
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(i);
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
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

/// Steps that convert `data` (a JSValue) to a DOMString: ToString, which runs
/// a toString the value may have - and what that throws is left pending.
fn convertSteps(data: ?*anyopaque) protocol.Error!void {
    const value: *const runtime.JSValue = @ptrCast(@alignCast(data.?));
    const text = try protocol.convertToDOMString(data_once.?, value.*, std.testing.allocator);
    std.testing.allocator.free(text);
}

fn returnsError(comptime err: protocol.Error) fn (?*anyopaque) protocol.Error!void {
    return struct {
        fn steps(_: ?*anyopaque) protocol.Error!void {
            return err;
        }
    }.steps;
}

test "a normal completion is null" {
    const ctx = try realm();
    var value: runtime.JSValue = .{ .number = 5 };
    try std.testing.expectEqual(@as(?protocol.Owned, null), try protocol.completionOf(ctx, convertSteps, &value));
}

test "a throw completion hands back the thrown value itself, owned" {
    const ctx = try realm();
    const boom = try eval("globalThis.boom = new Error('toString'); ({ toString() { throw boom; } })");
    defer ffi.v8_Value_Dispose(boom);
    var value: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(boom), .needs_disposal = false } };
    const thrown = (try protocol.completionOf(ctx, convertSteps, &value)) orelse return error.NoCompletion;
    defer thrown.release();
    try setGlobal("caught", thrown.value.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.caught === globalThis.boom ? 1 : 0"));
}

/// A native that runs a throwing conversion under completionOf and returns
/// normally: if anything were left pending, the calling script would see it.
fn completesNormally(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const argument = info.get(0);
    defer ffi.v8_Global_Dispose(argument);
    var value: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(argument), .needs_disposal = false } };
    const thrown = protocol.completionOf(data_once.?, convertSteps, &value) catch return;
    const was_thrown = thrown != null;
    if (thrown) |t| t.release();
    const result = ffi.v8_Number_New(info.getIsolate(), if (was_thrown) 1 else 0);
    defer ffi.v8_Value_Dispose(@ptrCast(result));
    info.setReturnValue(@ptrCast(result));
}

test "nothing is left pending for the calling script" {
    _ = try realm();
    const template = ffi.v8_FunctionTemplate_New(isolate_once.?, completesNormally, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, context_once.?) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    try setGlobal("completes", @ptrCast(function));
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  try { return completes({ toString() { throw new Error("x"); } }); }
        \\  catch (e) { return -1; }
        \\})()
    ));
}

test "a TypeError the steps return is a new TypeError of the realm" {
    const ctx = try realm();
    const thrown = (try protocol.completionOf(ctx, returnsError(error.TypeError), null)) orelse return error.NoCompletion;
    defer thrown.release();
    try setGlobal("typeError", thrown.value.handle.ptr);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.typeError instanceof TypeError ? 1 : 0"));
}

test "an engine failure is not a completion: it propagates" {
    const ctx = try realm();
    try std.testing.expectError(error.OutOfMemory, protocol.completionOf(ctx, returnsError(error.OutOfMemory), null));
    try std.testing.expectError(error.NotSupported, protocol.completionOf(ctx, returnsError(error.NotSupported), null));
}
