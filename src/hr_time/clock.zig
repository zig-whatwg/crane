//! Clock Infrastructure for High Resolution Time
//!
//! WHATWG/W3C HR-Time Spec: https://w3c.github.io/hr-time/
//!
//! This module provides monotonic and wall clock implementations
//! for the HR-Time specification. The monotonic clock never decreases
//! and is not subject to system clock adjustments. The wall clock
//! tracks real-world time and may be adjusted.
//!
//! ## Clocks
//!
//! Per spec section "Clocks":
//! - **Monotonic Clock**: Never decreases, not subject to system adjustments.
//!   Used for performance measurements and timing.
//! - **Wall Clock**: Tracks real-world time, may be adjusted.
//!   Used for timestamps that need to correlate with real time.
//!
//! ## Implementation Notes
//!
//! - All times are in nanoseconds internally for maximum precision
//! - Zig's std.time.nanoTimestamp() provides monotonic time
//! - For wall clock, we use platform-specific realtime clocks
//! - Times are converted to milliseconds (f64) for DOMHighResTimeStamp

const std = @import("std");
const builtin = @import("builtin");

/// Nanoseconds type for internal time representation
pub const Nanoseconds = i128;

/// Monotonic Clock
///
/// Per HR-Time spec: "The monotonic clock's unsafe current time never
/// decreases, so it can't be changed by system clock adjustments."
///
/// This clock is used for:
/// - Performance.now()
/// - Duration measurements
/// - Time origin calculations
pub const MonotonicClock = struct {
    /// Get unsafe current time from the monotonic clock.
    ///
    /// Returns nanoseconds since an arbitrary but fixed point in time.
    /// This value only has meaning relative to other values from this clock.
    ///
    /// Per spec: This is an "unsafe moment" that should be coarsened
    /// before being exposed to JavaScript.
    pub fn unsafeCurrentTime() Nanoseconds {
        return std.time.nanoTimestamp();
    }
};

/// Wall Clock
///
/// Per HR-Time spec: "The wall clock's unsafe current time is always
/// as close as possible to a user's notion of time."
///
/// This clock may be adjusted by:
/// - NTP synchronization
/// - User clock changes
/// - Daylight saving time (for local time)
///
/// Used for:
/// - Performance.timeOrigin (relative to Unix epoch)
/// - Correlation with Date.now()
pub const WallClock = struct {
    /// Get unsafe current time from the wall clock.
    ///
    /// Returns nanoseconds since the Unix epoch (1970-01-01 00:00:00 UTC).
    ///
    /// Per spec: This is an "unsafe moment" that should be coarsened
    /// before being exposed to JavaScript.
    pub fn unsafeCurrentTime() Nanoseconds {
        return getRealtimeNanoseconds();
    }
};

/// Get realtime (wall clock) nanoseconds since Unix epoch.
///
/// This uses platform-specific APIs to get the actual wall clock time,
/// which may differ from monotonic time due to clock adjustments.
fn getRealtimeNanoseconds() Nanoseconds {
    switch (builtin.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly => {
            return getRealtimePosix();
        },
        .macos, .ios, .tvos, .watchos, .visionos => {
            return getRealtimeDarwin();
        },
        .windows => {
            return getRealtimeWindows();
        },
        else => {
            // Fallback: use monotonic time (less accurate for wall clock)
            // This is acceptable for testing but not ideal for production
            return std.time.nanoTimestamp();
        },
    }
}

/// Get realtime on POSIX systems using clock_gettime(CLOCK_REALTIME)
fn getRealtimePosix() Nanoseconds {
    const c = @cImport({
        @cInclude("time.h");
    });

    var ts: c.struct_timespec = undefined;
    const result = c.clock_gettime(c.CLOCK_REALTIME, &ts);
    if (result != 0) {
        // Fallback to monotonic if realtime fails
        return std.time.nanoTimestamp();
    }

    const seconds: i128 = @intCast(ts.tv_sec);
    const nanoseconds: i128 = @intCast(ts.tv_nsec);
    return seconds * std.time.ns_per_s + nanoseconds;
}

/// Get realtime on Darwin (macOS/iOS) using clock_gettime(CLOCK_REALTIME)
/// macOS 10.12+ supports clock_gettime
fn getRealtimeDarwin() Nanoseconds {
    const c = @cImport({
        @cInclude("time.h");
    });

    var ts: c.struct_timespec = undefined;
    const result = c.clock_gettime(c.CLOCK_REALTIME, &ts);
    if (result != 0) {
        // Fallback to monotonic if realtime fails
        return std.time.nanoTimestamp();
    }

    const seconds: i128 = @intCast(ts.tv_sec);
    const nanoseconds: i128 = @intCast(ts.tv_nsec);
    return seconds * std.time.ns_per_s + nanoseconds;
}

/// Get realtime on Windows using GetSystemTimePreciseAsFileTime
fn getRealtimeWindows() Nanoseconds {
    const windows = std.os.windows;

    // GetSystemTimePreciseAsFileTime returns 100-nanosecond intervals
    // since January 1, 1601 (Windows epoch)
    var ft: windows.FILETIME = undefined;
    windows.kernel32.GetSystemTimePreciseAsFileTime(&ft);

    // Convert FILETIME to 64-bit value (100ns intervals since Windows epoch)
    const filetime: u64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;

    // Convert Windows epoch to Unix epoch
    // Windows epoch: 1601-01-01, Unix epoch: 1970-01-01
    // Difference: 11644473600 seconds = 116444736000000000 100-ns intervals
    const windows_to_unix_offset: u64 = 116444736000000000;

    if (filetime < windows_to_unix_offset) {
        // Time before Unix epoch (shouldn't happen in practice)
        return 0;
    }

    const unix_100ns = filetime - windows_to_unix_offset;

    // Convert 100-nanosecond intervals to nanoseconds
    return @as(Nanoseconds, unix_100ns) * 100;
}

/// Convert nanoseconds to milliseconds (DOMHighResTimeStamp)
///
/// Per HR-Time spec: DOMHighResTimeStamp is a double representing
/// time in milliseconds with sub-millisecond precision.
pub fn toMilliseconds(ns: Nanoseconds) f64 {
    return @as(f64, @floatFromInt(ns)) / @as(f64, std.time.ns_per_ms);
}

/// Convert milliseconds to nanoseconds
pub fn fromMilliseconds(ms: f64) Nanoseconds {
    return @intFromFloat(ms * @as(f64, std.time.ns_per_ms));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "MonotonicClock.unsafeCurrentTime returns positive value" {
    const time = MonotonicClock.unsafeCurrentTime();
    try testing.expect(time > 0);
}

test "MonotonicClock is monotonic" {
    const t1 = MonotonicClock.unsafeCurrentTime();
    const t2 = MonotonicClock.unsafeCurrentTime();
    try testing.expect(t2 >= t1);
}

test "WallClock.unsafeCurrentTime returns reasonable value" {
    const time = WallClock.unsafeCurrentTime();
    // Should be after 2020-01-01 (in nanoseconds since Unix epoch)
    const year_2020_ns: Nanoseconds = 1577836800 * std.time.ns_per_s;
    try testing.expect(time > year_2020_ns);
}

test "toMilliseconds conversion" {
    const ns: Nanoseconds = 1_500_000_000; // 1.5 seconds in ns
    const ms = toMilliseconds(ns);
    try testing.expectApproxEqAbs(@as(f64, 1500.0), ms, 0.001);
}

test "fromMilliseconds conversion" {
    const ms: f64 = 1500.0;
    const ns = fromMilliseconds(ms);
    try testing.expectEqual(@as(Nanoseconds, 1_500_000_000), ns);
}

test "toMilliseconds and fromMilliseconds are inverse" {
    const original_ns: Nanoseconds = 123456789012;
    const ms = toMilliseconds(original_ns);
    const back_ns = fromMilliseconds(ms);
    // Allow some rounding error due to floating point
    const diff = if (original_ns > back_ns) original_ns - back_ns else back_ns - original_ns;
    try testing.expect(diff < 1000); // Less than 1 microsecond error
}
