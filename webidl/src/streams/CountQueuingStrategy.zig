//! CountQueuingStrategy class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#cqs-class
//!
//! A queuing strategy that counts chunks for backpressure.

const std = @import("std");
const webidl = @import("webidl");

// Import QueuingStrategyInit from ByteLengthQueuingStrategy
const ByteLengthQueuingStrategy = @import("byte_length_queuing_strategy");
pub const QueuingStrategyInit = ByteLengthQueuingStrategy.QueuingStrategyInit;

pub const CountQueuingStrategy = webidl.interface(struct {
    /// [[highWaterMark]]: The high water mark (internal slot)
    _highWaterMark: f64,

    /// Constructor: new CountQueuingStrategy(init)
    /// Spec: https://streams.spec.whatwg.org/#cqs-constructor
    pub fn init(allocator: std.mem.Allocator, initDict: QueuingStrategyInit) CountQueuingStrategy {
        _ = allocator; // Not needed for this simple structure
        return .{
            ._highWaterMark = initDict.highWaterMark,
        };
    }

    pub fn deinit(_: *CountQueuingStrategy) void {}

    // ============================================================================
    // WebIDL Interface: Readonly Attributes
    // ============================================================================

    /// readonly attribute unrestricted double highWaterMark
    /// Getter returns this.[[highWaterMark]]
    /// Spec: https://streams.spec.whatwg.org/#cqs-high-water-mark
    pub fn get_highWaterMark(self: *const CountQueuingStrategy) f64 {
        return self._highWaterMark;
    }

    // NOTE: The 'size' attribute is similar to ByteLengthQueuingStrategy
    // but returns a function that always returns 1 (counting chunks, not bytes).
    //
    // Spec: https://streams.spec.whatwg.org/#cqs-size

    /// size function: Returns 1 for each chunk (count-based strategy)
    /// This is called as strategy.size(chunk) in JavaScript
    pub fn call_size(_: *const CountQueuingStrategy, _: webidl.JSValue) f64 {
        // Always returns 1 for count-based strategy
        return 1.0;
    }
}, .{
    .exposed = &.{.global},
});
