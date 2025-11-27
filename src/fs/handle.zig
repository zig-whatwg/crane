//! FileSystemHandle Base Implementation
//!
//! Spec: https://fs.spec.whatwg.org/#api-filesystemhandle
//!
//! A FileSystemHandle object represents a file or directory entry.
//! This is the base type for FileSystemFileHandle and FileSystemDirectoryHandle.

const std = @import("std");
const locator_mod = @import("locator.zig");
const errors = @import("errors.zig");
const backend_mod = @import("backend.zig");

const FileSystemLocator = locator_mod.FileSystemLocator;
const FileSystemHandleKind = locator_mod.FileSystemHandleKind;
const FileSystemAccessResult = errors.FileSystemAccessResult;
const FileSystemBackend = backend_mod.FileSystemBackend;
const SerializedHandle = backend_mod.SerializedHandle;

/// FileSystemHandle represents a file or directory entry.
/// https://fs.spec.whatwg.org/#api-filesystemhandle
///
/// Multiple FileSystemHandle objects can have the same file system locator.
pub const FileSystemHandle = struct {
    /// The locator for this handle
    file_locator: FileSystemLocator,
    /// The backend providing file system operations
    file_backend: ?FileSystemBackend,
    /// Allocator for this handle
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new file handle from a locator.
    pub fn init(allocator: std.mem.Allocator, file_locator: FileSystemLocator, file_backend: ?FileSystemBackend) Self {
        return .{
            .file_locator = file_locator,
            .file_backend = file_backend,
            .allocator = allocator,
        };
    }

    /// Create a handle by cloning a locator.
    pub fn initClone(allocator: std.mem.Allocator, file_locator: *const FileSystemLocator, file_backend: ?FileSystemBackend) !Self {
        return .{
            .file_locator = try file_locator.clone(allocator),
            .file_backend = file_backend,
            .allocator = allocator,
        };
    }

    /// Get the kind of this handle.
    /// https://fs.spec.whatwg.org/#dom-filesystemhandle-kind
    ///
    /// Returns "file" for FileSystemFileHandle, "directory" for FileSystemDirectoryHandle.
    pub fn kind(self: *const Self) FileSystemHandleKind {
        return self.file_locator.kind;
    }

    /// Get the name of this handle.
    /// https://fs.spec.whatwg.org/#dom-filesystemhandle-name
    ///
    /// Returns the last path component of the locator's path.
    pub fn name(self: *const Self) []const u8 {
        return self.file_locator.name() orelse "";
    }

    /// Check if this handle is the same entry as another handle.
    /// https://fs.spec.whatwg.org/#api-filesystemhandle-issameentry
    ///
    /// Returns true if both handles represent the same file or directory.
    pub fn isSameEntry(self: *const Self, other: *const Self) bool {
        return self.file_locator.isSameLocator(&other.file_locator);
    }

    /// Check if this handle is in a bucket file system.
    /// https://fs.spec.whatwg.org/#is-in-a-bucket-file-system
    ///
    /// A FileSystemHandle is in a bucket file system if the first item
    /// of its locator's path is the empty string.
    pub fn isInBucketFileSystem(self: *const Self) bool {
        return self.file_locator.isInBucketFileSystem();
    }

    /// Query access permission for this handle.
    /// https://fs.spec.whatwg.org/#api-filesystemhandle-querypermission
    ///
    /// Checks if the current context has the requested access level
    /// without prompting the user.
    pub fn queryPermission(self: *const Self, mode: PermissionMode) FileSystemAccessResult {
        if (self.file_backend) |file_backend| {
            const entry_ptr = file_backend.locateEntry(&self.file_locator);
            if (entry_ptr) |file_entry| {
                const access_mode = switch (mode) {
                    .read => @import("entry.zig").AccessMode.read,
                    .readwrite => @import("entry.zig").AccessMode.readwrite,
                };
                return file_backend.queryAccess(file_entry, access_mode);
            }
        }
        // No backend or entry not found - return denied
        return FileSystemAccessResult.denied(.NotFoundError);
    }

    /// Request access permission for this handle.
    /// https://fs.spec.whatwg.org/#api-filesystemhandle-requestpermission
    ///
    /// May prompt the user for permission if needed.
    /// For bucket file systems, always returns granted.
    pub fn requestPermission(self: *const Self, mode: PermissionMode) FileSystemAccessResult {
        // Bucket file system handles always have permission
        if (self.isInBucketFileSystem()) {
            return FileSystemAccessResult.granted();
        }

        if (self.file_backend) |file_backend| {
            const entry_ptr = file_backend.locateEntry(&self.file_locator);
            if (entry_ptr) |file_entry| {
                const access_mode = switch (mode) {
                    .read => @import("entry.zig").AccessMode.read,
                    .readwrite => @import("entry.zig").AccessMode.readwrite,
                };
                return file_backend.requestAccess(file_entry, access_mode);
            }
        }
        // No backend or entry not found - return denied
        return FileSystemAccessResult.denied(.NotFoundError);
    }

    /// Serialize this handle for structured clone.
    /// https://fs.spec.whatwg.org/#filesystemhandle-serialization-steps
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator, origin: []const u8) !SerializedHandle {
        if (self.file_backend) |file_backend| {
            return file_backend.serializeHandle(allocator, &self.file_locator, origin);
        }
        return error.NotSupported;
    }

    /// Free this handle's resources.
    pub fn deinit(self: *Self) void {
        self.file_locator.deinit();
    }
};

/// Permission mode for file system access.
/// https://wicg.github.io/file-system-access/#enumdef-filesystempermissionmode
pub const PermissionMode = enum {
    read,
    readwrite,

    pub fn toString(self: PermissionMode) []const u8 {
        return switch (self) {
            .read => "read",
            .readwrite => "readwrite",
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "FileSystemHandle - kind and name" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "example.txt" };

    const file_locator = try FileSystemLocator.file(allocator, "bucket:test", &components);
    var handle = FileSystemHandle.init(allocator, file_locator, null);
    defer handle.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.file, handle.kind());
    try std.testing.expectEqualStrings("example.txt", handle.name());
}

test "FileSystemHandle - isSameEntry" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "example.txt" };

    const loc1 = try FileSystemLocator.file(allocator, "bucket:test", &components);
    var handle1 = FileSystemHandle.init(allocator, loc1, null);
    defer handle1.deinit();

    const loc2 = try FileSystemLocator.file(allocator, "bucket:test", &components);
    var handle2 = FileSystemHandle.init(allocator, loc2, null);
    defer handle2.deinit();

    const loc3 = try FileSystemLocator.file(allocator, "bucket:test", &[_][]const u8{ "data", "other.txt" });
    var handle3 = FileSystemHandle.init(allocator, loc3, null);
    defer handle3.deinit();

    try std.testing.expect(handle1.isSameEntry(&handle2));
    try std.testing.expect(!handle1.isSameEntry(&handle3));
}

test "FileSystemHandle - isInBucketFileSystem" {
    const allocator = std.testing.allocator;

    // Bucket file system handle (path starts with empty string)
    const bucket_loc = try FileSystemLocator.bucketRoot(allocator, "bucket:origin");
    var bucket_handle = FileSystemHandle.init(allocator, bucket_loc, null);
    defer bucket_handle.deinit();
    try std.testing.expect(bucket_handle.isInBucketFileSystem());

    // Non-bucket handle
    const non_bucket_loc = try FileSystemLocator.file(allocator, "native:/", &[_][]const u8{ "Users", "test.txt" });
    var non_bucket_handle = FileSystemHandle.init(allocator, non_bucket_loc, null);
    defer non_bucket_handle.deinit();
    try std.testing.expect(!non_bucket_handle.isInBucketFileSystem());
}

test "FileSystemHandle - bucket permission always granted" {
    const allocator = std.testing.allocator;

    const bucket_loc = try FileSystemLocator.bucketRoot(allocator, "bucket:origin");
    var handle = FileSystemHandle.init(allocator, bucket_loc, null);
    defer handle.deinit();

    // Bucket handles should always have granted permission
    const result = handle.requestPermission(.read);
    try std.testing.expect(result.isGranted());
}

test "PermissionMode - toString" {
    try std.testing.expectEqualStrings("read", PermissionMode.read.toString());
    try std.testing.expectEqualStrings("readwrite", PermissionMode.readwrite.toString());
}
