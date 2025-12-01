//! Time Origin Management for High Resolution Time
//!
//! WHATWG/W3C HR-Time Spec: https://w3c.github.io/hr-time/
//! Spec Reference: Section 3.4 "Time Origin"
//!
//! This module manages the time origin for environment settings objects.
//! The time origin is the moment when a context (Window, Worker) was created,
//! used as the reference point for Performance.now() measurements.
//!
//! ## Concepts
//!
//! - **Time Origin**: The moment when the context was created (navigation start
//!   for Window, worker start for Worker)
//! - **Estimated Monotonic Time of Unix Epoch**: A shared reference point that
//!   allows correlating monotonic time with wall clock time
//!
//! ## Per Spec Section 3.4:
//!
//! "The Unix epoch is the moment on the wall clock corresponding to
//! 1 January 1970 00:00:00 UTC."
//!
//! "Each group of environment settings objects that could possibly communicate
//! in any way has an estimated monotonic time of the Unix epoch."

const std = @import("std");
const clock = @import("clock.zig");
const coarsen = @import("coarsen.zig");

/// Time Origin for an environment settings object
///
/// Per HR-Time spec, each context has a time origin that represents
/// when the context was created. This is used as the reference point
/// for Performance.now() which returns time relative to the origin.
pub const TimeOrigin = struct {
    /// The moment on the monotonic clock when this context was created.
    /// This is a coarsened moment (safe to expose).
    origin_moment: clock.Nanoseconds,

    /// Estimated monotonic time of the Unix epoch.
    /// Shared across related contexts that can communicate.
    /// This is used to calculate Performance.timeOrigin.
    estimated_epoch: clock.Nanoseconds,

    /// Whether this context has cross-origin isolated capability.
    /// Affects timer resolution per spec section 3.6.
    cross_origin_isolated: bool,

    const Self = @This();

    /// Initialize a new time origin for a context
    ///
    /// This should be called when creating a new environment settings object:
    /// - For Window: at navigation start
    /// - For Worker: when the worker is run
    ///
    /// Per spec section 3.4 "estimated monotonic time of the Unix epoch":
    /// 1. Let wall time be the wall clock's unsafe current time
    /// 2. Let monotonic time be the monotonic clock's unsafe current time
    /// 3. Let epoch time be monotonic time - (wall time - Unix epoch)
    /// 4. Initialize the estimated monotonic time of the Unix epoch to
    ///    the result of calling coarsen time with epoch time.
    pub fn init(cross_origin_isolated: bool) Self {
        const wall_time = clock.WallClock.unsafeCurrentTime();
        const monotonic_time = clock.MonotonicClock.unsafeCurrentTime();

        // Calculate estimated monotonic time of Unix epoch
        // epoch_time = monotonic_time - wall_time
        // (since wall_time is ns since Unix epoch, this gives us
        // what the monotonic clock would have been at Unix epoch)
        const epoch_time = monotonic_time - wall_time;

        // Coarsen both timestamps before storing
        // Note: estimated_epoch uses default resolution per spec
        // (it's shared across contexts, not context-specific)
        const coarsened_epoch = coarsen.coarsenTime(epoch_time, false);
        const coarsened_origin = coarsen.coarsenTime(monotonic_time, cross_origin_isolated);

        return Self{
            .origin_moment = coarsened_origin,
            .estimated_epoch = coarsened_epoch,
            .cross_origin_isolated = cross_origin_isolated,
        };
    }

    /// Initialize with a specific origin moment (for testing or custom scenarios)
    pub fn initWithOrigin(
        origin_moment: clock.Nanoseconds,
        estimated_epoch: clock.Nanoseconds,
        cross_origin_isolated: bool,
    ) Self {
        return Self{
            .origin_moment = origin_moment,
            .estimated_epoch = estimated_epoch,
            .cross_origin_isolated = cross_origin_isolated,
        };
    }

    /// Get the current relative timestamp
    ///
    /// Per spec: "current relative timestamp" is the duration from
    /// the time origin to the current monotonic time.
    ///
    /// This is what Performance.now() returns.
    pub fn currentRelativeTimestamp(self: *const Self) clock.Nanoseconds {
        const current_time = clock.MonotonicClock.unsafeCurrentTime();
        const coarsened = coarsen.coarsenTime(current_time, self.cross_origin_isolated);
        return coarsened - self.origin_moment;
    }

    /// Get the current relative timestamp in milliseconds
    ///
    /// This is the value returned by Performance.now()
    pub fn currentRelativeTimestampMs(self: *const Self) f64 {
        return clock.toMilliseconds(self.currentRelativeTimestamp());
    }

    /// Get the time origin timestamp
    ///
    /// Per spec "get time origin timestamp":
    /// 1. Let timeOrigin be the time origin
    /// 2. Return the duration from the estimated monotonic time of the
    ///    Unix epoch to timeOrigin
    ///
    /// This is what Performance.timeOrigin returns.
    pub fn getTimeOriginTimestamp(self: *const Self) clock.Nanoseconds {
        return self.origin_moment - self.estimated_epoch;
    }

    /// Get the time origin timestamp in milliseconds
    ///
    /// This is the value returned by Performance.timeOrigin
    pub fn getTimeOriginTimestampMs(self: *const Self) f64 {
        return clock.toMilliseconds(self.getTimeOriginTimestamp());
    }

    /// Get the current monotonic time (coarsened)
    ///
    /// Per spec: "current monotonic time" for an environment settings object
    /// is the coarsened current time from the monotonic clock.
    pub fn currentMonotonicTime(self: *const Self) clock.Nanoseconds {
        const current_time = clock.MonotonicClock.unsafeCurrentTime();
        return coarsen.coarsenTime(current_time, self.cross_origin_isolated);
    }

    /// Get the current wall time (coarsened)
    ///
    /// Per spec: "current wall time" for an environment settings object
    /// is the coarsened current time from the wall clock.
    pub fn currentWallTime(self: *const Self) clock.Nanoseconds {
        const current_time = clock.WallClock.unsafeCurrentTime();
        return coarsen.coarsenTime(current_time, self.cross_origin_isolated);
    }
};

/// Get the current coarsened wall time (global, no context)
///
/// Per spec: "current coarsened wall time" is the result of calling
/// coarsen time with the wall clock's unsafe current time.
///
/// Uses default resolution (not cross-origin isolated).
pub fn currentCoarsenedWallTime() clock.Nanoseconds {
    const wall_time = clock.WallClock.unsafeCurrentTime();
    return coarsen.coarsenTime(wall_time, false);
}

/// Get the unsafe shared current time
///
/// Per spec: "unsafe shared current time" must return the
/// monotonic clock's unsafe current time.
///
/// This is NOT coarsened and should only be used internally.
pub fn unsafeSharedCurrentTime() clock.Nanoseconds {
    return clock.MonotonicClock.unsafeCurrentTime();
}

/// Get the coarsened shared current time
///
/// Per spec: "coarsened shared current time" given an optional boolean
/// crossOriginIsolatedCapability (default false), must return the result
/// of calling coarsen time with the unsafe shared current time.
pub fn coarsenedSharedCurrentTime(cross_origin_isolated: bool) clock.Nanoseconds {
    const unsafe_time = unsafeSharedCurrentTime();
    return coarsen.coarsenTime(unsafe_time, cross_origin_isolated);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "TimeOrigin.init creates valid origin" {
    const origin = TimeOrigin.init(false);

    // Origin moment should be positive (after epoch)
    try testing.expect(origin.origin_moment > 0);

    // Estimated epoch can be any value (it's the monotonic time at Unix epoch)
    // The key relationship is: origin_moment - estimated_epoch ≈ wall clock time
}

test "TimeOrigin.currentRelativeTimestamp starts near zero" {
    const origin = TimeOrigin.init(false);

    // Immediately after creation, relative timestamp should be very small
    const relative = origin.currentRelativeTimestamp();

    // Should be less than 1 second (1 billion nanoseconds)
    // In practice it should be microseconds
    try testing.expect(relative < 1_000_000_000);
    try testing.expect(relative >= 0);
}

test "TimeOrigin.currentRelativeTimestamp is monotonic" {
    const origin = TimeOrigin.init(false);

    const t1 = origin.currentRelativeTimestamp();
    const t2 = origin.currentRelativeTimestamp();

    try testing.expect(t2 >= t1);
}

test "TimeOrigin.getTimeOriginTimestamp is positive" {
    const origin = TimeOrigin.init(false);

    // timeOrigin should be positive (time after Unix epoch)
    const timestamp = origin.getTimeOriginTimestamp();
    try testing.expect(timestamp > 0);
}

test "TimeOrigin.getTimeOriginTimestampMs returns milliseconds" {
    const origin = TimeOrigin.init(false);

    const timestamp_ms = origin.getTimeOriginTimestampMs();

    // Should be after 2020 (roughly 1577836800000 ms since epoch)
    try testing.expect(timestamp_ms > 1577836800000.0);
}

test "TimeOrigin cross-origin isolated affects resolution" {
    const origin_default = TimeOrigin.init(false);
    const origin_isolated = TimeOrigin.init(true);

    // Both should work, the difference is in resolution which is harder to test
    // Just verify they create valid origins
    try testing.expect(origin_default.origin_moment > 0);
    try testing.expect(origin_isolated.origin_moment > 0);
}

test "currentCoarsenedWallTime returns reasonable value" {
    const wall_time = currentCoarsenedWallTime();

    // Should be after 2020
    const year_2020_ns: clock.Nanoseconds = 1577836800 * std.time.ns_per_s;
    try testing.expect(wall_time > year_2020_ns);
}

test "coarsenedSharedCurrentTime is coarsened" {
    const time = coarsenedSharedCurrentTime(false);

    // Result should be divisible by default resolution (100 microseconds)
    try testing.expect(coarsen.isCoarsened(time, false));
}

test "TimeOrigin.initWithOrigin allows custom values" {
    const origin = TimeOrigin.initWithOrigin(
        1_000_000_000, // 1 second
        500_000_000, // 0.5 seconds
        false,
    );

    try testing.expectEqual(@as(clock.Nanoseconds, 1_000_000_000), origin.origin_moment);
    try testing.expectEqual(@as(clock.Nanoseconds, 500_000_000), origin.estimated_epoch);
    try testing.expectEqual(false, origin.cross_origin_isolated);

    // Time origin timestamp should be origin - epoch = 0.5 seconds
    try testing.expectEqual(@as(clock.Nanoseconds, 500_000_000), origin.getTimeOriginTimestamp());
}
