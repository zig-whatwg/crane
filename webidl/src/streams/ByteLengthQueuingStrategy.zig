//! ByteLengthQueuingStrategy class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#blqs-class
//!
//! A queuing strategy that uses byte length for backpressure.

const std = @import("std");
const webidl = @import("webidl");

/// QueuingStrategyInit dictionary
/// Spec: https://streams.spec.whatwg.org/#dictdef-queuingstrategyinit
pub const QueuingStrategyInit = struct {
    highWaterMark: f64,
};

pub const ByteLengthQueuingStrategy = webidl.interface(struct {
    /// [[highWaterMark]]: The high water mark (internal slot)
    _highWaterMark: f64,

    /// Constructor: new ByteLengthQueuingStrategy(init)
    /// Spec: https://streams.spec.whatwg.org/#blqs-constructor
    pub fn init(allocator: std.mem.Allocator, initDict: QueuingStrategyInit) ByteLengthQueuingStrategy {
        _ = allocator; // Not needed for this simple structure
        return .{
            ._highWaterMark = initDict.highWaterMark,
        };
    }

    pub fn deinit(_: *ByteLengthQueuingStrategy) void {}

    // ============================================================================
    // WebIDL Interface: Readonly Attributes
    // ============================================================================

    /// readonly attribute unrestricted double highWaterMark
    /// Getter returns this.[[highWaterMark]]
    /// Spec: https://streams.spec.whatwg.org/#blqs-high-water-mark
    pub fn get_highWaterMark(self: *const ByteLengthQueuingStrategy) f64 {
        return self._highWaterMark;
    }

    // NOTE: The 'size' attribute is handled differently in the spec.
    // It's a readonly attribute of type Function that returns a global function.
    // In our implementation, we provide a call_size method that behaves like
    // calling strategy.size(chunk), which internally calls GetV(chunk, "byteLength").
    //
    // Spec: https://streams.spec.whatwg.org/#blqs-size
    // The size getter steps are:
    //   1. Return this's relevant global object's byte length queuing strategy size function.
    //
    // The size function steps (given chunk):
    //   1. Return ? GetV(chunk, "byteLength").

    /// size function: Measures the size of chunk by returning chunk.byteLength
    /// This is called as strategy.size(chunk) in JavaScript
    pub fn call_size(_: *const ByteLengthQueuingStrategy, chunk: webidl.JSValue) f64 {
        // NOTE: Property extraction requires JS runtime integration
        // For now, return 1.0 as placeholder until JSValue type is fully implemented
        _ = chunk;
        return 1.0;
    }
}, .{
    .exposed = &.{.global},
});
