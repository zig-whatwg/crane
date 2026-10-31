//! Own accessor attributes use the same flags as instance-template accessors.
const std = @import("std");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");

fn getter(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    ffi.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnValueInt32(info, 7);
}

fn checkAttributes() !void {
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.NoScope;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    inline for (.{ .{ "ordinary", @as(c_int, 0) }, .{ "fixed", @as(c_int, 4) } }) |entry| {
        const name = ffi.v8_String_NewFromUtf8(isolate, entry[0].ptr, entry[0].len) orelse return error.NoString;
        defer ffi.v8_String_Dispose(name);
        const ok = if (comptime @typeInfo(@TypeOf(ffi.v8_Object_SetAccessorPropertyChecked)).@"fn".param_types.len == 8)
            ffi.v8_Object_SetAccessorPropertyChecked(global, context, name, getter, null, true, true, entry[1])
        else
            ffi.v8_Object_SetAccessorPropertyChecked(global, context, name, getter, null, true, true);
        try std.testing.expect(ok);
    }
    const source =
        \\(() => {
        \\  const a = Object.getOwnPropertyDescriptor(globalThis, 'ordinary');
        \\  const b = Object.getOwnPropertyDescriptor(globalThis, 'fixed');
        \\  return a.configurable && !b.configurable && a.enumerable && b.enumerable &&
        \\    a.set === undefined && b.set === undefined && ordinary === 7 && fixed === 7 &&
        \\    Reflect.deleteProperty(globalThis, 'ordinary') && !Reflect.deleteProperty(globalThis, 'fixed');
        \\})()
    ;
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, source.len) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.NoValue;
    defer ffi.v8_Value_Dispose(value);
    try std.testing.expect(try v8.conversions.fromV8Value(bool, std.testing.allocator, isolate, context, value));
}

test "own accessor None is configurable and DontDelete is unforgeable" {
    const Runner = struct {
        fn run(result: *anyerror!void) void {
            result.* = checkAttributes();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Runner.run, .{&result});
    thread.join();
    try result;
}
