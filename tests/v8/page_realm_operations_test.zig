//! The Engine table's page-realm operations, as V8 implements them
//! (src/runtime/engines/v8/page_realm.zig): invokeCallbackFunction and
//! installWindowOperations.
//!
//! The realm is registered with the context manager, as every Window realm
//! is: the window's natives find the realm they were called in through it.
//! The isolate keeps V8's default microtask policy (kAuto), which is the
//! browser's - the order of a report against the microtask checkpoint
//! depends on it.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;

/// One isolate, context and realm for the whole file; V8 is never torn down
/// here (see engine_realm_operations_test.zig).
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    // Already initialized is fine: the manager is per thread, not per test.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

/// Script's value of `expression`, as an integer.
fn scriptInt(expression: []const u8) !i32 {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

/// Script's value of `expression`, as a handle the caller disposes.
fn scriptValue(expression: []const u8) !*ffi.Value {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// `value` as the binding hands an object to an impl: conversions.fromV8Value
/// tags it `.local` - borrowed for the call - over the same Global.
fn borrowed(value: *ffi.Value) runtime.JSValue {
    return v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, isolate_once.?, context_once.?, value) catch unreachable;
}

const Reports = struct {
    count: usize = 0,
    message: [256]u8 = undefined,
    message_len: usize = 0,
    had_value: bool = false,
    /// Script to run from inside the report, to observe its ordering.
    run_inside: ?[]const u8 = null,

    fn report(host: ?*anyopaque, info: *const runtime.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.message_len = @min(info.message.len, self.message.len);
        @memcpy(self.message[0..self.message_len], info.message[0..self.message_len]);
        self.had_value = info.error_value != null;
        if (self.run_inside) |source| {
            var ignored: Reports = .{};
            engine.runClassicScript.?(realm_once.?, source, null, Reports.report, &ignored) catch {};
        }
    }

    fn messageText(self: *const Reports) []const u8 {
        return self.message[0..self.message_len];
    }
};

fn run(source: []const u8) !Reports {
    var reports: Reports = .{};
    try engine.runClassicScript.?(try realm(), source, null, Reports.report, &reports);
    return reports;
}

// ============================================================================
// invokeCallbackFunction
// ============================================================================

test "a callback is invoked with its arguments and the realm's global as this" {
    const ctx = try realm();
    _ = try run("globalThis.cb = function (a, b) { globalThis.sum = a + b; globalThis.thisIsGlobal = this === globalThis ? 1 : 0; };");
    const cb = try scriptValue("globalThis.cb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .global_this, &.{ .{ .number = 2 }, .{ .number = 3 } }, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 5), try scriptInt("globalThis.sum"));
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("globalThis.thisIsGlobal"));
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

test "a callback's this is undefined, or the value given" {
    const ctx = try realm();
    _ = try run("globalThis.strictCb = function () { 'use strict'; globalThis.seenThis = this === undefined ? -1 : this; };");
    const cb = try scriptValue("globalThis.strictCb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, -1), try scriptInt("globalThis.seenThis"));
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .{ .value = .{ .number = 7 } }, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 7), try scriptInt("globalThis.seenThis"));
}

test "more arguments than fit inline all arrive" {
    const ctx = try realm();
    _ = try run("globalThis.manyCb = function () { globalThis.argCount = arguments.length; globalThis.last = arguments[arguments.length - 1]; };");
    const cb = try scriptValue("globalThis.manyCb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    const args = [_]runtime.JSValue{ .{ .number = 1 }, .{ .number = 2 }, .{ .number = 3 }, .{ .number = 4 }, .{ .number = 5 }, .{ .number = 6 } };
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .undefined, &args, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 6), try scriptInt("globalThis.argCount"));
    try std.testing.expectEqual(@as(i32, 6), try scriptInt("globalThis.last"));
}

test "what a callback throws is reported, after the microtasks it queued" {
    const ctx = try realm();
    _ = try run("globalThis.order = ''; globalThis.thrower = function () { Promise.resolve().then(() => { globalThis.order += 'm'; }); throw new RangeError('nope'); };");
    const cb = try scriptValue("globalThis.thrower");
    defer ffi.v8_Value_Dispose(cb);

    // WebIDL: "clean up after running script" (the checkpoint) precedes the
    // report, so the report sees the microtask's effect.
    var reports: Reports = .{ .run_inside = "globalThis.order += 'r';" };
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "nope") != null);
    try std.testing.expect(reports.had_value);
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("globalThis.order === 'mr' ? 1 : 0"));
}

test "a callback that is not callable is not called" {
    const ctx = try realm();
    const object = try scriptValue("({})");
    defer ffi.v8_Value_Dispose(object);

    var reports: Reports = .{};
    try engine.invokeCallbackFunction.?(ctx, borrowed(object), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // A value that is no engine handle at all is a caller's mistake.
    try std.testing.expectError(error.TypeError, engine.invokeCallbackFunction.?(ctx, .{ .number = 1 }, .undefined, &.{}, Reports.report, &reports));
}

// ============================================================================
// installWindowOperations
// ============================================================================

/// What the host's steps were called with, as test WindowOperations record it.
const Seen = struct {
    realm: ?runtime.Context = null,
    timers: usize = 0,
    function_handlers: usize = 0,
    string_source: [64]u8 = undefined,
    string_len: usize = 0,
    timeout: i32 = 0,
    argument_count: usize = 0,
    repeat: bool = false,
    cleared: ?i32 = null,
    frames: usize = 0,
    cancelled: ?u32 = null,

    fn stringSource(self: *const Seen) []const u8 {
        return self.string_source[0..self.string_len];
    }
};

var seen: Seen = .{};

fn testInitializeTimer(r: runtime.Context, handler: runtime.WindowTimerHandler, timeout: i32, arguments: []const runtime.JSValue, repeat: bool) i32 {
    seen.realm = r;
    seen.timers += 1;
    seen.timeout = timeout;
    seen.argument_count = arguments.len;
    seen.repeat = repeat;
    switch (handler) {
        .function => |h| {
            seen.function_handlers += 1;
            engine.releaseValue.?(h);
        },
        .string => |h| {
            const string: *ffi.String = @ptrCast(@alignCast(h.handle.ptr));
            const len: usize = @intCast(ffi.v8_String_Utf8Length(string));
            seen.string_len = @min(len, seen.string_source.len);
            _ = ffi.v8_String_WriteUtf8(string, &seen.string_source, @intCast(seen.string_len));
            engine.releaseValue.?(h);
        },
    }
    // Every argument is the host's to release.
    for (arguments) |argument| engine.releaseValue.?(argument);
    return 41 + @as(i32, @intCast(seen.timers));
}

fn testClearTimer(r: runtime.Context, id: i32) void {
    seen.realm = r;
    seen.cleared = id;
}

fn testRequestAnimationFrame(r: runtime.Context, callback: runtime.JSValue) u32 {
    seen.realm = r;
    seen.frames += 1;
    engine.releaseValue.?(callback);
    return 9;
}

fn testCancelAnimationFrame(r: runtime.Context, handle: u32) void {
    seen.realm = r;
    seen.cancelled = handle;
}

fn testWindowDestroyed(_: runtime.Context) void {}

const test_operations = runtime.WindowOperations{
    .initializeTimer = testInitializeTimer,
    .clearTimer = testClearTimer,
    .requestAnimationFrame = testRequestAnimationFrame,
    .cancelAnimationFrame = testCancelAnimationFrame,
    .windowDestroyed = testWindowDestroyed,
};

fn installed() !runtime.Context {
    const ctx = try realm();
    try engine.installWindowOperations.?(ctx, &test_operations);
    seen = .{};
    return ctx;
}

test "setTimeout and setInterval hand their converted arguments to the host" {
    const ctx = try installed();

    var reports = try run("globalThis.id = setTimeout(function () {}, 5, 'a', 1);");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqual(@as(usize, 1), seen.timers);
    try std.testing.expectEqual(@as(usize, 1), seen.function_handlers);
    try std.testing.expectEqual(@as(i32, 5), seen.timeout);
    try std.testing.expectEqual(@as(usize, 2), seen.argument_count);
    try std.testing.expect(!seen.repeat);
    try std.testing.expect(seen.realm.? == ctx);
    // The host's id is what script gets.
    try std.testing.expectEqual(@as(i32, 42), try scriptInt("globalThis.id"));

    // A string handler is converted at the call; the timeout by ToInt32.
    reports = try run("globalThis.id2 = setInterval({ toString() { globalThis.converted = 1; return 'globalThis.ran = 1'; } }, 2 ** 32 + 7);");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("globalThis.converted"));
    try std.testing.expectEqualStrings("globalThis.ran = 1", seen.stringSource());
    try std.testing.expectEqual(@as(i32, 7), seen.timeout);
    try std.testing.expect(seen.repeat);
    try std.testing.expectEqual(@as(i32, 43), try scriptInt("globalThis.id2"));
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("setTimeout.length"));
    try std.testing.expectEqual(@as(i32, 0), try scriptInt("clearTimeout.length"));
}

test "setTimeout without a handler, or with one whose ToString throws, throws" {
    _ = try installed();

    var reports = try run("setTimeout();");
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "TypeError") != null);

    reports = try run("setTimeout({ toString() { throw new Error('no string'); } });");
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "no string") != null);
    try std.testing.expectEqual(@as(usize, 0), seen.timers);
}

test "clearTimeout and clearInterval convert the id with ToInt32" {
    const ctx = try installed();
    _ = try run("clearTimeout('5');");
    try std.testing.expectEqual(@as(?i32, 5), seen.cleared);
    try std.testing.expect(seen.realm.? == ctx);
    _ = try run("clearInterval(6.9);");
    try std.testing.expectEqual(@as(?i32, 6), seen.cleared);
}

test "requestAnimationFrame takes a callable; cancelAnimationFrame a handle in range" {
    const ctx = try installed();
    _ = try run("globalThis.handle = requestAnimationFrame(function () {});");
    try std.testing.expectEqual(@as(usize, 1), seen.frames);
    try std.testing.expect(seen.realm.? == ctx);
    try std.testing.expectEqual(@as(i32, 9), try scriptInt("globalThis.handle"));

    _ = try run("globalThis.none = requestAnimationFrame(3);");
    try std.testing.expectEqual(@as(usize, 1), seen.frames);
    try std.testing.expectEqual(@as(i32, 0), try scriptInt("globalThis.none"));

    _ = try run("cancelAnimationFrame(0); cancelAnimationFrame(NaN); cancelAnimationFrame('9');");
    try std.testing.expectEqual(@as(?u32, null), seen.cancelled);
    _ = try run("cancelAnimationFrame(9);");
    try std.testing.expectEqual(@as(?u32, 9), seen.cancelled);
}
