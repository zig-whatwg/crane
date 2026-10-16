//! Exercise Opt inside a dictionary through the actual argument converter and
//! its cleanup. A fresh thread neither inherits nor leaves an entered isolate.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;

const Dictionary = struct {
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),
};

fn check() !void {
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    for ([_][]const u8{ "({})", "({namespace: undefined})", "({namespace: null})", "({namespace: 'x'})" }, 0..) |source, index| {
        const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.StringFailed;
        defer ffi.v8_String_Dispose(text);
        const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
        defer ffi.v8_Script_Dispose(script);
        const object = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
        defer ffi.v8_Value_Dispose(object);
        // Warm conversion caches before measuring the 64 repeated conversions.
        const warm = try v8.conversions.fromV8Value(Dictionary, std.testing.allocator, isolate, context, object);
        v8.interface_mod.freeConvertedArg(Dictionary, std.testing.allocator, warm);
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        for (0..64) |_| {
            const value = try v8.conversions.fromV8Value(Dictionary, std.testing.allocator, isolate, context, object);
            defer v8.interface_mod.freeConvertedArg(Dictionary, std.testing.allocator, value);
            try std.testing.expectEqual(index >= 2, value.namespace.was_passed);
            if (index == 2) try std.testing.expect(value.namespace.value == null);
            if (index == 3) try std.testing.expectEqualStrings("x", value.namespace.value.?.asSlice());
        }
        try std.testing.expectEqual(before, ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    }
}

test "nullable dictionary presence converts absent undefined null and string without leaking" {
    const Thread = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Thread.run, .{&result});
    thread.join();
    try result;
}
