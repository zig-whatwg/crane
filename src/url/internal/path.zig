//! URL Path Types
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-path-segment
//! Spec Reference: Lines 811-840
//!
//! A URL path is either:
//! - Opaque path (single string, no segments)
//! - List of path segments (array of strings)

const std = @import("std");
const infra = @import("infra");

/// A URL path is either a URL path segment or a list of segments (spec line 834)
pub const Path = union(enum) {
    opaque_path: []const u8, // Opaque path (single string)
    segments: infra.List([]const u8), // List of path segments
};

/// Free path resources
pub fn deinitPath(self: *Path, allocator: std.mem.Allocator) void {
    switch (self.*) {
        .opaque_path => |o| allocator.free(o),
        .segments => |*s| {
            // Free each segment
            for (s.toSlice()) |segment| {
                allocator.free(segment);
            }
            s.deinit();
        },
    }
}

/// Check if path segment is single-dot (spec line 838)
///
/// Returns true if segment is:
/// - "." (literal dot)
/// - "%2e" or "%2E" (percent-encoded dot, case-insensitive)
pub fn isSingleDotPathSegment(segment: []const u8) bool {
    if (std.mem.eql(u8, segment, ".")) return true;
    if (std.ascii.eqlIgnoreCase(segment, "%2e")) return true;
    return false;
}

/// Check if path segment is double-dot (spec line 840)
///
/// Returns true if segment is:
/// - ".." (literal double-dot)
/// - ".%2e", "%2e.", or "%2e%2e" (percent-encoded variations, case-insensitive)
pub fn isDoubleDotPathSegment(segment: []const u8) bool {
    if (std.mem.eql(u8, segment, "..")) return true;
    if (std.ascii.eqlIgnoreCase(segment, ".%2e")) return true;
    if (std.ascii.eqlIgnoreCase(segment, "%2e.")) return true;
    if (std.ascii.eqlIgnoreCase(segment, "%2e%2e")) return true;
    return false;
}

test "path - single dot detection" {
    try std.testing.expect(isSingleDotPathSegment("."));
    try std.testing.expect(isSingleDotPathSegment("%2e"));
    try std.testing.expect(isSingleDotPathSegment("%2E"));
    try std.testing.expect(!isSingleDotPathSegment(".."));
    try std.testing.expect(!isSingleDotPathSegment("a"));
}

test "path - double dot detection" {
    try std.testing.expect(isDoubleDotPathSegment(".."));
    try std.testing.expect(isDoubleDotPathSegment(".%2e"));
    try std.testing.expect(isDoubleDotPathSegment(".%2E"));
    try std.testing.expect(isDoubleDotPathSegment("%2e."));
    try std.testing.expect(isDoubleDotPathSegment("%2E."));
    try std.testing.expect(isDoubleDotPathSegment("%2e%2e"));
    try std.testing.expect(isDoubleDotPathSegment("%2E%2E"));
    try std.testing.expect(!isDoubleDotPathSegment("."));
    try std.testing.expect(!isDoubleDotPathSegment("a"));
}

test "path - opaque path" {
    const allocator = std.testing.allocator;

    const path_str = try allocator.dupe(u8, "user@example.com");
    var path = Path{ .opaque_path = path_str };
    defer deinitPath(&path, allocator);

    try std.testing.expectEqualStrings("user@example.com", path.opaque_path);
}

test "path - segment path" {
    const allocator = std.testing.allocator;

    var segments = infra.List([]const u8).init(allocator);
    try segments.append(try allocator.dupe(u8, "path"));
    try segments.append(try allocator.dupe(u8, "to"));
    try segments.append(try allocator.dupe(u8, "file"));

    var path = Path{ .segments = segments };
    defer deinitPath(&path, allocator);

    try std.testing.expectEqual(@as(usize, 3), path.segments.len);
    try std.testing.expectEqualStrings("path", path.segments.get(0).?);
    try std.testing.expectEqualStrings("to", path.segments.get(1).?);
    try std.testing.expectEqualStrings("file", path.segments.get(2).?);
}
