//! File System API Mock
//!
//! Mock implementation of the File System API (WHATWG File System Standard).
//!
//! ## Specification
//!
//! - File System Standard: https://fs.spec.whatwg.org/
//! - File System Access API: https://wicg.github.io/file-system-access/
//!
//! ## Why This Mock Exists
//!
//! The WHATWG Storage spec (https://storage.spec.whatwg.org/) defines File System
//! as one of the storage endpoints. Each origin's storage bucket contains a
//! "bottle" for file system data (Origin Private File System - OPFS).
//! This mock allows the Storage spec to be implemented without a full
//! File System implementation.
//!
//! ## TODO: Full Implementation Required
//!
//! This mock should be replaced with a complete implementation that includes:
//! - FileSystemHandle (base class)
//! - FileSystemFileHandle
//! - FileSystemDirectoryHandle
//! - FileSystemSyncAccessHandle (for high-performance access)
//! - Origin Private File System (OPFS)
//! - File/directory creation, reading, writing, removal
//!

const std = @import("std");
const root = @import("root.zig");
const MockError = root.MockError;

/// File System Handle Kind
pub const FileSystemHandleKind = enum {
    file,
    directory,
};

/// Mock FileSystemHandle interface
///
/// Base interface for file and directory handles.
///
/// TODO(File System): Implement full FileSystemHandle per spec
/// https://fs.spec.whatwg.org/#api-filesystemhandle
pub const FileSystemHandle = struct {
    allocator: std.mem.Allocator,
    kind: FileSystemHandleKind,
    name: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, kind: FileSystemHandleKind, name: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .kind = kind,
            .name = try allocator.dupe(u8, name),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
    }

    /// Check if two handles reference the same entry
    ///
    /// TODO(File System): Implement proper isSameEntry comparison
    pub fn isSameEntry(self: *Self, other: *Self) MockError!bool {
        _ = self;
        _ = other;
        return MockError.NotImplemented;
    }

    /// Query permission state
    ///
    /// TODO(File System): Implement permission handling
    pub fn queryPermission(self: *Self, mode: PermissionMode) MockError!PermissionState {
        _ = self;
        _ = mode;
        return MockError.NotImplemented;
    }

    /// Request permission
    ///
    /// TODO(File System): Implement permission request flow
    pub fn requestPermission(self: *Self, mode: PermissionMode) MockError!PermissionState {
        _ = self;
        _ = mode;
        return MockError.NotImplemented;
    }
};

/// Mock FileSystemFileHandle interface
///
/// Handle to a file entry.
///
/// TODO(File System): Implement full FileSystemFileHandle
/// https://fs.spec.whatwg.org/#api-filesystemfilehandle
pub const FileSystemFileHandle = struct {
    base: FileSystemHandle,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Self {
        return Self{
            .base = try FileSystemHandle.init(allocator, .file, name),
        };
    }

    pub fn deinit(self: *Self) void {
        self.base.deinit();
    }

    /// Get a File object
    ///
    /// TODO(File System): Return File blob with contents
    pub fn getFile(self: *Self) MockError!*anyopaque {
        _ = self;
        return MockError.NotImplemented;
    }

    /// Create a writable stream
    ///
    /// TODO(File System): Return FileSystemWritableFileStream
    pub fn createWritable(self: *Self, options: CreateWritableOptions) MockError!*anyopaque {
        _ = self;
        _ = options;
        return MockError.NotImplemented;
    }

    /// Create a sync access handle (Worker only)
    ///
    /// TODO(File System): Return FileSystemSyncAccessHandle for OPFS
    pub fn createSyncAccessHandle(self: *Self) MockError!*anyopaque {
        _ = self;
        return MockError.NotImplemented;
    }
};

/// Mock FileSystemDirectoryHandle interface
///
/// Handle to a directory entry.
///
/// TODO(File System): Implement full FileSystemDirectoryHandle
/// https://fs.spec.whatwg.org/#api-filesystemdirectoryhandle
pub const FileSystemDirectoryHandle = struct {
    base: FileSystemHandle,
    allocator: std.mem.Allocator,
    /// Mock: Track child entries for basic testing
    entries: std.StringHashMap(FileSystemHandleKind),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Self {
        return Self{
            .base = try FileSystemHandle.init(allocator, .directory, name),
            .allocator = allocator,
            .entries = std.StringHashMap(FileSystemHandleKind).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit();
        self.base.deinit();
    }

    /// Get a file handle by name
    ///
    /// TODO(File System): Return actual FileSystemFileHandle
    pub fn getFileHandle(self: *Self, name: []const u8, options: GetHandleOptions) MockError!*FileSystemFileHandle {
        _ = self;
        _ = name;
        _ = options;
        return MockError.NotImplemented;
    }

    /// Get a directory handle by name
    ///
    /// TODO(File System): Return actual FileSystemDirectoryHandle
    pub fn getDirectoryHandle(self: *Self, name: []const u8, options: GetHandleOptions) MockError!*FileSystemDirectoryHandle {
        _ = self;
        _ = name;
        _ = options;
        return MockError.NotImplemented;
    }

    /// Remove an entry
    ///
    /// TODO(File System): Implement removal with recursive option
    pub fn removeEntry(self: *Self, name: []const u8, options: RemoveOptions) MockError!void {
        _ = self;
        _ = name;
        _ = options;
        return MockError.NotImplemented;
    }

    /// Resolve path from this directory to a descendant
    ///
    /// TODO(File System): Implement path resolution
    pub fn resolve(self: *Self, possibleDescendant: *FileSystemHandle) MockError!?[][]const u8 {
        _ = self;
        _ = possibleDescendant;
        return MockError.NotImplemented;
    }

    /// Iterate over entries
    ///
    /// TODO(File System): Return async iterator of [name, handle] pairs
    pub fn entries_iterator(self: *Self) MockError!void {
        _ = self;
        return MockError.NotImplemented;
    }

    /// Get estimated storage usage (for Storage API integration)
    pub fn estimateUsage(self: *Self) u64 {
        _ = self;
        return 0; // Mock returns 0 bytes
    }
};

/// Permission mode for file system access
pub const PermissionMode = enum {
    read,
    readwrite,
};

/// Permission state
pub const PermissionState = enum {
    granted,
    denied,
    prompt,
};

/// Options for getFileHandle/getDirectoryHandle
pub const GetHandleOptions = struct {
    create: bool = false,
};

/// Options for createWritable
pub const CreateWritableOptions = struct {
    keep_existing_data: bool = false,
};

/// Options for removeEntry
pub const RemoveOptions = struct {
    recursive: bool = false,
};

/// Origin Private File System (OPFS)
///
/// Mock for the origin-scoped file system root.
///
/// TODO(File System): Implement full OPFS
/// https://fs.spec.whatwg.org/#sandboxed-filesystem
pub const OriginPrivateFileSystem = struct {
    allocator: std.mem.Allocator,
    root: ?*FileSystemDirectoryHandle,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .root = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.root) |r| {
            r.deinit();
            self.allocator.destroy(r);
        }
    }

    /// Get the OPFS root directory
    ///
    /// TODO(File System): Return properly initialized root with persistence
    pub fn getDirectory(self: *Self) !*FileSystemDirectoryHandle {
        if (self.root) |r| {
            return r;
        }

        const new_root = try self.allocator.create(FileSystemDirectoryHandle);
        new_root.* = try FileSystemDirectoryHandle.init(self.allocator, "");
        self.root = new_root;
        return new_root;
    }

    /// Get estimated storage usage (for Storage API integration)
    pub fn estimateUsage(self: *Self) u64 {
        _ = self;
        return 0; // Mock returns 0 bytes
    }
};

test "FileSystemHandle basic operations" {
    const allocator = std.testing.allocator;

    var handle = try FileSystemHandle.init(allocator, .file, "test.txt");
    defer handle.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.file, handle.kind);
    try std.testing.expectEqualStrings("test.txt", handle.name);
}

test "FileSystemDirectoryHandle mock returns NotImplemented" {
    const allocator = std.testing.allocator;

    var dir = try FileSystemDirectoryHandle.init(allocator, "test-dir");
    defer dir.deinit();

    try std.testing.expectError(MockError.NotImplemented, dir.getFileHandle("file.txt", .{}));
    try std.testing.expectError(MockError.NotImplemented, dir.getDirectoryHandle("subdir", .{}));
    try std.testing.expectError(MockError.NotImplemented, dir.removeEntry("file.txt", .{}));
}

test "OriginPrivateFileSystem creates root" {
    const allocator = std.testing.allocator;

    var opfs = OriginPrivateFileSystem.init(allocator);
    defer opfs.deinit();

    const opfs_root = try opfs.getDirectory();
    try std.testing.expectEqual(FileSystemHandleKind.directory, opfs_root.base.kind);
}
