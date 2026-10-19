//! Freshness - RFC 9111 4.2, and the HTTP-date parser the cache and
//! document.lastModified share.
//!
//! A stored response's freshness inputs are read from its header list once,
//! when it is stored or freshened (`Facts.fromHeaders`); a lookup then needs
//! only arithmetic: fresh while `lifetime > currentAge` (4.2).
//!
//! RFC 9111 (June 2022) obsoletes RFC 7234, which the earlier code here
//! followed: it fell through to the Last-Modified heuristic on an invalid
//! Expires (9111 5.3: "already expired"), gave every status a heuristic
//! lifetime capped at a day, and took the last of duplicate directives.
//!
//! Spec: https://www.rfc-editor.org/rfc/rfc9111#section-4.2

const std = @import("std");
const cache_control = @import("cache_control.zig");
const Directives = cache_control.Directives;

/// What a stored response's header list says about its freshness. Times are
/// seconds since the Unix epoch.
pub const Facts = struct {
    status: u16,
    /// The Date header (first line), if it parses.
    date: ?i64 = null,
    expires: Expires = .absent,
    /// The Last-Modified header (first line), if it parses.
    last_modified: ?i64 = null,
    /// age_value (4.2.3): the Age header's first member, 0 when absent or
    /// invalid (5.1: "a cache SHOULD ignore the field").
    age: u64 = 0,
    /// Every Cache-Control line, the first occurrence of each directive.
    directives: Directives = .{},

    pub const Expires = union(enum) {
        absent,
        /// 5.3: "A cache recipient MUST interpret invalid date formats,
        /// especially the value "0", as representing a time in the past".
        invalid,
        at: i64,
    };

    /// The facts of a response with `status` and `headers` - any slice of
    /// structs with `name` and `value`.
    pub fn fromHeaders(status: u16, headers: anytype) Facts {
        var facts: Facts = .{ .status = status };
        var seen_date = false;
        var seen_last_modified = false;
        var seen_age = false;
        var pragma_no_cache = false;
        for (headers) |header| {
            const name = header.name;
            const value = header.value;
            if (std.ascii.eqlIgnoreCase(name, "Cache-Control")) {
                facts.directives.add(value);
            } else if (std.ascii.eqlIgnoreCase(name, "Expires")) {
                // 4.2.1: of two Expires lines, the first.
                if (facts.expires == .absent) facts.expires = if (parseHttpDate(value)) |t| .{ .at = t } else .invalid;
            } else if (std.ascii.eqlIgnoreCase(name, "Date")) {
                if (!seen_date) facts.date = parseHttpDate(value);
                seen_date = true;
            } else if (std.ascii.eqlIgnoreCase(name, "Last-Modified")) {
                if (!seen_last_modified) facts.last_modified = parseHttpDate(value);
                seen_last_modified = true;
            } else if (std.ascii.eqlIgnoreCase(name, "Age")) {
                // 5.1: a list-based value's first member; an invalid one is
                // ignored.
                if (!seen_age) {
                    const first = std.mem.trim(u8, value[0 .. std.mem.indexOfScalar(u8, value, ',') orelse value.len], " \t");
                    facts.age = switch (cache_control.deltaSeconds(first)) {
                        .value => |seconds| seconds,
                        else => 0,
                    };
                }
                seen_age = true;
            } else if (std.ascii.eqlIgnoreCase(name, "Pragma")) {
                var tokens = std.mem.splitScalar(u8, value, ',');
                while (tokens.next()) |token| {
                    if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, token, " \t"), "no-cache")) pragma_no_cache = true;
                }
            }
        }
        // RFC 9111 5.4 gives a response's Pragma no meaning ("does not
        // provide a reliable replacement for Cache-Control: no-cache"), but
        // Chrome 155, Firefox 158 and Safari 27 all refuse to reuse a
        // `Pragma: no-cache` response without the network, Cache-Control
        // max-age and public notwithstanding; Chrome and Safari even with
        // immutable, where Firefox reuses it (fetch/http-cache/
        // pragma-no-cache-with-cache-control.html, wpt.fyi 23b0b89b1a;
        // Mozilla bug 1937766, Chromium issue 447171250). Golden rule 2, no
        // newer spec: the majority - it is no-cache.
        if (pragma_no_cache) facts.directives.no_cache = true;
        return facts;
    }

    /// Whether the response carries explicit freshness (RFC 9111 3's
    /// storage condition: an Expires field or a max-age directive, valid
    /// or not).
    pub fn hasExplicitFreshness(self: Facts) bool {
        return self.directives.max_age != .absent or self.expires != .absent;
    }
};

/// A lifetime longer than any age: RFC 9111 1.2.2's "infinity" (2^31 s).
pub const unlimited: u64 = Directives.delta_seconds_overflow;

/// RFC 9111 4.2.1's freshness_lifetime, in seconds, of a response with
/// `facts` received at `response_time` (the Date stand-in when it has none,
/// RFC 9110 6.6.1). This cache is private: s-maxage is not read.
pub fn lifetime(facts: Facts, response_time: i64) u64 {
    // "If the max-age response directive is present, use its value" - and an
    // invalid one is stale (4.2.1's last paragraph).
    switch (facts.directives.max_age) {
        .value => |seconds| return seconds,
        .invalid => return 0,
        .absent => {},
    }
    // "If the Expires response header field is present, use its value minus
    // the value of the Date response header field".
    const date = facts.date orelse response_time;
    switch (facts.expires) {
        .at => |expires| return if (expires > date) @intCast(expires - date) else 0,
        .invalid => return 0,
        .absent => {},
    }
    // 4.2.2: a heuristic, for the statuses the browsers' majority gives one.
    // 410 Gone is fresh without limit: Chromium's
    // HttpResponseHeaders::GetFreshnessLifetimes ("These responses are
    // implicitly fresh") and Gecko's
    // nsHttpResponseHead::ComputeFreshnessLifetime ("These responses can be
    // cached indefinitely") both.
    if (facts.status == 410) return unlimited;
    if (!heuristicFreshnessStatus(facts.status)) return 0;
    const last_modified = facts.last_modified orelse return 0;
    if (last_modified > date) return 0;
    // "no more than some fraction of the interval since that time. A typical
    // setting of this fraction might be 10%." No cap: Chromium has none,
    // Gecko a week, the RFC none - no majority, so the spec (golden rule 2).
    return @intCast(@divTrunc(date - last_modified, 10));
}

/// The statuses that get a Last-Modified heuristic lifetime. RFC 9110 15.1
/// makes 404, 405, 414 and 501 heuristically cacheable too, and a `public`
/// response of any status (RFC 9111 4.2.2), but Chrome 155 and Firefox 158
/// give them none (fetch/http-cache/heuristic.any.html at wpt.fyi
/// 23b0b89b1a: both fail those cases, Safari 27 passes them; 204: Firefox
/// and Safari pass, Chrome fails) - the browsers' majority, case by case
/// (golden rule 2; no newer spec: RFC 7231 6.1 had the same list).
/// Chromium: 200, 203, 206 (http_response_headers.cc); Gecko: below 400 but
/// 302, 303, 304, 307 (nsHttpResponseHead.cpp).
fn heuristicFreshnessStatus(status: u16) bool {
    return switch (status) {
        200, 203, 204, 206, 300, 301, 308 => true,
        else => false,
    };
}

/// RFC 9110 15.1's heuristically cacheable statuses: what RFC 9111 3 lets a
/// cache store without explicit freshness or `public`/`private`.
pub fn heuristicallyCacheable(status: u16) bool {
    return switch (status) {
        200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501 => true,
        else => false,
    };
}

/// RFC 9111 4.2.3's current_age at `now` of a response with `facts`, whose
/// request went at `request_time` and whose answer came at `response_time`.
/// Never negative; saturating.
pub fn currentAge(facts: Facts, request_time: i64, response_time: i64, now: i64) u64 {
    const date = facts.date orelse response_time;
    // apparent_age = max(0, response_time - date_value)
    const apparent_age: u64 = if (response_time > date) @intCast(response_time - date) else 0;
    // response_delay = response_time - request_time
    const response_delay: u64 = if (response_time > request_time) @intCast(response_time - request_time) else 0;
    // corrected_age_value = age_value + response_delay
    const corrected_age_value = facts.age +| response_delay;
    // corrected_initial_age = max(apparent_age, corrected_age_value)
    const corrected_initial_age = @max(apparent_age, corrected_age_value);
    // resident_time = now - response_time
    const resident_time: u64 = if (now > response_time) @intCast(now - response_time) else 0;
    // current_age = corrected_initial_age + resident_time
    return corrected_initial_age +| resident_time;
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
