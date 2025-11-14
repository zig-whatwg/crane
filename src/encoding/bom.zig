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



















