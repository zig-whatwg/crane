//! WHATWG MIME Sniffing - Constants and Byte Classification
//!
//! Spec: https://mimesniff.spec.whatwg.org/#terminology
//!
//! This module provides byte classification functions and constants
//! used throughout the MIME sniffing algorithms.

const std = @import("std");
const infra = @import("infra");

/// HTTP token code point (WHATWG MIME Sniffing §2)
///
/// An HTTP token code point is U+0021 (!), U+0023 (#), U+0024 ($), U+0025 (%),
/// U+0026 (&), U+0027 ('), U+002A (*), U+002B (+), U+002D (-), U+002E (.),
/// U+005E (^), U+005F (_), U+0060 (`), U+007C (|), U+007E (~), or an ASCII alphanumeric.
///
/// Spec: https://mimesniff.spec.whatwg.org/#http-token-code-point
pub fn isHttpTokenCodePoint(c: u21) bool {
    return switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        '0'...'9', 'A'...'Z', 'a'...'z' => true,
        else => false,
    };
}

/// HTTP quoted-string token code point (WHATWG MIME Sniffing §2)
///
/// An HTTP quoted-string token code point is U+0009 TAB, a code point in the
/// range U+0020 SPACE to U+007E (~), inclusive, or a code point in the range
/// U+0080 through U+00FF (ÿ), inclusive.
///
/// Spec: https://mimesniff.spec.whatwg.org/#http-quoted-string-token-code-point
pub fn isHttpQuotedStringTokenCodePoint(c: u21) bool {
    return switch (c) {
        0x09 => true, // TAB
        0x20...0x7E => true, // SPACE to ~
        0x80...0xFF => true, // Extended ASCII
        else => false,
    };
}

/// Binary data byte (WHATWG MIME Sniffing §2)
///
/// A binary data byte is a byte in the range 0x00 to 0x08 (NUL to BS),
/// the byte 0x0B (VT), a byte in the range 0x0E to 0x1A (SO to SUB),
/// or a byte in the range 0x1C to 0x1F (FS to US).
///
/// Spec: https://mimesniff.spec.whatwg.org/#binary-data-byte
pub fn isBinaryDataByte(b: u8) bool {
    return switch (b) {
        0x00...0x08 => true, // NUL to BS
        0x0B => true, // VT
        0x0E...0x1A => true, // SO to SUB
        0x1C...0x1F => true, // FS to US
        else => false,
    };
}

/// Whitespace byte (WHATWG MIME Sniffing §2)
///
/// A whitespace byte (abbreviated 0xWS) is any one of the following bytes:
/// 0x09 (HT), 0x0A (LF), 0x0C (FF), 0x0D (CR), 0x20 (SP).
///
/// Spec: https://mimesniff.spec.whatwg.org/#whitespace-byte
pub fn isWhitespaceByte(b: u8) bool {
    return switch (b) {
        0x09 => true, // HT (tab)
        0x0A => true, // LF (line feed)
        0x0C => true, // FF (form feed)
        0x0D => true, // CR (carriage return)
        0x20 => true, // SP (space)
        else => false,
    };
}

/// Tag-terminating byte (WHATWG MIME Sniffing §2)
///
/// A tag-terminating byte (abbreviated 0xTT) is any one of the following bytes:
/// 0x20 (SP), 0x3E (">").
///
/// Spec: https://mimesniff.spec.whatwg.org/#tag-terminating-byte
pub fn isTagTerminatingByte(b: u8) bool {
    return switch (b) {
        0x20 => true, // SP (space)
        0x3E => true, // ">"
        else => false,
    };
}

// Tests

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
