//! Streaming Response Source - WHATWG Fetch Implementation
//!
//! Provides a chunk-based interface for reading response bodies, enabling
//! ReadableStream-like consumption patterns without requiring full runtime.
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-body
//!
//! Phase 3a: Basic streaming from buffered data
//! - Chunks pre-buffered response data
//! - Provides pull-based iteration
//! - Tracks read position and completion
//!
//! Phase 3b (Future): True streaming with curl_multi
//! - Background transfer thread
//! - curl_easy_pause for backpressure
//! - Real-time chunk delivery

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Default chunk size for streaming (64KB)
pub const DEFAULT_CHUNK_SIZE: usize = 64 * 1024;

/// Streaming source state
pub const StreamingState = enum {
    /// Stream is ready to read
    readable,
    /// Stream has been fully consumed
    closed,
    /// Stream encountered an error
    errored,
    /// Stream was cancelled
    cancelled,
};

/// Streaming source for response body data.
///
/// Provides chunk-based access to buffered response data, enabling
/// incremental processing patterns similar to ReadableStream.
///
/// Usage:
/// ```zig
/// var source = StreamingSource.fromBytes(allocator, response_body, .{});
/// defer source.deinit();
///
/// while (try source.read()) |chunk| {
///     // Process chunk
///     defer allocator.free(chunk);
/// }
/// // Stream is now closed
/// ```
pub const StreamingSource = struct {
    allocator: Allocator,

    /// The underlying data buffer
    data: []const u8,

    /// Current read position
    position: usize,

    /// Chunk size for reads
    chunk_size: usize,

    /// Current state
    state: StreamingState,

    /// Whether we own the data buffer
    owns_data: bool,

    /// Error message if errored
    error_message: ?[]const u8,

    /// Total bytes read so far
    bytes_read: usize,

    const Self = @This();

    /// Options for creating a streaming source
    pub const Options = struct {
        /// Size of chunks to return (default: 64KB)
        chunk_size: usize = DEFAULT_CHUNK_SIZE,
    };

    /// Create a streaming source from a byte slice.
    /// The source does NOT take ownership of the data.
    pub fn fromBytes(allocator: Allocator, data: []const u8, options: Options) Self {
        return .{
            .allocator = allocator,
            .data = data,
            .position = 0,
            .chunk_size = if (options.chunk_size > 0) options.chunk_size else DEFAULT_CHUNK_SIZE,
            .state = .readable,
            .owns_data = false,
            .error_message = null,
            .bytes_read = 0,
        };
    }

    /// Create a streaming source that takes ownership of the data.
    pub fn fromOwnedBytes(allocator: Allocator, data: []const u8, options: Options) Self {
        var source = fromBytes(allocator, data, options);
        source.owns_data = true;
        return source;
    }

    /// Clean up resources.
    pub fn deinit(self: *Self) void {
        if (self.owns_data) {
            self.allocator.free(self.data);
        }
        if (self.error_message) |msg| {
            self.allocator.free(msg);
        }
    }

    /// Read the next chunk of data.
    ///
    /// Returns:
    /// - Owned slice of the next chunk (caller must free)
    /// - null if stream is closed/complete
    /// - error if stream is in error state or cancelled
    pub fn read(self: *Self) !?[]u8 {
        switch (self.state) {
            .readable => {
                // Check if we've read everything
                if (self.position >= self.data.len) {
                    self.state = .closed;
                    return null;
                }

                // Calculate chunk boundaries
                const remaining = self.data.len - self.position;
                const chunk_len = @min(remaining, self.chunk_size);
                const end = self.position + chunk_len;

                // Copy chunk data (caller owns it)
                const chunk = try self.allocator.dupe(u8, self.data[self.position..end]);

                // Advance position
                self.position = end;
                self.bytes_read += chunk_len;

                return chunk;
            },
            .closed => return null,
            .errored => return error.StreamErrored,
            .cancelled => return error.StreamCancelled,
        }
    }

    /// Read all remaining data at once.
    /// Returns owned slice of remaining data.
    pub fn readAll(self: *Self) !?[]u8 {
        switch (self.state) {
            .readable => {
                if (self.position >= self.data.len) {
                    self.state = .closed;
                    return null;
                }

                const remaining = self.data[self.position..];
                const result = try self.allocator.dupe(u8, remaining);

                self.bytes_read += remaining.len;
                self.position = self.data.len;
                self.state = .closed;

                return result;
            },
            .closed => return null,
            .errored => return error.StreamErrored,
            .cancelled => return error.StreamCancelled,
        }
    }

    /// Cancel the stream.
    /// After cancellation, further reads will return error.
    pub fn cancel(self: *Self) void {
        if (self.state == .readable) {
            self.state = .cancelled;
        }
    }

    /// Set stream to error state with message.
    pub fn setError(self: *Self, message: []const u8) !void {
        if (self.state == .readable) {
            self.error_message = try self.allocator.dupe(u8, message);
            self.state = .errored;
        }
    }

    /// Get current state.
    pub fn getState(self: *const Self) StreamingState {
        return self.state;
    }

    /// Check if stream is complete (closed or errored).
    pub fn isComplete(self: *const Self) bool {
        return self.state != .readable;
    }

    /// Get progress information.
    pub fn getProgress(self: *const Self) Progress {
        return .{
            .bytes_read = self.bytes_read,
            .total_bytes = self.data.len,
            .is_complete = self.isComplete(),
        };
    }

    /// Progress information
    pub const Progress = struct {
        bytes_read: usize,
        total_bytes: usize,
        is_complete: bool,

        /// Get progress as a percentage (0.0 to 1.0)
        pub fn percentage(self: Progress) f64 {
            if (self.total_bytes == 0) return 1.0;
            return @as(f64, @floatFromInt(self.bytes_read)) / @as(f64, @floatFromInt(self.total_bytes));
        }
    };
};

/// Chunk iterator for streaming source.
/// Provides iterator interface for for-loop consumption.
pub const ChunkIterator = struct {
    source: *StreamingSource,

    const Self = @This();

    pub fn next(self: *Self) ?[]u8 {
        return self.source.read() catch null;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "StreamingSource - basic read" {
    const allocator = std.testing.allocator;
    const data = "Hello, World!";

    var source = StreamingSource.fromBytes(allocator, data, .{ .chunk_size = 5 });
    defer source.deinit();

    // First chunk: "Hello"
    const chunk1 = (try source.read()).?;
    defer allocator.free(chunk1);
    try std.testing.expectEqualStrings("Hello", chunk1);

    // Second chunk: ", Wor"
    const chunk2 = (try source.read()).?;
    defer allocator.free(chunk2);
    try std.testing.expectEqualStrings(", Wor", chunk2);

    // Third chunk: "ld!"
    const chunk3 = (try source.read()).?;
    defer allocator.free(chunk3);
    try std.testing.expectEqualStrings("ld!", chunk3);

    // No more data
    try std.testing.expect(try source.read() == null);
    try std.testing.expect(source.getState() == .closed);
}

test "StreamingSource - readAll" {
    const allocator = std.testing.allocator;
    const data = "Complete data";

    var source = StreamingSource.fromBytes(allocator, data, .{});
    defer source.deinit();

    const all = (try source.readAll()).?;
    defer allocator.free(all);

    try std.testing.expectEqualStrings("Complete data", all);
    try std.testing.expect(source.getState() == .closed);
    try std.testing.expect(try source.readAll() == null);
}

test "StreamingSource - cancel" {
    const allocator = std.testing.allocator;
    const data = "Test data";

    var source = StreamingSource.fromBytes(allocator, data, .{});
    defer source.deinit();

    source.cancel();

    try std.testing.expectError(error.StreamCancelled, source.read());
    try std.testing.expect(source.getState() == .cancelled);
}

test "StreamingSource - error state" {
    const allocator = std.testing.allocator;
    const data = "Test data";

    var source = StreamingSource.fromBytes(allocator, data, .{});
    defer source.deinit();

    try source.setError("Network error");

    try std.testing.expectError(error.StreamErrored, source.read());
    try std.testing.expect(source.getState() == .errored);
    try std.testing.expectEqualStrings("Network error", source.error_message.?);
}

test "StreamingSource - progress tracking" {
    const allocator = std.testing.allocator;
    const data = "0123456789"; // 10 bytes

    var source = StreamingSource.fromBytes(allocator, data, .{ .chunk_size = 3 });
    defer source.deinit();

    // Initial progress
    var progress = source.getProgress();
    try std.testing.expectEqual(@as(usize, 0), progress.bytes_read);
    try std.testing.expectEqual(@as(usize, 10), progress.total_bytes);
    try std.testing.expectEqual(false, progress.is_complete);

    // Read first chunk (3 bytes)
    const chunk1 = (try source.read()).?;
    defer allocator.free(chunk1);

    progress = source.getProgress();
    try std.testing.expectEqual(@as(usize, 3), progress.bytes_read);
    try std.testing.expectApproxEqAbs(@as(f64, 0.3), progress.percentage(), 0.01);

    // Read remaining
    while (try source.read()) |chunk| {
        allocator.free(chunk);
    }

    progress = source.getProgress();
    try std.testing.expectEqual(@as(usize, 10), progress.bytes_read);
    try std.testing.expectEqual(true, progress.is_complete);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), progress.percentage(), 0.01);
}

test "StreamingSource - empty data" {
    const allocator = std.testing.allocator;

    var source = StreamingSource.fromBytes(allocator, "", .{});
    defer source.deinit();

    // Empty stream should immediately close
    try std.testing.expect(try source.read() == null);
    try std.testing.expect(source.getState() == .closed);
}

test "StreamingSource - owned data cleanup" {
    const allocator = std.testing.allocator;

    // Create owned copy
    const data = try allocator.dupe(u8, "owned data");

    var source = StreamingSource.fromOwnedBytes(allocator, data, .{});
    // deinit should free the data
    source.deinit();

    // If we get here without leak, test passes
}

test "StreamingSource - large chunk size" {
    const allocator = std.testing.allocator;
    const data = "small";

    // Chunk size larger than data
    var source = StreamingSource.fromBytes(allocator, data, .{ .chunk_size = 1000 });
    defer source.deinit();

    const chunk = (try source.read()).?;
    defer allocator.free(chunk);

    try std.testing.expectEqualStrings("small", chunk);
    try std.testing.expect(try source.read() == null);
}
