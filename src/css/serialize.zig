//! CSSOM §2.1 "Common Serializing Idioms": serialize an identifier - the
//! algorithm behind CSS.escape().
//!
//! https://drafts.csswg.org/cssom/#serialize-an-identifier

const std = @import("std");

/// "To serialize an identifier means to create a string represented by the
/// concatenation of, for each character of the identifier:" the steps below.
/// `ident` is UTF-8 (a DOMString as Crane holds it; an ill-formed sequence is
/// taken as U+FFFD, as a lone surrogate would have become). Owned by the
/// caller.
pub fn serializeIdentifier(allocator: std.mem.Allocator, ident: []const u8) std.mem.Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    // The code points, for the "first" and "second character" tests.
    var first: ?u21 = null;
    var index: usize = 0;
    var i: usize = 0;
    var count: usize = 0;
    {
        var j: usize = 0;
        while (j < ident.len) : (count += 1) j += codePointAt(ident, j).len;
    }

    while (i < ident.len) : (index += 1) {
        const cp = codePointAt(ident, i);
        const c = cp.value;
        i += cp.len;
        if (index == 0) first = c;

        if (c == 0) {
            // "If the character is NULL (U+0000), then the REPLACEMENT
            // CHARACTER (U+FFFD)."
            try appendCodePoint(allocator, &out, 0xFFFD);
        } else if ((c >= 0x01 and c <= 0x1F) or c == 0x7F) {
            // "If the character is in the range [\1-\1f] (U+0001 to U+001F)
            // or is U+007F, then the character escaped as code point."
            try escapeAsCodePoint(allocator, &out, c);
        } else if (index == 0 and isDigit(c)) {
            // "If the character is the first character and is in the range
            // [0-9] (U+0030 to U+0039), then the character escaped as code
            // point."
            try escapeAsCodePoint(allocator, &out, c);
        } else if (index == 1 and isDigit(c) and first.? == '-') {
            // "If the character is the second character and is in the range
            // [0-9] (U+0030 to U+0039) and the first character is a "-"
            // (U+002D), then the character escaped as code point."
            try escapeAsCodePoint(allocator, &out, c);
        } else if (index == 0 and c == '-' and count == 1) {
            // "If the character is the first character and is a "-"
            // (U+002D), and there is no second character, then the escaped
            // character."
            try out.appendSlice(allocator, "\\-");
        } else if (c >= 0x80 or c == '-' or c == '_' or isDigit(c) or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')) {
            // "If the character is not handled by one of the above rules and
            // is greater than or equal to U+0080, is "-" (U+002D) or "_"
            // (U+005F), or is in one of the ranges [0-9], [A-Z] or [a-z],
            // then the character itself."
            try appendCodePoint(allocator, &out, c);
        } else {
            // "Otherwise, the escaped character."
            try out.append(allocator, '\\');
            try appendCodePoint(allocator, &out, c);
        }
    }
    return out.toOwnedSlice(allocator);
}

fn isDigit(c: u21) bool {
    return c >= '0' and c <= '9';
}

/// "To escape a character as code point means to create a string of "\"
/// (U+005C), followed by the Unicode code point as the smallest possible
/// number of hexadecimal digits in the range 0-9 a-f (U+0030 to U+0039 and
/// U+0061 to U+0066) to represent the code point in base 16, followed by a
/// single SPACE (U+0020)."
fn escapeAsCodePoint(allocator: std.mem.Allocator, out: *std.ArrayList(u8), c: u21) !void {
    var buf: [16]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "\\{x} ", .{c}) catch unreachable;
    try out.appendSlice(allocator, text);
}

fn appendCodePoint(allocator: std.mem.Allocator, out: *std.ArrayList(u8), c: u21) !void {
    var buf: [4]u8 = undefined;
    const n = std.unicode.utf8Encode(c, &buf) catch std.unicode.utf8Encode(0xFFFD, &buf) catch unreachable;
    try out.appendSlice(allocator, buf[0..n]);
}

const CodePoint = struct { value: u21, len: usize };

/// The code point at `i`; an ill-formed sequence is U+FFFD, one byte long.
fn codePointAt(s: []const u8, i: usize) CodePoint {
    const len = std.unicode.utf8ByteSequenceLength(s[i]) catch return .{ .value = 0xFFFD, .len = 1 };
    if (i + len > s.len) return .{ .value = 0xFFFD, .len = 1 };
    const value = std.unicode.utf8Decode(s[i .. i + len]) catch return .{ .value = 0xFFFD, .len = 1 };
    return .{ .value = value, .len = len };
}

fn expectSerialized(input: []const u8, expected: []const u8) !void {
    const got = try serializeIdentifier(std.testing.allocator, input);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

test "NULL becomes U+FFFD" {
    try expectSerialized("\x00", "\u{FFFD}");
    try expectSerialized("a\x00", "a\u{FFFD}");
    try expectSerialized("\x00b", "\u{FFFD}b");
}

test "a leading digit, and a digit after a leading -, are escaped as code points" {
    try expectSerialized("0a", "\\30 a");
    try expectSerialized("1a2b3c", "\\31 a2b3c");
    try expectSerialized("-0a", "-\\30 a");
    try expectSerialized("-1a2b3c", "-\\31 a2b3c");
    // Only right after a leading '-'.
    try expectSerialized("--a", "--a");
    try expectSerialized("a0", "a0");
}

test "a lone - is escaped as a character; - with more is not" {
    try expectSerialized("-", "\\-");
    try expectSerialized("-a", "-a");
    try expectSerialized("--", "--");
}

test "control characters and U+007F are escaped as code points, in lower-case hex with a trailing space" {
    try expectSerialized("\x01\x02\x1E\x1F", "\\1 \\2 \\1e \\1f ");
    try expectSerialized("\x7F", "\\7f ");
}

test "U+0080 and above, -, _, and ASCII letters and digits are themselves" {
    try expectSerialized("\u{80}\u{2D}\u{5F}\u{A9}", "\u{80}-_\u{A9}");
    try expectSerialized("\u{A0}\u{A1}\u{A2}", "\u{A0}\u{A1}\u{A2}");
    try expectSerialized("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    try expectSerialized("\u{1D306}", "\u{1D306}");
}

test "every other character is escaped as itself" {
    try expectSerialized(" !xy", "\\ \\!xy");
    try expectSerialized("&", "\\&");
    try expectSerialized("a#b.c", "a\\#b\\.c");
    try expectSerialized("\\", "\\\\");
}

test "the empty string serializes to the empty string" {
    try expectSerialized("", "");
}
