//! W3C File API - Package Data Algorithm
//!
//! This module implements the `package data` algorithm per W3C File API spec §6.1.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#readOperation
//!
//! ## Algorithm Overview
//!
//! The package data algorithm converts raw bytes into the format requested
//! by the FileReader read operation:
//!
//! - ArrayBuffer: Return bytes as-is
//! - BinaryString: Convert bytes to binary string (one char per byte)
//! - Text: Decode bytes using specified encoding (default UTF-8)
//! - DataURL: Encode as base64 data URL
//!
//! ## DataURL Format
//!
//! Per spec, data URLs have the format:
//! data:<mediatype>;base64,<data>
//!
//! If the blob has no type, the mediatype is omitted.

const std = @import("std");
const base64 = std.base64.standard;

/// The type of read operation (determines output format).
pub const ReadType = enum {
    /// Return bytes as ArrayBuffer
    ArrayBuffer,
    /// Return bytes as binary string (legacy)
    BinaryString,
    /// Return bytes as decoded text
    Text,
    /// Return bytes as base64 data URL
    DataURL,
};

/// Package data result.
pub const PackageResult = union(enum) {
    /// ArrayBuffer result (raw bytes)
    array_buffer: []const u8,
    /// String result (text or binary string)
    string: []const u8,
};

/// Package data algorithm per W3C File API spec §6.1.
///
/// Converts raw bytes into the format specified by readType.
///
/// Parameters:
/// - allocator: Memory allocator
/// - bytes: The raw bytes to package
/// - read_type: The desired output format
/// - mime_type: The MIME type (for DataURL)
/// - encoding: The text encoding (for Text, default UTF-8)
///
/// Returns the packaged result (caller owns any allocated memory).
pub fn packageData(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    read_type: ReadType,
    mime_type: []const u8,
    encoding: ?[]const u8,
) !PackageResult {
    switch (read_type) {
        .ArrayBuffer => {
            // Return bytes as-is (copy for ownership)
            const result = try allocator.dupe(u8, bytes);
            return .{ .array_buffer = result };
        },

        .BinaryString => {
            // Binary string: one character per byte (Latin-1 encoding)
            // In JavaScript, this is a string where charCodeAt(i) === bytes[i]
            // In Zig, we just return the bytes as a string
            const result = try allocator.dupe(u8, bytes);
            return .{ .string = result };
        },

        .Text => {
            // Decode using specified encoding (default UTF-8)
            const enc = encoding orelse "utf-8";

            // TODO: Integrate with encoding module for full encoding support
            // For now, only UTF-8 is supported
            if (!std.ascii.eqlIgnoreCase(enc, "utf-8") and
                !std.ascii.eqlIgnoreCase(enc, "utf8"))
            {
                // Return bytes as-is for unsupported encodings
                // Real implementation would use encoding module
                const result = try allocator.dupe(u8, bytes);
                return .{ .string = result };
            }

            // UTF-8: return as-is (already UTF-8)
            const result = try allocator.dupe(u8, bytes);
            return .{ .string = result };
        },

        .DataURL => {
            // Format: data:<mediatype>;base64,<data>
            const encoded_len = base64.Encoder.calcSize(bytes.len);

            // Calculate total URL length
            const has_type = mime_type.len > 0;

            // Build the data URL
            var url: []u8 = undefined;
            if (has_type) {
                url = try std.fmt.allocPrint(
                    allocator,
                    "data:{s};base64,",
                    .{mime_type},
                );
            } else {
                url = try allocator.dupe(u8, "data:;base64,");
            }
            errdefer allocator.free(url);

            // Allocate space for base64 data
            const result = try allocator.realloc(url, url.len + encoded_len);
            errdefer allocator.free(result);

            // Encode to base64
            _ = base64.Encoder.encode(result[result.len - encoded_len ..], bytes);

            return .{ .string = result };
        },
    }
}

test "package - ArrayBuffer" {
    const allocator = std.testing.allocator;

    const bytes = "Hello, World!";
    const result = try packageData(allocator, bytes, .ArrayBuffer, "", null);
    defer allocator.free(result.array_buffer);

    try std.testing.expectEqualStrings("Hello, World!", result.array_buffer);
}

test "package - BinaryString" {
    const allocator = std.testing.allocator;

    const bytes = &[_]u8{ 0, 1, 2, 255 };
    const result = try packageData(allocator, bytes, .BinaryString, "", null);
    defer allocator.free(result.string);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2, 255 }, result.string);
}

test "package - Text UTF-8" {
    const allocator = std.testing.allocator;

    const bytes = "Hello, World!";
    const result = try packageData(allocator, bytes, .Text, "", "utf-8");
    defer allocator.free(result.string);

    try std.testing.expectEqualStrings("Hello, World!", result.string);
}

test "package - DataURL with type" {
    const allocator = std.testing.allocator;

    const bytes = "Hello";
    const result = try packageData(allocator, bytes, .DataURL, "text/plain", null);
    defer allocator.free(result.string);

    try std.testing.expectEqualStrings("data:text/plain;base64,SGVsbG8=", result.string);
}

test "package - DataURL without type" {
    const allocator = std.testing.allocator;

    const bytes = "Hello";
    const result = try packageData(allocator, bytes, .DataURL, "", null);
    defer allocator.free(result.string);

    try std.testing.expectEqualStrings("data:;base64,SGVsbG8=", result.string);
}

test "package - empty bytes" {
    const allocator = std.testing.allocator;

    const bytes: []const u8 = "";
    const result = try packageData(allocator, bytes, .ArrayBuffer, "", null);
    defer allocator.free(result.array_buffer);

    try std.testing.expectEqual(@as(usize, 0), result.array_buffer.len);
}
