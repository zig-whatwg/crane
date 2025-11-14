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





































