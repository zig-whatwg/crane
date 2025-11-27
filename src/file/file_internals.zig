//! W3C File API - File Internal Data Structure
//!
//! This module implements the internal storage structure for File objects.
//! A File extends Blob with name and lastModified attributes.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#file-section
//!
//! ## File Internal Slots
//!
//! In addition to Blob's slots, File has:
//! - [[Name]]: The filename (without path)
//! - [[LastModified]]: Unix timestamp in milliseconds
//!
//! ## Constructor Behavior
//!
//! Per spec §4.1.1:
//! - If lastModified is not provided, use current time
//! - Name should not include path information

const std = @import("std");
const BlobData = @import("blob_internals.zig").BlobData;

/// Internal data storage for a File object.
///
/// File extends Blob with:
/// - A name (the filename without path)
/// - A lastModified timestamp (milliseconds since Unix epoch)
pub const FileData = struct {
    /// The underlying Blob data
    blob_data: *BlobData,

    /// The filename (without path information)
    name: []const u8,

    /// Last modified timestamp in milliseconds since Unix epoch
    last_modified: i64,

    /// Memory allocator for cleanup
    allocator: std.mem.Allocator,

    /// Initialize a new FileData.
    ///
    /// Parameters:
    /// - blob_data: The underlying Blob storage (takes ownership)
    /// - name: The filename (will be copied)
    /// - last_modified: Unix timestamp in ms (null = use current time)
    pub fn init(
        allocator: std.mem.Allocator,
        blob_data: *BlobData,
        name: []const u8,
        last_modified: ?i64,
    ) !*FileData {
        const self = try allocator.create(FileData);
        errdefer allocator.destroy(self);

        // Copy the filename
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);

        // Use provided timestamp or current time
        const timestamp = last_modified orelse getCurrentTimeMs();

        self.* = .{
            .blob_data = blob_data,
            .name = owned_name,
            .last_modified = timestamp,
            .allocator = allocator,
        };

        return self;
    }

    /// Clean up resources.
    pub fn deinit(self: *FileData) void {
        self.blob_data.deinit();
        self.allocator.free(@constCast(self.name));
        self.allocator.destroy(self);
    }

    /// Get the filename.
    /// Per spec: "The name attribute must return the name of the file"
    pub fn getName(self: *const FileData) []const u8 {
        return self.name;
    }

    /// Get the last modified timestamp.
    /// Per spec: "The lastModified attribute must return the last modified date"
    /// Returns milliseconds since Unix epoch.
    pub fn getLastModified(self: *const FileData) i64 {
        return self.last_modified;
    }

    /// Get the file size (delegates to blob).
    pub fn size(self: *const FileData) u64 {
        return self.blob_data.size();
    }

    /// Get the MIME type (delegates to blob).
    pub fn getType(self: *const FileData) []const u8 {
        return self.blob_data.getType();
    }

    /// Get the raw bytes (delegates to blob).
    pub fn getBytes(self: *const FileData) []const u8 {
        return self.blob_data.bytes;
    }

    /// Get current time in milliseconds since Unix epoch.
    fn getCurrentTimeMs() i64 {
        const ns = std.time.nanoTimestamp();
        return @intCast(@divTrunc(ns, std.time.ns_per_ms));
    }
};

test "FileData - basic initialization" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "text/plain");
    const file = try FileData.init(allocator, blob, "test.txt", 1700000000000);
    defer file.deinit();

    try std.testing.expectEqualStrings("test.txt", file.getName());
    try std.testing.expectEqual(@as(i64, 1700000000000), file.getLastModified());
    try std.testing.expectEqual(@as(u64, 13), file.size());
    try std.testing.expectEqualStrings("text/plain", file.getType());
}

test "FileData - default lastModified" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "test", "text/plain");
    const file = try FileData.init(allocator, blob, "test.txt", null);
    defer file.deinit();

    // Should be a reasonable timestamp (after year 2020)
    const min_timestamp: i64 = 1577836800000; // 2020-01-01
    try std.testing.expect(file.getLastModified() > min_timestamp);
}
