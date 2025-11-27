//! W3C File API - FileList Internal Data Structure
//!
//! This module implements the internal storage structure for FileList objects.
//! A FileList is an immutable list of File objects, typically from <input type="file">.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#filelist-section
//!
//! ## FileList Characteristics
//!
//! - Immutable after creation
//! - Length and item access only
//! - Used by HTML forms for file input
//! - Iterable (supports for...of in JS)

const std = @import("std");
const FileData = @import("file_internals.zig").FileData;

/// Internal data storage for a FileList object.
///
/// FileList is a simple read-only list of File objects.
/// Per spec, it provides:
/// - length attribute
/// - item(index) method
/// - Array-like indexed access
pub const FileListData = struct {
    /// The list of files (owned references)
    files: []*FileData,

    /// Memory allocator for cleanup
    allocator: std.mem.Allocator,

    /// Initialize a FileList with the given files.
    ///
    /// Takes ownership of the file references.
    pub fn init(allocator: std.mem.Allocator, files: []*FileData) !*FileListData {
        const self = try allocator.create(FileListData);
        errdefer allocator.destroy(self);

        // Copy the file pointer array
        const owned_files = try allocator.dupe(*FileData, files);

        self.* = .{
            .files = owned_files,
            .allocator = allocator,
        };

        return self;
    }

    /// Initialize an empty FileList.
    pub fn initEmpty(allocator: std.mem.Allocator) !*FileListData {
        const self = try allocator.create(FileListData);

        self.* = .{
            .files = &[_]*FileData{},
            .allocator = allocator,
        };

        return self;
    }

    /// Clean up resources.
    ///
    /// Note: This deinitializes all contained FileData objects.
    pub fn deinit(self: *FileListData) void {
        for (self.files) |file| {
            file.deinit();
        }
        if (self.files.len > 0) {
            self.allocator.free(self.files);
        }
        self.allocator.destroy(self);
    }

    /// Get the number of files in the list.
    /// Per spec: "The length attribute must return the number of files"
    pub fn length(self: *const FileListData) u32 {
        return @intCast(self.files.len);
    }

    /// Get a file by index.
    /// Per spec: "The item(index) method must return the indexth File object"
    /// Returns null if index is out of bounds.
    pub fn item(self: *const FileListData, index: u32) ?*FileData {
        if (index >= self.files.len) {
            return null;
        }
        return self.files[index];
    }
};

test "FileListData - basic initialization" {
    const allocator = std.testing.allocator;
    const BlobData = @import("blob_internals.zig").BlobData;

    // Create some files
    const blob1 = try BlobData.init(allocator, "content1", "text/plain");
    const file1 = try FileData.init(allocator, blob1, "file1.txt", 1700000000000);

    const blob2 = try BlobData.init(allocator, "content2", "text/plain");
    const file2 = try FileData.init(allocator, blob2, "file2.txt", 1700000000000);

    var files = [_]*FileData{ file1, file2 };
    const file_list = try FileListData.init(allocator, &files);
    defer file_list.deinit(); // This also deinitializes the files

    try std.testing.expectEqual(@as(u32, 2), file_list.length());
    try std.testing.expectEqualStrings("file1.txt", file_list.item(0).?.getName());
    try std.testing.expectEqualStrings("file2.txt", file_list.item(1).?.getName());
    try std.testing.expect(file_list.item(2) == null);
}

test "FileListData - empty list" {
    const allocator = std.testing.allocator;

    const file_list = try FileListData.initEmpty(allocator);
    defer file_list.deinit();

    try std.testing.expectEqual(@as(u32, 0), file_list.length());
    try std.testing.expect(file_list.item(0) == null);
}
