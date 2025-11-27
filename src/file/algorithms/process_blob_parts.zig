//! W3C File API - Process Blob Parts Algorithm
//!
//! This module implements the `process blob parts` algorithm per W3C File API spec §3.1.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#constructorBlob
//!
//! ## Algorithm Overview
//!
//! The process blob parts algorithm converts a sequence of BlobPart values
//! into a single byte sequence. BlobPart can be:
//! - Blob (copy bytes)
//! - BufferSource (ArrayBuffer, ArrayBufferView - copy bytes)
//! - USVString (encode as UTF-8)
//!
//! ## Line Ending Conversion
//!
//! If the `endings` option is "native", line endings in strings are
//! converted to the platform's native format (CRLF on Windows, LF elsewhere).

const std = @import("std");
const BlobData = @import("../blob_internals.zig").BlobData;
const line_endings = @import("line_endings.zig");

/// A BlobPart can be one of several types.
/// Per spec: typedef (Blob or BufferSource or USVString) BlobPart;
pub const BlobPart = union(enum) {
    /// Another Blob
    blob: *const BlobData,
    /// Raw bytes (ArrayBuffer or ArrayBufferView)
    buffer: []const u8,
    /// String (will be UTF-8 encoded)
    string: []const u8,
};

/// Options for processing blob parts.
pub const ProcessOptions = struct {
    /// Whether to convert line endings to native format
    endings: Endings = .transparent,
};

/// Line ending conversion mode.
pub const Endings = enum {
    /// Do not convert line endings (default)
    transparent,
    /// Convert line endings to native format
    native,
};

/// Process blob parts algorithm per W3C File API spec §3.1.
///
/// Converts a sequence of BlobPart values into a single byte sequence.
///
/// Returns the concatenated bytes (caller owns memory).
pub fn processBlobParts(
    allocator: std.mem.Allocator,
    parts: []const BlobPart,
    options: ProcessOptions,
) ![]u8 {
    // Calculate total size first for efficient allocation
    var total_size: usize = 0;
    for (parts) |part| {
        switch (part) {
            .blob => |blob| total_size += blob.bytes.len,
            .buffer => |buf| total_size += buf.len,
            .string => |str| {
                if (options.endings == .native) {
                    // Count potential line ending expansion
                    total_size += countWithLineEndingExpansion(str);
                } else {
                    total_size += str.len;
                }
            },
        }
    }

    // Allocate result buffer
    var result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    var offset: usize = 0;
    for (parts) |part| {
        switch (part) {
            .blob => |blob| {
                @memcpy(result[offset..][0..blob.bytes.len], blob.bytes);
                offset += blob.bytes.len;
            },
            .buffer => |buf| {
                @memcpy(result[offset..][0..buf.len], buf);
                offset += buf.len;
            },
            .string => |str| {
                if (options.endings == .native) {
                    const written = line_endings.convertLineEndingsToNative(str, result[offset..]);
                    offset += written;
                } else {
                    @memcpy(result[offset..][0..str.len], str);
                    offset += str.len;
                }
            },
        }
    }

    // Trim if native line endings resulted in smaller output
    if (offset < total_size) {
        result = try allocator.realloc(result, offset);
    }

    return result;
}

/// Count bytes needed for string with line ending expansion.
fn countWithLineEndingExpansion(str: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if (str[i] == '\n') {
            // On Windows, \n becomes \r\n (2 bytes)
            // On Unix, \n stays \n (1 byte)
            count += line_endings.NATIVE_LINE_ENDING.len;
        } else if (str[i] == '\r') {
            if (i + 1 < str.len and str[i + 1] == '\n') {
                // \r\n stays as native ending
                count += line_endings.NATIVE_LINE_ENDING.len;
                i += 1; // Skip the \n
            } else {
                // Lone \r becomes native ending
                count += line_endings.NATIVE_LINE_ENDING.len;
            }
        } else {
            count += 1;
        }
    }
    return count;
}

test "process - single string part" {
    const allocator = std.testing.allocator;

    const parts = [_]BlobPart{
        .{ .string = "Hello, World!" },
    };

    const result = try processBlobParts(allocator, &parts, .{});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello, World!", result);
}

test "process - multiple string parts" {
    const allocator = std.testing.allocator;

    const parts = [_]BlobPart{
        .{ .string = "Hello" },
        .{ .string = ", " },
        .{ .string = "World!" },
    };

    const result = try processBlobParts(allocator, &parts, .{});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello, World!", result);
}

test "process - buffer parts" {
    const allocator = std.testing.allocator;

    const parts = [_]BlobPart{
        .{ .buffer = &[_]u8{ 1, 2, 3 } },
        .{ .buffer = &[_]u8{ 4, 5, 6 } },
    };

    const result = try processBlobParts(allocator, &parts, .{});
    defer allocator.free(result);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 5, 6 }, result);
}

test "process - blob parts" {
    const allocator = std.testing.allocator;

    const blob1 = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob1.deinit();

    const blob2 = try BlobData.init(allocator, " World", "text/plain");
    defer blob2.deinit();

    const parts = [_]BlobPart{
        .{ .blob = blob1 },
        .{ .blob = blob2 },
    };

    const result = try processBlobParts(allocator, &parts, .{});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}

test "process - mixed parts" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Blob", "text/plain");
    defer blob.deinit();

    const parts = [_]BlobPart{
        .{ .string = "String " },
        .{ .blob = blob },
        .{ .buffer = &[_]u8{ ' ', 'B', 'u', 'f' } },
    };

    const result = try processBlobParts(allocator, &parts, .{});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("String Blob Buf", result);
}

test "process - empty parts" {
    const allocator = std.testing.allocator;

    const parts = [_]BlobPart{};

    const result = try processBlobParts(allocator, &parts, .{});
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}
