//! NavigatorConcurrentHardware Mixin
//!
//! HTML Standard § 8.8.1.4 - NavigatorConcurrentHardware
//! https://html.spec.whatwg.org/#navigatorconcurrenthardware
//!
//! This mixin provides information about hardware parallelism.

const std = @import("std");

/// NavigatorConcurrentHardware mixin implementation
/// Spec: HTML Standard § 8.8.1.4
pub const NavigatorConcurrentHardware = struct {
    /// Number of logical processors
    hardware_concurrency: usize,

    const Self = @This();

    /// Initialize with detected CPU count
    pub fn init() Self {
        return .{
            .hardware_concurrency = getHardwareConcurrency(),
        };
    }

    /// Initialize with custom value (for testing/simulation)
    pub fn initWithValue(concurrency: usize) Self {
        return .{
            .hardware_concurrency = @max(1, concurrency),
        };
    }

    // ========================================================================
    // NavigatorConcurrentHardware Properties
    // ========================================================================

    /// Get hardware concurrency.
    /// Spec: "Must return a number greater than or equal to 1,
    /// representing the approximate number of logical processors
    /// available to run JavaScript."
    pub fn getConcurrency(self: *const Self) usize {
        return self.hardware_concurrency;
    }
};

/// Get the hardware concurrency (number of logical processors)
fn getHardwareConcurrency() usize {
    // Try to get actual CPU count
    // Default to 1 if unable to determine
    return std.Thread.getCpuCount() catch 1;
}

// ============================================================================
// Tests
// ============================================================================

test "NavigatorConcurrentHardware - init" {
    const hw = NavigatorConcurrentHardware.init();

    // Should be at least 1
    try std.testing.expect(hw.getConcurrency() >= 1);
}

test "NavigatorConcurrentHardware - custom value" {
    const hw = NavigatorConcurrentHardware.initWithValue(8);
    try std.testing.expectEqual(@as(usize, 8), hw.getConcurrency());
}

test "NavigatorConcurrentHardware - minimum is 1" {
    const hw = NavigatorConcurrentHardware.initWithValue(0);
    try std.testing.expectEqual(@as(usize, 1), hw.getConcurrency());
}
