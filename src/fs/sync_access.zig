//! FileSystemSyncAccessHandle Implementation
//!
//! Spec: https://fs.spec.whatwg.org/#filesystemsyncaccesshandle
//!
//! A FileSystemSyncAccessHandle provides synchronous read and write access
//! to a file. It is only available in dedicated workers and for files in
//! bucket file systems.
//!
//! This is a self-contained implementation that doesn't depend on the
//! WritableStreamHandle from file_handle.zig, providing the full spec
//! interface directly.

const std = @import("std");
const entry_mod = @import("entry.zig");
const backend_mod = @import("backend.zig");
const errors = @import("errors.zig");

const FileEntry = entry_mod.FileEntry;
const FileSystemBackend = backend_mod.FileSystemBackend;

/// Options for read/write operations.
/// https://fs.spec.whatwg.org/#dictdef-filesystemreadwriteoptions
pub const FileSystemReadWriteOptions = struct {
    /// The position at which to read/write.
    /// If null, uses the current file position cursor.
    at: ?u64 = null,
};

/// FileSystemSyncAccessHandle provides synchronous file access.
/// https://fs.spec.whatwg.org/#filesystemsyncaccesshandle
///
/// Internal slots:
/// - [[file]]: The associated file entry
/// - [[state]]: "open" or "closed"
/// - file position cursor (implicit)
///
/// Restrictions:
/// - Only available in DedicatedWorker
/// - Only for files in bucket file systems
/// - Requires exclusive lock on the file
pub const FileSystemSyncAccessHandle = struct {
    /// The associated file entry [[file]]
    file_entry: *FileEntry,
    /// The backend (optional, for advanced operations)
    backend: ?FileSystemBackend,
    /// Allocator for operations
    allocator: std.mem.Allocator,
    /// Current file position cursor
    file_position: u64,
    /// The state [[state]]: true = open, false = closed
    is_open: bool,

    const Self = @This();

    /// Create a new FileSystemSyncAccessHandle.
    ///
    /// The file entry should already have an exclusive lock taken.
    /// This is typically called from FileSystemFileHandle.createSyncAccessHandle().
    pub fn init(
        allocator: std.mem.Allocator,
        file_entry: *FileEntry,
        backend: ?FileSystemBackend,
    ) Self {
        return .{
            .file_entry = file_entry,
            .backend = backend,
            .allocator = allocator,
            .file_position = 0,
            .is_open = true,
        };
    }

    /// Read data from the file into a buffer.
    /// https://fs.spec.whatwg.org/#dom-filesystemsyncaccesshandle-read
    ///
    /// Returns the number of bytes read.
    pub fn read(self: *Self, buffer: []u8, options: FileSystemReadWriteOptions) SyncAccessError!u64 {
        if (!self.is_open) {
            return error.InvalidStateError;
        }

        const position = options.at orelse self.file_position;
        const file_data = self.file_entry.data();

        // If position is at or beyond EOF, return 0
        if (position >= file_data.len) {
            return 0;
        }

        // Calculate how much we can read
        const start: usize = @intCast(position);
        const available = file_data.len - start;
        const bytes_to_read = @min(buffer.len, available);

        // Copy data to buffer
        @memcpy(buffer[0..bytes_to_read], file_data[start..][0..bytes_to_read]);

        // Update file position if not using explicit position
        if (options.at == null) {
            self.file_position = position + bytes_to_read;
        }

        return bytes_to_read;
    }

    /// Write data from a buffer to the file.
    /// https://fs.spec.whatwg.org/#dom-filesystemsyncaccesshandle-write
    ///
    /// Returns the number of bytes written.
    pub fn write(self: *Self, buffer: []const u8, options: FileSystemReadWriteOptions) SyncAccessError!u64 {
        if (!self.is_open) {
            return error.InvalidStateError;
        }

        const position = options.at orelse self.file_position;
        const start: usize = @intCast(position);
        const end = start + buffer.len;

        // Get current file data
        const current_data = self.file_entry.data();

        // Build new data
        var new_data = std.ArrayListUnmanaged(u8){};
        defer new_data.deinit(self.allocator);

        // Ensure capacity for the result
        const new_size = @max(current_data.len, end);
        try new_data.resize(self.allocator, new_size);

        // Copy existing data
        if (current_data.len > 0) {
            @memcpy(new_data.items[0..current_data.len], current_data);
        }

        // Zero-fill gap if writing beyond current end
        if (start > current_data.len) {
            @memset(new_data.items[current_data.len..start], 0);
        }

        // Write new data
        @memcpy(new_data.items[start..end], buffer);

        // Update file entry
        self.file_entry.setData(new_data.items) catch return error.QuotaExceededError;

        // Update file position if not using explicit position
        if (options.at == null) {
            self.file_position = end;
        }

        return buffer.len;
    }

    /// Truncate the file to a new size.
    /// https://fs.spec.whatwg.org/#dom-filesystemsyncaccesshandle-truncate
    pub fn truncate(self: *Self, new_size: u64) SyncAccessError!void {
        if (!self.is_open) {
            return error.InvalidStateError;
        }

        const size: usize = @intCast(new_size);
        const current_data = self.file_entry.data();

        if (size == current_data.len) {
            // No change needed
            return;
        }

        if (size < current_data.len) {
            // Shrink: copy to temp buffer first to avoid aliasing
            var new_data = std.ArrayListUnmanaged(u8){};
            defer new_data.deinit(self.allocator);

            try new_data.appendSlice(self.allocator, current_data[0..size]);
            self.file_entry.setData(new_data.items) catch return error.QuotaExceededError;
        } else {
            // Grow: append zeros
            var new_data = std.ArrayListUnmanaged(u8){};
            defer new_data.deinit(self.allocator);

            try new_data.appendSlice(self.allocator, current_data);
            try new_data.appendNTimes(self.allocator, 0, size - current_data.len);

            self.file_entry.setData(new_data.items) catch return error.QuotaExceededError;
        }

        // Adjust file position if beyond new size
        if (self.file_position > new_size) {
            self.file_position = new_size;
        }
    }

    /// Get the size of the file.
    /// https://fs.spec.whatwg.org/#dom-filesystemsyncaccesshandle-getsize
    pub fn getSize(self: *const Self) SyncAccessError!u64 {
        if (!self.is_open) {
            return error.InvalidStateError;
        }
        return self.file_entry.size();
    }

    /// Flush any pending writes to storage.
    /// https://fs.spec.whatwg.org/#dom-filesystemsyncaccesshandle-flush
    ///
    /// For in-memory backends, this is a no-op.
    /// Real file system backends would sync to disk.
    pub fn flush(self: *Self) SyncAccessError!void {
        if (!self.is_open) {
            return error.InvalidStateError;
        }
        // In-memory implementation: data is already "persisted"
        // A real backend would call fsync() or equivalent here
    }

    /// Close the handle and release the exclusive lock.
    /// https://fs.spec.whatwg.org/#dom-filesystemsyncaccesshandle-close
    pub fn close(self: *Self) void {
        if (!self.is_open) {
            return;
        }
        self.is_open = false;
        self.file_entry.releaseLock();
    }

    /// Get the current file position.
    pub fn getFilePosition(self: *const Self) u64 {
        return self.file_position;
    }

    /// Check if the handle is open.
    pub fn isOpen(self: *const Self) bool {
        return self.is_open;
    }

    /// Clean up resources.
    pub fn deinit(self: *Self) void {
        self.close();
    }
};

/// Error set for sync access operations.
pub const SyncAccessError = error{
    /// Handle is closed
    InvalidStateError,
    /// Storage quota exceeded
    QuotaExceededError,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// Tests
// ============================================================================

test "FileSystemSyncAccessHandle - read" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();

    // Set up test data
    try file_entry.setData("Hello, World!");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Read into buffer
    var buffer: [20]u8 = undefined;
    const bytes_read = try handle.read(&buffer, .{});

    try std.testing.expectEqual(@as(u64, 13), bytes_read);
    try std.testing.expectEqualStrings("Hello, World!", buffer[0..13]);
    try std.testing.expectEqual(@as(u64, 13), handle.getFilePosition());
}

test "FileSystemSyncAccessHandle - read with position" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();

    try file_entry.setData("Hello, World!");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Read from specific position
    var buffer: [10]u8 = undefined;
    const bytes_read = try handle.read(&buffer, .{ .at = 7 });

    try std.testing.expectEqual(@as(u64, 6), bytes_read);
    try std.testing.expectEqualStrings("World!", buffer[0..6]);

    // File position should not have changed
    try std.testing.expectEqual(@as(u64, 0), handle.getFilePosition());
}

test "FileSystemSyncAccessHandle - write" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Write data
    const bytes_written = try handle.write("Hello", .{});
    try std.testing.expectEqual(@as(u64, 5), bytes_written);
    try std.testing.expectEqualStrings("Hello", file_entry.data());

    // Write more
    _ = try handle.write(", World!", .{});
    try std.testing.expectEqualStrings("Hello, World!", file_entry.data());
}

test "FileSystemSyncAccessHandle - write with position" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    try file_entry.setData("Hello World");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Overwrite at position
    _ = try handle.write("Zig!", .{ .at = 6 });
    try std.testing.expectEqualStrings("Hello Zig!d", file_entry.data());

    // File position should not have changed
    try std.testing.expectEqual(@as(u64, 0), handle.getFilePosition());
}

test "FileSystemSyncAccessHandle - write beyond end" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    try file_entry.setData("Hi");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Write beyond end (should zero-fill gap)
    _ = try handle.write("End", .{ .at = 5 });

    const expected = "Hi\x00\x00\x00End";
    try std.testing.expectEqual(@as(usize, 8), file_entry.data().len);
    try std.testing.expectEqualSlices(u8, expected, file_entry.data());
}

test "FileSystemSyncAccessHandle - truncate shrink" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    try file_entry.setData("Hello, World!");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Set position beyond truncate point
    handle.file_position = 10;

    try handle.truncate(5);
    try std.testing.expectEqualStrings("Hello", file_entry.data());

    // Position should be adjusted
    try std.testing.expectEqual(@as(u64, 5), handle.getFilePosition());
}

test "FileSystemSyncAccessHandle - truncate grow" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    try file_entry.setData("Hi");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    try handle.truncate(10);
    try std.testing.expectEqual(@as(usize, 10), file_entry.data().len);

    // First two bytes should be original data
    try std.testing.expectEqualStrings("Hi", file_entry.data()[0..2]);

    // Rest should be zeros
    for (file_entry.data()[2..]) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

test "FileSystemSyncAccessHandle - getSize" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    try file_entry.setData("Hello");
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    const size = try handle.getSize();
    try std.testing.expectEqual(@as(u64, 5), size);
}

test "FileSystemSyncAccessHandle - flush" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    defer handle.deinit();

    // Flush should succeed (no-op for in-memory)
    try handle.flush();
}

test "FileSystemSyncAccessHandle - close releases lock" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);

    try std.testing.expect(file_entry.isLocked());
    try std.testing.expect(handle.isOpen());

    handle.close();

    try std.testing.expect(!file_entry.isLocked());
    try std.testing.expect(!handle.isOpen());
}

test "FileSystemSyncAccessHandle - operations on closed handle" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.exclusive);

    var handle = FileSystemSyncAccessHandle.init(allocator, &file_entry, null);
    handle.close();

    // All operations should fail with InvalidStateError
    var buffer: [10]u8 = undefined;
    try std.testing.expectError(error.InvalidStateError, handle.read(&buffer, .{}));
    try std.testing.expectError(error.InvalidStateError, handle.write("test", .{}));
    try std.testing.expectError(error.InvalidStateError, handle.truncate(10));
    try std.testing.expectError(error.InvalidStateError, handle.getSize());
    try std.testing.expectError(error.InvalidStateError, handle.flush());
}

test "FileSystemReadWriteOptions - default values" {
    const options = FileSystemReadWriteOptions{};
    try std.testing.expect(options.at == null);

    const with_position = FileSystemReadWriteOptions{ .at = 100 };
    try std.testing.expectEqual(@as(?u64, 100), with_position.at);
}
