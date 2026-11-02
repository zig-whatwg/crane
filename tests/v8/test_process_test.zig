//! test_process.zig's promises, which every tests/v8 test relies on to run in
//! any order (lane v8order1): the process starts once and stays started, a
//! test's own standalone runtime gives the process's back, a file's isolate
//! is current only while its test runs, and V8 runs with the runtime's flags
//! whichever test started it.

const std = @import("std");
const runtime = @import("runtime");
const ffi = @import("v8").ffi;
const test_process = @import("test_process.zig");

test "start leaves the process started with a standalone runtime, and a second start changes nothing" {
    test_process.start();
    const scope = runtime.BrowserScope.standalone() orelse return error.NoStandaloneRuntime;
    test_process.start();
    try std.testing.expectEqual(scope, runtime.BrowserScope.standalone().?);
}

test "a test's own standalone runtime ends with the test and gives the process's back" {
    test_process.start();
    const process_scope = runtime.BrowserScope.standalone().?;
    {
        const own = test_process.OwnRuntime.begin(std.testing.allocator);
        defer own.end();
        const scope = runtime.BrowserScope.standalone().?;
        try std.testing.expect(scope != process_scope);
        // start finds a runtime running - the test's own - and keeps it.
        test_process.start();
        try std.testing.expectEqual(scope, runtime.BrowserScope.standalone().?);
    }
    try std.testing.expectEqual(process_scope, runtime.BrowserScope.standalone().?);
}

test "a file's isolate is the current one only until its test leaves it" {
    test_process.start();
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    defer ffi.v8_Isolate_Dispose(isolate);
    const before = ffi.v8_Isolate_GetCurrent();
    var file: test_process.FileIsolate = .{ .isolate = isolate };
    {
        defer file.leave();
        file.enter();
        try std.testing.expectEqual(@as(?*ffi.Isolate, isolate), ffi.v8_Isolate_GetCurrent());
        // Entering it again while it is current adds no entry to undo.
        file.enter();
        try std.testing.expectEqual(@as(u32, 1), file.entries);
    }
    try std.testing.expectEqual(before, ffi.v8_Isolate_GetCurrent());
    try std.testing.expectEqual(@as(u32, 0), file.entries);
}

test "V8 runs with the runtime's flags, whichever test started it" {
    // A bare v8_Isolate_New starts V8's platform without them when nothing
    // has started it; start() runs first in every test that makes an isolate.
    test_process.start();
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.NoHandleScope;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    // --harmony-shadow-realm and --js-float16array (RUNTIME_V8_FLAGS).
    const code = "(typeof ShadowRealm === 'function' ? 1 : 0) + (typeof Float16Array === 'function' ? 2 : 0)";
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    try std.testing.expectEqual(@as(i32, 3), ffi.v8_Value_Int32Value(value, context));
}
