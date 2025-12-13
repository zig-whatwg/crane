//! Republic of China (Minguo) Calendar Implementation
//!
//! The ROC calendar is used in Taiwan. It is identical to the Gregorian
//! calendar but with years counted from the founding of the Republic of
//! China in 1912.
//!
//! ## Year Offset
//!
//! ROC year = Gregorian year - 1911
//! Example: 2024 CE = ROC 113
//!
//! Year 1 of the ROC calendar began on January 1, 1912.

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;
const gregorian = @import("gregorian.zig");

/// ROC calendar eras
pub const ERAS = [_]Era{
    // Before ROC (pre-1912)
    Era{
        .id = "before_roc",
        .abbr = "Before R.O.C.",
        .name = "Before R.O.C.",
        .start_year = std.math.minInt(i32),
        .end_year = 0,
        .gregorian_start_year = std.math.minInt(i32),
        .gregorian_start_month = 1,
        .gregorian_start_day = 1,
    },
    // ROC era (1912 onwards)
    Era{
        .id = "minguo",
        .abbr = "民國",
        .name = "民國",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 1912,
        .gregorian_start_month = 1,
        .gregorian_start_day = 1,
    },
};

/// ROC year offset from Gregorian
pub const YEAR_OFFSET: i32 = 1911;

/// Check if an ROC year is a leap year
pub fn isLeapYear(year: i32) bool {
    return gregorian.isLeapYear(year + YEAR_OFFSET);
}

/// Get days in month for ROC calendar
pub fn daysInMonth(year: i32, month: u8) u8 {
    return gregorian.daysInMonth(year + YEAR_OFFSET, month);
}

/// Convert ROC date to Julian Day Number
pub fn toJulianDay(date: CalendarDate) i64 {
    const gregorian_date = CalendarDate{
        .year = date.year + YEAR_OFFSET,
        .month = date.month,
        .day = date.day,
        .era = null,
    };
    return gregorian.toJulianDay(gregorian_date);
}

/// Convert Julian Day Number to ROC date
pub fn fromJulianDay(jd: i64) CalendarDate {
    const greg = gregorian.fromJulianDay(jd);
    const roc_year = greg.year - YEAR_OFFSET;
    return CalendarDate{
        .year = roc_year,
        .month = greg.month,
        .day = greg.day,
        .era = if (roc_year < 1) 0 else 1,
    };
}

/// Convert Gregorian date to ROC date
pub fn fromGregorian(date: CalendarDate) CalendarDate {
    const roc_year = date.year - YEAR_OFFSET;
    return CalendarDate{
        .year = roc_year,
        .month = date.month,
        .day = date.day,
        .era = if (roc_year < 1) 0 else 1,
    };
}

/// Convert ROC date to Gregorian date
pub fn toGregorian(date: CalendarDate) CalendarDate {
    return CalendarDate{
        .year = date.year + YEAR_OFFSET,
        .month = date.month,
        .day = date.day,
        .era = 1, // AD era
    };
}

// ============================================================================
// Tests
// ============================================================================

test "roc - year conversion" {
    // 2024 CE = ROC 113
    const gregorian_date = CalendarDate.init(2024, 1, 1);
    const roc_date = fromGregorian(gregorian_date);

    try std.testing.expectEqual(@as(i32, 113), roc_date.year);
    try std.testing.expectEqual(@as(u8, 1), roc_date.month);
    try std.testing.expectEqual(@as(u8, 1), roc_date.day);
    try std.testing.expectEqual(@as(u8, 1), roc_date.era.?); // Minguo era

    // Round-trip
    const back = toGregorian(roc_date);
    try std.testing.expectEqual(@as(i32, 2024), back.year);
}

test "roc - before roc era" {
    // 1911 CE = ROC 0 (before ROC)
    const gregorian_date = CalendarDate.init(1911, 12, 31);
    const roc_date = fromGregorian(gregorian_date);

    try std.testing.expectEqual(@as(i32, 0), roc_date.year);
    try std.testing.expectEqual(@as(u8, 0), roc_date.era.?); // Before ROC era
}

test "roc - julian day round-trip" {
    const dates = [_]CalendarDate{
        CalendarDate.init(113, 1, 1), // 2024 CE
        CalendarDate.init(1, 1, 1), // 1912 CE (ROC founding)
        CalendarDate.init(100, 12, 31), // 2011 CE
    };

    for (dates) |date| {
        const jd = toJulianDay(date);
        const result = fromJulianDay(jd);
        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}

test "roc - leap year" {
    // ROC 113 = 2024 CE (leap year)
    try std.testing.expect(isLeapYear(113));
    // ROC 112 = 2023 CE (not leap year)
    try std.testing.expect(!isLeapYear(112));
}

test "roc - days in month" {
    // February in leap year (ROC 113 = 2024 CE)
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(113, 2));
    // February in non-leap year (ROC 112 = 2023 CE)
    try std.testing.expectEqual(@as(u8, 28), daysInMonth(112, 2));
}
