//! WHATWG Fetch Standard - Internal Body Struct
//!
//! This module implements the internal Body representation used by the Fetch API.
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-body
//!
//! A body consists of:
//! - stream: A ReadableStream object
//! - source: null, a byte sequence, a Blob object, or a FormData object
//! - length: null or an integer
//!
//! This is the internal representation - the Body mixin (exposed to JS) wraps this.

const std = @import("std");
const Allocator = std.mem.Allocator;
const network = @import("../network/root.zig");
const StreamingSource = network.StreamingSource;

/// Body source types for tracking the origin of body data.
/// Per spec, source can be null, bytes, Blob, or FormData.
///
/// ARCHITECTURAL NOTE: The blob and form_data fields use *anyopaque because this
/// module is designed for standalone testing without runtime dependency. When
/// integrated with the full runtime, these should be *runtime.Instance (WebIDL
/// Blob and FormData interface instances respectively).
/// See: specs/idl/FileAPI.idl (Blob), specs/idl/xhr.idl (FormData)
pub const BodySource = union(enum) {
    /// No source (e.g., network responses where source is unknown)
    none,
    /// Byte sequence source
    bytes: []const u8,
    /// Blob source - should be *runtime.Instance when integrated with runtime.
    /// WebIDL type: Blob (https://w3c.github.io/FileAPI/#blob-section)
    blob: *anyopaque,
    /// FormData source - should be *runtime.Instance when integrated with runtime.
    /// WebIDL type: FormData (https://xhr.spec.whatwg.org/#interface-formdata)
    form_data: *anyopaque,
};

/// A body with type tuple.
/// Per spec: "A body with type is a tuple that consists of a body and a type (a header value or null)."
pub const BodyWithType = struct {
    body: *Body,
    /// Content-Type header value, or null if not known
    content_type: ?[]const u8,
};

/// Internal Body struct representing request/response body content.
///
/// Per WHATWG Fetch spec section on Bodies:
/// - stream: A ReadableStream object (for incremental reading)
/// - source: null, byte sequence, Blob, or FormData (for cloning/extraction)
/// - length: null or integer (Content-Length if known)
///
/// Design Notes:
/// - For now, we store body data directly as bytes since stream integration
///   requires the full runtime. This allows the Fetch implementation to proceed.
/// - When full ReadableStream integration is needed, this can be upgraded to
///   use the streams module's ReadableStream interface.
/// - The stream field is optional until stream integration is complete.
pub const Body = struct {
    allocator: Allocator,

    /// The body data as bytes.
    /// For network responses, this accumulates as data arrives.
    /// For constructed bodies (from bytes, Blob, etc.), this is set directly.
    data: std.ArrayListUnmanaged(u8),

    /// Original source of the body (for cloning semantics).
    /// null for network responses where source is unknown.
    source: BodySource,

    /// Content length if known, null otherwise.
    /// Corresponds to Content-Length header value.
    length: ?u64,

    /// Whether the body has been used (read/consumed).
    /// Per spec: once a body is read, it cannot be read again.
    used: bool,

    /// Whether the body is currently being read.
    /// Used to prevent concurrent reads.
    disturbed: bool,

    const Self = @This();

    /// Error set for body operations.
    pub const BodyError = error{
        /// Body has already been consumed/used
        BodyAlreadyUsed,
    };

    /// Initialize a new empty body.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .data = .{},
            .source = .none,
            .length = null,
            .used = false,
            .disturbed = false,
        };
    }

    /// Initialize a body from a byte sequence.
    ///
    /// Per spec: "To get a byte sequence bytes as a body, return the body
    /// of the result of safely extracting bytes."
    ///
    /// This creates a body with:
    /// - stream: A ReadableStream containing the bytes
    /// - source: The byte sequence
    /// - length: The byte sequence's length
    pub fn fromBytes(allocator: Allocator, bytes: []const u8) !*Self {
        const body = try allocator.create(Self);
        errdefer allocator.destroy(body);

        body.* = .{
            .allocator = allocator,
            .data = .{},
            .source = .{ .bytes = bytes },
            .length = bytes.len,
            .used = false,
            .disturbed = false,
        };

        // Copy the bytes into our data buffer
        try body.data.appendSlice(allocator, bytes);

        return body;
    }

    /// Initialize a body from a source with optional length.
    pub fn fromSource(allocator: Allocator, source: BodySource, length: ?u64) !*Self {
        const body = try allocator.create(Self);
        errdefer allocator.destroy(body);

        body.* = .{
            .allocator = allocator,
            .data = .{},
            .source = source,
            .length = length,
            .used = false,
            .disturbed = false,
        };

        // If source is bytes, copy them
        if (source == .bytes) {
            try body.data.appendSlice(allocator, source.bytes);
        }

        return body;
    }

    /// Deinitialize the body, freeing all resources.
    pub fn deinit(self: *Self) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Clone a body.
    ///
    /// Per spec (https://fetch.spec.whatwg.org/#concept-body-clone):
    /// 1. Let « out1, out2 » be the result of teeing body's stream.
    /// 2. Set body's stream to out1.
    /// 3. Return a body whose stream is out2 and other members are copied from body.
    ///
    /// Since we're not yet fully integrated with ReadableStream, we clone the
    /// underlying data directly. When stream integration is complete, this will
    /// use stream.tee() as specified.
    pub fn clone(self: *Self, allocator: Allocator) !*Self {
        const new_body = try allocator.create(Self);
        errdefer allocator.destroy(new_body);

        new_body.* = .{
            .allocator = allocator,
            .data = .{},
            .source = self.source,
            .length = self.length,
            .used = false,
            .disturbed = false,
        };

        // Clone the data
        try new_body.data.appendSlice(allocator, self.data.items);

        return new_body;
    }

    /// Get the body's bytes without consuming it.
    /// This is an internal operation not exposed to JS.
    pub fn getBytes(self: *const Self) []const u8 {
        return self.data.items;
    }

    /// Check if the body has been used/consumed.
    pub fn isUsed(self: *const Self) bool {
        return self.used;
    }

    /// Check if the body has been disturbed (reading started).
    pub fn isDisturbed(self: *const Self) bool {
        return self.disturbed;
    }

    /// Mark the body as disturbed.
    pub fn markDisturbed(self: *Self) void {
        self.disturbed = true;
    }

    /// Mark the body as used/consumed.
    pub fn markUsed(self: *Self) void {
        self.used = true;
        self.disturbed = true;
    }

    /// Append bytes to the body.
    /// Used during incremental body reception from network.
    pub fn appendBytes(self: *Self, bytes: []const u8) !void {
        try self.data.appendSlice(self.allocator, bytes);
    }

    // =========================================================================
    // Body Reading Operations
    // =========================================================================
    //
    // The spec defines two main reading patterns:
    // 1. incrementallyRead - processes chunks as they arrive via callbacks
    // 2. fullyRead - accumulates all bytes then calls callback
    //
    // Since we store data directly (not via streams yet), these are simplified.

    /// Callback types for incremental reading.
    /// KEEP: These use *anyopaque for ctx because they are internal Zig callback patterns
    /// (classic user_data pattern), not WebIDL interface types. The ctx is type-erased
    /// to allow any caller-defined context to be passed through the callback chain.
    pub const ProcessChunkFn = *const fn (ctx: *anyopaque, bytes: []const u8) void;
    pub const ProcessEndFn = *const fn (ctx: *anyopaque) void;
    pub const ProcessErrorFn = *const fn (ctx: *anyopaque, err: anyerror) void;

    /// Read context for callback-based reading.
    /// KEEP: ctx is *anyopaque because this is an internal callback context pattern,
    /// not a WebIDL type. Callers cast their own context type to pass through.
    pub const ReadContext = struct {
        ctx: *anyopaque,
        process_chunk: ProcessChunkFn,
        process_end: ProcessEndFn,
        process_error: ProcessErrorFn,
    };

    /// Incrementally read a body with callbacks.
    ///
    /// Per spec (https://fetch.spec.whatwg.org/#incrementally-read-body):
    /// Given processBodyChunk, processEndOfBody, processBodyError callbacks:
    /// 1. Get a reader for body's stream
    /// 2. Perform the incrementally-read loop
    ///
    /// Since we're not using streams yet, we simulate this by calling
    /// processBodyChunk once with all data, then processEndOfBody.
    pub fn incrementallyRead(self: *Self, read_ctx: ReadContext) void {
        if (self.used) {
            read_ctx.process_error(read_ctx.ctx, BodyError.BodyAlreadyUsed);
            return;
        }

        self.disturbed = true;

        // For now, deliver all data in one chunk
        // With stream integration, this would read chunks from the stream
        if (self.data.items.len > 0) {
            read_ctx.process_chunk(read_ctx.ctx, self.data.items);
        }

        self.used = true;
        read_ctx.process_end(read_ctx.ctx);
    }

    /// Callback types for fully reading.
    /// KEEP: *anyopaque for ctx is the internal Zig callback user_data pattern.
    pub const ProcessBodyFn = *const fn (ctx: *anyopaque, bytes: []const u8) void;

    /// Full read context.
    /// KEEP: ctx is *anyopaque because this is an internal callback context pattern.
    pub const FullReadContext = struct {
        ctx: *anyopaque,
        process_body: ProcessBodyFn,
        process_error: ProcessErrorFn,
    };

    /// Fully read a body and return all bytes.
    ///
    /// Per spec (https://fetch.spec.whatwg.org/#fully-read-body):
    /// 1. Get a reader for body's stream
    /// 2. Read all bytes from reader
    /// 3. Call processBody with bytes or processBodyError on error
    pub fn fullyRead(self: *Self, read_ctx: FullReadContext) void {
        if (self.used) {
            read_ctx.process_error(read_ctx.ctx, BodyError.BodyAlreadyUsed);
            return;
        }

        self.disturbed = true;
        self.used = true;

        // Return all accumulated data
        read_ctx.process_body(read_ctx.ctx, self.data.items);
    }

    /// Synchronously read all bytes from the body.
    /// Returns error if body has already been used.
    pub fn readAllBytes(self: *Self) BodyError![]const u8 {
        if (self.used) {
            return BodyError.BodyAlreadyUsed;
        }

        self.disturbed = true;
        self.used = true;

        return self.data.items;
    }

    // =========================================================================
    // Streaming Interface
    // =========================================================================
    //
    // These methods provide ReadableStream-like access to body data.
    // Per spec, body.stream should be a ReadableStream. Until full runtime
    // integration, StreamingSource provides chunk-based iteration.

    /// Get a streaming source for reading the body in chunks.
    ///
    /// This is Phase 3a streaming: chunks the buffered data for incremental
    /// reading. The caller can iterate over chunks without loading everything
    /// into memory at once (though the data is already buffered).
    ///
    /// Per spec, this corresponds to getting a reader from body's stream.
    ///
    /// Returns error if body has already been used.
    pub fn getStreamingSource(self: *Self, options: StreamingSource.Options) BodyError!StreamingSource {
        if (self.used) {
            return BodyError.BodyAlreadyUsed;
        }

        self.disturbed = true;
        // Note: we don't mark as "used" until stream is fully consumed

        return StreamingSource.fromBytes(self.allocator, self.data.items, options);
    }

    /// Get a streaming source with default options.
    pub fn stream(self: *Self) BodyError!StreamingSource {
        return self.getStreamingSource(.{});
    }
};

/// Create an empty body (null body per spec).
pub fn nullBody() ?*Body {
    return null;
}

/// Check if a value represents a null body.
pub fn isNullBody(body: ?*Body) bool {
    return body == null;
}

// =============================================================================
// Tests
// =============================================================================

test "Body.init creates empty body" {
    const allocator = std.testing.allocator;
    var body = Body.init(allocator);
    defer body.data.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), body.data.items.len);
    try std.testing.expectEqual(false, body.used);
    try std.testing.expectEqual(false, body.disturbed);
    try std.testing.expect(body.length == null);
}

test "Body.fromBytes creates body with data" {
    const allocator = std.testing.allocator;
    const bytes = "Hello, World!";

    const body = try Body.fromBytes(allocator, bytes);
    defer body.deinit();

    try std.testing.expectEqualStrings(bytes, body.getBytes());
    try std.testing.expectEqual(@as(?u64, bytes.len), body.length);
    try std.testing.expectEqual(false, body.used);
    try std.testing.expect(body.source == .bytes);
}

test "Body.clone creates independent copy" {
    const allocator = std.testing.allocator;
    const bytes = "Original data";

    const original = try Body.fromBytes(allocator, bytes);
    defer original.deinit();

    const cloned = try original.clone(allocator);
    defer cloned.deinit();

    // Both should have same data
    try std.testing.expectEqualStrings(bytes, original.getBytes());
    try std.testing.expectEqualStrings(bytes, cloned.getBytes());

    // Modifying original shouldn't affect clone
    try original.appendBytes(" modified");
    try std.testing.expectEqualStrings("Original data modified", original.getBytes());
    try std.testing.expectEqualStrings(bytes, cloned.getBytes());
}

test "Body.appendBytes accumulates data" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Hello");
    defer body.deinit();

    try body.appendBytes(", ");
    try body.appendBytes("World!");

    try std.testing.expectEqualStrings("Hello, World!", body.getBytes());
}

test "Body.readAllBytes marks body as used" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "test data");
    defer body.deinit();

    try std.testing.expectEqual(false, body.isUsed());
    try std.testing.expectEqual(false, body.isDisturbed());

    const data = try body.readAllBytes();
    try std.testing.expectEqualStrings("test data", data);

    try std.testing.expectEqual(true, body.isUsed());
    try std.testing.expectEqual(true, body.isDisturbed());
}

test "Body.readAllBytes fails when already used" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "test");
    defer body.deinit();

    _ = try body.readAllBytes();

    // Second read should fail
    const result = body.readAllBytes();
    try std.testing.expectError(Body.BodyError.BodyAlreadyUsed, result);
}

test "Body.incrementallyRead delivers chunks" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "chunk data");
    defer body.deinit();

    const TestContext = struct {
        chunks_received: usize = 0,
        end_called: bool = false,
        error_called: bool = false,
        last_chunk: []const u8 = "",
        last_error: ?anyerror = null,

        fn processChunk(ctx_ptr: *anyopaque, bytes: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ctx_ptr));
            self.chunks_received += 1;
            self.last_chunk = bytes;
        }

        fn processEnd(ctx_ptr: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx_ptr));
            self.end_called = true;
        }

        fn processError(ctx_ptr: *anyopaque, err: anyerror) void {
            const self: *@This() = @ptrCast(@alignCast(ctx_ptr));
            self.error_called = true;
            self.last_error = err;
        }
    };

    var ctx = TestContext{};
    body.incrementallyRead(.{
        .ctx = &ctx,
        .process_chunk = TestContext.processChunk,
        .process_end = TestContext.processEnd,
        .process_error = TestContext.processError,
    });

    try std.testing.expectEqual(@as(usize, 1), ctx.chunks_received);
    try std.testing.expectEqual(true, ctx.end_called);
    try std.testing.expectEqual(false, ctx.error_called);
    try std.testing.expectEqualStrings("chunk data", ctx.last_chunk);
}

test "Body.fullyRead delivers all data at once" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "full body data");
    defer body.deinit();

    const TestContext = struct {
        body_received: bool = false,
        error_called: bool = false,
        received_data: []const u8 = "",
        last_error: ?anyerror = null,

        fn processBody(ctx_ptr: *anyopaque, bytes: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ctx_ptr));
            self.body_received = true;
            self.received_data = bytes;
        }

        fn processError(ctx_ptr: *anyopaque, err: anyerror) void {
            const self: *@This() = @ptrCast(@alignCast(ctx_ptr));
            self.error_called = true;
            self.last_error = err;
        }
    };

    var ctx = TestContext{};
    body.fullyRead(.{
        .ctx = &ctx,
        .process_body = TestContext.processBody,
        .process_error = TestContext.processError,
    });

    try std.testing.expectEqual(true, ctx.body_received);
    try std.testing.expectEqual(false, ctx.error_called);
    try std.testing.expectEqualStrings("full body data", ctx.received_data);
}

test "Body with null source" {
    const allocator = std.testing.allocator;

    const body = try Body.fromSource(allocator, .none, null);
    defer body.deinit();

    try std.testing.expect(body.source == .none);
    try std.testing.expect(body.length == null);
    try std.testing.expectEqual(@as(usize, 0), body.getBytes().len);
}

test "BodyWithType struct" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "test");
    defer body.deinit();

    const body_with_type = BodyWithType{
        .body = body,
        .content_type = "application/json",
    };

    try std.testing.expectEqualStrings("test", body_with_type.body.getBytes());
    try std.testing.expectEqualStrings("application/json", body_with_type.content_type.?);
}

test "nullBody and isNullBody" {
    try std.testing.expect(isNullBody(nullBody()));

    const allocator = std.testing.allocator;
    const body = try Body.fromBytes(allocator, "test");
    defer body.deinit();

    try std.testing.expect(!isNullBody(body));
}

test "Body.stream returns StreamingSource" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "streaming data");
    defer body.deinit();

    var source = try body.stream();
    defer source.deinit();

    // Read first chunk
    const chunk1 = (try source.read()).?;
    defer allocator.free(chunk1);
    try std.testing.expectEqualStrings("streaming data", chunk1);

    // Stream should be closed
    try std.testing.expect(try source.read() == null);
    try std.testing.expect(source.getState() == .closed);
}

test "Body.getStreamingSource with custom chunk size" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "ABCDEFGHIJ"); // 10 bytes
    defer body.deinit();

    var source = try body.getStreamingSource(.{ .chunk_size = 3 });
    defer source.deinit();

    // Read in 3-byte chunks
    const chunk1 = (try source.read()).?;
    defer allocator.free(chunk1);
    try std.testing.expectEqualStrings("ABC", chunk1);

    const chunk2 = (try source.read()).?;
    defer allocator.free(chunk2);
    try std.testing.expectEqualStrings("DEF", chunk2);

    const chunk3 = (try source.read()).?;
    defer allocator.free(chunk3);
    try std.testing.expectEqualStrings("GHI", chunk3);

    const chunk4 = (try source.read()).?;
    defer allocator.free(chunk4);
    try std.testing.expectEqualStrings("J", chunk4);

    try std.testing.expect(try source.read() == null);
}

test "Body.stream fails if already used" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "test");
    defer body.deinit();

    // Use the body first
    _ = try body.readAllBytes();

    // stream() should fail
    const result = body.stream();
    try std.testing.expectError(Body.BodyError.BodyAlreadyUsed, result);
}
