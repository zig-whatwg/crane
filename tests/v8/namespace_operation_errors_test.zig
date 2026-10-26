//! A namespace operation that fails THROWS (WebIDL 3.13.1, "create an
//! operation function": the steps' abrupt completion is the function's).
//!
//! The binding handed the impl's whole `anyerror!T` to conv.toV8Value, whose
//! error-union branch MADE an Error object and returned it as the call's
//! value: CSS.registerProperty's TypeError, SyntaxError and
//! InvalidModificationError came back as ordinary objects and nothing threw
//! (Codex row 120 Q20, tmp/plans/feature-queue.md "NAMESPACE OPERATION ERRORS
//! ARE RETURNED, NOT THROWN"). The getter path already threw through
//! conv.throwWebIDLErrorFromContext; the operation path now does the same,
//! and an error that says script has already thrown (error.ExceptionPending)
//! leaves script's own exception pending, as the interface binding does
//! (docs/lessons/architecture-a-pending-script-exception-is-not-a-new-host-error.md).
//!
//! Each test runs on a thread of its own with its own isolate: the
//! directory's other files may have left theirs entered.

const std = @import("std");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");

/// A hand-written namespace, bound by the generated-namespace binding.
const Failing = struct {
    pub const Meta = struct {
        pub const name = "Failing";
        pub const methods = .{
            .{ "modification", "call_modification", 0 },
            .{ "typeError", "call_typeError", 0 },
            .{ "syntaxWithPayload", "call_syntaxWithPayload", 1 },
            .{ "succeedVoid", "call_succeedVoid", 0 },
            .{ "succeedNumber", "call_succeedNumber", 2 },
            .{ "pending", "call_pending", 0 },
        };
    };

    pub fn call_modification() anyerror!void {
        return error.InvalidModificationError;
    }

    pub fn call_typeError() anyerror!void {
        return error.TypeError;
    }

    pub fn call_syntaxWithPayload(n: u32) anyerror!u32 {
        if (n == 0) return error.SyntaxError;
        return n + 1;
    }

    pub fn call_succeedVoid() anyerror!void {}

    pub fn call_succeedNumber(a: u32, b: u32) anyerror!u32 {
        return a * b;
    }

    /// Script's own exception is pending (as a callback's would be): the
    /// binding must not replace it with a new one.
    pub fn call_pending() anyerror!void {
        v8.conversions.throwTypeError(ffi.v8_Isolate_GetCurrent().?, "thrown by script");
        return error.ExceptionPending;
    }
};

const FailingBinding = v8.V8Namespace(Failing);

fn evalIn(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8) ![]const u8 {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.NoValue;
    defer ffi.v8_Value_Dispose(value);
    return v8.conversions.fromV8Value([]const u8, std.testing.allocator, isolate, context, value);
}

const Check = struct { source: []const u8, expected: []const u8 };

fn runChecks(checks: []const Check) !void {
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
    FailingBinding.registerGlobal(isolate, context, "Failing");

    for (checks) |check| {
        const got = try evalIn(isolate, context, check.source);
        defer if (got.len > 0) std.testing.allocator.free(got);
        std.testing.expectEqualStrings(check.expected, got) catch |err| {
            std.debug.print("source: {s}\n", .{check.source});
            return err;
        };
    }
}

fn onThread(checks: []const Check) !void {
    const Runner = struct {
        fn run(c: []const Check, result: *anyerror!void) void {
            result.* = runChecks(c);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Runner.run, .{ checks, &result });
    thread.join();
    try result;
}

/// `outcome(expr)`: "threw <name>" or "returned <typeof> <value>". A bare
/// context has no DOMException; a stand-in with the WebIDL constructor's
/// shape (message, name) is what conv.throwDOMExceptionFromContext
/// constructs, as it would construct the realm's own.
const outcome =
    \\if (typeof DOMException === 'undefined')
    \\  globalThis.DOMException = class DOMException extends Error {
    \\    constructor(message, name) { super(message); this.name = name; } };
    \\function outcome(f) {
    \\  try { const v = f(); return 'returned ' + typeof v + ' ' + String(v); }
    \\  catch (e) { return 'threw ' + (e instanceof DOMException ? 'DOMException ' + e.name
    \\                                  : e instanceof TypeError ? 'TypeError ' + e.message : String(e)); }
    \\}
;

test "an operation returning a DOMException name throws that DOMException" {
    try onThread(&.{
        .{ .source = outcome ++ "outcome(() => Failing.modification())", .expected = "threw DOMException InvalidModificationError" },
        .{ .source = outcome ++ "outcome(() => Failing.syntaxWithPayload(0))", .expected = "threw DOMException SyntaxError" },
    });
}

test "an operation returning error.TypeError throws a TypeError" {
    try onThread(&.{
        .{ .source = outcome ++ "outcome(() => Failing.typeError()).split(' ').slice(0, 2).join(' ')", .expected = "threw TypeError" },
    });
}

test "a successful operation returns its value unchanged" {
    try onThread(&.{
        .{ .source = outcome ++ "outcome(() => Failing.succeedVoid())", .expected = "returned undefined undefined" },
        .{ .source = outcome ++ "outcome(() => Failing.succeedNumber(6, 7))", .expected = "returned number 42" },
        .{ .source = outcome ++ "outcome(() => Failing.syntaxWithPayload(4))", .expected = "returned number 5" },
    });
}

test "an operation that leaves script's exception pending rethrows it, not a new error" {
    try onThread(&.{
        .{ .source = outcome ++ "outcome(() => Failing.pending())", .expected = "threw TypeError thrown by script" },
    });
}
