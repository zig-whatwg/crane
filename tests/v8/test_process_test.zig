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

test "a test's agent takes its realms down with it, their context handles too" {
    var test_agent: test_process.TestAgent = .{};
    var key: usize = 0;
    // Every Global<Context> v8_wrapper.cpp has made and not disposed, in
    // the process: the realm's entry holds one of its own
    // (context_manager.getOrCreateWithIsolate), which the agent's end must
    // dispose with the entry.
    const context_globals = ffi.v8_Debug_LiveContextGlobals();
    {
        defer test_agent.close();
        _ = try test_agent.open(.{});
        const context = test_agent.context.?;
        const realm = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        key = v8.context_manager.keyOf(context).?;
        try std.testing.expectEqual(@as(?runtime.Context, realm), v8.context_manager.getByKey(key));
    }
    // The realm was its agent's (context_manager.Realms, on the agent's
    // record): the agent's end took it down.
    try std.testing.expectEqual(@as(?runtime.Context, null), v8.context_manager.getByKey(key));
    try std.testing.expectEqual(context_globals, ffi.v8_Debug_LiveContextGlobals());
}

test "a test's agent is not made while an earlier test left an isolate entered" {
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
    // --harmony-shadow-realm (RUNTIME_V8_FLAGS) and Float16Array (shipped in V8 13.5).
    const code = "(typeof ShadowRealm === 'function' ? 1 : 0) + (typeof Float16Array === 'function' ? 2 : 0)";
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    try std.testing.expectEqual(@as(i32, 3), ffi.v8_Value_Int32Value(value, context));
}

// ---------------------------------------------------------------------------
// The engine is started and ended only by test_process.zig (lane testfix3):
// 86 helpers called engine.initializeEngine themselves, so each test wrote the
// process's engine state again - its dispatchers and its snapshot - while the
// many-Browsers variant's busy Browser read it (lanes tsanfix1, crashes7:
// ThreadSanitizer races in protocol_agents.initializeEngine). A helper starts
// the process with test_process.start() and a snapshot with startSnapshot.
// ---------------------------------------------------------------------------

/// The tests/v8 files whose subject IS the engine's start or end, with how
/// many of their lines call initializeEngine or deinitializeEngine and why.
/// Exact: a call added or removed fails the check until this list says so.
const engine_start_subjects = [_]struct { file: []const u8, lines: usize, reason: []const u8 }{
    .{ .file = "platform_start_once_test.zig", .lines = 6, .reason = "V8's platform starts once with the runtime's flags, whichever of two racing threads calls initializeEngine first, and survives deinitializeEngine" },
    .{ .file = "page_realm_operations_test.zig", .lines = 5, .reason = "\"protocol: initializeEngine starts V8 once, and refuses a snapshot this build did not make\": initializeEngine's own refusals" },
};

/// The lines of `source` that call initializeEngine or deinitializeEngine,
/// by any alias of the engine (`engine.`, `protocol.`), outside comments.
fn engineStartLines(source: []const u8) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const code = if (std.mem.indexOf(u8, line, "//")) |i| line[0..i] else line;
        // The end's name contains the start's: either counts. Spelled in two
        // pieces, so that this file, which the check reads too, holds no call.
        if (std.mem.indexOf(u8, code, "initialize" ++ "Engine(") != null) count += 1;
    }
    return count;
}

test "the engine-start check counts calls by any alias and both ends, never a comment" {
    // Spelled in two pieces, so that this file - which the check reads too -
    // holds no call of its own.
    const start_call = "initialize" ++ "Engine(";
    try std.testing.expectEqual(@as(usize, 0), engineStartLines("    // try engine." ++ start_call ++ ".{});\n    test_process.start();\n"));
    try std.testing.expectEqual(@as(usize, 1), engineStartLines("    try protocol." ++ start_call ++ ".{});\n"));
    try std.testing.expectEqual(@as(usize, 1), engineStartLines("    defer engine.de" ++ start_call ++ "); // the end\n"));
    try std.testing.expectEqual(@as(usize, 2), engineStartLines("try engine." ++ start_call ++ ".{ .snapshot = bytes });\nengine.de" ++ start_call ++ ");\n"));
}

test "no tests/v8 file starts or ends the engine itself: test_process.zig does, and the files whose subject is the start" {
    const io = std.testing.io;
    var dir = try std.Io.Dir.cwd().openDir(io, "tests/v8", .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    var files: usize = 0;
    var wrong: usize = 0;
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (std.mem.eql(u8, entry.name, "test_process.zig")) continue;
        files += 1;
        const source = try dir.readFileAlloc(io, entry.name, std.testing.allocator, .limited(16 << 20));
        defer std.testing.allocator.free(source);
        const found = engineStartLines(source);
        const declared = for (engine_start_subjects) |subject| {
            if (std.mem.eql(u8, subject.file, entry.name)) break subject.lines;
        } else 0;
        if (found != declared) {
            wrong += 1;
            std.debug.print("tests/v8/{s}: {d} line(s) call initializeEngine/deinitializeEngine, {d} declared - start the process with test_process.start(), a snapshot with test_process.startSnapshot(bytes) and its end with endSnapshot(); a file whose subject is the engine's start is declared in engine_start_subjects with its reason\n", .{ entry.name, found, declared });
        }
    }
    // The directory is there: over a hundred test files.
    try std.testing.expect(files > 100);
    try std.testing.expectEqual(@as(usize, 0), wrong);
}
