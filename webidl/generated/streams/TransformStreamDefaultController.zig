//! TransformStreamDefaultController class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#ts-default-controller-class
//!
//! Controls a TransformStream's state and transformation.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");

pub const TransformStreamDefaultController = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[stream]]: The TransformStream instance controlled
    stream: ?*anyopaque,

    /// [[flushAlgorithm]]: Algorithm to flush remaining data
    flushAlgorithm: ?common.FlushAlgorithm,

    pub fn init(allocator: std.mem.Allocator, flushAlgorithm: ?common.FlushAlgorithm) TransformStreamDefaultController {
        return .{
            .allocator = allocator,
            .stream = null,
            .flushAlgorithm = flushAlgorithm,
        };
    }

    pub fn deinit(_: *TransformStreamDefaultController) void {}

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn enqueue(self: *TransformStreamDefaultController, chunk: ?webidl.JSValue) !void {
        const chunk_value = if (chunk) |c| common.JSValue.fromWebIDL(c) else common.JSValue.undefined_value();
        try self.enqueueInternal(chunk_value);
    }

    pub fn terminate(self: *TransformStreamDefaultController) void {
        _ = self;
        // Terminate the stream
    }

    pub fn errorStream(self: *TransformStreamDefaultController, e: ?webidl.JSValue) void {
        const error_value = if (e) |err| common.JSValue.fromWebIDL(err) else common.JSValue.undefined_value();
        self.errorInternal(error_value);
    }

    // ============================================================================
    // Internal Algorithms
    // ============================================================================

    pub fn enqueueInternal(self: *TransformStreamDefaultController, chunk: common.JSValue) !void {
        _ = self;
        _ = chunk;
        // Enqueue chunk to readable side
    }

    fn errorInternal(self: *TransformStreamDefaultController, error_value: common.JSValue) void {
        _ = self;
        _ = error_value;
        // Error both sides of the transform stream
    }
});
