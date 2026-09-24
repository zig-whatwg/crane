//! WHATWG Infra Base64 Operations
//!
//! Spec: https://infra.spec.whatwg.org/#forgiving-base64
//!
//! Forgiving Base64 encode and decode operations. The "forgiving" decode
//! algorithm strips ASCII whitespace before decoding.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Base64Error = error{
    InvalidBase64,
    OutOfMemory,
};

pub fn forgivingBase64Encode(allocator: Allocator, data: []const u8) ![]const u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    const result = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(result);

    const encoded = encoder.encode(result, data);
    return encoded;
}

/// Infra "forgiving-base64 decode": the bytes `data` encodes, or
/// error.InvalidBase64 for "failure".
///
/// Not RFC 4648 decoding, which std.base64 does: that demands padding and
/// rejects set bits past the last whole byte, where this allows the padding
/// to be missing and discards the extra bits (step 9).
pub fn forgivingBase64Decode(allocator: Allocator, data: []const u8) Base64Error![]u8 {
    // Step 1: Remove all ASCII whitespace from data.
    var stripped: std.ArrayListUnmanaged(u8) = .empty;
    defer stripped.deinit(allocator);
    try stripped.ensureTotalCapacity(allocator, data.len);
    for (data) |c| {
        if (!isAsciiWhitespace(c)) stripped.appendAssumeCapacity(c);
    }
    var chars = stripped.items;

    // Step 2: If data's code point length divides by 4 leaving no remainder,
    // remove one or two trailing U+003D (=).
    //
    // Lengths here are in bytes, not code points. They differ only for a
    // non-ASCII character, and step 4 fails every one of those.
    if (chars.len % 4 == 0) {
        if (std.mem.endsWith(u8, chars, "==")) {
            chars = chars[0 .. chars.len - 2];
        } else if (std.mem.endsWith(u8, chars, "=")) {
            chars = chars[0 .. chars.len - 1];
        }
    }

    // Step 3: A remainder of 1 is failure.
    if (chars.len % 4 == 1) return error.InvalidBase64;

    // Steps 5-8: accumulate six bits per character; every 24 are three
    // bytes. Step 4 - a character outside the alphabet is failure - is the
    // lookup's null.
    var output: std.ArrayListUnmanaged(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, chars.len / 4 * 3 + 2);
    var buffer: u32 = 0;
    var bits: u8 = 0;
    for (chars) |c| {
        const n = alphabetValue(c) orelse return error.InvalidBase64;
        buffer = (buffer << 6) | n;
        bits += 6;
        if (bits == 24) {
            output.appendAssumeCapacity(@truncate(buffer >> 16));
            output.appendAssumeCapacity(@truncate(buffer >> 8));
            output.appendAssumeCapacity(@truncate(buffer));
            buffer = 0;
            bits = 0;
        }
    }

    // Step 9: 12 bits left are one byte and 4 discarded; 18 are two bytes
    // and 2 discarded.
    switch (bits) {
        0 => {},
        12 => output.appendAssumeCapacity(@truncate(buffer >> 4)),
        18 => {
            output.appendAssumeCapacity(@truncate(buffer >> 10));
            output.appendAssumeCapacity(@truncate(buffer >> 2));
        },
        // Step 3 left no other remainder.
        else => unreachable,
    }

    // Step 10.
    return output.toOwnedSlice(allocator);
}

/// RFC 4648 Table 1: The Base 64 Alphabet.
fn alphabetValue(c: u8) ?u32 {
    return switch (c) {
        'A'...'Z' => c - 'A',
        'a'...'z' => c - 'a' + 26,
        '0'...'9' => c - '0' + 52,
        '+' => 62,
        '/' => 63,
        else => null,
    };
}

const ascii_whitespace_table = blk: {
    var table: [256]bool = [_]bool{false} ** 256;
    table[0x09] = true;
    table[0x0A] = true;
    table[0x0C] = true;
    table[0x0D] = true;
    table[0x20] = true;
    break :blk table;
};

inline fn isAsciiWhitespace(c: u8) bool {
    return ascii_whitespace_table[c];
}

/// WPT's own vectors, fetch/data-urls/resources/base64.json: the input, and
/// the decoded bytes or null for failure.
const Vector = struct { input: []const u8, output: ?[]const u8 };
const wpt_vectors = [_]Vector{
    .{ .input = "", .output = &[_]u8{} },
    .{ .input = "abcd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = " abcd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "abcd ", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = " abcd===", .output = null },
    .{ .input = "abcd=== ", .output = null },
    .{ .input = "abcd ===", .output = null },
    .{ .input = "a", .output = null },
    .{ .input = "ab", .output = &[_]u8{105} },
    .{ .input = "abc", .output = &[_]u8{ 105, 183 } },
    .{ .input = "abcde", .output = null },
    .{ .input = "\xf0\x90\x80\x80", .output = null },
    .{ .input = "=", .output = null },
    .{ .input = "==", .output = null },
    .{ .input = "===", .output = null },
    .{ .input = "====", .output = null },
    .{ .input = "=====", .output = null },
    .{ .input = "a=", .output = null },
    .{ .input = "a==", .output = null },
    .{ .input = "a===", .output = null },
    .{ .input = "a====", .output = null },
    .{ .input = "a=====", .output = null },
    .{ .input = "ab=", .output = null },
    .{ .input = "ab==", .output = &[_]u8{105} },
    .{ .input = "ab===", .output = null },
    .{ .input = "ab====", .output = null },
    .{ .input = "ab=====", .output = null },
    .{ .input = "abc=", .output = &[_]u8{ 105, 183 } },
    .{ .input = "abc==", .output = null },
    .{ .input = "abc===", .output = null },
    .{ .input = "abc====", .output = null },
    .{ .input = "abc=====", .output = null },
    .{ .input = "abcd=", .output = null },
    .{ .input = "abcd==", .output = null },
    .{ .input = "abcd===", .output = null },
    .{ .input = "abcd====", .output = null },
    .{ .input = "abcd=====", .output = null },
    .{ .input = "abcde=", .output = null },
    .{ .input = "abcde==", .output = null },
    .{ .input = "abcde===", .output = null },
    .{ .input = "abcde====", .output = null },
    .{ .input = "abcde=====", .output = null },
    .{ .input = "=a", .output = null },
    .{ .input = "=a=", .output = null },
    .{ .input = "a=b", .output = null },
    .{ .input = "a=b=", .output = null },
    .{ .input = "ab=c", .output = null },
    .{ .input = "ab=c=", .output = null },
    .{ .input = "abc=d", .output = null },
    .{ .input = "abc=d=", .output = null },
    .{ .input = "ab\x0bcd", .output = null },
    .{ .input = "ab\xe3\x80\x80cd", .output = null },
    .{ .input = "ab\xe3\x80\x81cd", .output = null },
    .{ .input = "ab\x09cd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "ab\x0acd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "ab\x0ccd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "ab\x0dcd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "ab cd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "ab\xc2\xa0cd", .output = null },
    .{ .input = "ab\x09\x0a\x0c\x0d cd", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = " \x09\x0a\x0c\x0d ab\x09\x0a\x0c\x0d cd\x09\x0a\x0c\x0d ", .output = &[_]u8{ 105, 183, 29 } },
    .{ .input = "ab\x09\x0a\x0c\x0d =\x09\x0a\x0c\x0d =\x09\x0a\x0c\x0d ", .output = &[_]u8{105} },
    .{ .input = "A", .output = null },
    .{ .input = "/A", .output = &[_]u8{252} },
    .{ .input = "//A", .output = &[_]u8{ 255, 240 } },
    .{ .input = "///A", .output = &[_]u8{ 255, 255, 192 } },
    .{ .input = "////A", .output = null },
    .{ .input = "/", .output = null },
    .{ .input = "A/", .output = &[_]u8{3} },
    .{ .input = "AA/", .output = &[_]u8{ 0, 15 } },
    .{ .input = "AAAA/", .output = null },
    .{ .input = "AAA/", .output = &[_]u8{ 0, 0, 63 } },
    .{ .input = "\x00nonsense", .output = null },
    .{ .input = "abcd\x00nonsense", .output = null },
    .{ .input = "YQ", .output = &[_]u8{97} },
    .{ .input = "YR", .output = &[_]u8{97} },
    .{ .input = "~~", .output = null },
    .{ .input = "..", .output = null },
    .{ .input = "--", .output = null },
    .{ .input = "__", .output = null },
};

test "forgiving-base64 decode matches WPT's vectors" {
    for (wpt_vectors) |vector| {
        const decoded = forgivingBase64Decode(std.testing.allocator, vector.input) catch |err| switch (err) {
            error.InvalidBase64 => {
                if (vector.output != null) {
                    std.debug.print("failed to decode \"{s}\"\n", .{vector.input});
                    return error.TestUnexpectedResult;
                }
                continue;
            },
            else => return err,
        };
        defer std.testing.allocator.free(decoded);
        const expected = vector.output orelse {
            std.debug.print("decoded \"{s}\", which is not base64\n", .{vector.input});
            return error.TestUnexpectedResult;
        };
        try std.testing.expectEqualSlices(u8, expected, decoded);
    }
}

test "forgiving-base64 encode pads to a multiple of four" {
    const cases = [_][2][]const u8{
        .{ "", "" },
        .{ "f", "Zg==" },
        .{ "fo", "Zm8=" },
        .{ "foo", "Zm9v" },
        .{ "\xff\xfe", "//4=" },
    };
    for (cases) |case| {
        const encoded = try forgivingBase64Encode(std.testing.allocator, case[0]);
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqualStrings(case[1], encoded);
    }
}
