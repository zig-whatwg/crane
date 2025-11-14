//! Tests migrated from src/mimesniff/constants.zig
//! Per WHATWG specifications

const std = @import("std");
const infra = @import("infra");

const mimesniff = @import("mimesniff");

test "isHttpTokenCodePoint - valid tokens" {
    // Special characters
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('!'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('#'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('$'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('%'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('&'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('\''));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('*'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('+'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('-'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('.'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('^'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('_'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('`'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('|'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('~'));

    // Alphanumerics
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('0'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('9'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('A'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('Z'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('a'));
    try std.testing.expect(mimesniff.isHttpTokenCodePoint('z'));
}
test "isHttpTokenCodePoint - invalid tokens" {
    // Whitespace
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint(' '));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('\t'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('\n'));

    // Delimiters
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('('));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint(')'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('<'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('>'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('@'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint(','));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint(';'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint(':'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('\\'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('"'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('/'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('['));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint(']'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('?'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('='));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('{'));
    try std.testing.expect(!mimesniff.isHttpTokenCodePoint('}'));
}
test "isHttpQuotedStringTokenCodePoint - valid" {
    // TAB
    try std.testing.expect(mimesniff.isHttpQuotedStringTokenCodePoint(0x09));

    // SPACE to ~
    try std.testing.expect(mimesniff.isHttpQuotedStringTokenCodePoint(' '));
    try std.testing.expect(mimesniff.isHttpQuotedStringTokenCodePoint('A'));
    try std.testing.expect(mimesniff.isHttpQuotedStringTokenCodePoint('~'));

    // Extended ASCII
    try std.testing.expect(mimesniff.isHttpQuotedStringTokenCodePoint(0x80));
    try std.testing.expect(mimesniff.isHttpQuotedStringTokenCodePoint(0xFF));
}
test "isBinaryDataByte - binary bytes" {
    // 0x00 to 0x08
    try std.testing.expect(mimesniff.isBinaryDataByte(0x00)); // NUL
    try std.testing.expect(mimesniff.isBinaryDataByte(0x01)); // SOH
    try std.testing.expect(mimesniff.isBinaryDataByte(0x08)); // BS

    // 0x0B
    try std.testing.expect(mimesniff.isBinaryDataByte(0x0B)); // VT

    // 0x0E to 0x1A
    try std.testing.expect(mimesniff.isBinaryDataByte(0x0E)); // SO
    try std.testing.expect(mimesniff.isBinaryDataByte(0x1A)); // SUB

    // 0x1C to 0x1F
    try std.testing.expect(mimesniff.isBinaryDataByte(0x1C)); // FS
    try std.testing.expect(mimesniff.isBinaryDataByte(0x1F)); // US
}
test "isWhitespaceByte - whitespace" {
    try std.testing.expect(mimesniff.isWhitespaceByte(0x09)); // HT
    try std.testing.expect(mimesniff.isWhitespaceByte(0x0A)); // LF
    try std.testing.expect(mimesniff.isWhitespaceByte(0x0C)); // FF
    try std.testing.expect(mimesniff.isWhitespaceByte(0x0D)); // CR
    try std.testing.expect(mimesniff.isWhitespaceByte(0x20)); // SP
}
test "isWhitespaceByte - non-whitespace" {
    try std.testing.expect(!mimesniff.isWhitespaceByte(0x00)); // NUL
    try std.testing.expect(!mimesniff.isWhitespaceByte(0x0B)); // VT
    try std.testing.expect(!mimesniff.isWhitespaceByte('A'));
    try std.testing.expect(!mimesniff.isWhitespaceByte(' ' + 1));
}
test "isTagTerminatingByte - terminators" {
    try std.testing.expect(mimesniff.isTagTerminatingByte(0x20)); // SP
    try std.testing.expect(mimesniff.isTagTerminatingByte(0x3E)); // ">"
}
test "isTagTerminatingByte - non-terminators" {
    try std.testing.expect(!mimesniff.isTagTerminatingByte(0x00));
    try std.testing.expect(!mimesniff.isTagTerminatingByte('<'));
    try std.testing.expect(!mimesniff.isTagTerminatingByte('A'));
}