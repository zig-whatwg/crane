//! WHATWG Infra Code Point Operations
//!
//! Spec: https://infra.spec.whatwg.org/#code-points
//!
//! A code point is a Unicode code point in the range U+0000 to U+10FFFF.
//! This module provides predicates for classifying code points and operations
//! for working with surrogate pairs.

const std = @import("std");

pub const CodePoint = u21;

pub inline fn isSurrogate(cp: CodePoint) bool {
    return cp >= 0xD800 and cp <= 0xDFFF;
}

pub inline fn isScalarValue(cp: CodePoint) bool {
    return !isSurrogate(cp);
}

pub fn isNoncharacter(cp: CodePoint) bool {
    if (cp >= 0xFDD0 and cp <= 0xFDEF) {
        return true;
    }
    return switch (cp) {
        0xFFFE, 0xFFFF, 0x1FFFE, 0x1FFFF, 0x2FFFE, 0x2FFFF, 0x3FFFE, 0x3FFFF, 0x4FFFE, 0x4FFFF, 0x5FFFE, 0x5FFFF, 0x6FFFE, 0x6FFFF, 0x7FFFE, 0x7FFFF, 0x8FFFE, 0x8FFFF, 0x9FFFE, 0x9FFFF, 0xAFFFE, 0xAFFFF, 0xBFFFE, 0xBFFFF, 0xCFFFE, 0xCFFFF, 0xDFFFE, 0xDFFFF, 0xEFFFE, 0xEFFFF, 0xFFFFE, 0xFFFFF, 0x10FFFE, 0x10FFFF => true,
        else => false,
    };
}

pub inline fn isAsciiCodePoint(cp: CodePoint) bool {
    return cp <= 0x7F;
}

pub inline fn isAsciiTabOrNewline(cp: CodePoint) bool {
    return cp == 0x0009 or cp == 0x000A or cp == 0x000D;
}

pub inline fn isAsciiWhitespaceCodePoint(cp: CodePoint) bool {
    return isAsciiTabOrNewline(cp) or cp == 0x000C or cp == 0x0020;
}

pub inline fn isC0Control(cp: CodePoint) bool {
    return cp <= 0x001F;
}

pub inline fn isC0ControlOrSpace(cp: CodePoint) bool {
    return isC0Control(cp) or cp == 0x0020;
}

pub inline fn isControl(cp: CodePoint) bool {
    return isC0Control(cp) or (cp >= 0x007F and cp <= 0x009F);
}

pub inline fn isAsciiDigit(cp: CodePoint) bool {
    return cp >= '0' and cp <= '9';
}

pub inline fn isAsciiUpperHexDigit(cp: CodePoint) bool {
    return isAsciiDigit(cp) or (cp >= 'A' and cp <= 'F');
}

pub inline fn isAsciiLowerHexDigit(cp: CodePoint) bool {
    return isAsciiDigit(cp) or (cp >= 'a' and cp <= 'f');
}

pub inline fn isAsciiHexDigit(cp: CodePoint) bool {
    return isAsciiUpperHexDigit(cp) or isAsciiLowerHexDigit(cp);
}

pub inline fn isAsciiUpperAlpha(cp: CodePoint) bool {
    return cp >= 'A' and cp <= 'Z';
}

pub inline fn isAsciiLowerAlpha(cp: CodePoint) bool {
    return cp >= 'a' and cp <= 'z';
}

pub inline fn isAsciiAlpha(cp: CodePoint) bool {
    return isAsciiUpperAlpha(cp) or isAsciiLowerAlpha(cp);
}

pub inline fn isAsciiAlphanumeric(cp: CodePoint) bool {
    return isAsciiAlpha(cp) or isAsciiDigit(cp);
}

pub inline fn isLeadSurrogate(cp: CodePoint) bool {
    return cp >= 0xD800 and cp <= 0xDBFF;
}

pub inline fn isTrailSurrogate(cp: CodePoint) bool {
    return cp >= 0xDC00 and cp <= 0xDFFF;
}

pub const SurrogatePair = struct {
    high: u16,
    low: u16,
};

pub const CodePointError = error{
    InvalidCodePoint,
    InvalidSurrogatePair,
};

pub fn encodeSurrogatePair(cp: CodePoint) CodePointError!SurrogatePair {
    if (cp < 0x10000 or cp > 0x10FFFF) {
        return CodePointError.InvalidCodePoint;
    }

    const offset = cp - 0x10000;
    const high = @as(u16, @intCast(0xD800 + (offset >> 10)));
    const low = @as(u16, @intCast(0xDC00 + (offset & 0x3FF)));

    return SurrogatePair{ .high = high, .low = low };
}

pub fn decodeSurrogatePair(high: u16, low: u16) CodePointError!CodePoint {
    if (!isLeadSurrogate(high) or !isTrailSurrogate(low)) {
        return CodePointError.InvalidSurrogatePair;
    }

    const high_bits = @as(CodePoint, high - 0xD800);
    const low_bits = @as(CodePoint, low - 0xDC00);
    return 0x10000 + (high_bits << 10) + low_bits;
}

test "isSurrogate - lead surrogate" {
    try std.testing.expect(isSurrogate(0xD800));
    try std.testing.expect(isSurrogate(0xDBFF));
}

test "isSurrogate - trail surrogate" {
    try std.testing.expect(isSurrogate(0xDC00));
    try std.testing.expect(isSurrogate(0xDFFF));
}

test "isSurrogate - non-surrogate" {
    try std.testing.expect(!isSurrogate(0xD7FF));
    try std.testing.expect(!isSurrogate(0xE000));
    try std.testing.expect(!isSurrogate('A'));
}

test "isScalarValue - scalar values" {
    try std.testing.expect(isScalarValue(0x0000));
    try std.testing.expect(isScalarValue(0xD7FF));
    try std.testing.expect(isScalarValue(0xE000));
    try std.testing.expect(isScalarValue(0x10FFFF));
}

test "isScalarValue - surrogates not scalar" {
    try std.testing.expect(!isScalarValue(0xD800));
    try std.testing.expect(!isScalarValue(0xDFFF));
}

test "isNoncharacter - U+FDD0 to U+FDEF" {
    try std.testing.expect(isNoncharacter(0xFDD0));
    try std.testing.expect(isNoncharacter(0xFDEF));
}

test "isNoncharacter - plane endings" {
    try std.testing.expect(isNoncharacter(0xFFFE));
    try std.testing.expect(isNoncharacter(0xFFFF));
    try std.testing.expect(isNoncharacter(0x10FFFE));
    try std.testing.expect(isNoncharacter(0x10FFFF));
}

test "isNoncharacter - regular characters" {
    try std.testing.expect(!isNoncharacter('A'));
    try std.testing.expect(!isNoncharacter(0xFDCF));
    try std.testing.expect(!isNoncharacter(0xFDF0));
}

test "isAsciiCodePoint - ASCII range" {
    try std.testing.expect(isAsciiCodePoint(0x00));
    try std.testing.expect(isAsciiCodePoint('A'));
    try std.testing.expect(isAsciiCodePoint(0x7F));
}

test "isAsciiCodePoint - non-ASCII" {
    try std.testing.expect(!isAsciiCodePoint(0x80));
    try std.testing.expect(!isAsciiCodePoint(0xFF));
    try std.testing.expect(!isAsciiCodePoint(0x1234));
}

test "isAsciiTabOrNewline" {
    try std.testing.expect(isAsciiTabOrNewline(0x09));
    try std.testing.expect(isAsciiTabOrNewline(0x0A));
    try std.testing.expect(isAsciiTabOrNewline(0x0D));
    try std.testing.expect(!isAsciiTabOrNewline(' '));
    try std.testing.expect(!isAsciiTabOrNewline('A'));
}

test "isAsciiWhitespaceCodePoint" {
    try std.testing.expect(isAsciiWhitespaceCodePoint(0x09));
    try std.testing.expect(isAsciiWhitespaceCodePoint(0x0A));
    try std.testing.expect(isAsciiWhitespaceCodePoint(0x0C));
    try std.testing.expect(isAsciiWhitespaceCodePoint(0x0D));
    try std.testing.expect(isAsciiWhitespaceCodePoint(0x20));
    try std.testing.expect(!isAsciiWhitespaceCodePoint('A'));
}

test "isC0Control" {
    try std.testing.expect(isC0Control(0x00));
    try std.testing.expect(isC0Control(0x1F));
    try std.testing.expect(!isC0Control(0x20));
    try std.testing.expect(!isC0Control('A'));
}

test "isC0ControlOrSpace" {
    try std.testing.expect(isC0ControlOrSpace(0x00));
    try std.testing.expect(isC0ControlOrSpace(0x1F));
    try std.testing.expect(isC0ControlOrSpace(0x20));
    try std.testing.expect(!isC0ControlOrSpace('A'));
}

test "isControl - C0 controls" {
    try std.testing.expect(isControl(0x00));
    try std.testing.expect(isControl(0x1F));
}

test "isControl - DEL and C1 controls" {
    try std.testing.expect(isControl(0x7F));
    try std.testing.expect(isControl(0x80));
    try std.testing.expect(isControl(0x9F));
}

test "isControl - non-control" {
    try std.testing.expect(!isControl(0x20));
    try std.testing.expect(!isControl('A'));
    try std.testing.expect(!isControl(0xA0));
}

test "isAsciiDigit" {
    try std.testing.expect(isAsciiDigit('0'));
    try std.testing.expect(isAsciiDigit('5'));
    try std.testing.expect(isAsciiDigit('9'));
    try std.testing.expect(!isAsciiDigit('A'));
    try std.testing.expect(!isAsciiDigit('/'));
    try std.testing.expect(!isAsciiDigit(':'));
}

test "isAsciiUpperHexDigit" {
    try std.testing.expect(isAsciiUpperHexDigit('0'));
    try std.testing.expect(isAsciiUpperHexDigit('9'));
    try std.testing.expect(isAsciiUpperHexDigit('A'));
    try std.testing.expect(isAsciiUpperHexDigit('F'));
    try std.testing.expect(!isAsciiUpperHexDigit('a'));
    try std.testing.expect(!isAsciiUpperHexDigit('G'));
}

test "isAsciiLowerHexDigit" {
    try std.testing.expect(isAsciiLowerHexDigit('0'));
    try std.testing.expect(isAsciiLowerHexDigit('9'));
    try std.testing.expect(isAsciiLowerHexDigit('a'));
    try std.testing.expect(isAsciiLowerHexDigit('f'));
    try std.testing.expect(!isAsciiLowerHexDigit('A'));
    try std.testing.expect(!isAsciiLowerHexDigit('g'));
}

test "isAsciiHexDigit" {
    try std.testing.expect(isAsciiHexDigit('0'));
    try std.testing.expect(isAsciiHexDigit('9'));
    try std.testing.expect(isAsciiHexDigit('A'));
    try std.testing.expect(isAsciiHexDigit('F'));
    try std.testing.expect(isAsciiHexDigit('a'));
    try std.testing.expect(isAsciiHexDigit('f'));
    try std.testing.expect(!isAsciiHexDigit('G'));
    try std.testing.expect(!isAsciiHexDigit('g'));
}

test "isAsciiUpperAlpha" {
    try std.testing.expect(isAsciiUpperAlpha('A'));
    try std.testing.expect(isAsciiUpperAlpha('Z'));
    try std.testing.expect(!isAsciiUpperAlpha('a'));
    try std.testing.expect(!isAsciiUpperAlpha('0'));
    try std.testing.expect(!isAsciiUpperAlpha('@'));
    try std.testing.expect(!isAsciiUpperAlpha('['));
}

test "isAsciiLowerAlpha" {
    try std.testing.expect(isAsciiLowerAlpha('a'));
    try std.testing.expect(isAsciiLowerAlpha('z'));
    try std.testing.expect(!isAsciiLowerAlpha('A'));
    try std.testing.expect(!isAsciiLowerAlpha('0'));
    try std.testing.expect(!isAsciiLowerAlpha('`'));
    try std.testing.expect(!isAsciiLowerAlpha('{'));
}

test "isAsciiAlpha" {
    try std.testing.expect(isAsciiAlpha('A'));
    try std.testing.expect(isAsciiAlpha('Z'));
    try std.testing.expect(isAsciiAlpha('a'));
    try std.testing.expect(isAsciiAlpha('z'));
    try std.testing.expect(!isAsciiAlpha('0'));
    try std.testing.expect(!isAsciiAlpha('@'));
}

test "isAsciiAlphanumeric" {
    try std.testing.expect(isAsciiAlphanumeric('0'));
    try std.testing.expect(isAsciiAlphanumeric('9'));
    try std.testing.expect(isAsciiAlphanumeric('A'));
    try std.testing.expect(isAsciiAlphanumeric('Z'));
    try std.testing.expect(isAsciiAlphanumeric('a'));
    try std.testing.expect(isAsciiAlphanumeric('z'));
    try std.testing.expect(!isAsciiAlphanumeric(' '));
    try std.testing.expect(!isAsciiAlphanumeric('@'));
}

test "isLeadSurrogate" {
    try std.testing.expect(isLeadSurrogate(0xD800));
    try std.testing.expect(isLeadSurrogate(0xDBFF));
    try std.testing.expect(!isLeadSurrogate(0xD7FF));
    try std.testing.expect(!isLeadSurrogate(0xDC00));
}

test "isTrailSurrogate" {
    try std.testing.expect(isTrailSurrogate(0xDC00));
    try std.testing.expect(isTrailSurrogate(0xDFFF));
    try std.testing.expect(!isTrailSurrogate(0xDBFF));
    try std.testing.expect(!isTrailSurrogate(0xE000));
}

test "encodeSurrogatePair - U+10000" {
    const pair = try encodeSurrogatePair(0x10000);
    try std.testing.expectEqual(@as(u16, 0xD800), pair.high);
    try std.testing.expectEqual(@as(u16, 0xDC00), pair.low);
}

test "encodeSurrogatePair - U+10FFFF" {
    const pair = try encodeSurrogatePair(0x10FFFF);
    try std.testing.expectEqual(@as(u16, 0xDBFF), pair.high);
    try std.testing.expectEqual(@as(u16, 0xDFFF), pair.low);
}

test "encodeSurrogatePair - U+1F4A9 (pile of poo)" {
    const pair = try encodeSurrogatePair(0x1F4A9);
    try std.testing.expectEqual(@as(u16, 0xD83D), pair.high);
    try std.testing.expectEqual(@as(u16, 0xDCA9), pair.low);
}

test "encodeSurrogatePair - invalid (too small)" {
    const result = encodeSurrogatePair(0xFFFF);
    try std.testing.expectError(CodePointError.InvalidCodePoint, result);
}

test "encodeSurrogatePair - invalid (too large)" {
    const result = encodeSurrogatePair(0x110000);
    try std.testing.expectError(CodePointError.InvalidCodePoint, result);
}

test "decodeSurrogatePair - valid pair" {
    const cp = try decodeSurrogatePair(0xD83D, 0xDCA9);
    try std.testing.expectEqual(@as(CodePoint, 0x1F4A9), cp);
}

test "decodeSurrogatePair - minimum" {
    const cp = try decodeSurrogatePair(0xD800, 0xDC00);
    try std.testing.expectEqual(@as(CodePoint, 0x10000), cp);
}

test "decodeSurrogatePair - maximum" {
    const cp = try decodeSurrogatePair(0xDBFF, 0xDFFF);
    try std.testing.expectEqual(@as(CodePoint, 0x10FFFF), cp);
}

test "decodeSurrogatePair - invalid high" {
    const result = decodeSurrogatePair(0xDC00, 0xDC00);
    try std.testing.expectError(CodePointError.InvalidSurrogatePair, result);
}

test "decodeSurrogatePair - invalid low" {
    const result = decodeSurrogatePair(0xD800, 0xD800);
    try std.testing.expectError(CodePointError.InvalidSurrogatePair, result);
}

test "surrogate roundtrip - encode then decode" {
    const original: CodePoint = 0x1F600;
    const pair = try encodeSurrogatePair(original);
    const decoded = try decodeSurrogatePair(pair.high, pair.low);
    try std.testing.expectEqual(original, decoded);
}
