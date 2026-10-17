//! File API §6.3, package data for synchronous and asynchronous readers.
//! https://w3c.github.io/FileAPI/#blob-package-data
//!
//! Strings are owned UTF-8, including BinaryString's isomorphic decoding.
//! ArrayBuffer bytes are an owned copy for callers that need native storage;
//! callers creating an engine ArrayBuffer directly need not copy them here.

const std = @import("std");
const infra = @import("infra");
const encoding = @import("encoding");
const mimesniff = @import("mimesniff");

pub const ReadType = enum { ArrayBuffer, BinaryString, Text, DataURL };

/// Caller owns the returned allocation and frees it with the given allocator.
pub const PackageResult = union(enum) {
    array_buffer: []u8,
    string: []u8,
};

pub fn packageData(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    read_type: ReadType,
    mime_type: []const u8,
    encoding_label: ?[]const u8,
) !PackageResult {
    return switch (read_type) {
        // ArrayBuffer: a new buffer whose contents are bytes.
        .ArrayBuffer => .{ .array_buffer = try allocator.dupe(u8, bytes) },
        // BinaryString: each byte becomes a code unit of equal value.
        .BinaryString => .{ .string = try infra.bytes.isomorphicDecodeToUtf8(allocator, bytes) },
        .Text => .{ .string = try decodeText(allocator, bytes, mime_type, encoding_label) },
        .DataURL => blk: {
            // FileAPI issue 104 leaves this underspecified: all three browsers
            // use application/octet-stream when the type is empty. Match them,
            // as FileReader and filereader_readAsDataURL.any.js already do.
            // https://github.com/w3c/FileAPI/issues/104
            const media_type = if (mime_type.len > 0) mime_type else "application/octet-stream";
            const encoder = std.base64.standard.Encoder;
            const prefix = try std.fmt.allocPrint(allocator, "data:{s};base64,", .{media_type});
            defer allocator.free(prefix);
            const result = try allocator.alloc(u8, prefix.len + encoder.calcSize(bytes.len));
            @memcpy(result[0..prefix.len], prefix);
            _ = encoder.encode(result[prefix.len..], bytes);
            break :blk .{ .string = result };
        },
    };
}

fn decodeText(allocator: std.mem.Allocator, bytes: []const u8, mime_type: []const u8, label: ?[]const u8) ![]u8 {
    // Text 1–2: get an encoding from encodingLabel, if supplied.
    var charset: ?*const encoding.Encoding = if (label) |name| encoding.getEncoding(name) else null;
    // Text 3: an absent or unrecognized label falls back to the MIME charset.
    if (charset == null) {
        if (try mimesniff.parseMimeType(allocator, mime_type)) |parsed| {
            var mime = parsed;
            defer mime.deinit();
            const charset_name = std.unicode.utf8ToUtf16LeStringLiteral("charset");
            // This map compares slice keys by address; compare their contents.
            for (mime.parameters.entries.items()) |entry| {
                if (!std.mem.eql(u16, entry.key, charset_name)) continue;
                const name = try std.unicode.utf16LeToUtf8Alloc(allocator, entry.value);
                defer allocator.free(name);
                charset = encoding.getEncoding(name);
                break;
            }
        }
    }
    // Text 4–5: UTF-8 is the final fallback; Encoding's legacy decode lets
    // a BOM override it (and every explicit or MIME encoding).
    const code_units = try encoding.hooks.decode(allocator, bytes, charset orelse encoding.UTF_8);
    defer allocator.free(code_units);
    // Decoder output consists of scalar values, never unpaired surrogates.
    return std.unicode.utf16LeToUtf8Alloc(allocator, code_units) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => unreachable,
    };
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

    try std.testing.expectEqualStrings("\x00\x01\x02\xc3\xbf", result.string);
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

    try std.testing.expectEqualStrings("data:application/octet-stream;base64,SGVsbG8=", result.string);
}

test "package - empty bytes" {
    const allocator = std.testing.allocator;

    const bytes: []const u8 = "";
    const result = try packageData(allocator, bytes, .ArrayBuffer, "", null);
    defer allocator.free(result.array_buffer);

    try std.testing.expectEqual(@as(usize, 0), result.array_buffer.len);
}
