//! FileSystemFileHandle Implementation
//!
//! Spec: https://fs.spec.whatwg.org/#api-filesystemfilehandle
//!
//! A FileSystemFileHandle represents a handle to a file entry.
//! It provides methods to read the file and create writable streams.

const std = @import("std");
const handle_mod = @import("handle.zig");
const locator_mod = @import("locator.zig");
const entry_mod = @import("entry.zig");
const errors = @import("errors.zig");
const backend_mod = @import("backend.zig");

const FileSystemHandle = handle_mod.FileSystemHandle;
const PermissionMode = handle_mod.PermissionMode;
const FileSystemLocator = locator_mod.FileSystemLocator;
const FileSystemHandleKind = locator_mod.FileSystemHandleKind;
const FileEntry = entry_mod.FileEntry;
const LockResult = entry_mod.LockResult;
const Entry = entry_mod.Entry;
const FileSystemAccessResult = errors.FileSystemAccessResult;
const FileSystemError = errors.FileSystemError;
const ErrorName = errors.ErrorName;
const FileSystemBackend = backend_mod.FileSystemBackend;
const BackendError = backend_mod.BackendError;

/// Options for creating a writable stream.
/// https://fs.spec.whatwg.org/#dictdef-filesystemcreatewritableoptions
pub const FileSystemCreateWritableOptions = struct {
    /// If true, the stream will keep existing file data instead of starting empty.
    keep_existing_data: bool = false,
};

/// Represents a File object.
/// https://w3c.github.io/FileAPI/#file-section
///
/// This is a simplified representation for the file data.
/// The actual File API integration would happen at the JS binding layer.
pub const File = struct {
    /// The file name
    name: []const u8,
    /// The file data
    data: []const u8,
    /// The MIME type
    mime_type: []const u8,
    /// Last modified timestamp (milliseconds since Unix epoch)
    last_modified: i64,
    /// Allocator used for data
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a File from entry data.
    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        data: []const u8,
        last_modified: i64,
    ) !Self {
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);

        const owned_data = try allocator.dupe(u8, data);
        errdefer allocator.free(owned_data);

        return .{
            .name = owned_name,
            .data = owned_data,
            .mime_type = "application/octet-stream", // Default MIME type
            .last_modified = last_modified,
            .allocator = allocator,
        };
    }

    /// Get the size of the file in bytes.
    pub fn size(self: *const Self) u64 {
        return self.data.len;
    }

    /// Free the file resources.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }
};

/// FileSystemFileHandle represents a handle to a file entry.
/// https://fs.spec.whatwg.org/#api-filesystemfilehandle
///
/// It extends FileSystemHandle with file-specific operations.
pub const FileSystemFileHandle = struct {
    /// The base handle
    base: FileSystemHandle,

    const Self = @This();

    /// Create a new file handle from a locator.
    /// The locator must be for a file (not a directory).
    pub fn init(allocator: std.mem.Allocator, file_locator: FileSystemLocator, file_backend: ?FileSystemBackend) !Self {
        if (file_locator.kind != .file) {
            return error.TypeMismatch;
        }
        return .{
            .base = FileSystemHandle.init(allocator, file_locator, file_backend),
        };
    }

    /// Create a file handle by cloning a locator.
    pub fn initClone(allocator: std.mem.Allocator, file_locator: *const FileSystemLocator, file_backend: ?FileSystemBackend) !Self {
        if (file_locator.kind != .file) {
            return error.TypeMismatch;
        }
        return .{
            .base = try FileSystemHandle.initClone(allocator, file_locator, file_backend),
        };
    }

    // ========================================================================
    // FileSystemHandle interface (delegated to base)
    // ========================================================================

    /// Get the kind of this handle.
    /// Always returns .file for FileSystemFileHandle.
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

    /// Check if this handle is the same entry as another file handle.
    pub fn isSameFileEntry(self: *const Self, other: *const Self) bool {
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
    // FileSystemFileHandle-specific operations
    // ========================================================================

    /// Get the file contents as a File object.
    /// https://fs.spec.whatwg.org/#dom-filesystemfilehandle-getfile
    ///
    /// This method:
    /// 1. Queries read permission
    /// 2. Locates the file entry
    /// 3. Creates a snapshot of the file data
    ///
    /// Returns a File object or an error.
    pub fn getFile(self: *const Self) GetFileError!File {
        // Step 1: Query permission (we need read access)
        const permission = self.queryPermission(.read);
        if (!permission.isGranted()) {
            return error.NotAllowedError;
        }

        // Step 2: Get the backend and locate the entry
        const file_backend = self.base.file_backend orelse return error.NotSupported;
        const entry_ptr = file_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;

        // Step 3: Verify it's a file entry
        if (!entry_ptr.isFile()) {
            return error.TypeMismatchError;
        }

        const file_entry = &entry_ptr.file;

        // Step 4: Read the file data
        const data = file_backend.readFile(self.base.allocator, file_entry) catch |err| {
            return mapBackendError(err);
        };
        errdefer self.base.allocator.free(data);

        // Step 5: Get modification time
        const mod_time = file_backend.getModificationTime(file_entry);

        // Step 6: Create and return File object
        const file = File.init(
            self.base.allocator,
            self.name(),
            data,
            mod_time,
        ) catch return error.OutOfMemory;

        // Free the data buffer since File made its own copy
        self.base.allocator.free(data);

        return file;
    }

    /// Create a FileSystemWritableFileStream for writing to the file.
    /// https://fs.spec.whatwg.org/#dom-filesystemfilehandle-createwritable
    ///
    /// Note: This returns a WritableStreamHandle that wraps the actual stream.
    /// The WritableStream integration is handled in the streams module.
    ///
    /// This method:
    /// 1. Requests readwrite permission
    /// 2. Takes a shared lock on the file
    /// 3. Creates a temporary file for atomic writes
    /// 4. Returns a handle to the writable stream
    pub fn createWritable(self: *Self, options: FileSystemCreateWritableOptions) CreateWritableError!WritableStreamHandle {
        // Step 1: Request permission (we need readwrite access)
        const permission = self.requestPermission(.readwrite);
        if (!permission.isGranted()) {
            return error.NotAllowedError;
        }

        // Step 2: Get the backend and locate the entry
        const file_backend = self.base.file_backend orelse return error.NotSupported;
        const entry_ptr = file_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;

        // Step 3: Verify it's a file entry
        if (!entry_ptr.isFile()) {
            return error.TypeMismatchError;
        }

        var file_entry = &entry_ptr.file;

        // Step 4: Take a shared lock
        // https://fs.spec.whatwg.org/#filesystemwritablefilestream-lock
        const lock_result = file_entry.takeLock(.shared);
        if (lock_result == .failure) {
            return error.NoModificationAllowedError;
        }

        // If lock acquisition failed after this point, we need to release
        errdefer file_entry.releaseLock();

        // Step 5: Create the writable stream handle
        // The actual stream will be set up by the caller using streams module
        return WritableStreamHandle{
            .file_handle = self,
            .file_entry = file_entry,
            .keep_existing_data = options.keep_existing_data,
            .allocator = self.base.allocator,
        };
    }

    /// Create a FileSystemSyncAccessHandle for synchronous file access.
    /// https://fs.spec.whatwg.org/#dom-filesystemfilehandle-createsyncaccesshandle
    ///
    /// Note: This is only available in dedicated workers per the spec.
    /// The calling context validation happens at the JS binding layer.
    ///
    /// This method:
    /// 1. Checks if the handle is in a bucket file system
    /// 2. Takes an exclusive lock on the file
    /// 3. Returns a sync access handle
    pub fn createSyncAccessHandle(self: *Self) CreateSyncAccessHandleError!SyncAccessHandle {
        // Step 1: Bucket file system check
        // Per spec, sync access handles are only for bucket file systems
        if (!self.isInBucketFileSystem()) {
            return error.InvalidStateError;
        }

        // Step 2: Get the backend and locate the entry
        const file_backend = self.base.file_backend orelse return error.NotSupported;
        const entry_ptr = file_backend.locateEntry(&self.base.file_locator) orelse return error.NotFoundError;

        // Step 3: Verify it's a file entry
        if (!entry_ptr.isFile()) {
            return error.TypeMismatchError;
        }

        var file_entry = &entry_ptr.file;

        // Step 4: Take an exclusive lock
        // https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-lock
        const lock_result = file_entry.takeLock(.exclusive);
        if (lock_result == .failure) {
            return error.NoModificationAllowedError;
        }

        // If lock acquisition failed after this point, we need to release
        errdefer file_entry.releaseLock();

        // Step 5: Create and return the sync access handle
        return SyncAccessHandle{
            .file_handle = self,
            .file_entry = file_entry,
            .file_backend = file_backend,
            .allocator = self.base.allocator,
            .cursor_position = 0,
            .is_closed = false,
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

/// Error set for getFile operation.
pub const GetFileError = error{
    /// Permission denied
    NotAllowedError,
    /// File not found
    NotFoundError,
    /// Entry is not a file
    TypeMismatchError,
    /// Backend not available
    NotSupported,
    /// Out of memory
    OutOfMemory,
    /// I/O error
    IoError,
};

/// Error set for createWritable operation.
pub const CreateWritableError = error{
    /// Permission denied
    NotAllowedError,
    /// File not found
    NotFoundError,
    /// Entry is not a file
    TypeMismatchError,
    /// File is locked
    NoModificationAllowedError,
    /// Backend not available
    NotSupported,
};

/// Error set for createSyncAccessHandle operation.
pub const CreateSyncAccessHandleError = error{
    /// Not in a bucket file system
    InvalidStateError,
    /// File not found
    NotFoundError,
    /// Entry is not a file
    TypeMismatchError,
    /// File is locked
    NoModificationAllowedError,
    /// Backend not available
    NotSupported,
};

/// Map backend errors to getFile errors.
fn mapBackendError(err: BackendError) GetFileError {
    return switch (err) {
        error.NotFound => error.NotFoundError,
        error.NotAllowed => error.NotAllowedError,
        error.TypeMismatch => error.TypeMismatchError,
        error.IoError => error.IoError,
        error.OutOfMemory => error.OutOfMemory,
        else => error.IoError,
    };
}

/// Handle to a writable file stream.
/// This is returned by createWritable() and is used to set up the actual stream.
///
/// The caller should:
/// 1. Get this handle from createWritable()
/// 2. Use it with the streams module to create a WritableStream
/// 3. Call finish() or abort() when done
pub const WritableStreamHandle = struct {
    /// Reference to the parent file handle
    file_handle: *const FileSystemFileHandle,
    /// Reference to the file entry
    file_entry: *FileEntry,
    /// Whether to keep existing data
    keep_existing_data: bool,
    /// Allocator for operations
    allocator: std.mem.Allocator,
    /// Buffer for writes (temp file simulation)
    write_buffer: std.ArrayListUnmanaged(u8) = .{},
    /// Current cursor position
    cursor_position: u64 = 0,
    /// Whether the stream has been closed
    is_closed: bool = false,

    const Self = @This();

    /// Initialize the write buffer.
    /// If keep_existing_data is true, copies the current file data.
    pub fn initBuffer(self: *Self) !void {
        if (self.keep_existing_data) {
            const data = self.file_entry.data();
            try self.write_buffer.appendSlice(self.allocator, data);
        }
    }

    /// Write data to the buffer.
    /// https://fs.spec.whatwg.org/#filesystemwritablefilestream-write
    pub fn write(self: *Self, data: []const u8) !void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        // Ensure buffer is large enough
        const end_position = self.cursor_position + data.len;
        if (end_position > self.write_buffer.items.len) {
            try self.write_buffer.resize(self.allocator, end_position);
        }

        // Write data at cursor position
        const start: usize = @intCast(self.cursor_position);
        @memcpy(self.write_buffer.items[start..][0..data.len], data);

        // Advance cursor
        self.cursor_position = end_position;
    }

    /// Seek to a position in the buffer.
    /// https://fs.spec.whatwg.org/#filesystemwritablefilestream-seek
    pub fn seek(self: *Self, position: u64) !void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }
        self.cursor_position = position;
    }

    /// Truncate the buffer to a size.
    /// https://fs.spec.whatwg.org/#filesystemwritablefilestream-truncate
    pub fn truncate(self: *Self, new_size: u64) !void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        const size: usize = @intCast(new_size);
        if (size < self.write_buffer.items.len) {
            self.write_buffer.shrinkRetainingCapacity(size);
        } else if (size > self.write_buffer.items.len) {
            try self.write_buffer.resize(self.allocator, size);
            // Fill with zeros
            const items = self.write_buffer.items;
            @memset(items[self.write_buffer.items.len - (size - items.len) ..], 0);
        }

        // Adjust cursor if beyond new size
        if (self.cursor_position > new_size) {
            self.cursor_position = new_size;
        }
    }

    /// Finish writing and commit changes to the file.
    /// This atomically replaces the file contents.
    pub fn finish(self: *Self) !void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        defer self.close();

        // Commit the buffer to the file entry
        try self.file_entry.setData(self.write_buffer.items);
    }

    /// Abort writing and discard changes.
    pub fn abort(self: *Self) void {
        self.close();
    }

    /// Close the stream and release the lock.
    fn close(self: *Self) void {
        if (!self.is_closed) {
            self.is_closed = true;
            self.write_buffer.deinit(self.allocator);
            self.file_entry.releaseLock();
        }
    }

    /// Free resources (should be called if not using finish/abort).
    pub fn deinit(self: *Self) void {
        self.close();
    }
};

/// Synchronous access handle for file operations.
/// https://fs.spec.whatwg.org/#api-filesystemsyncaccesshandle
///
/// Provides synchronous read/write access to a file.
/// Only available in dedicated workers for bucket file system files.
pub const SyncAccessHandle = struct {
    /// Reference to the parent file handle
    file_handle: *const FileSystemFileHandle,
    /// Reference to the file entry
    file_entry: *FileEntry,
    /// Reference to the backend
    file_backend: FileSystemBackend,
    /// Allocator for operations
    allocator: std.mem.Allocator,
    /// Current cursor position
    cursor_position: u64,
    /// Whether the handle has been closed
    is_closed: bool,

    const Self = @This();

    /// Read data from the file into a buffer.
    /// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-read
    ///
    /// Returns the number of bytes read.
    pub fn read(self: *Self, buffer: []u8, options: ReadWriteOptions) !u64 {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        const position = options.at orelse self.cursor_position;
        const data = self.file_entry.data();

        // Calculate how much we can read
        if (position >= data.len) {
            return 0;
        }

        const available = data.len - @as(usize, @intCast(position));
        const to_read = @min(buffer.len, available);

        // Copy data to buffer
        const start: usize = @intCast(position);
        @memcpy(buffer[0..to_read], data[start..][0..to_read]);

        // Update cursor if not using explicit position
        if (options.at == null) {
            self.cursor_position = position + to_read;
        }

        return to_read;
    }

    /// Write data from a buffer to the file.
    /// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-write
    ///
    /// Returns the number of bytes written.
    pub fn writeData(self: *Self, data: []const u8, options: ReadWriteOptions) !u64 {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        const position = options.at orelse self.cursor_position;

        // Get current data
        var current_data = std.ArrayListUnmanaged(u8){};
        defer current_data.deinit(self.allocator);
        try current_data.appendSlice(self.allocator, self.file_entry.data());

        // Expand if necessary
        const end_position = position + data.len;
        if (end_position > current_data.items.len) {
            try current_data.resize(self.allocator, end_position);
        }

        // Write data at position
        const start: usize = @intCast(position);
        @memcpy(current_data.items[start..][0..data.len], data);

        // Update file entry
        try self.file_entry.setData(current_data.items);

        // Update cursor if not using explicit position
        if (options.at == null) {
            self.cursor_position = end_position;
        }

        return data.len;
    }

    /// Truncate the file to a size.
    /// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-truncate
    pub fn truncate(self: *Self, new_size: u64) !void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        const current_data = self.file_entry.data();
        const size: usize = @intCast(new_size);

        if (size < current_data.len) {
            // Shrink
            try self.file_entry.setData(current_data[0..size]);
        } else if (size > current_data.len) {
            // Grow with zeros
            var new_data = std.ArrayListUnmanaged(u8){};
            defer new_data.deinit(self.allocator);
            try new_data.appendSlice(self.allocator, current_data);
            try new_data.appendNTimes(self.allocator, 0, size - current_data.len);
            try self.file_entry.setData(new_data.items);
        }

        // Adjust cursor if beyond new size
        if (self.cursor_position > new_size) {
            self.cursor_position = new_size;
        }
    }

    /// Get the size of the file.
    /// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-getsize
    pub fn getSize(self: *const Self) !u64 {
        if (self.is_closed) {
            return error.InvalidStateError;
        }
        return self.file_entry.size();
    }

    /// Flush any pending writes to storage.
    /// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-flush
    pub fn flush(self: *Self) !void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }
        // For in-memory implementation, this is a no-op
        // Real backends would sync to disk here
    }

    /// Close the handle and release the lock.
    /// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle-close
    pub fn close(self: *Self) void {
        if (!self.is_closed) {
            self.is_closed = true;
            self.file_entry.releaseLock();
        }
    }

    /// Free resources (same as close).
    pub fn deinit(self: *Self) void {
        self.close();
    }
};

/// Options for read/write operations.
/// https://fs.spec.whatwg.org/#dictdef-filesystemreadwriteoptions
pub const ReadWriteOptions = struct {
    /// Position to read/write at. If null, uses current cursor.
    at: ?u64 = null,
};

// ============================================================================
// Tests
// ============================================================================

test "FileSystemFileHandle - kind and name" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "example.txt" };

    const file_locator = try FileSystemLocator.file(allocator, "bucket:test", &components);
    var handle = try FileSystemFileHandle.init(allocator, file_locator, null);
    defer handle.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.file, handle.kind());
    try std.testing.expectEqualStrings("example.txt", handle.name());
}

test "FileSystemFileHandle - type mismatch error" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "mydir" };

    var dir_locator = try FileSystemLocator.directory(allocator, "bucket:test", &components);
    defer dir_locator.deinit();

    // Should fail because locator is for directory, not file
    const result = FileSystemFileHandle.init(allocator, dir_locator, null);
    try std.testing.expectError(error.TypeMismatch, result);
}

test "FileSystemFileHandle - isSameEntry" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "example.txt" };

    const loc1 = try FileSystemLocator.file(allocator, "bucket:test", &components);
    var handle1 = try FileSystemFileHandle.init(allocator, loc1, null);
    defer handle1.deinit();

    const loc2 = try FileSystemLocator.file(allocator, "bucket:test", &components);
    var handle2 = try FileSystemFileHandle.init(allocator, loc2, null);
    defer handle2.deinit();

    try std.testing.expect(handle1.isSameFileEntry(&handle2));
}

test "FileSystemFileHandle - bucket file system detection" {
    const allocator = std.testing.allocator;

    // Create a bucket file system handle
    const bucket_loc = try FileSystemLocator.bucketFile(allocator, "bucket:origin", "test.txt");
    var bucket_handle = try FileSystemFileHandle.init(allocator, bucket_loc, null);
    defer bucket_handle.deinit();

    try std.testing.expect(bucket_handle.isInBucketFileSystem());

    // Create a non-bucket handle
    const non_bucket_loc = try FileSystemLocator.file(allocator, "native:/", &[_][]const u8{ "Users", "test.txt" });
    var non_bucket_handle = try FileSystemFileHandle.init(allocator, non_bucket_loc, null);
    defer non_bucket_handle.deinit();

    try std.testing.expect(!non_bucket_handle.isInBucketFileSystem());
}

test "File - basic properties" {
    const allocator = std.testing.allocator;

    var file = try File.init(
        allocator,
        "test.txt",
        "Hello, World!",
        1234567890,
    );
    defer file.deinit();

    try std.testing.expectEqualStrings("test.txt", file.name);
    try std.testing.expectEqualStrings("Hello, World!", file.data);
    try std.testing.expectEqual(@as(u64, 13), file.size());
    try std.testing.expectEqual(@as(i64, 1234567890), file.last_modified);
}

test "WritableStreamHandle - write and seek" {
    const allocator = std.testing.allocator;

    // Create a mock file entry for testing
    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();

    // Simulate taking a lock (normally done by createWritable)
    _ = file_entry.takeLock(.shared);

    // Create the writable stream handle directly for testing
    var stream = WritableStreamHandle{
        .file_handle = undefined, // Not used in this test
        .file_entry = &file_entry,
        .keep_existing_data = false,
        .allocator = allocator,
    };
    defer stream.deinit();

    // Write some data
    try stream.write("Hello");
    try std.testing.expectEqual(@as(u64, 5), stream.cursor_position);

    // Seek and write more
    try stream.seek(0);
    try stream.write("Hi");
    try std.testing.expectEqualStrings("Hillo", stream.write_buffer.items);

    // Truncate
    try stream.truncate(2);
    try std.testing.expectEqualStrings("Hi", stream.write_buffer.items);
}

test "ReadWriteOptions - default values" {
    const options = ReadWriteOptions{};
    try std.testing.expect(options.at == null);

    const options_with_pos = ReadWriteOptions{ .at = 100 };
    try std.testing.expectEqual(@as(?u64, 100), options_with_pos.at);
}
