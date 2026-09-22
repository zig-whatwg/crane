//! The iso-2022-jp encoder (Encoding § 12.2.2), byte for byte.
//!
//! It is the one stateful encoder, and every state change is an escape
//! sequence in the output: ESC ( B for ASCII, ESC ( J for Roman (JIS X 0201),
//! ESC $ B for JIS X 0208. The encoder had no tests, and it had drifted from
//! the handler in four places: U+00A5 and U+203E went out as bare 0x5C/0x7E
//! with no switch to Roman; ASCII in Roman state always left Roman; halfwidth
//! katakana were looked up in JIS X 0208 as themselves and never found; and
//! an unencodable code point in JIS X 0208 state was reported without first
//! returning to ASCII, so whatever the caller wrote for the error was read as
//! two-byte JIS.

const std = @import("std");
const encoding = @import("encoding");

/// Encode `input` (UTF-8) in one call, as a whole queue.
fn encodeAll(input: []const u8) ![]u8 {
    const enc = encoding.getEncoding("iso-2022-jp").?;
    var encoder = enc.newEncoder().?;
    const units = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(units);
    var buf: [256]u8 = undefined;
    const result = encoder.encode(units, &buf, true);
    try std.testing.expectEqual(encoding.EncodeResult.Status.input_empty, result.status);
    return std.testing.allocator.dupe(u8, buf[0..result.bytes_written]);
}

fn expectBytes(input: []const u8, expected: []const u8) !void {
    const got = try encodeAll(input);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualSlices(u8, expected, got);
}

test "ASCII is itself, with no escape" {
    try expectBytes("abc", "abc");
}

test "U+00A5 and U+203E switch to Roman (step 7) and map onto 0x5C and 0x7E (step 5)" {
    try expectBytes("\u{a5}", "\x1b(J\x5c\x1b(B");
    try expectBytes("\u{203e}", "\x1b(J\x7e\x1b(B");
}

test "ASCII other than 0x5C and 0x7E stays in Roman (step 5)" {
    try expectBytes("\u{a5}a\u{a5}", "\x1b(J\x5ca\x5c\x1b(B");
}

test "0x5C in Roman state returns to ASCII first (step 6)" {
    try expectBytes("\u{a5}\\", "\x1b(J\x5c\x1b(B\\");
}

test "JIS X 0208: one escape in, one out at the end of the queue" {
    // BLACK STAR and the star kanji: 0x21 0x7A and 0x40 0x31.
    try expectBytes("\u{2605}\u{661f}", "\x1b$B!z@1\x1b(B");
}

test "halfwidth katakana are encoded as their fullwidth forms (step 9)" {
    // U+FF76 HALFWIDTH KATAKANA LETTER KA -> U+30AB KATAKANA LETTER KA,
    // row 5 cell 11 of JIS X 0208: 0x25 0x2B.
    try expectBytes("\u{ff76}", "\x1b$B%+\x1b(B");
}

test "U+2212 MINUS SIGN is encoded as U+FF0D (step 8)" {
    // U+FF0D FULLWIDTH HYPHEN-MINUS is row 1 cell 61: 0x21 0x5D.
    try expectBytes("\u{2212}", "\x1b$B!]\x1b(B");
}

test "an unencodable code point in JIS X 0208 state returns to ASCII before the error (step 11.1)" {
    const enc = encoding.getEncoding("iso-2022-jp").?;
    var encoder = enc.newEncoder().?;
    var buf: [32]u8 = undefined;
    const star = [_]u16{0x661F};
    const first = encoder.encode(&star, &buf, false);
    try std.testing.expectEqual(encoding.EncodeResult.Status.input_empty, first.status);
    try std.testing.expectEqualSlices(u8, "\x1b$B@1", buf[0..first.bytes_written]);

    const snowman = [_]u16{0x2603};
    const second = encoder.encode(&snowman, &buf, false);
    try std.testing.expectEqual(encoding.EncodeResult.Status.unmappable, second.status);
    try std.testing.expectEqual(@as(u21, 0x2603), second.error_code_point);
    try std.testing.expectEqualSlices(u8, "\x1b(B", buf[0..second.bytes_written]);

    // Back in ASCII: the end of the queue needs no escape.
    const tail = encoder.encode(&.{}, &buf, true);
    try std.testing.expectEqual(@as(usize, 0), tail.bytes_written);
}

test "U+000E, U+000F and U+001B are errors reported as U+FFFD (step 3)" {
    const enc = encoding.getEncoding("iso-2022-jp").?;
    var encoder = enc.newEncoder().?;
    var buf: [32]u8 = undefined;
    const esc = [_]u16{0x1B};
    const result = encoder.encode(&esc, &buf, true);
    try std.testing.expectEqual(encoding.EncodeResult.Status.unmappable, result.status);
    try std.testing.expectEqual(@as(u21, 0xFFFD), result.error_code_point);
    try std.testing.expectEqual(@as(usize, 0), result.bytes_written);
}
