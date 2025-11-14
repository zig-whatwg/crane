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




