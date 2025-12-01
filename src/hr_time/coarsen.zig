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
//! Per spec section 3.6:
//! - Default resolution: 100 microseconds (100,000 nanoseconds)
//! - Cross-origin isolated: 5 microseconds (5,000 nanoseconds)
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

/// Default time resolution in nanoseconds (100 microseconds)
/// Per HR-Time spec section 3.6
pub const DEFAULT_RESOLUTION_NS: i128 = 100 * std.time.ns_per_us;

/// Cross-origin isolated time resolution in nanoseconds (5 microseconds)
/// Per HR-Time spec section 3.6
pub const CROSS_ORIGIN_ISOLATED_RESOLUTION_NS: i128 = 5 * std.time.ns_per_us;

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
    // Resolution: 100,000 ns (100 us)
    // Expected: 123,400,000 ns (rounded down to nearest 100us)
    const input: clock.Nanoseconds = 123_456_789;
    const result = coarsenTime(input, false);

    try testing.expectEqual(@as(clock.Nanoseconds, 123_400_000), result);
}

test "coarsenTime - cross-origin isolated resolution" {
    // Input: 123,456,789 ns
    // Resolution: 5,000 ns (5 us)
    // Expected: 123,455,000 ns (rounded down to nearest 5us)
    const input: clock.Nanoseconds = 123_456_789;
    const result = coarsenTime(input, true);

    try testing.expectEqual(@as(clock.Nanoseconds, 123_455_000), result);
}

test "coarsenTime - already at boundary" {
    const input: clock.Nanoseconds = 100_000_000; // Exactly on 100us boundary
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
}

test "isCoarsened - correctly identifies coarsened timestamps" {
    const coarsened: clock.Nanoseconds = 123_400_000;
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
