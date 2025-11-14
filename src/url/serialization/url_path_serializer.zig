//! URL Path Serializer
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-path-serializer
//! Spec Reference: Lines 1573-1581
//!
//! The URL path serializer takes a URL and returns an ASCII string
//! representing the serialized path.

const std = @import("std");
const infra = @import("infra");
const URLRecord = @import("url_record").URLRecord;

/// URL Path Serializer (spec lines 1573-1581)
///
/// Steps:
/// 1. If url has an opaque path, then return url's path
/// 2. Let output be the empty string
/// 3. For each segment of url's path: append U+002F (/) followed by segment to output
/// 4. Return output
///
/// Examples:
/// - Opaque path "user@example.com" → "user@example.com"
/// - Segments ["path", "to", "file"] → "/path/to/file"
/// - Empty segments [] → ""
pub fn serializePath(allocator: std.mem.Allocator, url: *const URLRecord) ![]const u8 {
    switch (url.path) {
        // Step 1: If url has opaque path, return it
        .opaque_path => |opaque_value| {
            return try allocator.dupe(u8, opaque_value);
        },

        // Steps 2-4: Serialize segment path
        .segments => |segments| {
            // Step 2: Let output be empty string
            var output = infra.List(u8).init(allocator);
            errdefer output.deinit();

            // Step 3: For each segment, append "/" followed by segment
            for (segments.toSlice()) |segment| {
                try output.append('/');
                try output.appendSlice(segment);
            }

            // Step 4: Return output
            return output.toOwnedSlice();
        },
    }
}

test "url path serializer - opaque path" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "mailto");
    const opaque_path = try allocator.dupe(u8, "user@example.com");

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 6,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = @import("path").Path{ .opaque_path = opaque_path },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serializePath(allocator, &url);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("user@example.com", serialized);
}

test "url path serializer - empty segments" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "http");
    var segments = infra.List([]const u8).init(allocator);
    defer segments.deinit();

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = @import("path").Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer allocator.free(url.buffer);

    const serialized = try serializePath(allocator, &url);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("", serialized);
}

test "url path serializer - single segment" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "http");
    var segments = infra.List([]const u8).init(allocator);
    try segments.append(try allocator.dupe(u8, "path"));

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = @import("path").Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serializePath(allocator, &url);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("/path", serialized);
}

test "url path serializer - multiple segments" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "http");
    var segments = infra.List([]const u8).init(allocator);
    try segments.append(try allocator.dupe(u8, "path"));
    try segments.append(try allocator.dupe(u8, "to"));
    try segments.append(try allocator.dupe(u8, "file"));

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = @import("path").Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serializePath(allocator, &url);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("/path/to/file", serialized);
}

test "url path serializer - segments with empty string" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "http");
    var segments = infra.List([]const u8).init(allocator);
    try segments.append(try allocator.dupe(u8, ""));
    try segments.append(try allocator.dupe(u8, "path"));

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = @import("path").Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serializePath(allocator, &url);
    defer allocator.free(serialized);

    // Empty segment becomes "/" + "" = "//"
    try std.testing.expectEqualStrings("//path", serialized);
}
