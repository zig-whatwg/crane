//! Persian (Solar Hijri) Calendar Implementation
//!
//! The Persian calendar (also known as Solar Hijri or Iranian calendar)
//! is a solar calendar used in Iran and Afghanistan.
//!
//! ## Structure
//!
//! - 12 months
//! - First 6 months: 31 days
//! - Next 5 months: 30 days
//! - Last month: 29 days (30 in leap years)
//!
//! ## Months
//!
//! 1. Farvardin (31 days) - Spring
//! 2. Ordibehesht (31 days)
//! 3. Khordad (31 days)
//! 4. Tir (31 days) - Summer
//! 5. Mordad (31 days)
//! 6. Shahrivar (31 days)
//! 7. Mehr (30 days) - Autumn
//! 8. Aban (30 days)
//! 9. Azar (30 days)
//! 10. Dey (30 days) - Winter
//! 11. Bahman (30 days)
//! 12. Esfand (29/30 days)
//!
//! ## Epoch
//!
//! The Persian calendar epoch is the vernal equinox of 622 CE,
//! the year of the Hijra. Year 1 began March 22, 622 CE (Julian).

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;

/// Persian calendar era
pub const ERAS = [_]Era{
    Era{
        .id = "ap",
        .abbr = "AP",
        .name = "Anno Persico",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 622,
        .gregorian_start_month = 3,
        .gregorian_start_day = 22,
    },
};

/// Julian Day Number of Persian epoch (March 22, 622 CE Julian)
const PERSIAN_EPOCH: i64 = 1948321;

/// Days per month
const DAYS_PER_MONTH = [_]u8{ 31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29 };

/// 2820-year cycle constants for Persian calendar
/// The Persian calendar uses a complex 2820-year cycle
const CYCLE_LENGTH: i64 = 2820;
const CYCLE_DAYS: i64 = 1029983; // Days in 2820 years

/// Check if a Persian year is a leap year
///
/// Uses the 2820-year cycle algorithm:
/// Leap years follow a pattern based on the year's position in the cycle.
pub fn isLeapYear(year: i32) bool {
    // Simplified algorithm using 33-year sub-cycles
    // Leap years occur in years 1, 5, 9, 13, 17, 22, 26, 30 of each 33-year cycle
    // (with some adjustments at cycle boundaries)

    // Get position in 2820-year cycle
    const cycle_pos = @mod(year - 474, 2820);

    // 2820 = 2137 + 683 leap years
    // Each 33-year sub-cycle has 8 leap years at positions:
    // 0, 4, 8, 12, 16, 20, 24, 28 (offset from start of sub-cycle)

    // Check using modular arithmetic
    const sub_cycle_pos = @mod(cycle_pos, 33);

    // Leap years at positions 1, 5, 9, 13, 17, 22, 26, 30 in 33-year sub-cycle
    // Or equivalently: (8*pos + 29) mod 33 < 8
    const test_val = @mod((8 * sub_cycle_pos + 29), 33);
    return test_val < 8;
}

/// Get days in a month
pub fn daysInMonth(year: i32, month: u8) u8 {
    if (month < 1 or month > 12) return 0;
    if (month == 12 and isLeapYear(year)) return 30;
    return DAYS_PER_MONTH[month - 1];
}

/// Get days in a year
pub fn daysInYear(year: i32) u16 {
    return if (isLeapYear(year)) 366 else 365;
}

/// Convert Persian date to Julian Day Number
pub fn toJulianDay(date: CalendarDate) i64 {
    const y: i64 = date.year;
    const m: i64 = date.month;
    const d: i64 = date.day;

    // Days from complete years
    // Using simplified algorithm for 33-year cycles
    const cycles_33 = @divFloor(y - 474, 33);
    const year_in_cycle = @mod(y - 474, 33);

    // Each 33-year cycle has 12053 days
    var days: i64 = cycles_33 * 12053;

    // Add days for complete years in current cycle
    // Each year contributes 365 or 366 days
    var year_days: i64 = 0;
    var i: i64 = 0;
    while (i < year_in_cycle) : (i += 1) {
        const test_year: i32 = @intCast(474 + cycles_33 * 33 + i);
        year_days += if (isLeapYear(test_year)) 366 else 365;
    }
    days += year_days;

    // Days from complete months
    if (m <= 7) {
        days += 31 * (m - 1);
    } else {
        days += 186 + 30 * (m - 7);
    }

    // Add day of month
    days += d;

    // Add epoch offset
    return PERSIAN_EPOCH + days - 1;
}

/// Convert Julian Day Number to Persian date
pub fn fromJulianDay(jd: i64) CalendarDate {
    // Days since epoch
    var days = jd - PERSIAN_EPOCH + 1;

    // Calculate 33-year cycles
    const cycles_33 = @divFloor(days, 12053);
    days = @mod(days, 12053);

    // Find year within cycle
    var year: i32 = @intCast(474 + cycles_33 * 33);
    while (days > daysInYear(year)) {
        days -= daysInYear(year);
        year += 1;
    }

    // Find month
    var month: u8 = 1;
    while (month <= 12) : (month += 1) {
        const month_days = daysInMonth(year, month);
        if (days <= month_days) break;
        days -= month_days;
    }

    return CalendarDate{
        .year = year,
        .month = month,
        .day = @intCast(days),
        .era = 0,
    };
}

/// Month names (Persian/Farsi)
pub const MONTH_NAMES = [_][]const u8{
    "Farvardin",
    "Ordibehesht",
    "Khordad",
    "Tir",
    "Mordad",
    "Shahrivar",
    "Mehr",
    "Aban",
    "Azar",
    "Dey",
    "Bahman",
    "Esfand",
};

/// Month names (abbreviated)
pub const MONTH_NAMES_ABBR = [_][]const u8{
    "Far.",
    "Ord.",
    "Kho.",
    "Tir",
    "Mor.",
    "Sha.",
    "Meh.",
    "Aba.",
    "Aza.",
    "Dey",
    "Bah.",
    "Esf.",
};

// ============================================================================
// Tests
// ============================================================================

test "persian - leap year detection" {
    // Some known leap years
    try std.testing.expect(isLeapYear(1403)); // 2024-2025 CE is leap
    try std.testing.expect(!isLeapYear(1402)); // 2023-2024 CE is not leap
    try std.testing.expect(isLeapYear(1399)); // 2020-2021 CE is leap
}

test "persian - days in month" {
    // First 6 months have 31 days
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(1403, 1));
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(1403, 6));

    // Months 7-11 have 30 days
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1403, 7));
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1403, 11));

    // Esfand in non-leap year
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(1402, 12));

    // Esfand in leap year
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1403, 12));
}

test "persian - julian day round-trip" {
    const test_dates = [_]CalendarDate{
        CalendarDate.init(1403, 9, 23), // ~Dec 13, 2024
        CalendarDate.init(1403, 1, 1), // ~Mar 20, 2024 (Nowruz)
        CalendarDate.init(1400, 12, 29), // End of non-leap year
        CalendarDate.init(1399, 12, 30), // End of leap year
    };

    for (test_dates) |date| {
        const jd = toJulianDay(date);
        const result = fromJulianDay(jd);

        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}
