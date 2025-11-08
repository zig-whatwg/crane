//! Queuing strategy operations per WHATWG Streams Standard
//!
//! Implements abstract operations for queuing strategies:
//! - ExtractHighWaterMark
//! - ExtractSizeAlgorithm
//! - ValidateAndNormalizeHighWaterMark
//!
//! Spec: § 8 "Queuing strategies"
//! https://streams.spec.whatwg.org/#qs

const std = @import("std");

/// Placeholder for JavaScript values
pub const Value = union(enum) {
    undefined: void,
    null: void,
    number: f64,
    string: []const u8,
    object: void,
};

/// Size algorithm function type
///
/// Takes a chunk and returns its size as a non-negative number
pub const SizeAlgorithm = *const fn (chunk: Value) f64;

/// Default size algorithm that always returns 1
fn defaultSizeAlgorithm(chunk: Value) f64 {
    _ = chunk;
    return 1.0;
}

/// ExtractHighWaterMark(strategy, defaultHWM)
///
/// Spec: § 8.1 "ExtractHighWaterMark(strategy, defaultHWM)"
/// https://streams.spec.whatwg.org/#extract-high-water-mark
///
/// Extracts the high water mark from a queuing strategy object.
pub fn extractHighWaterMark(strategy: ?Value, default_hwm: f64) !f64 {
    // Step 1: If strategy is undefined, return defaultHWM.
    const strat = strategy orelse return default_hwm;

    // Step 2: If strategy["highWaterMark"] does not exist, return defaultHWM.
    // For this simple implementation, we check if it's an object
    // In a real implementation, this would access the object property
    if (strat != .object) {
        return default_hwm;
    }

    // Step 3: Let highWaterMark be strategy["highWaterMark"].
    // For now, return default since we can't access object properties yet
    // TODO: Implement proper object property access when webidl is integrated
    return default_hwm;

    // Step 4: Return ? ValidateAndNormalizeHighWaterMark(highWaterMark).
    // (Will be implemented when we have proper value extraction)
}

/// ExtractSizeAlgorithm(strategy)
///
/// Spec: § 8.1 "ExtractSizeAlgorithm(strategy)"
/// https://streams.spec.whatwg.org/#extract-size-algorithm
///
/// Extracts the size algorithm from a queuing strategy object.
pub fn extractSizeAlgorithm(allocator: std.mem.Allocator, strategy: ?Value) !SizeAlgorithm {
    _ = allocator; // Will be needed for storing callback

    // Step 1: If strategy is undefined, return an algorithm that returns 1.
    const strat = strategy orelse return defaultSizeAlgorithm;

    // Step 2: If strategy["size"] does not exist, return an algorithm that returns 1.
    // For this simple implementation, we check if it's an object
    if (strat != .object) {
        return defaultSizeAlgorithm;
    }

    // Step 3: Return strategy["size"].
    // For now, return default since we can't access object properties yet
    // TODO: Implement proper callback extraction when webidl is integrated
    return defaultSizeAlgorithm;
}

/// ValidateAndNormalizeHighWaterMark(highWaterMark)
///
/// Spec: § 8.1 "ValidateAndNormalizeHighWaterMark(highWaterMark)"
/// https://streams.spec.whatwg.org/#validate-and-normalize-high-water-mark
///
/// Validates and normalizes a high water mark value.
pub fn validateAndNormalizeHighWaterMark(high_water_mark: f64) !f64 {
    // Step 1: Set highWaterMark to ? ToNumber(highWaterMark).
    // (Already a number in our case)

    // Step 2: If highWaterMark is NaN or highWaterMark < 0, throw a RangeError exception.
    if (std.math.isNan(high_water_mark) or high_water_mark < 0.0) {
        return error.RangeError;
    }

    // Step 3: Return highWaterMark.
    return high_water_mark;
}

// Tests

test "validateAndNormalizeHighWaterMark - valid values" {
    // Test various valid high water marks
    try std.testing.expectEqual(@as(f64, 0.0), try validateAndNormalizeHighWaterMark(0.0));
    try std.testing.expectEqual(@as(f64, 1.0), try validateAndNormalizeHighWaterMark(1.0));
    try std.testing.expectEqual(@as(f64, 100.5), try validateAndNormalizeHighWaterMark(100.5));
    try std.testing.expectEqual(@as(f64, 1000000.0), try validateAndNormalizeHighWaterMark(1000000.0));
}

test "validateAndNormalizeHighWaterMark - negative value throws" {
    try std.testing.expectError(error.RangeError, validateAndNormalizeHighWaterMark(-1.0));
    try std.testing.expectError(error.RangeError, validateAndNormalizeHighWaterMark(-0.1));
}

test "validateAndNormalizeHighWaterMark - NaN throws" {
    try std.testing.expectError(error.RangeError, validateAndNormalizeHighWaterMark(std.math.nan(f64)));
}

test "extractHighWaterMark - undefined strategy returns default" {
    const result = try extractHighWaterMark(null, 5.0);
    try std.testing.expectEqual(@as(f64, 5.0), result);
}

test "extractHighWaterMark - non-object strategy returns default" {
    const result = try extractHighWaterMark(.{ .number = 10.0 }, 5.0);
    try std.testing.expectEqual(@as(f64, 5.0), result);
}

test "extractSizeAlgorithm - undefined strategy returns default" {
    const allocator = std.testing.allocator;

    const algo = try extractSizeAlgorithm(allocator, null);
    const result = algo(.{ .number = 42.0 });
    try std.testing.expectEqual(@as(f64, 1.0), result);
}

test "extractSizeAlgorithm - non-object strategy returns default" {
    const allocator = std.testing.allocator;

    const algo = try extractSizeAlgorithm(allocator, .{ .number = 10.0 });
    const result = algo(.{ .string = "test" });
    try std.testing.expectEqual(@as(f64, 1.0), result);
}

test "defaultSizeAlgorithm - always returns 1" {
    try std.testing.expectEqual(@as(f64, 1.0), defaultSizeAlgorithm(.undefined));
    try std.testing.expectEqual(@as(f64, 1.0), defaultSizeAlgorithm(.{ .number = 100.0 }));
    try std.testing.expectEqual(@as(f64, 1.0), defaultSizeAlgorithm(.{ .string = "chunk" }));
}
