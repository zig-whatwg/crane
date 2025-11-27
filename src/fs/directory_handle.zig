//! FileSystemDirectoryHandle Implementation
//!
//! Spec: https://fs.spec.whatwg.org/#api-filesystemdirectoryhandle
//!
//! A FileSystemDirectoryHandle represents a handle to a directory entry.
//! It provides methods to navigate and manipulate directory contents.

const std = @import("std");
const handle_mod = @import("handle.zig");
const file_handle_mod = @import("file_handle.zig");
const locator_mod = @import("locator.zig");
const entry_mod = @import("entry.zig");
const errors = @import("errors.zig");
const backend_mod = @import("backend.zig");
const context_mod = @import("context.zig");

const FileSystemHandle = handle_mod.FileSystemHandle;
const PermissionMode = handle_mod.PermissionMode;
const FileSystemFileHandle = file_handle_mod.FileSystemFileHandle;
const FileSystemLocator = locator_mod.FileSystemLocator;
const FileSystemHandleKind = locator_mod.FileSystemHandleKind;
const DirectoryEntry = entry_mod.DirectoryEntry;
const Entry = entry_mod.Entry;
const FileSystemAccessResult = errors.FileSystemAccessResult;
const FileSystemError = errors.FileSystemError;
const ErrorName = errors.ErrorName;
const FileSystemBackend = backend_mod.FileSystemBackend;
const BackendError = backend_mod.BackendError;
const ChildIterator = backend_mod.ChildIterator;
const ChildEntry = backend_mod.ChildEntry;
const isValidFileName = context_mod.isValidFileName;

/// Options for getFileHandle.
/// https://fs.spec.whatwg.org/#dictdef-filesystemgetfileoptions
pub const FileSystemGetFileOptions = struct {
    /// If true, create the file if it doesn't exist.
    create: bool = false,
};

/// Options for getDirectoryHandle.
/// https://fs.spec.whatwg.org/#dictdef-filesystemgetdirectoryoptions
pub const FileSystemGetDirectoryOptions = struct {
    /// If true, create the directory if it doesn't exist.
    create: bool = false,
};

/// Options for removeEntry.
/// https://fs.spec.whatwg.org/#dictdef-filesystemremoveoptions
pub const FileSystemRemoveOptions = struct {
    /// If true, remove the directory and all its contents recursively.
    recursive: bool = false,
};

/// FileSystemDirectoryHandle represents a handle to a directory entry.
/// https://fs.spec.whatwg.org/#api-filesystemdirectoryhandle
///
/// It extends FileSystemHandle with directory-specific operations.
pub const FileSystemDirectoryHandle = struct {
    /// The base handle
    base: FileSystemHandle,

    const Self = @This();

    /// Create a new directory handle from a locator.
    /// The locator must be for a directory (not a file).
    pub fn init(allocator: std.mem.Allocator, dir_locator: FileSystemLocator, dir_backend: ?FileSystemBackend) !Self {
        if (dir_locator.kind != .directory) {
            return error.TypeMismatch;
        }
        return .{
            .base = FileSystemHandle.init(allocator, dir_locator, dir_backend),
        };
    }

    /// Create a directory handle by cloning a locator.
    pub fn initClone(allocator: std.mem.Allocator, dir_locator: *const FileSystemLocator, dir_backend: ?FileSystemBackend) !Self {
        if (dir_locator.kind != .directory) {
            return error.TypeMismatch;
        }
        return .{
            .base = try FileSystemHandle.initClone(allocator, dir_locator, dir_backend),
        };
    }

    // ========================================================================
    // FileSystemHandle interface (delegated to base)
    // ========================================================================

    /// Get the kind of this handle.
    /// Always returns .directory for FileSystemDirectoryHandle.
    pub fn kind(self: *const Self) FileSystemHandleKind {
        return self.base.kind();
    }

    /// Get the name of this handle.
    pub fn name(self: *const Self) []const u8 {
        return self.base.name();
    }

    /// Check if this handle is the same entry as another handle.
    pub fn isSameEntry(self: *const Self, other: *const FileSystemHandle) bool {
        return self.base.isSameEntry(other);
    }

    /// Check if this handle is the same entry as another directory handle.
    pub fn isSameDirectoryEntry(self: *const Self, other: *const Self) bool {
        return self.base.isSameEntry(&other.base);
    }

    /// Check if this handle is in a bucket file system.
    pub fn isInBucketFileSystem(self: *const Self) bool {
        return self.base.isInBucketFileSystem();
    }

    /// Query access permission for this handle.
    pub fn queryPermission(self: *const Self, mode: PermissionMode) FileSystemAccessResult {
        return self.base.queryPermission(mode);
    }

    /// Request access permission for this handle.
    pub fn requestPermission(self: *const Self, mode: PermissionMode) FileSystemAccessResult {
        return self.base.requestPermission(mode);
    }

    // ========================================================================
    // FileSystemDirectoryHandle-specific operations
    // ========================================================================

    /// Get a file handle for a file within this directory.
    /// https://fs.spec.whatwg.org/#dom-filesystemdirectoryhandle-getfilehandle
    ///
    /// This method:
    /// 1. Validates the file name
    /// 2. Queries or requests permission based on create option
    /// 3. Locates or creates the file entry
    /// 4. Returns a FileSystemFileHandle
    pub fn getFileHandle(self: *Self, child_name: []const u8, options: FileSystemGetFileOptions) GetFileHandleError!FileSystemFileHandle {
        // Step 1: Validate the name
        if (!isValidFileName(child_name)) {
            return error.TypeMismatchError;
        }

        // Step 2: Get permission based on operation type
        const permission = if (options.create)
            self.requestPermission(.readwrite)
        else
            self.queryPermission(.read);

        if (!permission.isGranted()) {
            return error.NotAllowedError;
        }

        // Step 3: Get the backend
        const dir_backend = self.base.file_backend orelse return error.NotSupported;

        // Step 4: Locate this directory entry
        const entry_ptr = dir_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;
        if (!entry_ptr.isDirectory()) {
            return error.TypeMismatchError;
        }

        var dir_entry = &entry_ptr.directory;

        // Step 5: Look for the child
        if (dir_entry.getChild(child_name)) |child| {
            // Child exists
            if (!child.isFile()) {
                return error.TypeMismatchError;
            }
            // Create a locator for the child file
            const child_locator = self.base.file_locator.createChildFile(self.base.allocator, child_name) catch return error.OutOfMemory;
            return FileSystemFileHandle.init(self.base.allocator, child_locator, dir_backend) catch return error.OutOfMemory;
        } else {
            // Child doesn't exist
            if (!options.create) {
                return error.NotFoundError;
            }

            // Create the file
            _ = dir_backend.createFile(dir_entry, child_name) catch |err| {
                return mapBackendError(err);
            };

            // Create a locator for the new file
            const child_locator = self.base.file_locator.createChildFile(self.base.allocator, child_name) catch return error.OutOfMemory;
            return FileSystemFileHandle.init(self.base.allocator, child_locator, dir_backend) catch return error.OutOfMemory;
        }
    }

    /// Get a directory handle for a subdirectory within this directory.
    /// https://fs.spec.whatwg.org/#dom-filesystemdirectoryhandle-getdirectoryhandle
    ///
    /// This method:
    /// 1. Validates the directory name
    /// 2. Queries or requests permission based on create option
    /// 3. Locates or creates the directory entry
    /// 4. Returns a FileSystemDirectoryHandle
    pub fn getDirectoryHandle(self: *Self, child_name: []const u8, options: FileSystemGetDirectoryOptions) GetDirectoryHandleError!Self {
        // Step 1: Validate the name
        if (!isValidFileName(child_name)) {
            return error.TypeMismatchError;
        }

        // Step 2: Get permission based on operation type
        const permission = if (options.create)
            self.requestPermission(.readwrite)
        else
            self.queryPermission(.read);

        if (!permission.isGranted()) {
            return error.NotAllowedError;
        }

        // Step 3: Get the backend
        const dir_backend = self.base.file_backend orelse return error.NotSupported;

        // Step 4: Locate this directory entry
        const entry_ptr = dir_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;
        if (!entry_ptr.isDirectory()) {
            return error.TypeMismatchError;
        }

        var dir_entry = &entry_ptr.directory;

        // Step 5: Look for the child
        if (dir_entry.getChild(child_name)) |child| {
            // Child exists
            if (!child.isDirectory()) {
                return error.TypeMismatchError;
            }
            // Create a locator for the child directory
            const child_locator = self.base.file_locator.createChildDirectory(self.base.allocator, child_name) catch return error.OutOfMemory;
            return Self.init(self.base.allocator, child_locator, dir_backend) catch return error.OutOfMemory;
        } else {
            // Child doesn't exist
            if (!options.create) {
                return error.NotFoundError;
            }

            // Create the directory
            _ = dir_backend.createDirectory(dir_entry, child_name) catch |err| {
                return mapBackendErrorForDir(err);
            };

            // Create a locator for the new directory
            const child_locator = self.base.file_locator.createChildDirectory(self.base.allocator, child_name) catch return error.OutOfMemory;
            return Self.init(self.base.allocator, child_locator, dir_backend) catch return error.OutOfMemory;
        }
    }

    /// Remove an entry from this directory.
    /// https://fs.spec.whatwg.org/#dom-filesystemdirectoryhandle-removeentry
    ///
    /// This method:
    /// 1. Validates the name
    /// 2. Requests readwrite permission
    /// 3. Removes the entry (recursively if specified)
    pub fn removeEntry(self: *Self, child_name: []const u8, options: FileSystemRemoveOptions) RemoveEntryError!void {
        // Step 1: Validate the name
        if (!isValidFileName(child_name)) {
            return error.TypeMismatchError;
        }

        // Step 2: Request permission
        const permission = self.requestPermission(.readwrite);
        if (!permission.isGranted()) {
            return error.NotAllowedError;
        }

        // Step 3: Get the backend
        const dir_backend = self.base.file_backend orelse return error.NotSupported;

        // Step 4: Locate this directory entry
        const entry_ptr = dir_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;
        if (!entry_ptr.isDirectory()) {
            return error.TypeMismatchError;
        }

        var dir_entry = &entry_ptr.directory;

        // Step 5: Check if entry exists
        if (!dir_entry.hasChild(child_name)) {
            return error.NotFoundError;
        }

        // Step 6: Remove the entry
        dir_backend.removeEntry(dir_entry, child_name, options.recursive) catch |err| {
            return mapBackendErrorForRemove(err);
        };
    }

    /// Resolve the path of a possible descendant handle relative to this directory.
    /// https://fs.spec.whatwg.org/#dom-filesystemdirectoryhandle-resolve
    ///
    /// Returns:
    /// - An array of path components if possibleDescendant is a descendant
    /// - null if possibleDescendant is not a descendant
    pub fn resolve(self: *const Self, allocator: std.mem.Allocator, possibleDescendant: *const FileSystemHandle) !?[][]const u8 {
        // Check if they share the same root
        if (!self.base.file_locator.root.equals(&possibleDescendant.file_locator.root)) {
            return null;
        }

        // Check if the descendant's path starts with our path
        const our_path = &self.base.file_locator.path;
        const their_path = &possibleDescendant.file_locator.path;

        if (!their_path.startsWith(our_path)) {
            return null;
        }

        // Get the relative path
        const relative_opt = try their_path.relativeTo(allocator, our_path);
        if (relative_opt) |relative| {
            defer {
                var rel = relative;
                rel.deinit();
            }

            // Copy the components
            const result = try allocator.alloc([]const u8, relative.components.items.len);
            errdefer allocator.free(result);

            for (relative.components.items, 0..) |component, i| {
                result[i] = try allocator.dupe(u8, component);
            }

            return result;
        }

        return null;
    }

    /// Create an iterator over the directory's entries.
    /// https://fs.spec.whatwg.org/#api-filesystemdirectoryhandle-asynciterable
    ///
    /// This is the async iterable interface for the directory.
    pub fn entries(self: *Self) EntriesError!DirectoryIterator {
        // Query permission
        const permission = self.queryPermission(.read);
        if (!permission.isGranted()) {
            return error.NotAllowedError;
        }

        // Get the backend
        const dir_backend = self.base.file_backend orelse return error.NotSupported;

        // Locate this directory entry
        const entry_ptr = dir_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;
        if (!entry_ptr.isDirectory()) {
            return error.TypeMismatchError;
        }

        const dir_entry = &entry_ptr.directory;

        // Create the iterator
        return DirectoryIterator{
            .directory_handle = self,
            .backend_iterator = dir_backend.listChildren(dir_entry),
            .dir_backend = dir_backend,
        };
    }

    /// Free this handle's resources.
    pub fn deinit(self: *Self) void {
        self.base.deinit();
    }

    /// Get the underlying locator (for internal use).
    pub fn getLocator(self: *const Self) *const FileSystemLocator {
        return &self.base.file_locator;
    }
};

/// Error set for getFileHandle operation.
pub const GetFileHandleError = error{
    /// Invalid file name
    TypeMismatchError,
    /// Permission denied
    NotAllowedError,
    /// Directory not found
    NotFoundError,
    /// Backend not available
    NotSupported,
    /// Out of memory
    OutOfMemory,
};

/// Error set for getDirectoryHandle operation.
pub const GetDirectoryHandleError = error{
    /// Invalid directory name
    TypeMismatchError,
    /// Permission denied
    NotAllowedError,
    /// Directory not found
    NotFoundError,
    /// Backend not available
    NotSupported,
    /// Out of memory
    OutOfMemory,
};

/// Error set for removeEntry operation.
pub const RemoveEntryError = error{
    /// Invalid name
    TypeMismatchError,
    /// Permission denied
    NotAllowedError,
    /// Entry not found
    NotFoundError,
    /// Cannot remove non-empty directory without recursive
    InvalidModificationError,
    /// Backend not available
    NotSupported,
};

/// Error set for entries iteration.
pub const EntriesError = error{
    /// Permission denied
    NotAllowedError,
    /// Directory not found
    NotFoundError,
    /// Entry is not a directory
    TypeMismatchError,
    /// Backend not available
    NotSupported,
};

/// Map backend errors to getFileHandle errors.
fn mapBackendError(err: BackendError) GetFileHandleError {
    return switch (err) {
        error.NotFound => error.NotFoundError,
        error.NotAllowed => error.NotAllowedError,
        error.TypeMismatch => error.TypeMismatchError,
        error.OutOfMemory => error.OutOfMemory,
        else => error.NotFoundError,
    };
}

/// Map backend errors to getDirectoryHandle errors.
fn mapBackendErrorForDir(err: BackendError) GetDirectoryHandleError {
    return switch (err) {
        error.NotFound => error.NotFoundError,
        error.NotAllowed => error.NotAllowedError,
        error.TypeMismatch => error.TypeMismatchError,
        error.OutOfMemory => error.OutOfMemory,
        else => error.NotFoundError,
    };
}

/// Map backend errors to removeEntry errors.
fn mapBackendErrorForRemove(err: BackendError) RemoveEntryError {
    return switch (err) {
        error.NotFound => error.NotFoundError,
        error.NotAllowed => error.NotAllowedError,
        error.TypeMismatch => error.TypeMismatchError,
        error.InvalidModification => error.InvalidModificationError,
        else => error.NotFoundError,
    };
}

/// Iterator for directory entries.
/// https://fs.spec.whatwg.org/#api-filesystemdirectoryhandle-asynciterable
///
/// Yields (name, handle) pairs for each entry in the directory.
pub const DirectoryIterator = struct {
    /// Reference to the parent directory handle
    directory_handle: *FileSystemDirectoryHandle,
    /// Backend-provided iterator
    backend_iterator: ChildIterator,
    /// Reference to the backend
    dir_backend: FileSystemBackend,

    const Self = @This();

    /// Entry result from iteration
    pub const IteratorEntry = struct {
        /// The entry name
        name: []const u8,
        /// The handle kind
        kind: FileSystemHandleKind,
    };

    /// Get the next entry.
    /// Returns null when iteration is complete.
    pub fn next(self: *Self) ?IteratorEntry {
        const child = self.backend_iterator.next() orelse return null;
        return IteratorEntry{
            .name = child.name,
            .kind = child.kind,
        };
    }

    /// Get a file handle for the current entry (if it's a file).
    pub fn getFileHandle(self: *Self, entry_name: []const u8) !FileSystemFileHandle {
        const child_locator = try self.directory_handle.base.file_locator.createChildFile(
            self.directory_handle.base.allocator,
            entry_name,
        );
        return FileSystemFileHandle.init(
            self.directory_handle.base.allocator,
            child_locator,
            self.dir_backend,
        );
    }

    /// Get a directory handle for the current entry (if it's a directory).
    pub fn getDirectoryHandle(self: *Self, entry_name: []const u8) !FileSystemDirectoryHandle {
        const child_locator = try self.directory_handle.base.file_locator.createChildDirectory(
            self.directory_handle.base.allocator,
            entry_name,
        );
        return FileSystemDirectoryHandle.init(
            self.directory_handle.base.allocator,
            child_locator,
            self.dir_backend,
        );
    }

    /// Clean up iterator resources.
    pub fn deinit(self: *Self) void {
        self.backend_iterator.deinit();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "FileSystemDirectoryHandle - kind and name" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "mydir" };

    const dir_locator = try FileSystemLocator.directory(allocator, "bucket:test", &components);
    var handle = try FileSystemDirectoryHandle.init(allocator, dir_locator, null);
    defer handle.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.directory, handle.kind());
    try std.testing.expectEqualStrings("mydir", handle.name());
}

test "FileSystemDirectoryHandle - type mismatch error" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "file.txt" };

    var file_locator = try FileSystemLocator.file(allocator, "bucket:test", &components);
    defer file_locator.deinit();

    // Should fail because locator is for file, not directory
    const result = FileSystemDirectoryHandle.init(allocator, file_locator, null);
    try std.testing.expectError(error.TypeMismatch, result);
}

test "FileSystemDirectoryHandle - isSameEntry" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "mydir" };

    const loc1 = try FileSystemLocator.directory(allocator, "bucket:test", &components);
    var handle1 = try FileSystemDirectoryHandle.init(allocator, loc1, null);
    defer handle1.deinit();

    const loc2 = try FileSystemLocator.directory(allocator, "bucket:test", &components);
    var handle2 = try FileSystemDirectoryHandle.init(allocator, loc2, null);
    defer handle2.deinit();

    try std.testing.expect(handle1.isSameDirectoryEntry(&handle2));
}

test "FileSystemDirectoryHandle - bucket file system detection" {
    const allocator = std.testing.allocator;

    // Create a bucket file system handle
    const bucket_loc = try FileSystemLocator.bucketRoot(allocator, "bucket:origin");
    var bucket_handle = try FileSystemDirectoryHandle.init(allocator, bucket_loc, null);
    defer bucket_handle.deinit();

    try std.testing.expect(bucket_handle.isInBucketFileSystem());

    // Create a non-bucket handle
    const non_bucket_loc = try FileSystemLocator.directory(allocator, "native:/", &[_][]const u8{ "Users", "Documents" });
    var non_bucket_handle = try FileSystemDirectoryHandle.init(allocator, non_bucket_loc, null);
    defer non_bucket_handle.deinit();

    try std.testing.expect(!non_bucket_handle.isInBucketFileSystem());
}

test "FileSystemGetFileOptions - default values" {
    const options = FileSystemGetFileOptions{};
    try std.testing.expect(!options.create);

    const create_options = FileSystemGetFileOptions{ .create = true };
    try std.testing.expect(create_options.create);
}

test "FileSystemGetDirectoryOptions - default values" {
    const options = FileSystemGetDirectoryOptions{};
    try std.testing.expect(!options.create);

    const create_options = FileSystemGetDirectoryOptions{ .create = true };
    try std.testing.expect(create_options.create);
}

test "FileSystemRemoveOptions - default values" {
    const options = FileSystemRemoveOptions{};
    try std.testing.expect(!options.recursive);

    const recursive_options = FileSystemRemoveOptions{ .recursive = true };
    try std.testing.expect(recursive_options.recursive);
}

test "DirectoryIterator.IteratorEntry - structure" {
    const entry = DirectoryIterator.IteratorEntry{
        .name = "test.txt",
        .kind = .file,
    };
    try std.testing.expectEqualStrings("test.txt", entry.name);
    try std.testing.expectEqual(FileSystemHandleKind.file, entry.kind);
}
