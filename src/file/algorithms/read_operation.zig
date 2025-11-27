//! W3C File API - Read Operation Algorithm
//!
//! This module implements the FileReader `read operation` algorithm
//! per W3C File API spec §6.2.3.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#readOperation
//!
//! ## Algorithm Overview
//!
//! The read operation algorithm:
//! 1. Validates FileReader state (throws if already LOADING)
//! 2. Sets state to LOADING, clears result and error
//! 3. Gets a stream from the blob
//! 4. Reads chunks asynchronously
//! 5. Fires progress events during read
//! 6. On completion, packages data and fires load/loadend
//! 7. On error, sets error and fires error/loadend
//!
//! ## Event Sequence
//!
//! Success: loadstart -> progress* -> load -> loadend
//! Error: loadstart -> progress* -> error -> loadend
//! Abort: loadstart -> progress* -> abort -> loadend
//!
//! ## Integration Notes
//!
//! This algorithm requires:
//! - Event loop integration (for async operations)
//! - EventTarget (for dispatching events)
//! - Streams API (for reading blob data)
//!
//! Currently implemented as a synchronous placeholder.
//! Full async implementation requires event loop integration.

const std = @import("std");
const BlobData = @import("../blob_internals.zig").BlobData;
const FileReaderData = @import("../file_reader_internals.zig").FileReaderData;
const FileReaderState = @import("../file_reader_internals.zig").FileReaderState;
const ReadType = @import("../file_reader_internals.zig").ReadType;
const package_data = @import("package_data.zig");

/// Error types for read operations.
pub const ReadError = error{
    /// FileReader is already loading
    InvalidStateError,
    /// File could not be read
    NotReadableError,
    /// File was modified during read
    NotFoundError,
    /// Read was aborted
    AbortError,
    /// Security error (cross-origin, etc.)
    SecurityError,
    /// Out of memory
    OutOfMemory,
};

/// Read operation result for async completion.
pub const ReadOperationResult = struct {
    /// Whether the read succeeded
    success: bool,
    /// Error name if failed
    error_name: ?[]const u8,
    /// Error message if failed
    error_message: ?[]const u8,
};

/// Start a read operation on a FileReader.
///
/// This is a synchronous implementation for now.
/// Full async implementation requires event loop integration.
///
/// Per spec §6.2.3:
/// 1. If state is LOADING, throw InvalidStateError
/// 2. Set state to LOADING
/// 3. Set result and error to null
/// 4. Read blob data
/// 5. Package data according to read type
/// 6. Set result and state to DONE
///
/// Note: This placeholder reads synchronously. Real implementation
/// should use async iteration with the Streams API.
pub fn startReadOperation(
    file_reader: *FileReaderData,
    blob: *const BlobData,
    read_type: ReadType,
    encoding: ?[]const u8,
) ReadError!void {
    // Step 1: If state is LOADING, throw InvalidStateError
    if (file_reader.state == .LOADING) {
        return ReadError.InvalidStateError;
    }

    // Step 2: Set state to LOADING
    file_reader.state = .LOADING;

    // Step 3: Clear result and error
    file_reader.clearResult();
    file_reader.error_name = null;
    file_reader.error_message = null;

    // Store read type and encoding
    file_reader.read_type = read_type;
    if (encoding) |enc| {
        file_reader.encoding = file_reader.allocator.dupe(u8, enc) catch {
            file_reader.state = .DONE;
            return ReadError.OutOfMemory;
        };
    }

    // Step 4-5: Read and package data (synchronous for now)
    // Real implementation would use async Streams API
    const packaged = package_data.packageData(
        file_reader.allocator,
        blob.bytes,
        convertReadType(read_type),
        blob.getType(),
        encoding,
    ) catch {
        // Set error state
        file_reader.state = .DONE;
        file_reader.setError("NotReadableError", "Failed to read blob data") catch {};
        return ReadError.NotReadableError;
    };

    // Step 6: Set result based on package type
    switch (packaged) {
        .array_buffer => |buf| {
            file_reader.result = .{ .array_buffer = buf };
        },
        .string => |str| {
            file_reader.result = .{ .string = str };
        },
    }

    // Step 7: Set state to DONE
    file_reader.state = .DONE;

    // Note: In full implementation, events would be fired here:
    // - loadstart (when starting)
    // - progress (during read)
    // - load (on success)
    // - loadend (always at end)
}

/// Convert FileReaderData.ReadType to package_data.ReadType
fn convertReadType(read_type: ReadType) package_data.ReadType {
    return switch (read_type) {
        .ArrayBuffer => .ArrayBuffer,
        .BinaryString => .BinaryString,
        .Text => .Text,
        .DataURL => .DataURL,
    };
}

/// Abort an in-progress read operation.
///
/// Per spec §6.2 (abort method):
/// 1. If state is EMPTY or DONE, set result to null and return
/// 2. If state is LOADING:
///    a. Set state to DONE
///    b. Set result to null
///    c. Fire abort event
///    d. Fire loadend event
pub fn abortReadOperation(file_reader: *FileReaderData) void {
    if (file_reader.state == .EMPTY or file_reader.state == .DONE) {
        file_reader.clearResult();
        return;
    }

    if (file_reader.state == .LOADING) {
        file_reader.state = .DONE;
        file_reader.clearResult();

        // Note: In full implementation, fire abort and loadend events
    }
}

test "read operation - basic read" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "text/plain");
    defer blob.deinit();

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    try startReadOperation(reader, blob, .Text, null);

    try std.testing.expectEqual(FileReaderState.DONE, reader.state);
    try std.testing.expectEqualStrings("Hello, World!", reader.result.string);
}

test "read operation - ArrayBuffer" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "application/octet-stream");
    defer blob.deinit();

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    try startReadOperation(reader, blob, .ArrayBuffer, null);

    try std.testing.expectEqual(FileReaderState.DONE, reader.state);
    try std.testing.expectEqualStrings("Hello", reader.result.array_buffer);
}

test "read operation - DataURL" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    try startReadOperation(reader, blob, .DataURL, null);

    try std.testing.expectEqual(FileReaderState.DONE, reader.state);
    try std.testing.expectEqualStrings("data:text/plain;base64,SGVsbG8=", reader.result.string);
}

test "read operation - already loading error" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    // Set to LOADING state
    reader.state = .LOADING;

    // Should fail with InvalidStateError
    const result = startReadOperation(reader, blob, .Text, null);
    try std.testing.expectError(ReadError.InvalidStateError, result);
}

test "read operation - abort during EMPTY" {
    const allocator = std.testing.allocator;

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    // Abort in EMPTY state should just clear result
    abortReadOperation(reader);

    try std.testing.expectEqual(FileReaderState.EMPTY, reader.state);
}

test "read operation - abort during LOADING" {
    const allocator = std.testing.allocator;

    const reader = try FileReaderData.init(allocator);
    defer reader.deinit();

    reader.state = .LOADING;
    try reader.setStringResult("partial data");

    abortReadOperation(reader);

    try std.testing.expectEqual(FileReaderState.DONE, reader.state);
    try std.testing.expect(reader.result == .none);
}
