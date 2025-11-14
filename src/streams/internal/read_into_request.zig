//! Read-into request record for BYOB pending read operations
//!
//! Used by ReadableStreamBYOBReader.read() to track pending BYOB reads.
//!
//! Spec: § 4.5.4 "Read-into request"
//! https://streams.spec.whatwg.org/#read-into-request

const std = @import("std");

/// Placeholder for ArrayBufferView
/// In a real implementation, this would be webidl.ArrayBufferView
pub const ArrayBufferView = struct {
    data: []u8,
    offset: usize,
    length: usize,
};

/// Placeholder for JavaScript values
pub const Value = union(enum) {
    undefined: void,
    null: void,
    number: f64,
    string: []const u8,
    bytes: []const u8,
};

/// Read-into request record
///
/// A read-into request is a struct with three items:
/// - chunk steps: algorithm accepting an ArrayBufferView
/// - close steps: algorithm accepting no parameters
/// - error steps: algorithm accepting a JavaScript value
pub const ReadIntoRequest = struct {
    allocator: std.mem.Allocator,

    /// chunk steps: Called when bytes are read into the buffer
    chunk_steps: ChunkStepsFn,
    /// close steps: Called when the stream closes
    close_steps: CloseStepsFn,
    /// error steps: Called when the stream errors
    error_steps: ErrorStepsFn,

    /// Context pointer for callback closures (optional)
    context: ?*anyopaque = null,

    /// Callback function types (note: chunk_steps receives ArrayBufferView)
    pub const ChunkStepsFn = *const fn (ctx: ?*anyopaque, chunk: ArrayBufferView) void;
    pub const CloseStepsFn = *const fn (ctx: ?*anyopaque) void;
    pub const ErrorStepsFn = *const fn (ctx: ?*anyopaque, e: Value) void;

    /// Initialize a new read-into request
    pub fn init(
        allocator: std.mem.Allocator,
        chunk_steps: ChunkStepsFn,
        close_steps: CloseStepsFn,
        error_steps: ErrorStepsFn,
        context: ?*anyopaque,
    ) ReadIntoRequest {
        return .{
            .allocator = allocator,
            .chunk_steps = chunk_steps,
            .close_steps = close_steps,
            .error_steps = error_steps,
            .context = context,
        };
    }

    /// Execute chunk steps with ArrayBufferView
    pub fn executeChunkSteps(self: *const ReadIntoRequest, chunk: ArrayBufferView) void {
        self.chunk_steps(self.context, chunk);
    }

    /// Execute close steps
    pub fn executeCloseSteps(self: *const ReadIntoRequest) void {
        self.close_steps(self.context);
    }

    /// Execute error steps
    pub fn executeErrorSteps(self: *const ReadIntoRequest, e: Value) void {
        self.error_steps(self.context, e);
    }
};

// Tests

