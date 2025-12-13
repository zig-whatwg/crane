//! Buddhist Calendar Implementation
//!
//! The Buddhist calendar (Thai Buddhist calendar) is primarily used in
//! Thailand, Cambodia, Laos, and Myanmar. It is simply the Gregorian
//! calendar with years offset by 543.
//!
//! ## Year Offset
//!
//! Buddhist Era (BE) = Gregorian year + 543
//! Example: 2024 CE = 2567 BE
//!
//! The epoch is traditionally the year of Buddha's death (parinibbana),
//! which occurred in 543 BCE according to Thai tradition.

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;
const gregorian = @import("gregorian.zig");

/// Buddhist calendar era
pub const ERAS = [_]Era{
    Era{
        .id = "be",
        .abbr = "BE",
        .name = "Buddhist Era",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = -543,
        .gregorian_start_month = 1,
        .gregorian_start_day = 1,
    },
};

/// Buddhist year offset from Gregorian
pub const YEAR_OFFSET: i32 = 543;

/// Check if a Buddhist year is a leap year
pub fn isLeapYear(year: i32) bool {
    return gregorian.isLeapYear(year - YEAR_OFFSET);
}

/// Get days in month for Buddhist calendar
pub fn daysInMonth(year: i32, month: u8) u8 {
    return gregorian.daysInMonth(year - YEAR_OFFSET, month);
}

/// Convert Buddhist date to Julian Day Number
pub fn toJulianDay(date: CalendarDate) i64 {
    const gregorian_date = CalendarDate{
        .year = date.year - YEAR_OFFSET,
        .month = date.month,
        .day = date.day,
        .era = null,
    };
    return gregorian.toJulianDay(gregorian_date);
}

/// Convert Julian Day Number to Buddhist date
pub fn fromJulianDay(jd: i64) CalendarDate {
    const greg = gregorian.fromJulianDay(jd);
    return CalendarDate{
        .year = greg.year + YEAR_OFFSET,
        .month = greg.month,
        .day = greg.day,
        .era = 0, // BE era
    };
}

/// Convert Gregorian date to Buddhist date
pub fn fromGregorian(date: CalendarDate) CalendarDate {
    return CalendarDate{
        .year = date.year + YEAR_OFFSET,
        .month = date.month,
        .day = date.day,
        .era = 0,
    };
}

/// Convert Buddhist date to Gregorian date
pub fn toGregorian(date: CalendarDate) CalendarDate {
    return CalendarDate{
        .year = date.year - YEAR_OFFSET,
        .month = date.month,
        .day = date.day,
        .era = if (date.year - YEAR_OFFSET < 1) 0 else 1,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "buddhist - year conversion" {
    // 2024 CE = 2567 BE
    const gregorian_date = CalendarDate.init(2024, 1, 1);
    const buddhist_date = fromGregorian(gregorian_date);

    try std.testing.expectEqual(@as(i32, 2567), buddhist_date.year);
    try std.testing.expectEqual(@as(u8, 1), buddhist_date.month);
    try std.testing.expectEqual(@as(u8, 1), buddhist_date.day);

    // Round-trip
    const back = toGregorian(buddhist_date);
    try std.testing.expectEqual(@as(i32, 2024), back.year);
}

test "buddhist - julian day round-trip" {
    const dates = [_]CalendarDate{
        CalendarDate.init(2567, 1, 1), // 2024 CE
        CalendarDate.init(2500, 5, 15), // 1957 CE
        CalendarDate.init(2550, 12, 31), // 2007 CE
    };

    for (dates) |date| {
        const jd = toJulianDay(date);
        const result = fromJulianDay(jd);
        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}

test "buddhist - leap year" {
    // 2567 BE = 2024 CE (leap year)
    try std.testing.expect(isLeapYear(2567));
    // 2566 BE = 2023 CE (not leap year)
    try std.testing.expect(!isLeapYear(2566));
}

test "buddhist - days in month" {
    // February in leap year (2567 BE = 2024 CE)
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(2567, 2));
    // February in non-leap year (2566 BE = 2023 CE)
    try std.testing.expectEqual(@as(u8, 28), daysInMonth(2566, 2));
}
