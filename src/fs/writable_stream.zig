//! FileSystemWritableFileStream Implementation
//!
//! Spec: https://fs.spec.whatwg.org/#filesystemwritablefilestream
//!
//! A FileSystemWritableFileStream is a WritableStream that provides
//! additional convenience methods for writing to a file.
//!
//! Note: This implementation provides the file-system specific functionality.
//! The actual WritableStream integration happens at the JS binding layer
//! where this interfaces with the streams module.

const std = @import("std");
const file_handle_mod = @import("file_handle.zig");
const entry_mod = @import("entry.zig");
const errors = @import("errors.zig");

const FileEntry = entry_mod.FileEntry;
const FileSystemError = errors.FileSystemError;

/// Write command type for structured writes.
/// https://fs.spec.whatwg.org/#enumdef-writecommandtype
pub const WriteCommandType = enum {
    write,
    seek,
    truncate,

    pub fn toString(self: WriteCommandType) []const u8 {
        return switch (self) {
            .write => "write",
            .seek => "seek",
            .truncate => "truncate",
        };
    }

    pub fn fromString(str: []const u8) ?WriteCommandType {
        if (std.mem.eql(u8, str, "write")) return .write;
        if (std.mem.eql(u8, str, "seek")) return .seek;
        if (std.mem.eql(u8, str, "truncate")) return .truncate;
        return null;
    }
};

/// Write parameters for structured writes.
/// https://fs.spec.whatwg.org/#dictdef-writeparams
pub const WriteParams = struct {
    /// The type of write operation
    command_type: WriteCommandType,
    /// Size for truncate operations
    size: ?u64 = null,
    /// Position for seek operations or write offset
    position: ?u64 = null,
    /// Data for write operations
    data: ?WriteData = null,

    /// Create a write command
    pub fn write(data: WriteData) WriteParams {
        return .{
            .command_type = .write,
            .data = data,
        };
    }

    /// Create a write command at a specific position
    pub fn writeAt(data: WriteData, position: u64) WriteParams {
        return .{
            .command_type = .write,
            .data = data,
            .position = position,
        };
    }

    /// Create a seek command
    pub fn seek(position: u64) WriteParams {
        return .{
            .command_type = .seek,
            .position = position,
        };
    }

    /// Create a truncate command
    pub fn truncate(size: u64) WriteParams {
        return .{
            .command_type = .truncate,
            .size = size,
        };
    }
};

/// Data types that can be written.
/// Corresponds to (BufferSource or Blob or USVString)
pub const WriteData = union(enum) {
    /// Raw bytes (BufferSource)
    bytes: []const u8,
    /// String data (USVString) - stored as bytes
    string: []const u8,
    /// Blob reference (for future Blob integration)
    blob: BlobRef,

    /// Get the data as bytes
    pub fn asBytes(self: WriteData) []const u8 {
        return switch (self) {
            .bytes => |b| b,
            .string => |s| s,
            .blob => |b| b.data,
        };
    }

    /// Get the length of the data
    pub fn len(self: WriteData) usize {
        return switch (self) {
            .bytes => |b| b.len,
            .string => |s| s.len,
            .blob => |b| b.data.len,
        };
    }
};

/// Blob reference for write operations.
/// This is a simplified representation - actual Blob integration
/// would come from the File API module.
pub const BlobRef = struct {
    /// The blob data
    data: []const u8,
    /// The blob MIME type
    mime_type: []const u8 = "application/octet-stream",
};

/// FileSystemWritableFileStream provides atomic write operations to a file.
/// https://fs.spec.whatwg.org/#filesystemwritablefilestream
///
/// Internal slots:
/// - [[file]]: The associated file entry
/// - [[buffer]]: Temporary buffer for writes
/// - [[seekOffset]]: Current write position
///
/// This type manages the low-level file writing. The actual WritableStream
/// wrapper is created at the JS binding layer.
pub const FileSystemWritableFileStream = struct {
    /// The associated file entry [[file]]
    file_entry: *FileEntry,
    /// Temporary buffer for writes [[buffer]]
    buffer: std.ArrayListUnmanaged(u8),
    /// Current write position [[seekOffset]]
    seek_offset: u64,
    /// Allocator for buffer operations
    allocator: std.mem.Allocator,
    /// Whether the stream is closed
    is_closed: bool,
    /// Whether keepExistingData was set
    keep_existing_data: bool,

    const Self = @This();

    /// Create a new FileSystemWritableFileStream.
    /// https://fs.spec.whatwg.org/#create-a-new-filesystemwritablefilestream
    ///
    /// The file entry should already have a shared lock taken.
    pub fn init(
        allocator: std.mem.Allocator,
        file_entry: *FileEntry,
        keep_existing_data: bool,
    ) !Self {
        var buffer = std.ArrayListUnmanaged(u8){};
        errdefer buffer.deinit(allocator);

        // If keeping existing data, copy it to the buffer
        if (keep_existing_data) {
            const data = file_entry.data();
            try buffer.appendSlice(allocator, data);
        }

        return .{
            .file_entry = file_entry,
            .buffer = buffer,
            .seek_offset = 0,
            .allocator = allocator,
            .is_closed = false,
            .keep_existing_data = keep_existing_data,
        };
    }

    /// Write data to the stream.
    /// https://fs.spec.whatwg.org/#dom-filesystemwritablefilestream-write
    ///
    /// Accepts FileSystemWriteChunkType which can be:
    /// - BufferSource (bytes)
    /// - Blob
    /// - USVString
    /// - WriteParams (structured write command)
    pub fn write(self: *Self, chunk: FileSystemWriteChunkType) WriteError!void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        switch (chunk) {
            .params => |params| try self.processWriteParams(params),
            .data => |data| try self.writeDataAtCursor(data),
        }
    }

    /// Seek to a position in the file.
    /// https://fs.spec.whatwg.org/#dom-filesystemwritablefilestream-seek
    pub fn seek(self: *Self, position: u64) WriteError!void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }
        self.seek_offset = position;
    }

    /// Truncate the file to a size.
    /// https://fs.spec.whatwg.org/#dom-filesystemwritablefilestream-truncate
    pub fn truncate(self: *Self, size: u64) WriteError!void {
        if (self.is_closed) {
            return error.InvalidStateError;
        }

        const new_size: usize = @intCast(size);

        if (new_size < self.buffer.items.len) {
            // Shrink the buffer
            self.buffer.shrinkRetainingCapacity(new_size);
        } else if (new_size > self.buffer.items.len) {
            // Grow the buffer, filling with zeros
            const old_len = self.buffer.items.len;
            try self.buffer.resize(self.allocator, new_size);
            @memset(self.buffer.items[old_len..], 0);
        }

        // Adjust cursor if beyond new size
        if (self.seek_offset > size) {
            self.seek_offset = size;
        }
    }

    /// Process a structured WriteParams command.
    fn processWriteParams(self: *Self, params: WriteParams) WriteError!void {
        switch (params.command_type) {
            .write => {
                // If position is specified, seek first
                if (params.position) |pos| {
                    self.seek_offset = pos;
                }
                // Write the data
                if (params.data) |data| {
                    try self.writeDataAtCursor(data);
                }
            },
            .seek => {
                if (params.position) |pos| {
                    self.seek_offset = pos;
                } else {
                    return error.SyntaxError;
                }
            },
            .truncate => {
                if (params.size) |size| {
                    try self.truncate(size);
                } else {
                    return error.SyntaxError;
                }
            },
        }
    }

    /// Write data at the current cursor position.
    fn writeDataAtCursor(self: *Self, data: WriteData) WriteError!void {
        const bytes = data.asBytes();
        const start: usize = @intCast(self.seek_offset);
        const end = start + bytes.len;

        // Ensure buffer is large enough
        if (end > self.buffer.items.len) {
            const old_len = self.buffer.items.len;
            try self.buffer.resize(self.allocator, end);
            // Zero-fill any gap
            if (start > old_len) {
                @memset(self.buffer.items[old_len..start], 0);
            }
        }

        // Write the data
        @memcpy(self.buffer.items[start..end], bytes);

        // Advance cursor
        self.seek_offset = end;
    }

    /// Close the stream and commit changes.
    /// https://fs.spec.whatwg.org/#filesystemwritablefilestream-close
    ///
    /// This atomically replaces the file contents with the buffer.
    pub fn close(self: *Self) WriteError!void {
        if (self.is_closed) {
            return;
        }

        defer {
            self.is_closed = true;
            self.file_entry.releaseLock();
            self.buffer.deinit(self.allocator);
        }

        // Commit the buffer to the file
        try self.file_entry.setData(self.buffer.items);
    }

    /// Abort the stream and discard changes.
    /// https://fs.spec.whatwg.org/#filesystemwritablefilestream-abort
    pub fn abort(self: *Self) void {
        if (self.is_closed) {
            return;
        }

        self.is_closed = true;
        self.file_entry.releaseLock();
        self.buffer.deinit(self.allocator);
    }

    /// Get the current buffer contents (for debugging/testing).
    pub fn getBufferContents(self: *const Self) []const u8 {
        return self.buffer.items;
    }

    /// Get the current seek offset.
    pub fn getSeekOffset(self: *const Self) u64 {
        return self.seek_offset;
    }

    /// Check if the stream is closed.
    pub fn isClosed(self: *const Self) bool {
        return self.is_closed;
    }

    /// Free resources (called automatically on close/abort).
    pub fn deinit(self: *Self) void {
        if (!self.is_closed) {
            self.abort();
        }
    }
};

/// FileSystemWriteChunkType union.
/// https://fs.spec.whatwg.org/#typedefdef-filesystemwritechunktype
///
/// Can be:
/// - BufferSource (bytes)
/// - Blob
/// - USVString
/// - WriteParams
pub const FileSystemWriteChunkType = union(enum) {
    /// Direct data (bytes, string, or blob)
    data: WriteData,
    /// Structured write command
    params: WriteParams,

    /// Create from raw bytes
    pub fn fromBytes(bytes: []const u8) FileSystemWriteChunkType {
        return .{ .data = .{ .bytes = bytes } };
    }

    /// Create from string
    pub fn fromString(str: []const u8) FileSystemWriteChunkType {
        return .{ .data = .{ .string = str } };
    }

    /// Create from WriteParams
    pub fn fromParams(params: WriteParams) FileSystemWriteChunkType {
        return .{ .params = params };
    }
};

/// Error set for write operations.
pub const WriteError = error{
    /// Stream is closed
    InvalidStateError,
    /// Invalid command syntax
    SyntaxError,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// Tests
// ============================================================================

test "WriteCommandType - toString and fromString" {
    try std.testing.expectEqualStrings("write", WriteCommandType.write.toString());
    try std.testing.expectEqualStrings("seek", WriteCommandType.seek.toString());
    try std.testing.expectEqualStrings("truncate", WriteCommandType.truncate.toString());

    try std.testing.expectEqual(WriteCommandType.write, WriteCommandType.fromString("write").?);
    try std.testing.expectEqual(WriteCommandType.seek, WriteCommandType.fromString("seek").?);
    try std.testing.expectEqual(WriteCommandType.truncate, WriteCommandType.fromString("truncate").?);
    try std.testing.expect(WriteCommandType.fromString("invalid") == null);
}

test "WriteParams - factory methods" {
    const write_cmd = WriteParams.write(.{ .bytes = "test" });
    try std.testing.expectEqual(WriteCommandType.write, write_cmd.command_type);
    try std.testing.expectEqualStrings("test", write_cmd.data.?.asBytes());

    const write_at_cmd = WriteParams.writeAt(.{ .bytes = "data" }, 100);
    try std.testing.expectEqual(WriteCommandType.write, write_at_cmd.command_type);
    try std.testing.expectEqual(@as(?u64, 100), write_at_cmd.position);

    const seek_cmd = WriteParams.seek(50);
    try std.testing.expectEqual(WriteCommandType.seek, seek_cmd.command_type);
    try std.testing.expectEqual(@as(?u64, 50), seek_cmd.position);

    const truncate_cmd = WriteParams.truncate(200);
    try std.testing.expectEqual(WriteCommandType.truncate, truncate_cmd.command_type);
    try std.testing.expectEqual(@as(?u64, 200), truncate_cmd.size);
}

test "WriteData - asBytes" {
    const bytes_data = WriteData{ .bytes = "hello" };
    try std.testing.expectEqualStrings("hello", bytes_data.asBytes());

    const string_data = WriteData{ .string = "world" };
    try std.testing.expectEqualStrings("world", string_data.asBytes());

    const blob_data = WriteData{ .blob = .{ .data = "blob data" } };
    try std.testing.expectEqualStrings("blob data", blob_data.asBytes());
}

test "FileSystemWritableFileStream - basic write" {
    const allocator = std.testing.allocator;

    // Create a test file entry
    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();

    // Take a lock (normally done by createWritable)
    _ = file_entry.takeLock(.shared);

    // Create the stream
    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, false);
    defer stream.deinit();

    // Write some data
    try stream.write(FileSystemWriteChunkType.fromBytes("Hello, "));
    try std.testing.expectEqual(@as(u64, 7), stream.getSeekOffset());

    try stream.write(FileSystemWriteChunkType.fromBytes("World!"));
    try std.testing.expectEqual(@as(u64, 13), stream.getSeekOffset());

    try std.testing.expectEqualStrings("Hello, World!", stream.getBufferContents());
}

test "FileSystemWritableFileStream - seek and write" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.shared);

    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, false);
    defer stream.deinit();

    // Write initial data
    try stream.write(FileSystemWriteChunkType.fromBytes("Hello World"));

    // Seek back and overwrite
    try stream.seek(6);
    try stream.write(FileSystemWriteChunkType.fromBytes("Zig!"));

    try std.testing.expectEqualStrings("Hello Zig!d", stream.getBufferContents());
}

test "FileSystemWritableFileStream - truncate" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.shared);

    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, false);
    defer stream.deinit();

    // Write data
    try stream.write(FileSystemWriteChunkType.fromBytes("Hello World!"));

    // Truncate to 5 bytes
    try stream.truncate(5);
    try std.testing.expectEqualStrings("Hello", stream.getBufferContents());
    try std.testing.expectEqual(@as(u64, 5), stream.getSeekOffset()); // Cursor adjusted

    // Truncate to larger size (fills with zeros)
    try stream.truncate(10);
    try std.testing.expectEqual(@as(usize, 10), stream.getBufferContents().len);
}

test "FileSystemWritableFileStream - write params" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.shared);

    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, false);
    defer stream.deinit();

    // Write with position
    try stream.write(FileSystemWriteChunkType.fromParams(
        WriteParams.writeAt(.{ .bytes = "World" }, 7),
    ));

    // Write at beginning
    try stream.write(FileSystemWriteChunkType.fromParams(
        WriteParams.writeAt(.{ .bytes = "Hello, " }, 0),
    ));

    try std.testing.expectEqualStrings("Hello, World", stream.getBufferContents());
}

test "FileSystemWritableFileStream - keep existing data" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();

    // Set initial data
    try file_entry.setData("Existing content");

    _ = file_entry.takeLock(.shared);

    // Create stream with keepExistingData = true
    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, true);
    defer stream.deinit();

    // Buffer should contain existing data
    try std.testing.expectEqualStrings("Existing content", stream.getBufferContents());

    // Write at end
    try stream.seek(16);
    try stream.write(FileSystemWriteChunkType.fromBytes(" plus more"));

    try std.testing.expectEqualStrings("Existing content plus more", stream.getBufferContents());
}

test "FileSystemWritableFileStream - close commits data" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    _ = file_entry.takeLock(.shared);

    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, false);

    // Write data
    try stream.write(FileSystemWriteChunkType.fromBytes("Final content"));

    // Close commits the data
    try stream.close();

    // File entry should now have the data
    try std.testing.expectEqualStrings("Final content", file_entry.data());
    try std.testing.expect(!file_entry.isLocked());
}

test "FileSystemWritableFileStream - abort discards data" {
    const allocator = std.testing.allocator;

    var file_entry = try FileEntry.init(allocator, "test.txt");
    defer file_entry.deinit();
    try file_entry.setData("Original");
    _ = file_entry.takeLock(.shared);

    var stream = try FileSystemWritableFileStream.init(allocator, &file_entry, false);

    // Write data
    try stream.write(FileSystemWriteChunkType.fromBytes("New content"));

    // Abort discards the data
    stream.abort();

    // File entry should still have original data
    try std.testing.expectEqualStrings("Original", file_entry.data());
    try std.testing.expect(!file_entry.isLocked());
}

test "FileSystemWriteChunkType - factory methods" {
    const bytes_chunk = FileSystemWriteChunkType.fromBytes("test");
    switch (bytes_chunk) {
        .data => |d| try std.testing.expectEqualStrings("test", d.asBytes()),
        else => return error.UnexpectedValue,
    }

    const string_chunk = FileSystemWriteChunkType.fromString("hello");
    switch (string_chunk) {
        .data => |d| try std.testing.expectEqualStrings("hello", d.asBytes()),
        else => return error.UnexpectedValue,
    }

    const params_chunk = FileSystemWriteChunkType.fromParams(WriteParams.seek(100));
    switch (params_chunk) {
        .params => |p| try std.testing.expectEqual(WriteCommandType.seek, p.command_type),
        else => return error.UnexpectedValue,
    }
}
