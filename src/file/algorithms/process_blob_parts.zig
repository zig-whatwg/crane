//! W3C File API - Process Blob Parts Algorithm
//!
//! This module implements the `process blob parts` algorithm per W3C File API spec §3.1.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#constructorBlob
//!
//! ## Algorithm Overview
//!
//! The process blob parts algorithm converts a sequence of BlobPart values
//! into a BlobData (or raw byte sequence for in-memory parts):
//! - Blob (retains file-backed parts lazily, or copies memory bytes)
//! - BufferSource (ArrayBuffer, ArrayBufferView - copy bytes)
//! - USVString (encode as UTF-8)
//!
//! ## Line Ending Conversion
//!
//! If the `endings` option is "native", line endings in strings are
//! converted to the platform's native format (CRLF on Windows, LF elsewhere).

const std = @import("std");
const blob_internals = @import("../blob_internals.zig");
const BlobData = blob_internals.BlobData;
const Part = blob_internals.Part;
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

/// Build a `BlobData` from `parts`, `options`, and `mime_type`.
///
/// Fast path: if every Blob part is in memory, concatenates all bytes into a
/// single `.memory` `BlobData` (zero extra overhead).
/// File-backed path (Blink's BlobData parts model): retains each `.file` part
/// lazily without reading from disk and coalesces adjacent in-memory chunks.
pub fn processBlobPartsToData(
    allocator: std.mem.Allocator,
    parts: []const BlobPart,
    options: ProcessOptions,
    mime_type: []const u8,
) !*BlobData {
    var has_file = false;
    for (parts) |part| {
        if (part == .blob and !part.blob.isMemoryOnly()) {
            has_file = true;
            break;
        }
    }

    if (!has_file) {
        const bytes = try processBlobParts(allocator, parts, options);
        defer allocator.free(bytes);
        return BlobData.init(allocator, bytes, mime_type);
    }

    var out_parts: std.ArrayListUnmanaged(Part) = .empty;
    errdefer {
        for (out_parts.items) |part| switch (part) {
            .bytes => |b| if (b.len > 0) allocator.free(@constCast(b)),
            .file => |f| f.backing.release(),
        };
        out_parts.deinit(allocator);
    }

    var pending_bytes: std.ArrayListUnmanaged(u8) = .empty;
    defer pending_bytes.deinit(allocator);
    var total_size: u64 = 0;

    for (parts) |part| {
        switch (part) {
            .blob => |blob| switch (blob.storage) {
                .memory => |mem| {
                    if (mem.bytes.len > 0) {
                        try pending_bytes.appendSlice(allocator, mem.bytes);
                        total_size += mem.bytes.len;
                    }
                },
                .parts => |sub| {
                    for (sub.items) |sub_part| switch (sub_part) {
                        .bytes => |b| {
                            if (b.len > 0) {
                                try pending_bytes.appendSlice(allocator, b);
                                total_size += b.len;
                            }
                        },
                        .file => |f| {
                            if (pending_bytes.items.len > 0) {
                                const flushed = try pending_bytes.toOwnedSlice(allocator);
                                errdefer allocator.free(flushed);
                                try out_parts.append(allocator, .{ .bytes = flushed });
                            }
                            try out_parts.ensureUnusedCapacity(allocator, 1);
                            out_parts.appendAssumeCapacity(.{
                                .file = .{
                                    .backing = f.backing.retain(),
                                    .offset = f.offset,
                                    .length = f.length,
                                },
                            });
                            total_size += f.length;
                        },
                    };
                },
            },
            .buffer => |buf| {
                if (buf.len > 0) {
                    try pending_bytes.appendSlice(allocator, buf);
                    total_size += buf.len;
                }
            },
            .string => |str| {
                if (str.len > 0) {
                    if (options.endings == .native) {
                        const expanded = try line_endings.convertLineEndingsToNativeAlloc(allocator, str);
                        defer allocator.free(expanded);
                        try pending_bytes.appendSlice(allocator, expanded);
                        total_size += expanded.len;
                    } else {
                        try pending_bytes.appendSlice(allocator, str);
                        total_size += str.len;
                    }
                }
            },
        }
    }

    if (pending_bytes.items.len > 0) {
        const flushed = try pending_bytes.toOwnedSlice(allocator);
        errdefer allocator.free(flushed);
        try out_parts.append(allocator, .{ .bytes = flushed });
    }

    const owned = try out_parts.toOwnedSlice(allocator);
    errdefer {
        for (owned) |part| switch (part) {
            .bytes => |b| if (b.len > 0) allocator.free(@constCast(b)),
            .file => |f| f.backing.release(),
        };
        allocator.free(owned);
    }
    return BlobData.initParts(allocator, owned, total_size, mime_type);
}

/// Process blob parts algorithm per W3C File API spec §3.1 (in-memory parts).
///
/// Converts a sequence of BlobPart values into a single byte sequence.
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
            .blob => |blob| total_size += @intCast(blob.size()),
            .buffer => |buf| total_size += buf.len,
            .string => |str| {
                if (options.endings == .native) {
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
                var bytes = try blob.readBytes(allocator);
                defer bytes.deinit();
                @memcpy(result[offset..][0..bytes.slice.len], bytes.slice);
                offset += bytes.slice.len;
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
            count += line_endings.NATIVE_LINE_ENDING.len;
        } else if (str[i] == '\r') {
            if (i + 1 < str.len and str[i + 1] == '\n') {
                count += line_endings.NATIVE_LINE_ENDING.len;
                i += 1;
            } else {
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
