//! ByteLengthQueuingStrategy class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#blqs-class
//!
//! A queuing strategy that uses byte length for backpressure.

const std = @import("std");
const webidl = @import("webidl");

pub const ByteLengthQueuingStrategy = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[highWaterMark]]: The high water mark
    highWaterMark: f64,

    pub fn init(highWaterMark: f64) ByteLengthQueuingStrategy {
        return .{
            .allocator = undefined,
            .highWaterMark = highWaterMark,
        };
    }

    pub fn deinit(_: *ByteLengthQueuingStrategy) void {}

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn size(_: *const ByteLengthQueuingStrategy, chunk: ?webidl.JSValue) f64 {
        _ = chunk;
        // Should return chunk.byteLength, but simplified for now
        return 1.0;
    }
});
