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

