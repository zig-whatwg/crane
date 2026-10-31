//! Time Coarsening for High Resolution Time
//!
//! WHATWG/W3C HR-Time Spec: https://w3c.github.io/hr-time/
//! Spec Reference: Section 3.6 "coarsen time"
//!
//! This module implements time coarsening to prevent timing attacks.
//! High-resolution timers can be used by attackers to extract sensitive
//! information through side-channel attacks (Spectre, cache attacks, etc.).
//!
//! ## Resolution
//!
//! The spec's floors are 100 microseconds, and 5 microseconds for a context
//! with cross-origin isolated capability. Crane coarsens to 125 and 15.625
//! microseconds, a binary fraction of a millisecond (see
//! DEFAULT_RESOLUTION_NS).
//!
//! ## Coarsening Algorithm
//!
//! The algorithm reduces timer resolution by:
//! 1. Rounding timestamps to the nearest resolution boundary
//! 2. Optionally adding jitter for additional protection
//!
//! ## Security Considerations
//!
//! Even with coarsening, timing attacks may still be possible through:
//! - Statistical analysis over many measurements
//! - Amplification attacks
//! - Combining with other timing sources
//!
//! User agents may implement additional mitigations beyond this spec.

const std = @import("std");
const clock = @import("clock.zig");

/// The default time resolution: 125 microseconds, 2^-3 ms.
///
/// HR-Time "coarsen time" steps 1-2: "Let time resolution be 100
/// microseconds, or a higher implementation-defined value. If
/// crossOriginIsolatedCapability is true, set time resolution to be 5
/// microseconds, or a higher implementation-defined value." The browsers'
/// values: Chrome 100 us and 5 us cross-origin isolated (with jitter);
/// Firefox 1 ms (privacy.resistFingerprinting.reduceTimerPrecision.microseconds
/// = 1000) and 20 us cross-origin isolated (RFP_TIMER_UNCONDITIONAL_VALUE);
/// WebKit 1 ms (Performance.cpp `timePrecision { 1_ms }`).
///
/// Why a power-of-two fraction of a millisecond (lane flaky2, approved by
/// the integrator 2026-10-31): every DOMHighResTimeStamp is a double of
/// milliseconds, and a multiple of 2^-3 ms is a double EXACTLY (up to 2^50
/// ms, past the year 37,000 since the Unix epoch). So timeOrigin + now(),
/// a worker's timeOrigin - its creator's, and Web Animations' (t - end) + end
/// are exact sums, as they are in Firefox and Safari's whole milliseconds. On
/// the 0.1 ms grid they were not: 0.1 ms is no double, timeOrigin is about
/// 1.79e12 ms with a 2.4e-4 ms rounding step, and fl(fl(a) + fl(b)) landed one
/// step above fl(a + b) for about 1 in 5 pairs - a worker created within the
/// 100 us of its creator's performance.now() read as created BEFORE it
/// (hr-time/timeOrigin.html, 7 of 60 isolated runs). 125 us keeps Chrome's
/// sub-millisecond resolution, which in-page measurement needs.
pub const DEFAULT_RESOLUTION_NS: i128 = 125 * std.time.ns_per_us;

/// The cross-origin isolated time resolution: 15.625 microseconds, 2^-6 ms
/// - the finest power-of-two fraction of a millisecond that is a whole
/// number of nanoseconds and not finer than 5 microseconds (see
/// DEFAULT_RESOLUTION_NS).
pub const CROSS_ORIGIN_ISOLATED_RESOLUTION_NS: i128 = 15_625;

/// The resolutions in milliseconds, exact doubles: 2^-3 and 2^-6.
pub const DEFAULT_RESOLUTION_MS: f64 = 0.125;
pub const CROSS_ORIGIN_ISOLATED_RESOLUTION_MS: f64 = 0.015625;

comptime {
    std.debug.assert(@as(f64, @floatFromInt(DEFAULT_RESOLUTION_NS)) / std.time.ns_per_ms == DEFAULT_RESOLUTION_MS);
    std.debug.assert(@as(f64, @floatFromInt(CROSS_ORIGIN_ISOLATED_RESOLUTION_NS)) / std.time.ns_per_ms == CROSS_ORIGIN_ISOLATED_RESOLUTION_MS);
}

/// Coarsen time algorithm
///
/// Per HR-Time spec section 3.6 "coarsen time":
/// 1. Let time resolution be 100 microseconds, or a higher
///    implementation-defined value.
/// 2. If crossOriginIsolatedCapability is true, set time
///    resolution to be 5 microseconds, or a higher
///    implementation-defined value.
/// 3. In an implementation-defined manner, coarsen and potentially
///    jitter timestamp such that its resolution will not exceed
///    time resolution.
/// 4. Return timestamp as a moment.
///
/// Arguments:
/// - `timestamp_ns`: Unsafe moment in nanoseconds
/// - `cross_origin_isolated`: Whether context has cross-origin isolated capability
///
/// Returns: Coarsened moment in nanoseconds
pub fn coarsenTime(timestamp_ns: clock.Nanoseconds, cross_origin_isolated: bool) clock.Nanoseconds {
    const resolution = getResolution(cross_origin_isolated);
    return coarsenToResolution(timestamp_ns, resolution);
}

/// "Coarsen time" for a time already in milliseconds - a DOMHighResTimeStamp
/// measured on the monotonic clock from a time origin, which is itself on
/// the grid (fetch's connection timing info): floored onto the same grid as
/// `coarsenTime`. Exact: the resolution is a power of two.
pub fn coarsenMilliseconds(time_ms: f64, cross_origin_isolated: bool) f64 {
    const resolution: f64 = if (cross_origin_isolated) CROSS_ORIGIN_ISOLATED_RESOLUTION_MS else DEFAULT_RESOLUTION_MS;
    return @floor(time_ms / resolution) * resolution;
}

/// Get the time resolution for a given isolation state
pub fn getResolution(cross_origin_isolated: bool) clock.Nanoseconds {
    return if (cross_origin_isolated)
        CROSS_ORIGIN_ISOLATED_RESOLUTION_NS
    else
        DEFAULT_RESOLUTION_NS;
}

/// Coarsen a timestamp to a specific resolution
///
/// Rounds the timestamp down to the nearest resolution boundary.
/// This is a simple floor division approach. More sophisticated
/// implementations might add jitter.
fn coarsenToResolution(timestamp_ns: clock.Nanoseconds, resolution_ns: clock.Nanoseconds) clock.Nanoseconds {
    if (resolution_ns <= 0) return timestamp_ns;

    // Floor division to resolution boundary
    // This reduces the precision while maintaining monotonicity
    return @divFloor(timestamp_ns, resolution_ns) * resolution_ns;
}

/// Coarsen time with optional jitter
///
/// This variant adds random jitter within the resolution window
/// for additional protection against timing attacks. The jitter
/// is deterministic based on the timestamp to maintain consistency
/// for the same input.
///
/// Note: This is an implementation-defined enhancement beyond the
/// basic spec requirements.
pub fn coarsenTimeWithJitter(
    timestamp_ns: clock.Nanoseconds,
    cross_origin_isolated: bool,
    seed: u64,
) clock.Nanoseconds {
    const resolution = getResolution(cross_origin_isolated);
    const base = coarsenToResolution(timestamp_ns, resolution);

    // Add deterministic jitter based on seed
    // The jitter is always positive and less than resolution
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    const jitter_ns: clock.Nanoseconds = @intCast(random.intRangeAtMost(u64, 0, @intCast(resolution - 1)));

    return base + jitter_ns;
}

/// Check if a timestamp has been properly coarsened
///
/// Useful for debugging and testing to verify coarsening is applied.
pub fn isCoarsened(timestamp_ns: clock.Nanoseconds, cross_origin_isolated: bool) bool {
    const resolution = getResolution(cross_origin_isolated);
    return @mod(timestamp_ns, resolution) == 0;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "coarsenTime - default resolution" {
    // Input: 123,456,789 ns
    // Resolution: 125,000 ns (125 us)
    // Expected: 123,375,000 ns (rounded down to the nearest 125 us)
    const input: clock.Nanoseconds = 123_456_789;
    const result = coarsenTime(input, false);

    try testing.expectEqual(@as(clock.Nanoseconds, 123_375_000), result);
}

test "coarsenTime - cross-origin isolated resolution" {
    // Input: 123,456,789 ns
    // Resolution: 15,625 ns (15.625 us)
    // Expected: 123,453,125 ns (rounded down to the nearest 15.625 us)
    const input: clock.Nanoseconds = 123_456_789;
    const result = coarsenTime(input, true);

    try testing.expectEqual(@as(clock.Nanoseconds, 123_453_125), result);
}

test "coarsenTime - already at boundary" {
    const input: clock.Nanoseconds = 100_000_000; // Exactly on a 125 us boundary
    const result = coarsenTime(input, false);

    try testing.expectEqual(input, result);
}

test "coarsenTime - zero" {
    const result = coarsenTime(0, false);
    try testing.expectEqual(@as(clock.Nanoseconds, 0), result);
}

test "coarsenTime - negative value" {
    // Negative times should also be coarsened correctly
    const input: clock.Nanoseconds = -123_456_789;
    const result = coarsenTime(input, false);

    // Floor division rounds toward negative infinity
    try testing.expectEqual(@as(clock.Nanoseconds, -123_500_000), result);
    try testing.expect(isCoarsened(result, false));
}

test "isCoarsened - correctly identifies coarsened timestamps" {
    const coarsened: clock.Nanoseconds = 123_375_000;
    const uncoarsened: clock.Nanoseconds = 123_456_789;

    try testing.expect(isCoarsened(coarsened, false));
    try testing.expect(!isCoarsened(uncoarsened, false));
}

test "coarsenTime - result is always <= input for positive values" {
    const input: clock.Nanoseconds = 999_999_999;
    const result_default = coarsenTime(input, false);
    const result_isolated = coarsenTime(input, true);

    try testing.expect(result_default <= input);
    try testing.expect(result_isolated <= input);
}

test "coarsenTimeWithJitter - stays within bounds" {
    const input: clock.Nanoseconds = 123_456_789;
    const base = coarsenTime(input, false);
    const resolution = getResolution(false);

    // Run multiple times with different seeds
    var i: u64 = 0;
    while (i < 100) : (i += 1) {
        const jittered = coarsenTimeWithJitter(input, false, i);
        // Result should be >= base and < base + resolution
        try testing.expect(jittered >= base);
        try testing.expect(jittered < base + resolution);
    }
}

test "getResolution - returns correct values" {
    try testing.expectEqual(DEFAULT_RESOLUTION_NS, getResolution(false));
    try testing.expectEqual(CROSS_ORIGIN_ISOLATED_RESOLUTION_NS, getResolution(true));
}
