//! Tests migrated from src/mimesniff/constants.zig
//! Per WHATWG specifications

const std = @import("std");

const mimesniff = @import("mimesniff");
const source = @import("../../src/mimesniff/constants.zig");

test "isHttpTokenCodePoint - valid tokens" {
    // Special characters
    try std.testing.expect(isHttpTokenCodePoint('!'));
    try std.testing.expect(isHttpTokenCodePoint('#'));
    try std.testing.expect(isHttpTokenCodePoint('$'));
    try std.testing.expect(isHttpTokenCodePoint('%'));
    try std.testing.expect(isHttpTokenCodePoint('&'));
    try std.testing.expect(isHttpTokenCodePoint('\''));
    try std.testing.expect(isHttpTokenCodePoint('*'));
    try std.testing.expect(isHttpTokenCodePoint('+'));
    try std.testing.expect(isHttpTokenCodePoint('-'));
    try std.testing.expect(isHttpTokenCodePoint('.'));
    try std.testing.expect(isHttpTokenCodePoint('^'));
    try std.testing.expect(isHttpTokenCodePoint('_'));
    try std.testing.expect(isHttpTokenCodePoint('`'));
    try std.testing.expect(isHttpTokenCodePoint('|'));
    try std.testing.expect(isHttpTokenCodePoint('~'));

    // Alphanumerics
    try std.testing.expect(isHttpTokenCodePoint('0'));
    try std.testing.expect(isHttpTokenCodePoint('9'));
    try std.testing.expect(isHttpTokenCodePoint('A'));
    try std.testing.expect(isHttpTokenCodePoint('Z'));
    try std.testing.expect(isHttpTokenCodePoint('a'));
    try std.testing.expect(isHttpTokenCodePoint('z'));
}
test "isHttpTokenCodePoint - invalid tokens" {
    // Whitespace
    try std.testing.expect(!isHttpTokenCodePoint(' '));
    try std.testing.expect(!isHttpTokenCodePoint('\t'));
    try std.testing.expect(!isHttpTokenCodePoint('\n'));

    // Delimiters
    try std.testing.expect(!isHttpTokenCodePoint('('));
    try std.testing.expect(!isHttpTokenCodePoint(')'));
    try std.testing.expect(!isHttpTokenCodePoint('<'));
    try std.testing.expect(!isHttpTokenCodePoint('>'));
    try std.testing.expect(!isHttpTokenCodePoint('@'));
    try std.testing.expect(!isHttpTokenCodePoint(','));
    try std.testing.expect(!isHttpTokenCodePoint(';'));
    try std.testing.expect(!isHttpTokenCodePoint(':'));
    try std.testing.expect(!isHttpTokenCodePoint('\\'));
    try std.testing.expect(!isHttpTokenCodePoint('"'));
    try std.testing.expect(!isHttpTokenCodePoint('/'));
    try std.testing.expect(!isHttpTokenCodePoint('['));
    try std.testing.expect(!isHttpTokenCodePoint(']'));
    try std.testing.expect(!isHttpTokenCodePoint('?'));
    try std.testing.expect(!isHttpTokenCodePoint('='));
    try std.testing.expect(!isHttpTokenCodePoint('{'));
    try std.testing.expect(!isHttpTokenCodePoint('}'));
}
test "isHttpQuotedStringTokenCodePoint - valid" {
    // TAB
    try std.testing.expect(isHttpQuotedStringTokenCodePoint(0x09));

    // SPACE to ~
    try std.testing.expect(isHttpQuotedStringTokenCodePoint(' '));
    try std.testing.expect(isHttpQuotedStringTokenCodePoint('A'));
    try std.testing.expect(isHttpQuotedStringTokenCodePoint('~'));

    // Extended ASCII
    try std.testing.expect(isHttpQuotedStringTokenCodePoint(0x80));
    try std.testing.expect(isHttpQuotedStringTokenCodePoint(0xFF));
}
test "isHttpQuotedStringTokenCodePoint - invalid" {
    // Below TAB (excluding TAB)
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x00));
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x08));

    // Between TAB and SPACE
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x0A));
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x0D));
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x1F));

    // Above ~, below extended ASCII
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x7F));

    // Above extended ASCII
    try std.testing.expect(!isHttpQuotedStringTokenCodePoint(0x100));
}
test "isBinaryDataByte - binary bytes" {
    // 0x00 to 0x08
    try std.testing.expect(isBinaryDataByte(0x00)); // NUL
    try std.testing.expect(isBinaryDataByte(0x01)); // SOH
    try std.testing.expect(isBinaryDataByte(0x08)); // BS

    // 0x0B
    try std.testing.expect(isBinaryDataByte(0x0B)); // VT

    // 0x0E to 0x1A
    try std.testing.expect(isBinaryDataByte(0x0E)); // SO
    try std.testing.expect(isBinaryDataByte(0x1A)); // SUB

    // 0x1C to 0x1F
    try std.testing.expect(isBinaryDataByte(0x1C)); // FS
    try std.testing.expect(isBinaryDataByte(0x1F)); // US
}
test "isBinaryDataByte - non-binary bytes" {
    // Whitespace (not binary)
    try std.testing.expect(!isBinaryDataByte(0x09)); // HT
    try std.testing.expect(!isBinaryDataByte(0x0A)); // LF
    try std.testing.expect(!isBinaryDataByte(0x0C)); // FF
    try std.testing.expect(!isBinaryDataByte(0x0D)); // CR
    try std.testing.expect(!isBinaryDataByte(0x20)); // SP

    // Between ranges
    try std.testing.expect(!isBinaryDataByte(0x1B)); // ESC

    // Printable ASCII
    try std.testing.expect(!isBinaryDataByte('A'));
    try std.testing.expect(!isBinaryDataByte('z'));
}
test "isWhitespaceByte - whitespace" {
    try std.testing.expect(isWhitespaceByte(0x09)); // HT
    try std.testing.expect(isWhitespaceByte(0x0A)); // LF
    try std.testing.expect(isWhitespaceByte(0x0C)); // FF
    try std.testing.expect(isWhitespaceByte(0x0D)); // CR
    try std.testing.expect(isWhitespaceByte(0x20)); // SP
}
test "isWhitespaceByte - non-whitespace" {
    try std.testing.expect(!isWhitespaceByte(0x00)); // NUL
    try std.testing.expect(!isWhitespaceByte(0x0B)); // VT
    try std.testing.expect(!isWhitespaceByte('A'));
    try std.testing.expect(!isWhitespaceByte(' ' + 1));
}
test "isTagTerminatingByte - terminators" {
    try std.testing.expect(isTagTerminatingByte(0x20)); // SP
    try std.testing.expect(isTagTerminatingByte(0x3E)); // ">"
}
test "isTagTerminatingByte - non-terminators" {
    try std.testing.expect(!isTagTerminatingByte(0x00));
    try std.testing.expect(!isTagTerminatingByte('<'));
    try std.testing.expect(!isTagTerminatingByte('A'));
}