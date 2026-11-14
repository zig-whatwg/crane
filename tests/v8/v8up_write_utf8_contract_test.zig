//! `v8_String_WriteUtf8` keeps V8 13.1's `String::WriteUtf8` contract, the one
//! its callers read (helpers.writtenUtf8, intl_binding, observable_array,
//! conversions, protocol_values): as many whole characters as fit; then, when
//! every character was written and a byte is left, a NUL, COUNTED in the
//! result; a capacity of -1 is unbounded (13.1 api.cc WriteUtf8Impl).
//!
//! V8 14 removed that WriteUtf8 and gave its name to the former WriteUtf8V2
//! (v8-primitive.h at 15.7.112.43): no NUL unless `kNullTerminate` is asked
//! for, and, asked, a NUL even where it costs the last character. Passing the
//! new call straight through cut every string a caller wrote with a byte to
//! spare and then dropped "the NUL": "gregory" read back as "gregor", and
//! `new Intl.Locale('en')` threw "Invalid locale identifier" (tests/v8 on
//! 15.7, intl_object_lifetime_test and intl_per_call_handle_test).

const std = @import("std");
const testing = std.testing;
const test_process = @import("test_process.zig");
const v8 = @import("v8");
const ffi = v8.ffi;

/// `body` with `text` as a V8 string in a test agent of its own.
fn withString(text: []const u8, comptime body: fn (*ffi.String) anyerror!void) !void {
    var agent: test_process.TestAgent = .{};
    defer agent.close();
    const isolate = try agent.open(.{});
    const string = ffi.v8_String_NewFromUtf8(isolate, text.ptr, @intCast(text.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(string);
    try body(string);
}

test "a buffer with a byte to spare gets the whole string and a NUL, counted" {
    try withString("gregory", struct {
        fn body(s: *ffi.String) !void {
            var buf: [8]u8 = @splat(0xaa);
            try testing.expectEqual(@as(c_int, 8), ffi.v8_String_WriteUtf8(s, &buf, buf.len));
            try testing.expectEqualStrings("gregory\x00", &buf);
        }
    }.body);
}

test "a buffer of exactly the string's length gets the whole string and no NUL" {
    try withString("gregory", struct {
        fn body(s: *ffi.String) !void {
            var buf: [8]u8 = @splat(0xaa);
            try testing.expectEqual(@as(c_int, 7), ffi.v8_String_WriteUtf8(s, &buf, 7));
            try testing.expectEqualStrings("gregory\xaa", &buf);
        }
    }.body);
}

test "a character that does not fit is not written, and no NUL follows" {
    // "a" then U+00E9, two bytes: with room for two, only "a" fits whole.
    try withString("a\xc3\xa9", struct {
        fn body(s: *ffi.String) !void {
            var buf: [4]u8 = @splat(0xaa);
            try testing.expectEqual(@as(c_int, 1), ffi.v8_String_WriteUtf8(s, &buf, 2));
            try testing.expectEqualStrings("a\xaa\xaa\xaa", &buf);
        }
    }.body);
}

test "the empty string is written as a lone NUL, counted" {
    try withString("", struct {
        fn body(s: *ffi.String) !void {
            var buf: [2]u8 = @splat(0xaa);
            try testing.expectEqual(@as(c_int, 1), ffi.v8_String_WriteUtf8(s, &buf, buf.len));
            try testing.expectEqualStrings("\x00\xaa", &buf);
        }
    }.body);
}

test "a capacity of -1 is unbounded: the whole string and its NUL" {
    try withString("en-US", struct {
        fn body(s: *ffi.String) !void {
            var buf: [16]u8 = @splat(0xaa);
            try testing.expectEqual(@as(c_int, 6), ffi.v8_String_WriteUtf8(s, &buf, -1));
            try testing.expectEqualStrings("en-US\x00", buf[0..6]);
        }
    }.body);
}
