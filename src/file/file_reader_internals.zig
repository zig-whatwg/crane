//! W3C File API - FileReader Internal Data Structure
//!
//! This module implements the internal state machine for FileReader objects.
//! FileReader provides async methods to read File/Blob contents.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#APIASynch
//!
//! ## FileReader States
//!
//! Per spec §6.2:
//! - EMPTY (0): No read initiated
//! - LOADING (1): Read in progress
//! - DONE (2): Read complete (success, error, or abort)
//!
//! ## Read Types
//!
//! FileReader supports reading as:
//! - ArrayBuffer (readAsArrayBuffer)
//! - BinaryString (readAsBinaryString) - legacy
//! - Text (readAsText) - with optional encoding
//! - DataURL (readAsDataURL) - base64 encoded
//!
//! ## Event Sequence
//!
//! A successful read fires events in order:
//! 1. loadstart
//! 2. progress (zero or more)
//! 3. load
//! 4. loadend

const std = @import("std");

/// FileReader state constants per W3C File API spec.
pub const FileReaderState = enum(u16) {
    /// No read initiated
    EMPTY = 0,
    /// Read in progress
    LOADING = 1,
    /// Read complete (success, error, or abort)
    DONE = 2,
};

/// The type of read operation being performed.
pub const ReadType = enum {
    /// readAsArrayBuffer - returns ArrayBuffer
    ArrayBuffer,
    /// readAsBinaryString - returns binary string (legacy)
    BinaryString,
    /// readAsText - returns string with encoding
    Text,
    /// readAsDataURL - returns base64 data URL
    DataURL,
};

/// The result of a read operation.
pub const ReadResult = union(enum) {
    /// ArrayBuffer result
    array_buffer: []const u8,
    /// String result (text or binary string)
    string: []const u8,
    /// No result yet
    none: void,
};

/// Internal data storage for a FileReader object.
///
/// FileReader is an EventTarget that maintains:
/// - Current state (EMPTY, LOADING, DONE)
/// - Read result (ArrayBuffer or string)
/// - Error information (DOMException)
/// - Event handlers
pub const FileReaderData = struct {
    /// Current state of the FileReader
    state: FileReaderState,

    /// The result of the read operation
    result: ReadResult,

    /// Error from failed read (if any)
    /// In real implementation, this would be a DOMException
    error_name: ?[]const u8,
    error_message: ?[]const u8,

    /// Type of current/last read operation
    read_type: ?ReadType,

    /// Encoding for text reads
    encoding: ?[]const u8,

    /// Memory allocator for cleanup
    allocator: std.mem.Allocator,

    /// Initialize a new FileReaderData in EMPTY state.
    pub fn init(allocator: std.mem.Allocator) !*FileReaderData {
        const self = try allocator.create(FileReaderData);

        self.* = .{
            .state = .EMPTY,
            .result = .none,
            .error_name = null,
            .error_message = null,
            .read_type = null,
            .encoding = null,
            .allocator = allocator,
        };

        return self;
    }

    /// Clean up resources.
    pub fn deinit(self: *FileReaderData) void {
        self.clearResult();
        if (self.error_name) |name| {
            self.allocator.free(@constCast(name));
        }
        if (self.error_message) |msg| {
            self.allocator.free(@constCast(msg));
        }
        if (self.encoding) |enc| {
            self.allocator.free(@constCast(enc));
        }
        self.allocator.destroy(self);
    }

    /// Clear the result and free any associated memory.
    pub fn clearResult(self: *FileReaderData) void {
        switch (self.result) {
            .array_buffer => |buf| self.allocator.free(@constCast(buf)),
            .string => |str| self.allocator.free(@constCast(str)),
            .none => {},
        }
        self.result = .none;
    }

    /// Set the result to an ArrayBuffer.
    pub fn setArrayBufferResult(self: *FileReaderData, bytes: []const u8) !void {
        self.clearResult();
        const owned = try self.allocator.dupe(u8, bytes);
        self.result = .{ .array_buffer = owned };
    }

    /// Set the result to a string.
    pub fn setStringResult(self: *FileReaderData, str: []const u8) !void {
        self.clearResult();
        const owned = try self.allocator.dupe(u8, str);
        self.result = .{ .string = owned };
    }

    /// Set an error condition.
    pub fn setError(self: *FileReaderData, name: []const u8, message: []const u8) !void {
        if (self.error_name) |n| {
            self.allocator.free(@constCast(n));
        }
        if (self.error_message) |m| {
            self.allocator.free(@constCast(m));
        }
        self.error_name = try self.allocator.dupe(u8, name);
        self.error_message = try self.allocator.dupe(u8, message);
    }

    /// Get the readyState value.
    pub fn getReadyState(self: *const FileReaderData) u16 {
        return @intFromEnum(self.state);
    }

    /// Check if currently loading.
    pub fn isLoading(self: *const FileReaderData) bool {
        return self.state == .LOADING;
    }
};

test "FileReaderData - initial state" {
    const allocator = std.testing.allocator;

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    try std.testing.expectEqual(FileReaderState.EMPTY, reader.state);
    try std.testing.expectEqual(@as(u16, 0), reader.getReadyState());
    try std.testing.expect(!reader.isLoading());
}

test "FileReaderData - state transitions" {
    const allocator = std.testing.allocator;

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    // Simulate starting a read
    reader.state = .LOADING;
    try std.testing.expectEqual(@as(u16, 1), reader.getReadyState());
    try std.testing.expect(reader.isLoading());

    // Simulate completing a read
    reader.state = .DONE;
    try std.testing.expectEqual(@as(u16, 2), reader.getReadyState());
    try std.testing.expect(!reader.isLoading());
}

test "FileReaderData - result handling" {
    const allocator = std.testing.allocator;

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    // Set string result
    try reader.setStringResult("Hello, World!");
    try std.testing.expectEqualStrings("Hello, World!", reader.result.string);

    // Replace with ArrayBuffer result
    try reader.setArrayBufferResult(&[_]u8{ 1, 2, 3, 4 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4 }, reader.result.array_buffer);
}

test "FileReaderData - error handling" {
    const allocator = std.testing.allocator;

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    try reader.setError("NotReadableError", "The file could not be read");
    try std.testing.expectEqualStrings("NotReadableError", reader.error_name.?);
    try std.testing.expectEqualStrings("The file could not be read", reader.error_message.?);
}
