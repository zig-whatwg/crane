//! The UTF-8 decoder must REPORT errors, not silently substitute them.
//!
//! WHATWG Encoding Standard § 8.1.1 (UTF-8 decoder) returns `error` from the
//! handler; § 5.1.3 (TextDecoder.decode) is where that becomes either a
//! TypeError (fatal error mode) or U+FFFD (replacement error mode). The
//! decoder does not get to choose.
//!
//! `single_byte/decoder.zig` already says so in as many words - "Step 4: Not in
//! index - return error. The higher-level algorithm decides whether to throw
//! (fatal mode) or emit replacement character (replacement mode)" - but the
//! UTF-8 decoder wrote U+FFFD itself and returned `input_empty`. Its caller in
//! `webidl/impls/TextDecoder.zig` reads
//!
//!     if (result.status == .malformed) { if (fatal) return ImplError.DecodingError; }
//!
//! which was unreachable for UTF-8, so `new TextDecoder("utf-8", {fatal: true})`
//! could never throw: 35 of 36 subtests in `encoding/textdecoder-fatal.any.js`
//! failed on `assert_throws_js(TypeError, ...)`, against 64,512 passing in
//! `textdecoder-fatal-single-byte.any.js`, where the decoder does report.
//!
//! The error's extent matters as much as its presence. Per § 8.1.1 step 4 an
//! invalid continuation byte is RESTORED to the queue - it is not part of the
//! error and is re-read as a fresh lead byte - so `bytes_consumed` points at the
//! start of the bad sequence and `error_length` counts only the bytes that
//! sequence actually claimed.

const std = @import("std");
const encoding = @import("encoding");

fn utf8() *const encoding.Encoding {
    return encoding.UTF_8;
}

const Case = struct {
    input: []const u8,
    /// Bytes decoded cleanly before the error.
    consumed: usize,
    /// Code units emitted before the error - never a substitution.
    units: usize,
    /// Bytes the failed sequence claimed, per § 8.1.1.
    error_length: u8,
    why: []const u8,
};

test "invalid sequences report malformed with the spec's error extent" {
    const cases = [_]Case{
        .{ .input = &.{0xFF}, .consumed = 0, .units = 0, .error_length = 1, .why = "0xF5-0xFF is not a lead byte (step 3, Otherwise)" },
        .{ .input = &.{0x80}, .consumed = 0, .units = 0, .error_length = 1, .why = "0x80-0xC1 is not a lead byte (step 3, Otherwise)" },
        .{ .input = &.{0xC0}, .consumed = 0, .units = 0, .error_length = 1, .why = "0xC0 would be an overlong two-byte sequence" },
        .{ .input = &.{0xC1}, .consumed = 0, .units = 0, .error_length = 1, .why = "0xC1 would be an overlong two-byte sequence" },
        // Truncated at end of stream: step 1, bytes needed is not 0 at end-of-queue.
        .{ .input = &.{0xC2}, .consumed = 0, .units = 0, .error_length = 1, .why = "two-byte lead with no continuation" },
        .{ .input = &.{0xE0}, .consumed = 0, .units = 0, .error_length = 1, .why = "three-byte lead with no continuation" },
        .{ .input = &.{ 0xE0, 0xA0 }, .consumed = 0, .units = 0, .error_length = 2, .why = "three-byte sequence one byte short" },
        // Bad continuation: step 4 restores the offending byte, so it is NOT in error_length.
        .{ .input = &.{ 0xC2, 0x41 }, .consumed = 0, .units = 0, .error_length = 1, .why = "0x41 is outside 0x80-0xBF; only the lead is consumed" },
        .{ .input = &.{ 0xE0, 0x80 }, .consumed = 0, .units = 0, .error_length = 1, .why = "0xE0's lower boundary is 0xA0, so 0x80 is invalid (overlong)" },
        .{ .input = &.{ 0xED, 0xA0 }, .consumed = 0, .units = 0, .error_length = 1, .why = "0xED's upper boundary is 0x9F, so 0xA0 is a surrogate" },
        .{ .input = &.{ 0xF0, 0x80 }, .consumed = 0, .units = 0, .error_length = 1, .why = "0xF0's lower boundary is 0x90 (overlong)" },
        .{ .input = &.{ 0xF4, 0x90 }, .consumed = 0, .units = 0, .error_length = 1, .why = "0xF4's upper boundary is 0x8F (beyond U+10FFFF)" },
        .{ .input = &.{ 0xE0, 0xA0, 0x41 }, .consumed = 0, .units = 0, .error_length = 2, .why = "lead plus one good continuation, then a bad one" },
        // Good output before the error is kept, and the error is positioned after it.
        .{ .input = &.{ 0x41, 0xFF, 0x42 }, .consumed = 1, .units = 1, .error_length = 1, .why = "'A' decodes, then the error" },
        .{ .input = &.{ 0xC2, 0xA5, 0xFF }, .consumed = 2, .units = 1, .error_length = 1, .why = "U+00A5 decodes, then the error" },
    };

    for (cases) |c| {
        var decoder = utf8().newDecoder();
        var out: [16]u16 = undefined;
        const r = decoder.decode(c.input, &out, true);

        std.testing.expectEqual(encoding.DecodeResult.Status.malformed, r.status) catch |e| {
            std.debug.print("\ninput {x} should be malformed: {s}\n", .{ c.input, c.why });
            return e;
        };
        std.testing.expectEqual(c.consumed, r.bytes_consumed) catch |e| {
            std.debug.print("\ninput {x} bytes_consumed: {s}\n", .{ c.input, c.why });
            return e;
        };
        std.testing.expectEqual(c.units, r.code_units_written) catch |e| {
            std.debug.print("\ninput {x} code_units_written: {s}\n", .{ c.input, c.why });
            return e;
        };
        std.testing.expectEqual(c.error_length, r.error_length) catch |e| {
            std.debug.print("\ninput {x} error_length: {s}\n", .{ c.input, c.why });
            return e;
        };

        // No substitution: U+FFFD is the caller's decision, and in fatal mode
        // the caller makes the opposite one.
        for (out[0..r.code_units_written]) |u| {
            try std.testing.expect(u != 0xFFFD);
        }
    }
}

test "valid sequences are unaffected" {
    const Valid = struct { input: []const u8, expected: []const u16 };
    const cases = [_]Valid{
        .{ .input = "hello", .expected = &.{ 'h', 'e', 'l', 'l', 'o' } },
        .{ .input = &.{ 0xC2, 0xA5 }, .expected = &.{0x00A5} }, // YEN SIGN
        .{ .input = &.{ 0xE3, 0x81, 0x82 }, .expected = &.{0x3042} }, // HIRAGANA A
        .{ .input = &.{ 0xF0, 0x9F, 0x92, 0xA9 }, .expected = &.{ 0xD83D, 0xDCA9 } }, // surrogate pair
        .{ .input = &.{ 0xED, 0x9F, 0xBF }, .expected = &.{0xD7FF} }, // last before surrogates
        .{ .input = &.{ 0xF4, 0x8F, 0xBF, 0xBF }, .expected = &.{ 0xDBFF, 0xDFFF } }, // U+10FFFF
    };
    for (cases) |c| {
        var decoder = utf8().newDecoder();
        var out: [16]u16 = undefined;
        const r = decoder.decode(c.input, &out, true);
        try std.testing.expectEqual(encoding.DecodeResult.Status.input_empty, r.status);
        try std.testing.expectEqual(c.input.len, r.bytes_consumed);
        try std.testing.expectEqualSlices(u16, c.expected, out[0..r.code_units_written]);
    }
}

test "a truncated sequence mid-stream is not an error until the stream ends" {
    // § 8.1.1 step 1 only errors at end-of-queue. With is_last false the decoder
    // keeps its state and waits, which is what `decode(bytes, {stream: true})`
    // relies on.
    var decoder = utf8().newDecoder();
    var out: [16]u16 = undefined;

    const r1 = decoder.decode(&.{0xE3}, &out, false);
    try std.testing.expectEqual(encoding.DecodeResult.Status.input_empty, r1.status);
    try std.testing.expectEqual(@as(usize, 0), r1.code_units_written);

    const r2 = decoder.decode(&.{ 0x81, 0x82 }, &out, true);
    try std.testing.expectEqual(encoding.DecodeResult.Status.input_empty, r2.status);
    try std.testing.expectEqualSlices(u16, &.{0x3042}, out[0..r2.code_units_written]);
}

test "replacement error mode still yields U+FFFD - the caller substitutes" {
    // `utf8Decode` is a § 6 hook, defined in terms of replacement error mode.
    // Reporting the error from the decoder must not change what it returns.
    const allocator = std.testing.allocator;

    const out = try encoding.utf8DecodeWithoutBom(allocator, &.{ 0x41, 0xFF, 0x42 });
    defer allocator.free(out);
    try std.testing.expectEqualSlices(u16, &.{ 'A', 0xFFFD, 'B' }, out);

    const out2 = try encoding.utf8DecodeWithoutBom(allocator, &.{ 0xE0, 0xA0, 0x41 });
    defer allocator.free(out2);
    try std.testing.expectEqualSlices(u16, &.{ 0xFFFD, 'A' }, out2);

    const out3 = try encoding.utf8DecodeWithoutBom(allocator, &.{ 0xC2, 0xA5, 0xFF, 0xC2, 0xA5 });
    defer allocator.free(out3);
    try std.testing.expectEqualSlices(u16, &.{ 0x00A5, 0xFFFD, 0x00A5 }, out3);
}

test "fatal error mode reports the failure - utf8DecodeWithoutBomOrFail" {
    // https://encoding.spec.whatwg.org/#utf-8-decode-without-bom-or-fail
    // Before the decoder reported errors this returned a string of U+FFFDs and
    // called it success, because `bytes_consumed == bytes.len` was always true.
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.InvalidUtf8Sequence, encoding.utf8DecodeWithoutBomOrFail(allocator, &.{ 0x41, 0xFF }));
    try std.testing.expectError(error.InvalidUtf8Sequence, encoding.utf8DecodeWithoutBomOrFail(allocator, &.{0xC2}));
    try std.testing.expectError(error.InvalidUtf8Sequence, encoding.utf8DecodeWithoutBomOrFail(allocator, &.{ 0xE0, 0x80, 0x80 }));

    const ok = try encoding.utf8DecodeWithoutBomOrFail(allocator, &.{ 0xE3, 0x81, 0x82 });
    defer allocator.free(ok);
    try std.testing.expectEqualSlices(u16, &.{0x3042}, ok);
}
