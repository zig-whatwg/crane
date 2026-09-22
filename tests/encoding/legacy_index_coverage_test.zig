//! The legacy CJK encoders and decoders against the WHATWG indexes' far ends.
//!
//! `tools/encoding/generate_japanese_korean.py` built each index array to a
//! hardcoded last pointer, and two were short of the data: index jis0208
//! stopped at 7939 of 11103 and index euc-kr at 17919 of 23749. Everything
//! past those - JIS X 0208's NEC-selected IBM extensions (rows 89-92) and
//! IBM extensions (rows 115-119), and EUC-KR's hanja from lead byte 0xE0 on -
//! could be neither decoded nor encoded. The vectors here sit in exactly
//! those ranges, plus the Shift_JIS encoder's own rules for them.

const std = @import("std");
const encoding = @import("encoding");

fn encodeAll(label: []const u8, input: []const u8) ![]u8 {
    const enc = encoding.getEncoding(label) orelse return error.UnknownEncoding;
    var encoder = enc.newEncoder() orelse return error.NoEncoder;
    const units = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(units);
    var buf: [64]u8 = undefined;
    const result = encoder.encode(units, &buf, true);
    try std.testing.expectEqual(encoding.EncodeResult.Status.input_empty, result.status);
    return std.testing.allocator.dupe(u8, buf[0..result.bytes_written]);
}

fn expectEncoded(label: []const u8, input: []const u8, expected: []const u8) !void {
    const got = try encodeAll(label, input);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualSlices(u8, expected, got);
}

fn expectDecoded(label: []const u8, bytes: []const u8, expected: []const u8) !void {
    const enc = encoding.getEncoding(label) orelse return error.UnknownEncoding;
    var decoder = enc.newDecoder();
    var buf: [16]u16 = undefined;
    const result = decoder.decode(bytes, &buf, true);
    const want = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, expected);
    defer std.testing.allocator.free(want);
    try std.testing.expectEqualSlices(u16, want, buf[0..result.code_units_written]);
}

test "Shift_JIS: an IBM extension is encoded from the index Shift_JIS pointer, which skips 8272-8835" {
    // U+2170 SMALL ROMAN NUMERAL ONE is at pointers 8634 and 10716.
    try expectEncoded("shift_jis", "\u{2170}", "\xFA\x40");
    // U+7E8A is at 8272 and 10744.
    try expectEncoded("shift_jis", "\u{7E8A}", "\xFA\x5C");
    // U+FFE2 is at 137, 8644 and 10736: the first one outside the range.
    try expectEncoded("shift_jis", "\u{FFE2}", "\x81\xCA");
}

test "Shift_JIS: U+0080 is the byte 0x80 (step 2)" {
    try expectEncoded("shift_jis", "\u{80}", "\x80");
}

test "Shift_JIS: the IBM extension rows decode" {
    try expectDecoded("shift_jis", "\xFA\x40", "\u{2170}");
    try expectDecoded("shift_jis", "\xFA\x5C", "\u{7E8A}");
}

test "ISO-2022-JP and EUC-JP use the FIRST jis0208 pointer, NEC-selected row 92 for U+2170" {
    try expectEncoded("iso-2022-jp", "\u{2170}", "\x1b$B|q\x1b(B");
    try expectEncoded("euc-jp", "\u{2170}", "\xFC\xF1");
    // U+2252 is at 159 and 1207 (NEC row 13): 159.
    try expectEncoded("iso-2022-jp", "\u{2252}", "\x1b$B\"b\x1b(B");
}

test "EUC-JP: row 92 decodes" {
    try expectDecoded("euc-jp", "\xFC\xF1", "\u{2170}");
}

test "EUC-KR: hanja past pointer 17919 encode and decode" {
    // Pointer 18146 (lead 0xE0) and the index's last, 23749 (0xFD 0xFE).
    try expectEncoded("euc-kr", "\u{80E5}", "\xE0\xA1");
    try expectEncoded("euc-kr", "\u{8A70}", "\xFD\xFE");
    try expectDecoded("euc-kr", "\xE0\xA1", "\u{80E5}");
    try expectDecoded("euc-kr", "\xFD\xFE", "\u{8A70}");
}
