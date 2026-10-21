//! A nullable callback is strict unless its attribute explicitly opts in.
const std = @import("std");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const Callback = ?*const fn () void;

fn checkStrict() !void {
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

    for ([_][]const u8{ "({})", "[]", "42", "'text'" }) |source| {
        const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
        defer ffi.v8_String_Dispose(text);
        const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
        defer ffi.v8_Script_Dispose(script);
        const value = ffi.v8_Script_Run(context, script) orelse return error.NoValue;
        defer ffi.v8_Value_Dispose(value);
        try std.testing.expectError(error.TypeError, v8.conversions.fromV8Value(Callback, std.testing.allocator, isolate, context, value));
    }
    const null_value = ffi.v8_Null(isolate) orelse return error.NoValue;
    defer ffi.v8_Value_Dispose(null_value);
    try std.testing.expectEqual(@as(Callback, null), try v8.conversions.fromV8Value(Callback, std.testing.allocator, isolate, context, null_value));
}

test "nullable callback conversion defaults to strict" {
    const Runner = struct {
        fn run(result: *anyerror!void) void {
            result.* = checkStrict();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Runner.run, .{&result});
    thread.join();
    try result;
}
