//! The running script's muted-errors flag follows its functions, not its caller.
const std = @import("std");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");

fn readMuted(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const muted = if (comptime @hasDecl(ffi, "v8_Isolate_CurrentScriptHasMutedErrors"))
        ffi.v8_Isolate_CurrentScriptHasMutedErrors(info.getIsolate())
    else
        false;
    ffi.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnValueBool(info, muted);
}

fn run(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8, muted: bool) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const compiled = if (comptime @typeInfo(@TypeOf(ffi.v8_Script_CompileWithHostDefined_Safe)).@"fn".param_types.len == 7)
        ffi.v8_Script_CompileWithHostDefined_Safe(context, text, null, 0, 0, null, muted)
    else
        ffi.v8_Script_CompileWithHostDefined_Safe(context, text, null, 0, 0, null);
    defer ffi.v8_FreeScriptCompileResult(compiled);
    const script = compiled.script orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.NoValue;
}

fn check() !void {
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
    const key = ffi.v8_String_NewFromUtf8(isolate, "readMuted", 9) orelse return error.NoString;
    defer ffi.v8_String_Dispose(key);
    const function = ffi.v8_Function_NewWithData(context, readMuted, null, 0) orelse return error.NoFunction;
    defer ffi.v8_Value_Dispose(function);
    try std.testing.expect(ffi.v8_Object_Set(global, context, @ptrCast(key), function));
    const unmuted = try run(isolate, context, "globalThis.unmuted = () => readMuted()", false);
    ffi.v8_Value_Dispose(unmuted);
    const muted = try run(isolate, context,
        \\globalThis.creationMuted = readMuted();
        \\globalThis.muted = () => [readMuted(), unmuted(), readMuted()].join(',');
    , true);
    ffi.v8_Value_Dispose(muted);
    const result = try run(isolate, context, "creationMuted && muted() === 'true,false,true' && !readMuted()", false);
    defer ffi.v8_Value_Dispose(result);
    try std.testing.expect(try v8.conversions.fromV8Value(bool, std.testing.allocator, isolate, context, result));
}

test "muted script metadata survives evaluation and nested unmuted calls" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}
