//! A union argument converted to its string arm through toString() leaves no
//! handle behind.
//!
//! WebIDL 3.2.25 step 15 for a union with interface arms and a string arm
//! (and no dictionary): an Object no arm took is converted to the string type
//! - ToString, so its toString() runs. TimerHandler is such a union
//! ((TrustedScript or DOMString) or Function), so `setTimeout({ toString() {
//! ... } })` takes that path. The conversion's `v8_Value_ToString` makes a
//! Global<String> (v8_wrapper.cpp: `new Global<String>`), which the caller
//! owns; convertValueAs converted it to the string arm and never released it:
//! 16 bytes of malloc and one global handle per call, for the agent's life.
//! `leaks --atExit` over the production runner named it (lane mem1, chat2,
//! 2026-11-22: operator new <- v8_Value_ToString <- convertArgAt <-
//! call_setTimeout, html/webappapis/timers/evil-spec-example.any.js's worker
//! variant; lane flk4).
//!
//! The measure is V8's own count of global handles in use in the isolate
//! (`v8_Isolate_GetGlobalHandleBytes`), which the leaked handle moves, as
//! tests/v8/argument_conversion_failure_handle_test.zig measures failed
//! conversions.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const iface = v8.interface_mod;

/// setTimeout's handler: (TrustedScript or DOMString) or Function.
const TimerHandler = v8.conversions.generated_typedefs.TimerHandler;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
}

/// Script's value of `code`, OWNED - a Global, as `info.get(i)` makes one.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

/// `code` converted as a TimerHandler, which must take its string arm with
/// `expected`; the converted value freed as the binding frees it.
fn convertToString(code: []const u8, expected: []const u8) !void {
    const e = try env();
    const arg = try eval(code);
    const value = try iface.convertArgReleasingWith(TimerHandler, .{}, testing.allocator, e.isolate, e.context, arg);
    defer iface.freeConvertedArg(TimerHandler, testing.allocator, value);
    switch (value) {
        .domstring => |string| try testing.expectEqualStrings(expected, string.asSlice()),
        else => return error.NotTheStringArm,
    }
}

/// The global handle bytes `rounds` conversions of `code` leave, after a
/// warm-up.
fn bytesLeftBy(code: []const u8, expected: []const u8, rounds: usize) !i64 {
    const e = try env();
    for (0..32) |_| try convertToString(code, expected);
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    for (0..rounds) |_| try convertToString(code, expected);
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    return after - before;
}

test "an object a TimerHandler takes as its string, through toString(), leaves no handle" {
    defer test_agent.close();
    try testing.expectEqual(@as(i64, 0), try bytesLeftBy("({ toString() { return 'logger(1)' } })", "logger(1)", 256));
}

test "an object whose toString() itself converts a TimerHandler (setTimeout's re-entry) leaves no handle" {
    defer test_agent.close();
    // evil-spec-example.any.js: the handler's toString() calls setTimeout
    // with a string - a conversion inside the conversion.
    _ = try env();
    try testing.expectEqual(@as(i64, 0), try bytesLeftBy(
        "({ toString() { String({ toString() { return 'inner' } }); return 'outer' } })",
        "outer",
        256,
    ));
}

test "a string a TimerHandler takes as it is leaves no handle (the control)" {
    defer test_agent.close();
    try testing.expectEqual(@as(i64, 0), try bytesLeftBy("'logger(2)'", "logger(2)", 256));
}
