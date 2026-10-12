//! XML 1.0 (Fifth Edition) character classes.
//!
//! Spec: specs/w3c/REC-xml.md, §2.2 "Characters" ([2] Char), §2.3 "Common
//! Syntactic Constructs" ([3] S, [4] NameStartChar, [4a] NameChar, [13]
//! PubidChar), and Namespaces in XML 1.0 (specs/w3c/xml-names.md) [4] NCName.
//!
//! The parser works on UTF-8. Every predicate here takes a code point; the
//! decoding helpers return the code point at a byte offset and its length, or
//! null where the bytes are not well-formed UTF-8 (which the XML parser treats
//! as a fatal error: an encoded surrogate, an overlong form or a truncated
//! sequence is not a Char).

const std = @import("std");

/// [2] Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
pub fn isChar(c: u21) bool {
    return switch (c) {
        0x9, 0xA, 0xD => true,
        0x20...0xD7FF => true,
        0xE000...0xFFFD => true,
        0x10000...0x10FFFF => true,
        else => false,
    };
}

/// [3] S ::= (#x20 | #x9 | #xD | #xA)+ - one of its characters.
pub fn isSpace(c: u21) bool {
    return c == 0x20 or c == 0x9 or c == 0xD or c == 0xA;
}

/// [4] NameStartChar ::= ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6]
///   | [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D]
///   | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF]
///   | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
pub fn isNameStartChar(c: u21) bool {
    return switch (c) {
        ':', 'A'...'Z', '_', 'a'...'z' => true,
        0xC0...0xD6, 0xD8...0xF6, 0xF8...0x2FF => true,
        0x370...0x37D, 0x37F...0x1FFF, 0x200C...0x200D => true,
        0x2070...0x218F, 0x2C00...0x2FEF, 0x3001...0xD7FF => true,
        0xF900...0xFDCF, 0xFDF0...0xFFFD, 0x10000...0xEFFFF => true,
        else => false,
    };
}

/// [4a] NameChar ::= NameStartChar | "-" | "." | [0-9] | #xB7
///   | [#x0300-#x036F] | [#x203F-#x2040]
pub fn isNameChar(c: u21) bool {
    return isNameStartChar(c) or switch (c) {
        '-', '.', '0'...'9', 0xB7 => true,
        0x300...0x36F, 0x203F...0x2040 => true,
        else => false,
    };
}

/// [13] PubidChar ::= #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
pub fn isPubidChar(c: u21) bool {
    return switch (c) {
        0x20, 0xD, 0xA => true,
        'a'...'z', 'A'...'Z', '0'...'9' => true,
        '-', '\'', '(', ')', '+', ',', '.', '/', ':', '=', '?', ';', '!', '*', '#', '@', '$', '_', '%' => true,
        else => false,
    };
}

/// A decoded code point and the number of bytes it took.
pub const Decoded = struct { c: u21, len: u3 };

/// The code point at `bytes[i]`, or null for bytes that are not well-formed
/// UTF-8 (including an encoded surrogate). `i` must be in range.
pub fn decodeAt(bytes: []const u8, i: usize) ?Decoded {
    const b0 = bytes[i];
    if (b0 < 0x80) return .{ .c = b0, .len = 1 };
    const len = std.unicode.utf8ByteSequenceLength(b0) catch return null;
    if (i + len > bytes.len) return null;
    const c = std.unicode.utf8Decode(bytes[i..][0..len]) catch return null;
    return .{ .c = c, .len = len };
}

/// Whether `name` matches [5] Name ::= NameStartChar (NameChar)*.
pub fn isName(name: []const u8) bool {
    if (name.len == 0) return false;
    var i: usize = 0;
    var first = true;
    while (i < name.len) {
        const d = decodeAt(name, i) orelse return false;
        if (first) {
            if (!isNameStartChar(d.c)) return false;
            first = false;
        } else if (!isNameChar(d.c)) return false;
        i += d.len;
    }
    return true;
}

/// Whether `name` matches Namespaces in XML [4] NCName ::= Name - (Char* ':' Char*).
pub fn isNCName(name: []const u8) bool {
    return isName(name) and std.mem.indexOfScalar(u8, name, ':') == null;
}

/// The byte offset of the first code point in `bytes` that is not a [2]
/// Char (or is not well-formed UTF-8), or null when every one is.
pub fn firstNonChar(bytes: []const u8) ?usize {
    var i: usize = 0;
    while (i < bytes.len) {
        const b = bytes[i];
        if (b >= 0x20 and b < 0x80) {
            i += 1;
            continue;
        }
        const d = decodeAt(bytes, i) orelse return i;
        if (!isChar(d.c)) return i;
        i += d.len;
    }
    return null;
}

test "Char excludes C0 controls other than tab, LF and CR, and the noncharacters FFFE/FFFF" {
    try std.testing.expect(isChar('\t'));
    try std.testing.expect(isChar('\n'));
    try std.testing.expect(isChar('\r'));
    try std.testing.expect(!isChar(0));
    try std.testing.expect(!isChar(0x1F));
    try std.testing.expect(isChar(0xD7FF));
    try std.testing.expect(!isChar(0xD800));
    try std.testing.expect(!isChar(0xFFFE));
    try std.testing.expect(!isChar(0xFFFF));
    try std.testing.expect(isChar(0x10FFFF));
}

test "Name productions follow the Fifth Edition ranges" {
    try std.testing.expect(isName("foo"));
    try std.testing.expect(isName("a:b"));
    try std.testing.expect(isName("_x-1.2"));
    try std.testing.expect(isName("\u{00E9}t\u{00E9}"));
    try std.testing.expect(!isName("8:test"));
    try std.testing.expect(!isName("-a"));
    try std.testing.expect(!isName(""));
    try std.testing.expect(isNCName("foo"));
    try std.testing.expect(!isNCName("a:b"));
}

test "firstNonChar finds controls and malformed UTF-8" {
    try std.testing.expectEqual(@as(?usize, null), firstNonChar("abc \t\n"));
    try std.testing.expectEqual(@as(?usize, 1), firstNonChar("a\x01b"));
    try std.testing.expectEqual(@as(?usize, 2), firstNonChar("ab\xED\xA0\x80"));
    try std.testing.expectEqual(@as(?usize, 0), firstNonChar("\xEF\xBF\xBE"));
}
