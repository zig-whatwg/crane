//! test_process.zig's promises, which every tests/v8 test relies on to run in
//! any order (lane v8order1): the process starts once and stays started, a
//! test's own standalone runtime gives the process's back, a test's agent is
//! current only while its test runs and takes its realms down with it, and
//! V8 runs with the runtime's flags whichever test started it.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
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

var reset_calls: usize = 0;
fn countReset() void {
    reset_calls += 1;
}

test "a test's agent is the current isolate while its test runs, and nothing is current after it ends" {
    try std.testing.expectEqual(@as(?*ffi.Isolate, null), ffi.v8_Isolate_GetCurrent());
    var test_agent: test_process.TestAgent = .{};
    {
        defer test_agent.close();
        const isolate = try test_agent.open(.{});
        try std.testing.expectEqual(@as(?*ffi.Isolate, isolate), ffi.v8_Isolate_GetCurrent());
        // Opening it again in the same test is the same agent, and adds no
        // entry to undo.
        try std.testing.expectEqual(isolate, try test_agent.open(.{}));
        try std.testing.expectEqual(@as(u32, 1), test_agent.entries);
        try std.testing.expect(test_agent.context != null);
    }
    try std.testing.expectEqual(@as(?*ffi.Isolate, null), ffi.v8_Isolate_GetCurrent());
    try std.testing.expectEqual(@as(?*ffi.Isolate, null), test_agent.isolate);
}

test "a test's agent takes its realms down with it: the thread's context manager keeps none of them" {
    var test_agent: test_process.TestAgent = .{};
    var key: usize = 0;
    {
        defer test_agent.close();
        _ = try test_agent.open(.{});
        const context = test_agent.context.?;
        v8.context_manager.init(std.heap.page_allocator) catch {};
        const realm = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        key = v8.context_manager.keyOf(context).?;
        try std.testing.expectEqual(@as(?runtime.Context, realm), v8.context_manager.getByKey(key));
    }
    // The agent was its thread's host agent: its end took the thread's
    // context manager down, and the realm with it.
    try std.testing.expectEqual(@as(?runtime.Context, null), v8.context_manager.getByKey(key));
}

test "a test's agent is its thread's host agent: with an isolate left entered it is not made" {
    test_process.start();
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    defer ffi.v8_Isolate_Dispose(isolate);
    var test_agent: test_process.TestAgent = .{};
    {
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        try std.testing.expectError(error.IsolateLeftEntered, test_agent.open(.{}));
    }
    test_agent.close();
}

test "a test's agent ends its Window realms before itself, then runs the file's reset" {
    reset_calls = 0;
    var test_agent: test_process.TestAgent = .{ .reset = countReset };
    {
        defer test_agent.close();
        _ = try test_agent.open(.{ .context = false });
        _ = try test_agent.windowRealm(&.{
            .agent = test_agent.agent(),
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        try std.testing.expectEqual(@as(usize, 1), test_agent.end_count);
        try std.testing.expectEqual(@as(usize, 0), reset_calls);
    }
    try std.testing.expectEqual(@as(usize, 1), reset_calls);
    // The reset is kept for the file's next test.
    try std.testing.expect(test_agent.reset != null);
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

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
