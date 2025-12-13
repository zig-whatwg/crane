//! Gregorian Calendar Implementation
//!
//! The Gregorian calendar is the internationally accepted civil calendar.
//! It was introduced by Pope Gregory XIII in October 1582.
//!
//! ## Leap Year Rule
//!
//! A year is a leap year if:
//! - Divisible by 4 AND
//! - NOT divisible by 100 OR divisible by 400
//!
//! ## Julian Day Number
//!
//! The Gregorian calendar uses the proleptic Gregorian calendar for
//! dates before October 15, 1582 (extending the Gregorian rules backwards).

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;

/// Gregorian calendar eras
pub const ERAS = [_]Era{
    Era{
        .id = "bc",
        .abbr = "BC",
        .name = "Before Christ",
        .start_year = std.math.minInt(i32),
        .end_year = 0,
        .gregorian_start_year = std.math.minInt(i32),
        .gregorian_start_month = 1,
        .gregorian_start_day = 1,
    },
    Era{
        .id = "ad",
        .abbr = "AD",
        .name = "Anno Domini",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 1,
        .gregorian_start_month = 1,
        .gregorian_start_day = 1,
    },
};

/// Days per month (non-leap year)
const DAYS_PER_MONTH = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

/// Check if a year is a leap year
pub fn isLeapYear(year: i32) bool {
    if (@mod(year, 400) == 0) return true;
    if (@mod(year, 100) == 0) return false;
    if (@mod(year, 4) == 0) return true;
    return false;
}

/// Get the number of days in a month
pub fn daysInMonth(year: i32, month: u8) u8 {
    if (month < 1 or month > 12) return 0;
    if (month == 2 and isLeapYear(year)) return 29;
    return DAYS_PER_MONTH[month - 1];
}

/// Get the number of days in a year
pub fn daysInYear(year: i32) u16 {
    return if (isLeapYear(year)) 366 else 365;
}

/// Convert Gregorian date to Julian Day Number
///
/// Uses a simplified algorithm that handles proleptic Gregorian calendar.
/// JDN = 367*Y - INT(7*(Y+INT((M+9)/12))/4) - INT(3*(INT((Y+(M-9)/7)/100)+1)/4) + INT(275*M/9) + D + 1721029
pub fn toJulianDay(date: CalendarDate) i64 {
    const y: i64 = date.year;
    const m: i64 = date.month;
    const d: i64 = date.day;

    // Adjust for months Jan-Feb (consider them months 13-14 of previous year)
    const a: i64 = @divFloor(14 - m, 12);
    const adjusted_y: i64 = y + 4800 - a;
    const adjusted_m: i64 = m + 12 * a - 3;

    // Calculate Julian Day Number for Gregorian calendar
    const jdn: i64 = d +
        @divFloor(153 * adjusted_m + 2, 5) +
        365 * adjusted_y +
        @divFloor(adjusted_y, 4) -
        @divFloor(adjusted_y, 100) +
        @divFloor(adjusted_y, 400) -
        32045;

    return jdn;
}

/// Convert Julian Day Number to Gregorian date
///
/// Uses a simplified algorithm for proleptic Gregorian calendar.
pub fn fromJulianDay(jd: i64) CalendarDate {
    // Algorithm from the Gregorian calendar article
    const a: i64 = jd + 32044;
    const b: i64 = @divFloor(4 * a + 3, 146097);
    const c: i64 = a - @divFloor(146097 * b, 4);

    const d_val: i64 = @divFloor(4 * c + 3, 1461);
    const e: i64 = c - @divFloor(1461 * d_val, 4);
    const m: i64 = @divFloor(5 * e + 2, 153);

    const day: u8 = @intCast(e - @divFloor(153 * m + 2, 5) + 1);
    const month: u8 = @intCast(m + 3 - 12 * @divFloor(m, 10));
    const year: i32 = @intCast(100 * b + d_val - 4800 + @divFloor(m, 10));

    return CalendarDate{
        .year = year,
        .month = month,
        .day = day,
        .era = if (year < 1) 0 else 1, // BC = 0, AD = 1
    };
}

/// Get day of week (0 = Sunday, 6 = Saturday)
pub fn dayOfWeek(date: CalendarDate) u8 {
    const jd = toJulianDay(date);
    // JDN 0 was Monday, adjust to make Sunday = 0
    return @intCast(@mod(jd + 1, 7));
}

/// Get day of year (1-366)
pub fn dayOfYear(date: CalendarDate) u16 {
    var day: u16 = date.day;
    var m: u8 = 1;
    while (m < date.month) : (m += 1) {
        day += daysInMonth(date.year, m);
    }
    return day;
}

/// Get ISO week number (1-53)
pub fn isoWeekNumber(date: CalendarDate) u8 {
    const doy = dayOfYear(date);
    const dow = dayOfWeek(date);
    const iso_dow: u8 = if (dow == 0) 7 else dow;

    // Calculate week number
    const week: i32 = @divFloor(@as(i32, doy) - @as(i32, iso_dow) + 10, 7);

    if (week < 1) {
        // Last week of previous year
        const prev_year_end = CalendarDate.init(date.year - 1, 12, 31);
        return isoWeekNumber(prev_year_end);
    } else if (week > 52) {
        // Check if week 53 or week 1 of next year
        const dec31 = CalendarDate.init(date.year, 12, 31);
        const dec31_dow = dayOfWeek(dec31);
        const iso_dec31_dow: u8 = if (dec31_dow == 0) 7 else dec31_dow;
        if (iso_dec31_dow < 4) {
            return 1; // Week 1 of next year
        }
        return @intCast(week);
    }

    return @intCast(week);
}

// ============================================================================
// Tests
// ============================================================================

test "gregorian - leap year" {
    try std.testing.expect(isLeapYear(2000)); // Divisible by 400
    try std.testing.expect(!isLeapYear(1900)); // Divisible by 100 but not 400
    try std.testing.expect(isLeapYear(2004)); // Divisible by 4
    try std.testing.expect(!isLeapYear(2001)); // Not divisible by 4
    try std.testing.expect(isLeapYear(2024)); // Current leap year
}

test "gregorian - days in month" {
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(2024, 1)); // January
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(2024, 2)); // Feb leap
    try std.testing.expectEqual(@as(u8, 28), daysInMonth(2023, 2)); // Feb non-leap
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(2024, 4)); // April
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(2024, 12)); // December
}

test "gregorian - julian day conversion" {
    // Unix epoch: 1970-01-01 = JD 2440588
    const epoch = CalendarDate.init(1970, 1, 1);
    try std.testing.expectEqual(@as(i64, 2440588), toJulianDay(epoch));

    // J2000.0: 2000-01-01 12:00:00 TT = JD 2451545
    // (We use noon, but our function gives start of day, so JD 2451545)
    const j2000 = CalendarDate.init(2000, 1, 1);
    try std.testing.expectEqual(@as(i64, 2451545), toJulianDay(j2000));

    // Test round-trip
    const dates = [_]CalendarDate{
        CalendarDate.init(2024, 12, 13),
        CalendarDate.init(1, 1, 1),
        CalendarDate.init(1582, 10, 15),
        CalendarDate.init(-44, 3, 15), // Ides of March, 44 BC
    };

    for (dates) |date| {
        const jd = toJulianDay(date);
        const result = fromJulianDay(jd);
        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}

test "gregorian - day of week" {
    // 2024-12-13 is Friday (5)
    try std.testing.expectEqual(@as(u8, 5), dayOfWeek(CalendarDate.init(2024, 12, 13)));

    // 1970-01-01 was Thursday (4)
    try std.testing.expectEqual(@as(u8, 4), dayOfWeek(CalendarDate.init(1970, 1, 1)));

    // 2000-01-01 was Saturday (6)
    try std.testing.expectEqual(@as(u8, 6), dayOfWeek(CalendarDate.init(2000, 1, 1)));
}

test "gregorian - day of year" {
    try std.testing.expectEqual(@as(u16, 1), dayOfYear(CalendarDate.init(2024, 1, 1)));
    try std.testing.expectEqual(@as(u16, 366), dayOfYear(CalendarDate.init(2024, 12, 31))); // Leap year
    try std.testing.expectEqual(@as(u16, 365), dayOfYear(CalendarDate.init(2023, 12, 31))); // Non-leap
}

test "gregorian - iso week number" {
    // 2024-01-01 is Monday, week 1
    try std.testing.expectEqual(@as(u8, 1), isoWeekNumber(CalendarDate.init(2024, 1, 1)));

    // 2023-01-01 is Sunday, week 52 of 2022
    try std.testing.expectEqual(@as(u8, 52), isoWeekNumber(CalendarDate.init(2023, 1, 1)));
}
