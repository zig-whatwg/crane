//! W3C File API - Blob Internal Data Structure
//!
//! This module implements the internal storage structure for Blob objects.
//! A Blob represents immutable raw binary data.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#blob-section
//!
//! ## Blob Internal Slots
//!
//! Each Blob has these internal slots:
//! - [[BlobData]]: A byte sequence (the blob's data)
//! - [[Size]]: The size of the byte sequence
//! - [[Type]]: A lowercase ASCII MIME type string
//!
//! ## Memory Management
//!
//! BlobData owns its byte storage and must be properly deinitialized.
//! For sliced blobs, bytes are either:
//! - Copied (small slices) for independent lifetime
//! - Reference counted (large blobs) for efficiency
//!
//! ## Thread Safety
//!
//! BlobData is designed for single-threaded access within a realm.
//! Cross-realm transfer requires structured cloning.

const std = @import("std");

/// Internal data storage for a Blob object.
///
/// Per W3C File API spec, a Blob has:
/// - An associated byte sequence (immutable)
/// - A size (derived from byte sequence length)
/// - A type (lowercase ASCII MIME type)
pub const BlobData = struct {
    /// The blob's byte sequence (owned)
    bytes: []const u8,

    /// The MIME type (lowercase ASCII, validated)
    /// Empty string if not provided or invalid
    mime_type: []const u8,

    /// Memory allocator for cleanup
    allocator: std.mem.Allocator,

    /// Whether this BlobData owns its bytes (vs. borrowed for slices)
    owns_bytes: bool,

    /// Initialize a new BlobData with the given bytes and MIME type.
    ///
    /// The bytes are copied, and the MIME type is validated and normalized.
    /// Invalid MIME type characters result in an empty type string.
    pub fn init(allocator: std.mem.Allocator, bytes: []const u8, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);

        // Copy bytes
        const owned_bytes = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned_bytes);

        // Normalize MIME type (lowercase, validate characters)
        const normalized_type = try normalizeMimeType(allocator, mime_type);

        self.* = .{
            .bytes = owned_bytes,
            .mime_type = normalized_type,
            .allocator = allocator,
            .owns_bytes = true,
        };

        return self;
    }

    /// Initialize a BlobData that borrows bytes from another source.
    /// Used for efficient slicing without copying.
    pub fn initBorrowed(allocator: std.mem.Allocator, bytes: []const u8, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);

        const normalized_type = try normalizeMimeType(allocator, mime_type);

        self.* = .{
            .bytes = bytes,
            .mime_type = normalized_type,
            .allocator = allocator,
            .owns_bytes = false,
        };

        return self;
    }

    /// Clean up resources.
    pub fn deinit(self: *BlobData) void {
        if (self.owns_bytes) {
            self.allocator.free(@constCast(self.bytes));
        }
        if (self.mime_type.len > 0) {
            self.allocator.free(@constCast(self.mime_type));
        }
        self.allocator.destroy(self);
    }

    /// Get the size of the blob in bytes.
    /// Per spec: "The size attribute must return the total number of bytes"
    pub fn size(self: *const BlobData) u64 {
        return self.bytes.len;
    }

    /// Get the MIME type of the blob.
    /// Per spec: "The type attribute must return the MIME type of the Blob"
    /// Returns empty string if type is unknown or invalid.
    pub fn getType(self: *const BlobData) []const u8 {
        return self.mime_type;
    }

    /// Normalize a MIME type string per W3C File API spec.
    ///
    /// Per spec §3.1:
    /// - If type contains characters outside U+0020-U+007E, return empty string
    /// - Convert to ASCII lowercase
    fn normalizeMimeType(allocator: std.mem.Allocator, mime_type: []const u8) ![]const u8 {
        // Empty type stays empty
        if (mime_type.len == 0) {
            return "";
        }

        // Validate characters (must be in printable ASCII range)
        for (mime_type) |c| {
            if (c < 0x20 or c > 0x7E) {
                return ""; // Invalid characters -> empty type
            }
        }

        // Allocate and convert to lowercase
        const normalized = try allocator.alloc(u8, mime_type.len);
        for (mime_type, 0..) |c, i| {
            normalized[i] = std.ascii.toLower(c);
        }

        return normalized;
    }
};

test "BlobData - basic initialization" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "text/plain");
    defer blob.deinit();

    try std.testing.expectEqualStrings("Hello, World!", blob.bytes);
    try std.testing.expectEqual(@as(u64, 13), blob.size());
    try std.testing.expectEqualStrings("text/plain", blob.getType());
}

test "BlobData - MIME type normalization" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "test", "TEXT/PLAIN");
    defer blob.deinit();

    try std.testing.expectEqualStrings("text/plain", blob.getType());
}

test "BlobData - invalid MIME type characters" {
    const allocator = std.testing.allocator;

    // MIME type with null byte (invalid)
    const blob = try BlobData.init(allocator, "test", "text/plain\x00");
    defer blob.deinit();

    try std.testing.expectEqualStrings("", blob.getType());
}

test "BlobData - empty MIME type" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "test", "");
    defer blob.deinit();

    try std.testing.expectEqualStrings("", blob.getType());
}

test "BlobData - empty bytes" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "", "text/plain");
    defer blob.deinit();

    try std.testing.expectEqual(@as(u64, 0), blob.size());
}
