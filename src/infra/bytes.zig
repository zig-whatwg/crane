//! WHATWG Infra Byte Sequence Operations
//!
//! Spec: https://infra.spec.whatwg.org/#byte-sequences
//!
//! A byte sequence is a sequence of bytes (8-bit unsigned integers).

const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;

pub const ByteSequence = []const u8;

pub const ByteError = error{
    InvalidUtf8,
    InvalidIsomorphicEncoding,
    OutOfMemory,
};

/// Byte-lowercase a byte sequence.
/// WHATWG Infra Standard §4.4 line 443
pub fn byteLowercase(allocator: Allocator, bytes: ByteSequence) !ByteSequence {
    if (bytes.len == 0) {
        return &[_]u8{};
    }

    const result = try allocator.alloc(u8, bytes.len);
    for (bytes, 0..) |byte, i| {
        if (byte >= 0x41 and byte <= 0x5A) {
            result[i] = byte + 0x20;
        } else {
            result[i] = byte;
        }
    }
    return result;
}

/// Byte-uppercase a byte sequence.
/// WHATWG Infra Standard §4.4 line 445
pub fn byteUppercase(allocator: Allocator, bytes: ByteSequence) !ByteSequence {
    if (bytes.len == 0) {
        return &[_]u8{};
    }

    const result = try allocator.alloc(u8, bytes.len);
    for (bytes, 0..) |byte, i| {
        if (byte >= 0x61 and byte <= 0x7A) {
            result[i] = byte - 0x20;
        } else {
            result[i] = byte;
        }
    }
    return result;
}

/// Check if two byte sequences are a byte-case-insensitive match.
/// WHATWG Infra Standard §4.4 line 447
pub fn byteCaseInsensitiveMatch(a: ByteSequence, b: ByteSequence) bool {
    if (a.len != b.len) return false;

    for (a, b) |byte_a, byte_b| {
        const lower_a = if (byte_a >= 0x41 and byte_a <= 0x5A) byte_a + 0x20 else byte_a;
        const lower_b = if (byte_b >= 0x41 and byte_b <= 0x5A) byte_b + 0x20 else byte_b;
        if (lower_a != lower_b) return false;
    }

    return true;
}

/// Check if a byte sequence is a prefix of another byte sequence.
/// WHATWG Infra Standard §4.4 lines 449-466
///
/// A byte sequence `potentialPrefix` is a **prefix** of a byte sequence `input`
/// if the algorithm returns true.
/// Synonym: "`input` **starts with** `potentialPrefix`" (line 467)
pub fn isPrefix(potentialPrefix: ByteSequence, input: ByteSequence) bool {
    if (potentialPrefix.len > input.len) return false;

    var i: usize = 0;
    while (i < potentialPrefix.len) {
        if (potentialPrefix[i] != input[i]) return false;
        i += 1;
    }

    return true;
}

/// Check if one byte sequence is byte less than another.
/// WHATWG Infra Standard §4.4 line 469-479
pub fn byteLessThan(a: ByteSequence, b: ByteSequence) bool {
    if (isPrefix(b, a)) return false;
    if (isPrefix(a, b)) return true;

    const min_len = @min(a.len, b.len);

    for (0..min_len) |i| {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }

    return a.len < b.len;
}

/// Check if all bytes in a byte sequence are ASCII bytes.
pub fn isAsciiByteSequence(bytes: ByteSequence) bool {
    for (bytes) |byte| {
        if (byte > 0x7F) return false;
    }
    return true;
}

/// Decode a byte sequence as UTF-8.
pub fn decodeAsUtf8(allocator: Allocator, bytes: ByteSequence) !String {
    const string_module = @import("string.zig");
    return string_module.utf8ToUtf16(allocator, bytes);
}

pub fn utf8Encode(allocator: Allocator, string: String) !ByteSequence {
    const string_module = @import("string.zig");
    return string_module.utf16ToUtf8(allocator, string);
}

/// Isomorphic decode a byte sequence.
/// WHATWG Infra Standard §4.4 line 481-482
pub fn isomorphicDecode(allocator: Allocator, bytes: ByteSequence) !String {
    if (bytes.len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, bytes.len);
    for (bytes, 0..) |byte, i| {
        result[i] = @as(u16, byte);
    }
    return result;
}

/// Isomorphic encode an isomorphic string.
/// WHATWG Infra Standard §4.6 line 695
pub fn isomorphicEncode(allocator: Allocator, string: String) !ByteSequence {
    if (string.len == 0) {
        return &[_]u8{};
    }

    const result = try allocator.alloc(u8, string.len);
    errdefer allocator.free(result);

    for (string, 0..) |c, i| {
        if (c > 0xFF) {
            return ByteError.InvalidIsomorphicEncoding;
        }
        result[i] = @as(u8, @intCast(c));
    }

    return result;
}

test "byteLessThan - less than" {
    const a = [_]u8{ 0x01, 0x02, 0x03 };
    const b = [_]u8{ 0x01, 0x02, 0x04 };
    try std.testing.expect(byteLessThan(&a, &b));
}

test "byteLessThan - equal" {
    const a = [_]u8{ 0x01, 0x02, 0x03 };
    const b = [_]u8{ 0x01, 0x02, 0x03 };
    try std.testing.expect(!byteLessThan(&a, &b));
}

test "byteLessThan - greater than" {
    const a = [_]u8{ 0x01, 0x02, 0x04 };
    const b = [_]u8{ 0x01, 0x02, 0x03 };
    try std.testing.expect(!byteLessThan(&a, &b));
}

test "byteLessThan - shorter is less" {
    const a = [_]u8{ 0x01, 0x02 };
    const b = [_]u8{ 0x01, 0x02, 0x03 };
    try std.testing.expect(byteLessThan(&a, &b));
}

test "byteLessThan - longer is greater" {
    const a = [_]u8{ 0x01, 0x02, 0x03 };
    const b = [_]u8{ 0x01, 0x02 };
    try std.testing.expect(!byteLessThan(&a, &b));
}

test "isAsciiByteSequence - pure ASCII" {
    const bytes = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiByteSequence(&bytes));
}

test "isAsciiByteSequence - contains high byte" {
    const bytes = [_]u8{ 'h', 0x80, 'l', 'l', 'o' };
    try std.testing.expect(!isAsciiByteSequence(&bytes));
}

test "isAsciiByteSequence - empty" {
    const bytes = [_]u8{};
    try std.testing.expect(isAsciiByteSequence(&bytes));
}

test "decodeAsUtf8 - valid UTF-8" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const result = try decodeAsUtf8(allocator, &bytes);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "decodeAsUtf8 - Unicode" {
    const allocator = std.testing.allocator;
    const bytes = "héllo";
    const result = try decodeAsUtf8(allocator, bytes);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "decodeAsUtf8 - invalid UTF-8" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 0xFF, 0xFE };
    const result = decodeAsUtf8(allocator, &bytes);
    try std.testing.expectError(error.InvalidUtf8, result);
}

test "utf8Encode - ASCII" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try utf8Encode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello", result);
}

test "utf8Encode - Unicode BMP" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    const result = try utf8Encode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("héllo", result);
}

test "utf8Encode - surrogate pairs" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 0xD83D, 0xDCA9 };
    const result = try utf8Encode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("💩", result);
}

test "isomorphicDecode - byte sequence to string" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 0x41, 0x42, 0x43, 0xFF };
    const result = try isomorphicDecode(allocator, &bytes);
    defer allocator.free(result);

    const expected = [_]u16{ 0x0041, 0x0042, 0x0043, 0x00FF };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "isomorphicDecode - empty" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{};
    const result = try isomorphicDecode(allocator, &bytes);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "isomorphicEncode - string to bytes" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 0x0041, 0x0042, 0x0043, 0x00FF };
    const result = try isomorphicEncode(allocator, &string);
    defer allocator.free(result);

    const expected = [_]u8{ 0x41, 0x42, 0x43, 0xFF };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "isomorphicEncode - error on high code unit" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 0x0041, 0x0100 };
    const result = isomorphicEncode(allocator, &string);
    try std.testing.expectError(ByteError.InvalidIsomorphicEncoding, result);
}

test "isomorphicEncode - empty" {
    const allocator = std.testing.allocator;
    const string = [_]u16{};
    const result = try isomorphicEncode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "roundtrip - isomorphicDecode then encode" {
    const allocator = std.testing.allocator;
    const original = [_]u8{ 0x41, 0x42, 0x43, 0xFF };

    const string = try isomorphicDecode(allocator, &original);
    defer allocator.free(string);

    const bytes = try isomorphicEncode(allocator, string);
    defer allocator.free(bytes);

    try std.testing.expectEqualSlices(u8, &original, bytes);
}

test "byteLowercase - uppercase ASCII" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 'H', 'E', 'L', 'L', 'O' };
    const result = try byteLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "byteLowercase - mixed case" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 'H', 'e', 'L', 'l', 'O', '1', '2', '3' };
    const result = try byteLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u8{ 'h', 'e', 'l', 'l', 'o', '1', '2', '3' };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "byteUppercase - lowercase ASCII" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const result = try byteUppercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u8{ 'H', 'E', 'L', 'L', 'O' };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "byteUppercase - mixed case" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 'h', 'E', 'l', 'L', 'o', '1', '2', '3' };
    const result = try byteUppercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u8{ 'H', 'E', 'L', 'L', 'O', '1', '2', '3' };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "byteCaseInsensitiveMatch - same case" {
    const a = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(byteCaseInsensitiveMatch(&a, &b));
}

test "byteCaseInsensitiveMatch - different case" {
    const a = [_]u8{ 'H', 'E', 'L', 'L', 'O' };
    const b = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(byteCaseInsensitiveMatch(&a, &b));
}

test "byteCaseInsensitiveMatch - not matching" {
    const a = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u8{ 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expect(!byteCaseInsensitiveMatch(&a, &b));
}

test "byteCaseInsensitiveMatch - different lengths" {
    const a = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u8{ 'h', 'e', 'l', 'l' };
    try std.testing.expect(!byteCaseInsensitiveMatch(&a, &b));
}

test "isPrefix - valid prefix" {
    const prefix = [_]u8{ 'h', 'e', 'l' };
    const input = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isPrefix(&prefix, &input));
}

test "isPrefix - not a prefix" {
    const prefix = [_]u8{ 'w', 'o', 'r' };
    const input = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(!isPrefix(&prefix, &input));
}

test "isPrefix - empty prefix" {
    const prefix = [_]u8{};
    const input = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isPrefix(&prefix, &input));
}

test "isPrefix - same length" {
    const prefix = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const input = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isPrefix(&prefix, &input));
}

test "isPrefix - prefix longer than input" {
    const prefix = [_]u8{ 'h', 'e', 'l', 'l', 'o', 'w' };
    const input = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(!isPrefix(&prefix, &input));
}

test "byteLessThan - with prefix check" {
    const a = [_]u8{ 'h', 'e', 'l' };
    const b = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(byteLessThan(&a, &b));
    try std.testing.expect(!byteLessThan(&b, &a));
}
