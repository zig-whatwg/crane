//! W3C File API - Slice Blob Algorithm
//!
//! This module implements the `slice blob` algorithm per W3C File API spec §2.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#slice-blob
//!
//! ## Algorithm Overview
//!
//! The slice blob algorithm creates a new Blob containing a byte range
//! of an existing Blob. Parameters use JavaScript-style semantics:
//! - Negative indices count from the end
//! - Out-of-bounds indices are clamped
//! - If start >= end, result is empty
//!
//! ## ContentType Behavior
//!
//! The contentType parameter is NOT inherited from the original blob.
//! If not provided, the new blob's type is empty string.

const std = @import("std");
const BlobData = @import("../blob_internals.zig").BlobData;

/// Slice blob algorithm per W3C File API spec §2.
///
/// Creates a new Blob containing bytes from start to end with optional contentType.
///
/// Parameters follow JavaScript semantics:
/// - Negative indices count from end of blob
/// - Indices are clamped to valid range
/// - end is exclusive (slice includes bytes from start up to but not including end)
///
/// Per spec, if contentType is null, the new blob's type is empty (not inherited).
pub fn sliceBlob(
    allocator: std.mem.Allocator,
    blob: *const BlobData,
    start: ?i64,
    end: ?i64,
    content_type: ?[]const u8,
) !*BlobData {
    // Step 1: Let originalSize be blob's size
    const original_size: i64 = @intCast(blob.bytes.len);

    // Step 2: Normalize start parameter
    const relative_start: usize = blk: {
        if (start) |s| {
            if (s < 0) {
                // Step 2b: If start is negative, relativeStart = max((originalSize + start), 0)
                const adjusted = original_size + s;
                break :blk @intCast(@max(adjusted, 0));
            } else {
                // Step 2c: Otherwise, relativeStart = min(start, originalSize)
                break :blk @intCast(@min(s, original_size));
            }
        } else {
            // Step 2a: If start is null, relativeStart = 0
            break :blk 0;
        }
    };

    // Step 3: Normalize end parameter
    const relative_end: usize = blk: {
        if (end) |e| {
            if (e < 0) {
                // Step 3b: If end is negative, relativeEnd = max((originalSize + end), 0)
                const adjusted = original_size + e;
                break :blk @intCast(@max(adjusted, 0));
            } else {
                // Step 3c: Otherwise, relativeEnd = min(end, originalSize)
                break :blk @intCast(@min(e, original_size));
            }
        } else {
            // Step 3a: If end is null, relativeEnd = originalSize
            break :blk @intCast(original_size);
        }
    };

    // Step 4: Normalize contentType parameter
    const relative_content_type: []const u8 = blk: {
        if (content_type) |ct| {
            // Step 4b.i: Check for invalid characters (outside U+0020 to U+007E)
            for (ct) |c| {
                if (c < 0x20 or c > 0x7E) {
                    break :blk ""; // Invalid, use empty string
                }
            }
            // Note: Lowercase conversion happens in BlobData.init
            break :blk ct;
        } else {
            // Step 4a: If contentType is null, use empty string
            break :blk "";
        }
    };

    // Step 5: Let span be max((relativeEnd - relativeStart), 0)
    const span: usize = if (relative_end > relative_start)
        relative_end - relative_start
    else
        0;

    // Step 6: Return a new Blob object S
    // S refers to span consecutive bytes starting at relativeStart
    const sliced_bytes = if (span > 0)
        blob.bytes[relative_start .. relative_start + span]
    else
        "";

    // Create new BlobData with copied bytes
    return BlobData.init(allocator, sliced_bytes, relative_content_type);
}

test "slice - basic range" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "text/plain");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, 0, 5, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.bytes);
    try std.testing.expectEqual(@as(u64, 5), sliced.size());
    try std.testing.expectEqualStrings("", sliced.getType()); // null contentType -> empty
}

test "slice - with contentType" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, null, null, "application/octet-stream");
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.bytes);
    try std.testing.expectEqualStrings("application/octet-stream", sliced.getType());
}

test "slice - negative start" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "");
    defer blob.deinit();

    // -6 from end = "World!"
    const sliced = try sliceBlob(allocator, blob, -6, null, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("World!", sliced.bytes);
}

test "slice - negative end" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "");
    defer blob.deinit();

    // 0 to -1 = all but last char
    const sliced = try sliceBlob(allocator, blob, 0, -1, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello, World", sliced.bytes);
}

test "slice - both negative" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "");
    defer blob.deinit();

    // -6 to -1 = "World" (without !)
    const sliced = try sliceBlob(allocator, blob, -6, -1, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("World", sliced.bytes);
}

test "slice - start >= end returns empty" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, 5, 3, null);
    defer sliced.deinit();

    try std.testing.expectEqual(@as(u64, 0), sliced.size());
}

test "slice - start beyond size" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, 100, 200, null);
    defer sliced.deinit();

    try std.testing.expectEqual(@as(u64, 0), sliced.size());
}

test "slice - end clamped to size" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, 0, 1000, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.bytes);
}

test "slice - null params = clone" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, null, null, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.bytes);
    try std.testing.expectEqualStrings("", sliced.getType()); // Note: contentType not inherited
}

test "slice - invalid contentType chars" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "");
    defer blob.deinit();

    // contentType with null byte (invalid) should become empty
    const sliced = try sliceBlob(allocator, blob, null, null, "text/plain\x00");
    defer sliced.deinit();

    try std.testing.expectEqualStrings("", sliced.getType());
}

test "slice - empty blob" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "", "");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, 0, 10, null);
    defer sliced.deinit();

    try std.testing.expectEqual(@as(u64, 0), sliced.size());
}

test "slice - very negative start clamped to 0" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, -1000, null, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.bytes);
}
