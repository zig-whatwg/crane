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
//! For file-backed Blobs (Blink's BlobData parts model), slicing produces a new
//! `BlobData` referencing the sub-range of the underlying `FileBacking`(s) with
//! zero disk I/O at slice time.
//!
//! ## ContentType Behavior
//!
//! The contentType parameter is NOT inherited from the original blob.
//! If not provided, the new blob's type is empty string.

const std = @import("std");
const blob_internals = @import("../blob_internals.zig");
const BlobData = blob_internals.BlobData;
const Part = blob_internals.Part;

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
    const original_size_u64 = blob.size();
    const original_size: i64 = @intCast(@min(original_size_u64, @as(u64, std.math.maxInt(i64))));

    // Step 2: Normalize start parameter
    const relative_start: u64 = blk: {
        if (start) |s| {
            if (s < 0) {
                // Step 2b: If start is negative, relativeStart = max((originalSize + start), 0)
                const adjusted: i128 = @as(i128, original_size) + @as(i128, s);
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
    const relative_end: u64 = blk: {
        if (end) |e| {
            if (e < 0) {
                // Step 3b: If end is negative, relativeEnd = max((originalSize + end), 0)
                const adjusted: i128 = @as(i128, original_size) + @as(i128, e);
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
            // Note: Lowercase conversion happens in BlobData.init / initParts
            break :blk ct;
        } else {
            // Step 4a: If contentType is null, use empty string
            break :blk "";
        }
    };

    // Step 5: Let span be max((relativeEnd - relativeStart), 0)
    const span: u64 = if (relative_end > relative_start)
        relative_end - relative_start
    else
        0;

    // Step 6: Return a new Blob object S
    if (span == 0) {
        return BlobData.init(allocator, "", relative_content_type);
    }

    switch (blob.storage) {
        .memory => |mem| {
            const rs: usize = @intCast(relative_start);
            const sp: usize = @intCast(span);
            return BlobData.init(allocator, mem.bytes[rs..][0..sp], relative_content_type);
        },
        .parts => |parts| {
            var new_parts: std.ArrayListUnmanaged(Part) = .empty;
            errdefer {
                for (new_parts.items) |part| switch (part) {
                    .bytes => |b| if (b.len > 0) allocator.free(@constCast(b)),
                    .file => |f| f.backing.release(),
                };
                new_parts.deinit(allocator);
            }

            var skip: u64 = relative_start;
            var remaining: u64 = span;
            var has_file = false;

            for (parts.items) |part| {
                if (remaining == 0) break;
                const part_len: u64 = switch (part) {
                    .bytes => |b| b.len,
                    .file => |f| f.length,
                };
                if (skip >= part_len) {
                    skip -= part_len;
                    continue;
                }
                const avail = part_len - skip;
                const take = @min(avail, remaining);
                switch (part) {
                    .bytes => |b| {
                        const start_idx: usize = @intCast(skip);
                        const take_len: usize = @intCast(take);
                        const copy = try allocator.dupe(u8, b[start_idx..][0..take_len]);
                        errdefer allocator.free(copy);
                        try new_parts.append(allocator, .{ .bytes = copy });
                    },
                    .file => |f| {
                        has_file = true;
                        try new_parts.ensureUnusedCapacity(allocator, 1);
                        new_parts.appendAssumeCapacity(.{
                            .file = .{
                                .backing = f.backing.retain(),
                                .offset = f.offset + skip,
                                .length = take,
                            },
                        });
                    },
                }
                remaining -= take;
                skip = 0;
            }

            // If the sliced sub-range touches only in-memory parts, collapse
            // to a plain `.memory` BlobData.
            if (!has_file) {
                const total: usize = @intCast(span);
                const flat = try allocator.alloc(u8, total);
                defer allocator.free(flat);
                var cursor: usize = 0;
                for (new_parts.items) |part| {
                    const b = part.bytes;
                    @memcpy(flat[cursor..][0..b.len], b);
                    cursor += b.len;
                    if (b.len > 0) allocator.free(@constCast(b));
                }
                new_parts.deinit(allocator);
                return BlobData.init(allocator, flat, relative_content_type);
            }

            const owned = try new_parts.toOwnedSlice(allocator);
            errdefer {
                for (owned) |part| switch (part) {
                    .bytes => |b| if (b.len > 0) allocator.free(@constCast(b)),
                    .file => |f| f.backing.release(),
                };
                allocator.free(owned);
            }
            return BlobData.initParts(allocator, owned, span, relative_content_type);
        },
    }
}

test "slice - basic range" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "text/plain");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, 0, 5, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.memoryBytes().?);
    try std.testing.expectEqual(@as(u64, 5), sliced.size());
    try std.testing.expectEqualStrings("", sliced.getType()); // null contentType -> empty
}

test "slice - with contentType" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, null, null, "application/octet-stream");
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.memoryBytes().?);
    try std.testing.expectEqualStrings("application/octet-stream", sliced.getType());
}

test "slice - negative start" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "");
    defer blob.deinit();

    // -6 from end = "World!"
    const sliced = try sliceBlob(allocator, blob, -6, null, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("World!", sliced.memoryBytes().?);
}

test "slice - negative end" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "");
    defer blob.deinit();

    // 0 to -1 = all but last char
    const sliced = try sliceBlob(allocator, blob, 0, -1, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello, World", sliced.memoryBytes().?);
}

test "slice - both negative" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "");
    defer blob.deinit();

    // -6 to -1 = "World" (without !)
    const sliced = try sliceBlob(allocator, blob, -6, -1, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("World", sliced.memoryBytes().?);
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

    try std.testing.expectEqualStrings("Hello", sliced.memoryBytes().?);
}

test "slice - null params = clone" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const sliced = try sliceBlob(allocator, blob, null, null, null);
    defer sliced.deinit();

    try std.testing.expectEqualStrings("Hello", sliced.memoryBytes().?);
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

    try std.testing.expectEqualStrings("Hello", sliced.memoryBytes().?);
}
