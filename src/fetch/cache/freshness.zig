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
const clock = @import("clock");
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
        return clock.wallSeconds();
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

/// RFC 9110 section 5.6.7: parse any of the three HTTP-date wire formats.
/// Returns signed Unix epoch seconds, or null for an invalid date.
pub fn parseHttpDate(date_str: []const u8) ?i64 {
    return parseHttpDateAt(date_str, @import("platform").wallSeconds());
}

/// The same parser with a supplied current UTC instant, for RFC850's
/// fifty-year rule (section 5.6.7 paragraph 18).
pub fn parseHttpDateAt(date_str: []const u8, now: i64) ?i64 {
    const input = std.mem.trim(u8, date_str, " \t");
    var date: HttpDate = undefined;
    // Section 5.6.7 paragraph 11: IMF-fixdate.
    if (input.len == 29 and input[3] == ',') {
        if (!httpWeekday(input[0..3], false) or input[4] != ' ' or
            input[7] != ' ' or input[11] != ' ' or input[16] != ' ' or
            input[25] != ' ' or !std.ascii.eqlIgnoreCase(input[26..29], "GMT")) return null;
        date = httpDateFields(input[5..7], input[8..11], input[12..16], input[17..25]) orelse return null;
    } else if (std.mem.indexOfScalar(u8, input, ',')) |comma| {
        // Section 5.6.7 paragraph 14: obsolete rfc850-date. Recipients MUST
        // accept it, including its long weekday and two-digit year.
        if (!httpWeekday(input[0..comma], true) or input.len - comma != 24 or input[comma + 1] != ' ') return null;
        const rest = input[comma + 2 ..];
        if (rest[2] != '-' or rest[6] != '-' or rest[9] != ' ' or
            rest[18] != ' ' or !std.ascii.eqlIgnoreCase(rest[19..22], "GMT")) return null;
        date = httpDateFields(rest[0..2], rest[3..6], rest[7..9], rest[10..18]) orelse return null;
        const current = utcDateFields(now);
        const latest_year = current.year + 50;
        // Pick the matching year at or before the fifty-year boundary,
        // including across centuries, then compare the rest of the date.
        date.year = latest_year - @mod(latest_year - date.year, 100);
        if (date.year == latest_year and httpDateRemainder(date) > httpDateRemainder(current)) date.year -= 100;
    } else {
        // Section 5.6.7 paragraph 15: asctime-date, implicitly UTC.
        if (input.len != 24 or !httpWeekday(input[0..3], false) or
            input[3] != ' ' or input[7] != ' ' or input[10] != ' ' or input[19] != ' ') return null;
        const day = if (input[8] == ' ') input[9..10] else input[8..10];
        date = httpDateFields(day, input[4..7], input[20..24], input[11..19]) orelse return null;
    }
    // Section 5.6.7 paragraph 17 imports RFC 5322 section 3.3's calendar
    // semantics (year >= 1900, an actual day of the month, valid clock fields).
    if (date.year < 1900 or date.year > 9999 or date.day == 0 or
        date.hour > 23 or date.minute > 59 or date.second > 60) return null;
    const year: u16 = @intCast(date.year);
    const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const last_day = days_in_month[date.month - 1] + @as(u8, @intFromBool(date.month == 2 and isLeapYear(year)));
    if (date.day > last_day) return null;
    return dateToEpoch(year, date.month, date.day, date.hour, date.minute, date.second);
}

/// HTML lastModified: unrepresentable or invalid source dates are "not known".
/// WallTime has a narrower nanosecond range than HTTP's epoch seconds. Never
/// wrap or clamp it; a wider source timestamp is a separate follow-up.
pub fn parseHttpDateWallTime(date_str: []const u8) ?@import("platform").WallTime {
    const seconds = parseHttpDate(date_str) orelse return null;
    return .{ .ns_since_epoch = std.math.mul(i64, seconds, std.time.ns_per_s) catch return null };
}

const HttpDate = struct {
    year: i64,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
};

fn httpDateFields(day: []const u8, month: []const u8, year: []const u8, time: []const u8) ?HttpDate {
    if (time.len != 8 or time[2] != ':' or time[5] != ':') return null;
    return .{
        .year = httpDateNumber(year) orelse return null,
        .month = httpMonth(month) orelse return null,
        .day = @intCast(httpDateNumber(day) orelse return null),
        .hour = @intCast(httpDateNumber(time[0..2]) orelse return null),
        .minute = @intCast(httpDateNumber(time[3..5]) orelse return null),
        .second = @intCast(httpDateNumber(time[6..8]) orelse return null),
    };
}

/// All callers supply at most four digits; signs and other parseInt syntax
/// are not DIGIT in the HTTP-date grammar.
fn httpDateNumber(input: []const u8) ?u16 {
    if (input.len == 0 or input.len > 4) return null;
    var result: u16 = 0;
    for (input) |c| {
        if (!std.ascii.isDigit(c)) return null;
        result = result * 10 + (c - '0');
    }
    return result;
}

fn httpMonth(input: []const u8) ?u8 {
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    // RFC 9111 section 4.2 relaxes name case for cache recipients. This
    // shared parser preserves that tolerance for its cache callers.
    for (months, 1..) |month, number| {
        if (std.ascii.eqlIgnoreCase(input, month)) return @intCast(number);
    }
    return null;
}

fn httpWeekday(input: []const u8, comptime long: bool) bool {
    const names = if (long)
        [_][]const u8{ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
    else
        [_][]const u8{ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
    // RFC 9110 section 5.6.7 imports weekday semantics, but all three
    // browsers ignore a recognized weekday's disagreement with the date:
    // WebKit Source/WTF/wtf/DateMath.cpp:709; Blink base/third_party/nspr/
    // prtime.cc:1058-1068; Gecko nsHttpResponseHead.cpp:904-914,977-979 uses
    // that same PR_ParseTimeString. No newer spec change (golden rule 2).
    for (names) |name| if (std.ascii.eqlIgnoreCase(input, name)) return true;
    return false;
}

/// UTC civil fields without an OS timezone or unsigned pre-epoch cast.
fn utcDateFields(seconds: i64) HttpDate {
    // Gregorian dates repeat every 400 years. Reduce to 1970..2369 so the
    // standard library's unsigned epoch helpers also handle negative times.
    const cycle_seconds: i64 = 146097 * std.time.s_per_day;
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(@mod(seconds, cycle_seconds)) };
    const year_day = epoch.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const time = epoch.getDaySeconds();
    return .{
        .year = @as(i64, year_day.year) + @divFloor(seconds, cycle_seconds) * 400,
        .month = @intFromEnum(month_day.month),
        .day = @as(u8, month_day.day_index) + 1,
        .hour = time.getHoursIntoDay(),
        .minute = time.getMinutesIntoHour(),
        .second = time.getSecondsIntoMinute(),
    };
}

/// Lexicographic month/day/time order, including 23:59:60. No calendar
/// normalization is needed to compare with the fifty-year boundary.
fn httpDateRemainder(date: HttpDate) u64 {
    var value: u64 = date.month;
    value = value * 32 + date.day;
    value = value * 24 + date.hour;
    value = value * 60 + date.minute;
    return value * 61 + date.second;
}

/// Convert validated Gregorian date components to signed Unix epoch seconds.
fn dateToEpoch(year: u16, month: u8, day: u8, hour: u8, minute: u8, second: u8) i64 {
    var days = daysBeforeYear(year) - daysBeforeYear(1970);
    const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    for (days_in_month[0 .. month - 1]) |count| days += count;
    if (month > 2 and isLeapYear(year)) days += 1;
    days += day - 1;
    return days * 86400 + @as(i64, hour) * 3600 + @as(i64, minute) * 60 + second;
}

fn daysBeforeYear(year: u16) i64 {
    const previous = @as(i64, year) - 1;
    return previous * 365 + @divFloor(previous, 4) - @divFloor(previous, 100) + @divFloor(previous, 400);
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
