//! CountQueuingStrategy class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#cqs-class
//!
//! A queuing strategy that counts chunks for backpressure.

const std = @import("std");
const webidl = @import("webidl");

pub const CountQueuingStrategy = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[highWaterMark]]: The high water mark
    highWaterMark: f64,

    pub fn init(highWaterMark: f64) CountQueuingStrategy {
        return .{
            .allocator = undefined,
            .highWaterMark = highWaterMark,
        };
    }

    pub fn deinit(_: *CountQueuingStrategy) void {}

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn call_size(_: *const CountQueuingStrategy, _: ?webidl.JSValue) f64 {
        // Always returns 1 for count-based strategy
        return 1.0;
    }
});
