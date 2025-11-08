//! Read request record for pending read operations
//!
//! Used by ReadableStreamDefaultReader.read() to track pending reads.
//!
//! Spec: § 4.4.4 "Read request"
//! https://streams.spec.whatwg.org/#read-request

const std = @import("std");
const queue = @import("queue_with_sizes");

const Value = queue.Value;

/// Read request record
///
/// A read request is a struct with three items:
/// - chunk steps: algorithm accepting a chunk
/// - close steps: algorithm accepting no parameters
/// - error steps: algorithm accepting a JavaScript value
pub const ReadRequest = struct {
    allocator: std.mem.Allocator,

    /// chunk steps: Called when a chunk is available
    chunk_steps: ChunkStepsFn,
    /// close steps: Called when the stream closes
    close_steps: CloseStepsFn,
    /// error steps: Called when the stream errors
    error_steps: ErrorStepsFn,

    /// Context pointer for callback closures (optional)
    context: ?*anyopaque = null,

    /// Callback function types
    pub const ChunkStepsFn = *const fn (ctx: ?*anyopaque, chunk: Value) void;
    pub const CloseStepsFn = *const fn (ctx: ?*anyopaque) void;
    pub const ErrorStepsFn = *const fn (ctx: ?*anyopaque, e: Value) void;

    /// Initialize a new read request
    pub fn init(
        allocator: std.mem.Allocator,
        chunk_steps: ChunkStepsFn,
        close_steps: CloseStepsFn,
        error_steps: ErrorStepsFn,
        context: ?*anyopaque,
    ) ReadRequest {
        return .{
            .allocator = allocator,
            .chunk_steps = chunk_steps,
            .close_steps = close_steps,
            .error_steps = error_steps,
            .context = context,
        };
    }

    /// Execute chunk steps
    pub fn executeChunkSteps(self: *const ReadRequest, chunk: Value) void {
        self.chunk_steps(self.context, chunk);
    }

    /// Execute close steps
    pub fn executeCloseSteps(self: *const ReadRequest) void {
        self.close_steps(self.context);
    }

    /// Execute error steps
    pub fn executeErrorSteps(self: *const ReadRequest, e: Value) void {
        self.error_steps(self.context, e);
    }
};

// Tests

test "ReadRequest - basic creation and execution" {
    const allocator = std.testing.allocator;

    // Test context to track callback invocations
    const TestContext = struct {
        chunk_called: bool = false,
        close_called: bool = false,
        error_called: bool = false,
        last_chunk: ?Value = null,
        last_error: ?Value = null,
    };

    var ctx = TestContext{};

    const chunk_fn = struct {
        fn call(context: ?*anyopaque, chunk: Value) void {
            const c: *TestContext = @ptrCast(@alignCast(context.?));
            c.chunk_called = true;
            c.last_chunk = chunk;
        }
    }.call;

    const close_fn = struct {
        fn call(context: ?*anyopaque) void {
            const c: *TestContext = @ptrCast(@alignCast(context.?));
            c.close_called = true;
        }
    }.call;

    const error_fn = struct {
        fn call(context: ?*anyopaque, e: Value) void {
            const c: *TestContext = @ptrCast(@alignCast(context.?));
            c.error_called = true;
            c.last_error = e;
        }
    }.call;

    const request = ReadRequest.init(
        allocator,
        chunk_fn,
        close_fn,
        error_fn,
        &ctx,
    );

    // Test chunk steps
    request.executeChunkSteps(.{ .number = 42.0 });
    try std.testing.expect(ctx.chunk_called);
    try std.testing.expectEqual(Value{ .number = 42.0 }, ctx.last_chunk.?);

    // Test close steps
    request.executeCloseSteps();
    try std.testing.expect(ctx.close_called);

    // Test error steps
    request.executeErrorSteps(.{ .string = "error" });
    try std.testing.expect(ctx.error_called);
    try std.testing.expectEqualStrings("error", ctx.last_error.?.string);
}
