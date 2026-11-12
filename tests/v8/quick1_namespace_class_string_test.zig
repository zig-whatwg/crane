//! A namespace object has its class string as @@toStringTag (WebIDL 3.13.1:
//! "The class string of a namespace object is the namespace's identifier";
//! WebIDL 3: an object with a class string has, from its creation, a
//! %Symbol.toStringTag% property {[[Writable]]: false, [[Enumerable]]:
//! false, [[Configurable]]: true, [[Value]]: classString}).
//!
//! RED at 9a7434fdee9: V8Namespace.createObject defined no such property,
//! so Object.prototype.toString gave "[object Object]" for console and CSS
//! (console/console-namespace-object-class-string.any.js,
//! css/cssom/CSS-namespace-object-class-string.html: 4/4 in Chrome 157,
//! Firefox 160 and Safari 27.2; 0/4 and 0/4 in Crane).
//!
//! Each test runs on a thread of its own with its own isolate: the
//! directory's other files may have left theirs entered.

const std = @import("std");
const v8 = @import("v8");
const ffi = v8.ffi;
const test_process = @import("test_process.zig");

/// A hand-written namespace, bound by the generated-namespace binding.
const Gauge = struct {
    pub const Meta = struct {
        pub const name = "Gauge";
        pub const methods = .{
            .{ "read", "call_read", 0 },
        };
    };

    pub fn call_read() anyerror!u32 {
        return 7;
    }
};

const GaugeBinding = v8.V8Namespace(Gauge);

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
    test_process.start();
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
    GaugeBinding.registerGlobal(isolate, context, "Gauge");

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

test "a namespace object's @@toStringTag is its identifier, with WebIDL's descriptor" {
    try onThread(&.{
        .{ .source = "Object.prototype.toString.call(Gauge)", .expected = "[object Gauge]" },
        .{ .source = "String(Gauge[Symbol.toStringTag])", .expected = "Gauge" },
        .{ .source = "(() => { const d = Object.getOwnPropertyDescriptor(Gauge, Symbol.toStringTag); return [d.writable, d.enumerable, d.configurable, typeof d.get].join(); })()", .expected = "false,false,true,undefined" },
        // An own property, not an inherited one, and not one of the
        // namespace's enumerable members.
        .{ .source = "[Object.getOwnPropertySymbols(Gauge).length, Object.keys(Gauge).join()].join(' ')", .expected = "1 read" },
    });
}

test "the tag can be changed and deleted, as a configurable non-writable property" {
    try onThread(&.{
        .{ .source = "Object.defineProperty(Gauge, Symbol.toStringTag, { value: 'Other' }); Object.prototype.toString.call(Gauge)", .expected = "[object Other]" },
        .{ .source = "delete Gauge[Symbol.toStringTag]; Object.prototype.toString.call(Gauge)", .expected = "[object Object]" },
        // The namespace's operations are untouched.
        .{ .source = "String(Gauge.read())", .expected = "7" },
    });
}
