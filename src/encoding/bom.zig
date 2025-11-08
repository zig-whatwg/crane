//! BOM (Byte Order Mark) Handling
//!
//! WHATWG Encoding Standard § 6 - Hooks for standards
//! https://encoding.spec.whatwg.org/#bom-sniff
//!
//! Provides BOM detection and removal functions for UTF-8, UTF-16BE, and UTF-16LE.

const std = @import("std");

/// Byte Order Mark for UTF-8: 0xEF 0xBB 0xBF
pub const UTF8_BOM = [3]u8{ 0xEF, 0xBB, 0xBF };

/// Byte Order Mark for UTF-16BE: 0xFE 0xFF
pub const UTF16BE_BOM = [2]u8{ 0xFE, 0xFF };

/// Byte Order Mark for UTF-16LE: 0xFF 0xFE
pub const UTF16LE_BOM = [2]u8{ 0xFF, 0xFE };

/// Encoding detected from BOM
pub const BomEncoding = enum {
    utf8,
    utf16be,
    utf16le,
};

/// BOM sniff - detects encoding from byte order mark.
///
/// WHATWG Encoding Standard § 6.1
/// https://encoding.spec.whatwg.org/#bom-sniff
///
/// Returns the encoding if a BOM is found, null otherwise.
/// Caller is responsible for skipping the BOM bytes after detection.
pub fn sniff(bytes: []const u8) ?BomEncoding {
    // WHATWG spec: peek 3 bytes and check against BOM table
    if (bytes.len >= 3) {
        // 1. UTF-8 BOM: 0xEF 0xBB 0xBF
        if (std.mem.eql(u8, bytes[0..3], &UTF8_BOM)) {
            return .utf8;
        }
    }

    if (bytes.len >= 2) {
        // 2. UTF-16BE BOM: 0xFE 0xFF
        if (std.mem.eql(u8, bytes[0..2], &UTF16BE_BOM)) {
            return .utf16be;
        }

        // 3. UTF-16LE BOM: 0xFF 0xFE
        if (std.mem.eql(u8, bytes[0..2], &UTF16LE_BOM)) {
            return .utf16le;
        }
    }

    return null;
}

/// Returns the length of the BOM for a given encoding.
pub fn length(encoding: BomEncoding) usize {
    return switch (encoding) {
        .utf8 => 3,
        .utf16be, .utf16le => 2,
    };
}

/// Checks if the input starts with a UTF-8 BOM.
pub fn hasUtf8Bom(bytes: []const u8) bool {
    return bytes.len >= 3 and std.mem.eql(u8, bytes[0..3], &UTF8_BOM);
}

/// Skips UTF-8 BOM if present and returns the remaining slice.
/// If no BOM is present, returns the original slice.
pub fn skipUtf8Bom(bytes: []const u8) []const u8 {
    if (hasUtf8Bom(bytes)) {
        return bytes[3..];
    }
    return bytes;
}

/// Checks if the input starts with a UTF-16BE BOM.
pub fn hasUtf16BeBom(bytes: []const u8) bool {
    return bytes.len >= 2 and std.mem.eql(u8, bytes[0..2], &UTF16BE_BOM);
}

/// Skips UTF-16BE BOM if present and returns the remaining slice.
/// If no BOM is present, returns the original slice.
pub fn skipUtf16BeBom(bytes: []const u8) []const u8 {
    if (hasUtf16BeBom(bytes)) {
        return bytes[2..];
    }
    return bytes;
}

/// Checks if the input starts with a UTF-16LE BOM.
pub fn hasUtf16LeBom(bytes: []const u8) bool {
    return bytes.len >= 2 and std.mem.eql(u8, bytes[0..2], &UTF16LE_BOM);
}

/// Skips UTF-16LE BOM if present and returns the remaining slice.
/// If no BOM is present, returns the original slice.
pub fn skipUtf16LeBom(bytes: []const u8) []const u8 {
    if (hasUtf16LeBom(bytes)) {
        return bytes[2..];
    }
    return bytes;
}

// Tests

test "BOM sniff - UTF-8" {
    const bytes = [_]u8{ 0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F }; // "Hello" with UTF-8 BOM
    const result = sniff(&bytes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(BomEncoding.utf8, result.?);
}

test "BOM sniff - UTF-16BE" {
    const bytes = [_]u8{ 0xFE, 0xFF, 0x00, 0x48 }; // "H" in UTF-16BE with BOM
    const result = sniff(&bytes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(BomEncoding.utf16be, result.?);
}

test "BOM sniff - UTF-16LE" {
    const bytes = [_]u8{ 0xFF, 0xFE, 0x48, 0x00 }; // "H" in UTF-16LE with BOM
    const result = sniff(&bytes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(BomEncoding.utf16le, result.?);
}

test "BOM sniff - no BOM" {
    const bytes = [_]u8{ 0x48, 0x65, 0x6C, 0x6C, 0x6F }; // "Hello" without BOM
    const result = sniff(&bytes);
    try std.testing.expect(result == null);
}

test "BOM sniff - empty input" {
    const bytes = [_]u8{};
    const result = sniff(&bytes);
    try std.testing.expect(result == null);
}

test "BOM sniff - partial BOM (2 bytes)" {
    const bytes = [_]u8{ 0xEF, 0xBB }; // Incomplete UTF-8 BOM
    const result = sniff(&bytes);
    try std.testing.expect(result == null);
}

test "BOM length" {
    try std.testing.expectEqual(@as(usize, 3), length(.utf8));
    try std.testing.expectEqual(@as(usize, 2), length(.utf16be));
    try std.testing.expectEqual(@as(usize, 2), length(.utf16le));
}

test "hasUtf8Bom - with BOM" {
    const bytes = [_]u8{ 0xEF, 0xBB, 0xBF, 0x48 };
    try std.testing.expect(hasUtf8Bom(&bytes));
}

test "hasUtf8Bom - without BOM" {
    const bytes = [_]u8{ 0x48, 0x65, 0x6C, 0x6C, 0x6F };
    try std.testing.expect(!hasUtf8Bom(&bytes));
}

test "skipUtf8Bom - with BOM" {
    const bytes = [_]u8{ 0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F };
    const result = skipUtf8Bom(&bytes);
    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqualSlices(u8, "Hello", result);
}

test "skipUtf8Bom - without BOM" {
    const bytes = [_]u8{ 0x48, 0x65, 0x6C, 0x6C, 0x6F };
    const result = skipUtf8Bom(&bytes);
    try std.testing.expectEqual(bytes.len, result.len);
    try std.testing.expectEqualSlices(u8, &bytes, result);
}

test "hasUtf16BeBom - with BOM" {
    const bytes = [_]u8{ 0xFE, 0xFF, 0x00, 0x48 };
    try std.testing.expect(hasUtf16BeBom(&bytes));
}

test "hasUtf16BeBom - without BOM" {
    const bytes = [_]u8{ 0x00, 0x48, 0x00, 0x65 };
    try std.testing.expect(!hasUtf16BeBom(&bytes));
}

test "skipUtf16BeBom - with BOM" {
    const bytes = [_]u8{ 0xFE, 0xFF, 0x00, 0x48, 0x00, 0x65 }; // "He" in UTF-16BE with BOM
    const result = skipUtf16BeBom(&bytes);
    try std.testing.expectEqual(@as(usize, 4), result.len);
    const expected = [_]u8{ 0x00, 0x48, 0x00, 0x65 };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "skipUtf16BeBom - without BOM" {
    const bytes = [_]u8{ 0x00, 0x48, 0x00, 0x65 };
    const result = skipUtf16BeBom(&bytes);
    try std.testing.expectEqual(bytes.len, result.len);
    try std.testing.expectEqualSlices(u8, &bytes, result);
}

test "hasUtf16LeBom - with BOM" {
    const bytes = [_]u8{ 0xFF, 0xFE, 0x48, 0x00 };
    try std.testing.expect(hasUtf16LeBom(&bytes));
}

test "hasUtf16LeBom - without BOM" {
    const bytes = [_]u8{ 0x48, 0x00, 0x65, 0x00 };
    try std.testing.expect(!hasUtf16LeBom(&bytes));
}

test "skipUtf16LeBom - with BOM" {
    const bytes = [_]u8{ 0xFF, 0xFE, 0x48, 0x00, 0x65, 0x00 }; // "He" in UTF-16LE with BOM
    const result = skipUtf16LeBom(&bytes);
    try std.testing.expectEqual(@as(usize, 4), result.len);
    const expected = [_]u8{ 0x48, 0x00, 0x65, 0x00 };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "skipUtf16LeBom - without BOM" {
    const bytes = [_]u8{ 0x48, 0x00, 0x65, 0x00 };
    const result = skipUtf16LeBom(&bytes);
    try std.testing.expectEqual(bytes.len, result.len);
    try std.testing.expectEqualSlices(u8, &bytes, result);
}
