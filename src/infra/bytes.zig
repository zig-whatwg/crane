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


































