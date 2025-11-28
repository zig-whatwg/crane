//! Freshness Calculation - HTTP Caching (RFC 7234)
//!
//! This module implements HTTP cache freshness calculations per RFC 7234.
//!
//! Spec: https://httpwg.org/specs/rfc7234.html#calculating.freshness.lifetime
//!       https://httpwg.org/specs/rfc7234.html#age.calculations
//!
//! Key concepts:
//! - Freshness lifetime: How long a response can be considered "fresh"
//! - Current age: How old the response currently is
//! - Fresh if: current_age < freshness_lifetime

const std = @import("std");
const cache_control = @import("cache_control.zig");
const CacheControl = cache_control.CacheControl;

/// Represents timestamps for cache entry freshness calculations.
/// All times are in seconds since Unix epoch.
pub const CacheTiming = struct {
    /// When the request was sent (request_time in RFC 7234)
    request_time: i64,
    /// When the response was received (response_time in RFC 7234)
    response_time: i64,
    /// Date header value from response (or response_time if missing)
    date_value: i64,
    /// Age header value from response (0 if missing)
    age_value: u64 = 0,
    /// Last-Modified header value (optional, for heuristic freshness)
    last_modified: ?i64 = null,
    /// Expires header value (optional)
    expires: ?i64 = null,
    /// Parsed Cache-Control directives
    cache_control: CacheControl = .{},

    /// Current time for age calculations
    pub fn now() i64 {
        return std.time.timestamp();
    }
};

/// Calculate the current age of a cached response per RFC 7234 § 4.2.3.
///
/// The algorithm accounts for:
/// - Age header from origin or intermediate caches
/// - Network delay (response_time - request_time)
/// - Time since response was stored (resident_time)
///
/// age_value          = Age header value (0 if absent)
/// date_value         = Date header value
/// request_time       = when request was sent
/// response_time      = when response was received
/// now                = current time
///
/// apparent_age       = max(0, response_time - date_value)
/// response_delay     = response_time - request_time
/// corrected_age_value = age_value + response_delay
/// corrected_initial_age = max(apparent_age, corrected_age_value)
/// resident_time      = now - response_time
/// current_age        = corrected_initial_age + resident_time
pub fn calculateCurrentAge(timing: CacheTiming, current_time: i64) u64 {
    // Step 1: Apparent age (clock skew correction)
    const apparent_age: i64 = @max(0, timing.response_time - timing.date_value);

    // Step 2: Response delay
    const response_delay: i64 = timing.response_time - timing.request_time;

    // Step 3: Corrected age value (accounts for intermediate cache age)
    const corrected_age_value: i64 = @as(i64, @intCast(timing.age_value)) + response_delay;

    // Step 4: Corrected initial age (take maximum for safety)
    const corrected_initial_age: i64 = @max(apparent_age, corrected_age_value);

    // Step 5: Resident time (time in our cache)
    const resident_time: i64 = current_time - timing.response_time;

    // Step 6: Current age
    const current_age: i64 = corrected_initial_age + resident_time;

    // Return as unsigned (age can't be negative)
    return if (current_age > 0) @intCast(current_age) else 0;
}

/// Calculate the freshness lifetime of a cached response per RFC 7234 § 4.2.1.
///
/// Priority order:
/// 1. s-maxage (for shared caches)
/// 2. max-age
/// 3. Expires - Date
/// 4. Heuristic (10% of time since Last-Modified)
///
/// Returns null if response should not be cached.
pub fn calculateFreshnessLifetime(timing: CacheTiming, is_shared_cache: bool) ?u64 {
    const cc = timing.cache_control;

    // no-store means don't cache at all
    if (cc.no_store) {
        return null;
    }

    // 1. For shared caches, s-maxage takes precedence
    if (is_shared_cache) {
        if (cc.s_maxage) |s_max| {
            return s_max;
        }
    }

    // 2. max-age directive
    if (cc.max_age) |max| {
        return max;
    }

    // 3. Expires header (if no max-age)
    if (timing.expires) |exp| {
        const delta = exp - timing.date_value;
        return if (delta > 0) @intCast(delta) else 0;
    }

    // 4. Heuristic freshness (10% of age since Last-Modified)
    // Only use heuristic if response is cacheable
    if (timing.last_modified) |lm| {
        const age_since_modified = timing.date_value - lm;
        if (age_since_modified > 0) {
            // Use 10% as heuristic, with a reasonable cap
            const heuristic: u64 = @intCast(@divTrunc(age_since_modified, 10));
            // Cap at 1 day for heuristic freshness
            return @min(heuristic, 86400);
        }
    }

    // No freshness information available - treat as stale
    return 0;
}

/// Check if a cached response is fresh.
///
/// A response is fresh if: current_age < freshness_lifetime
pub fn isFresh(timing: CacheTiming, is_shared_cache: bool, current_time: i64) bool {
    const freshness = calculateFreshnessLifetime(timing, is_shared_cache) orelse return false;
    const age = calculateCurrentAge(timing, current_time);
    return age < freshness;
}

/// Check if a stale response can be served while revalidating.
///
/// Per stale-while-revalidate extension (RFC 5861).
/// Response can be served stale if:
///   current_age < freshness_lifetime + stale_while_revalidate
pub fn canServeStaleWhileRevalidate(timing: CacheTiming, is_shared_cache: bool, current_time: i64) bool {
    const cc = timing.cache_control;

    // Check if stale-while-revalidate is specified
    const swr = cc.stale_while_revalidate orelse return false;

    // Get freshness lifetime
    const freshness = calculateFreshnessLifetime(timing, is_shared_cache) orelse return false;
    const age = calculateCurrentAge(timing, current_time);

    // Can serve stale if within the stale-while-revalidate window
    return age < freshness + swr;
}

/// Check if a stale response can be served when origin returns an error.
///
/// Per stale-if-error extension (RFC 5861).
/// Response can be served stale on error if:
///   current_age < freshness_lifetime + stale_if_error
pub fn canServeStaleIfError(timing: CacheTiming, is_shared_cache: bool, current_time: i64) bool {
    const cc = timing.cache_control;

    // Check if stale-if-error is specified
    const sie = cc.stale_if_error orelse return false;

    // Get freshness lifetime
    const freshness = calculateFreshnessLifetime(timing, is_shared_cache) orelse return false;
    const age = calculateCurrentAge(timing, current_time);

    // Can serve stale on error if within the stale-if-error window
    return age < freshness + sie;
}

/// Calculate time remaining until response becomes stale.
/// Returns 0 if already stale.
pub fn timeUntilStale(timing: CacheTiming, is_shared_cache: bool, current_time: i64) u64 {
    const freshness = calculateFreshnessLifetime(timing, is_shared_cache) orelse return 0;
    const age = calculateCurrentAge(timing, current_time);

    if (age >= freshness) {
        return 0;
    }
    return freshness - age;
}

/// Parse HTTP date format (RFC 7231 § 7.1.1.1).
/// Supports IMF-fixdate format: "Sun, 06 Nov 1994 08:49:37 GMT"
///
/// Returns seconds since Unix epoch, or null if parsing fails.
pub fn parseHttpDate(date_str: []const u8) ?i64 {
    // Simple parser for IMF-fixdate format
    // Full format: "Sun, 06 Nov 1994 08:49:37 GMT"

    // Must have at least "Day, DD Mon YYYY HH:MM:SS GMT" = 29 chars
    if (date_str.len < 29) return null;

    // Skip day name and comma
    const after_day = std.mem.indexOf(u8, date_str, ", ") orelse return null;
    const rest = date_str[after_day + 2 ..];

    // Parse: "06 Nov 1994 08:49:37 GMT"
    if (rest.len < 20) return null;

    const day = std.fmt.parseInt(u8, rest[0..2], 10) catch return null;

    const month_str = rest[3..6];
    const month: u8 = blk: {
        const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
        for (months, 1..) |m, i| {
            if (std.mem.eql(u8, month_str, m)) break :blk @intCast(i);
        }
        return null;
    };

    const year = std.fmt.parseInt(u16, rest[7..11], 10) catch return null;
    const hour = std.fmt.parseInt(u8, rest[12..14], 10) catch return null;
    const minute = std.fmt.parseInt(u8, rest[15..17], 10) catch return null;
    const second = std.fmt.parseInt(u8, rest[18..20], 10) catch return null;

    // Convert to epoch timestamp
    // Simple conversion (doesn't handle all edge cases)
    return dateToEpoch(year, month, day, hour, minute, second);
}

/// Convert date components to Unix epoch seconds.
fn dateToEpoch(year: u16, month: u8, day: u8, hour: u8, minute: u8, second: u8) i64 {
    // Days from year 1970
    var days: i64 = 0;

    // Add days for years
    var y: u16 = 1970;
    while (y < year) : (y += 1) {
        days += if (isLeapYear(y)) 366 else 365;
    }

    // Add days for months
    const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        days += days_in_month[m - 1];
        if (m == 2 and isLeapYear(year)) {
            days += 1;
        }
    }

    // Add days in current month
    days += day - 1;

    // Convert to seconds
    return days * 86400 + @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
}

fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// =============================================================================
// Tests
// =============================================================================

test "calculateCurrentAge - basic" {
    const timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
        .age_value = 0,
    };

    // At response_time, age should be ~1 (response delay)
    try std.testing.expectEqual(@as(u64, 1), calculateCurrentAge(timing, 1001));

    // 100 seconds later
    try std.testing.expectEqual(@as(u64, 101), calculateCurrentAge(timing, 1101));
}

test "calculateCurrentAge - with Age header" {
    const timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
        .age_value = 50, // Response was already 50s old at intermediate cache
    };

    // Age should include the 50s from Age header
    try std.testing.expectEqual(@as(u64, 51), calculateCurrentAge(timing, 1001));
}

test "calculateCurrentAge - clock skew" {
    // Server clock is ahead by 10 seconds
    const timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1011, // Server says it's 10s in the future
        .age_value = 0,
    };

    // apparent_age = max(0, 1001 - 1011) = 0
    // corrected_age = 0 + (1001 - 1000) = 1
    // current_age at 1001 = max(0, 1) + 0 = 1
    try std.testing.expectEqual(@as(u64, 1), calculateCurrentAge(timing, 1001));
}

test "calculateFreshnessLifetime - max-age" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600");

    try std.testing.expectEqual(@as(?u64, 3600), calculateFreshnessLifetime(timing, false));
}

test "calculateFreshnessLifetime - s-maxage for shared cache" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600, s-maxage=600");

    // Shared cache uses s-maxage
    try std.testing.expectEqual(@as(?u64, 600), calculateFreshnessLifetime(timing, true));

    // Private cache uses max-age
    try std.testing.expectEqual(@as(?u64, 3600), calculateFreshnessLifetime(timing, false));
}

test "calculateFreshnessLifetime - Expires header" {
    const timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
        .expires = 4601, // Expires in 3600 seconds
    };

    try std.testing.expectEqual(@as(?u64, 3600), calculateFreshnessLifetime(timing, false));
}

test "calculateFreshnessLifetime - heuristic" {
    const timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
        .last_modified = 1001 - 36000, // Modified 10 hours ago
    };

    // Heuristic: 10% of 36000 = 3600
    try std.testing.expectEqual(@as(?u64, 3600), calculateFreshnessLifetime(timing, false));
}

test "calculateFreshnessLifetime - heuristic cap" {
    const timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
        .last_modified = 1001 - 864000, // Modified 10 days ago
    };

    // Heuristic would be 86400, capped at 1 day
    try std.testing.expectEqual(@as(?u64, 86400), calculateFreshnessLifetime(timing, false));
}

test "calculateFreshnessLifetime - no-store" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("no-store");

    try std.testing.expectEqual(@as(?u64, null), calculateFreshnessLifetime(timing, false));
}

test "isFresh - fresh response" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600");

    // 1000 seconds after response (age ~1001)
    try std.testing.expect(isFresh(timing, false, 2001));
}

test "isFresh - stale response" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600");

    // 4000 seconds after response (age ~4001)
    try std.testing.expect(!isFresh(timing, false, 5001));
}

test "canServeStaleWhileRevalidate" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600, stale-while-revalidate=60");

    // Fresh (age ~3599 < 3600)
    try std.testing.expect(canServeStaleWhileRevalidate(timing, false, 4599));

    // Stale but within SWR window (age ~3650 < 3660)
    try std.testing.expect(canServeStaleWhileRevalidate(timing, false, 4650));

    // Beyond SWR window (age ~3670 >= 3660)
    try std.testing.expect(!canServeStaleWhileRevalidate(timing, false, 4670));
}

test "canServeStaleIfError" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600, stale-if-error=300");

    // Within stale-if-error window
    try std.testing.expect(canServeStaleIfError(timing, false, 4800));

    // Beyond stale-if-error window
    try std.testing.expect(!canServeStaleIfError(timing, false, 5000));
}

test "timeUntilStale" {
    var timing = CacheTiming{
        .request_time = 1000,
        .response_time = 1001,
        .date_value = 1001,
    };
    timing.cache_control = CacheControl.parse("max-age=3600");

    // At response time, ~3599 seconds until stale
    const remaining = timeUntilStale(timing, false, 1001);
    try std.testing.expect(remaining >= 3598 and remaining <= 3600);
}

test "parseHttpDate - IMF-fixdate" {
    const date = "Sun, 06 Nov 1994 08:49:37 GMT";
    const epoch = parseHttpDate(date);
    try std.testing.expect(epoch != null);
    try std.testing.expectEqual(@as(i64, 784111777), epoch.?);
}

test "parseHttpDate - invalid" {
    try std.testing.expectEqual(@as(?i64, null), parseHttpDate("invalid"));
    try std.testing.expectEqual(@as(?i64, null), parseHttpDate(""));
    try std.testing.expectEqual(@as(?i64, null), parseHttpDate("Sun"));
}
