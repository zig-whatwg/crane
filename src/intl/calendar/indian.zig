//! Indian National Calendar Implementation
//!
//! The Indian National Calendar (Saka calendar) is the official civil
//! calendar of India, adopted in 1957. It is based on the Saka era.
//!
//! ## Structure
//!
//! - 12 months
//! - Month 1: 30 days (31 in leap years)
//! - Months 2-6: 31 days
//! - Months 7-12: 30 days
//!
//! ## Months
//!
//! 1. Chaitra (30/31 days)
//! 2. Vaishakha (31 days)
//! 3. Jyeshtha (31 days)
//! 4. Ashadha (31 days)
//! 5. Shravana (31 days)
//! 6. Bhadra (31 days)
//! 7. Ashwin (30 days)
//! 8. Kartika (30 days)
//! 9. Agrahayana (30 days)
//! 10. Pausha (30 days)
//! 11. Magha (30 days)
//! 12. Phalguna (30 days)
//!
//! ## Epoch
//!
//! The Saka era began in 78 CE. Day 1 of the Indian National Calendar
//! corresponds to March 22 (March 21 in leap years) of the Gregorian calendar.
//!
//! Indian year = Gregorian year - 78 (approximately)

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;
const gregorian = @import("gregorian.zig");

/// Indian National calendar era
pub const ERAS = [_]Era{
    Era{
        .id = "saka",
        .abbr = "Saka",
        .name = "Saka Era",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 79,
        .gregorian_start_month = 3,
        .gregorian_start_day = 22,
    },
};

/// Saka year offset from Gregorian
pub const YEAR_OFFSET: i32 = 78;

/// Days per month for non-leap year
const DAYS_PER_MONTH = [_]u8{ 30, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30 };

/// Days per month for leap year (Chaitra has 31 days)
const DAYS_PER_MONTH_LEAP = [_]u8{ 31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30 };

/// Check if an Indian year is a leap year
/// Indian calendar leap years follow Gregorian leap year rules
/// Year Y in Indian calendar corresponds to Gregorian year Y + 78 or Y + 79
pub fn isLeapYear(year: i32) bool {
    // The Indian year starting in March corresponds to Gregorian year + 78
    return gregorian.isLeapYear(year + YEAR_OFFSET);
}

/// Get days in a month
pub fn daysInMonth(year: i32, month: u8) u8 {
    if (month < 1 or month > 12) return 0;
    if (isLeapYear(year)) {
        return DAYS_PER_MONTH_LEAP[month - 1];
    }
    return DAYS_PER_MONTH[month - 1];
}

/// Get days in a year
pub fn daysInYear(year: i32) u16 {
    return if (isLeapYear(year)) 366 else 365;
}

/// Convert Indian date to Julian Day Number
pub fn toJulianDay(date: CalendarDate) i64 {
    // Start of Indian year in Gregorian calendar
    // Chaitra 1 = March 22 (non-leap) or March 21 (leap) of Gregorian year
    const gregorian_year = date.year + YEAR_OFFSET;
    const leap = gregorian.isLeapYear(gregorian_year);

    // Calculate days from start of Gregorian year to Chaitra 1
    const chaitra_1_gregorian_day: u8 = if (leap) 21 else 22;

    // Start with JD of March 22 (or 21) of corresponding Gregorian year
    var jd = gregorian.toJulianDay(CalendarDate.init(gregorian_year, 3, chaitra_1_gregorian_day));

    // Add days from complete months
    var m: u8 = 1;
    while (m < date.month) : (m += 1) {
        jd += daysInMonth(date.year, m);
    }

    // Add days in current month (subtract 1 because day is 1-indexed)
    jd += date.day - 1;

    return jd;
}

/// Convert Julian Day Number to Indian date
pub fn fromJulianDay(jd: i64) CalendarDate {
    // Get Gregorian date
    const greg = gregorian.fromJulianDay(jd);

    // Determine Indian year
    // If before March 22 (or 21 in leap years), it's previous Indian year
    var indian_year = greg.year - YEAR_OFFSET;
    const leap = gregorian.isLeapYear(greg.year);
    const chaitra_1_day: u8 = if (leap) 21 else 22;

    // Check if date is before Chaitra 1 of this Gregorian year
    if (greg.month < 3 or (greg.month == 3 and greg.day < chaitra_1_day)) {
        indian_year -= 1;
    }

    // Calculate JD of Chaitra 1 of this Indian year
    const indian_year_gregorian = indian_year + YEAR_OFFSET;
    const indian_year_leap = gregorian.isLeapYear(indian_year_gregorian);
    const chaitra_1_gregorian_day: u8 = if (indian_year_leap) 21 else 22;
    const chaitra_1_jd = gregorian.toJulianDay(CalendarDate.init(indian_year_gregorian, 3, chaitra_1_gregorian_day));

    // Days since start of Indian year
    var days_since_chaitra_1 = jd - chaitra_1_jd + 1;

    // Find month and day
    var month: u8 = 1;
    while (month <= 12) : (month += 1) {
        const month_days = daysInMonth(indian_year, month);
        if (days_since_chaitra_1 <= month_days) break;
        days_since_chaitra_1 -= month_days;
    }

    return CalendarDate{
        .year = indian_year,
        .month = month,
        .day = @intCast(days_since_chaitra_1),
        .era = 0,
    };
}

/// Month names (Sanskrit/Hindi)
pub const MONTH_NAMES = [_][]const u8{
    "Chaitra",
    "Vaishakha",
    "Jyeshtha",
    "Ashadha",
    "Shravana",
    "Bhadra",
    "Ashwin",
    "Kartika",
    "Agrahayana",
    "Pausha",
    "Magha",
    "Phalguna",
};

/// Month names (abbreviated)
pub const MONTH_NAMES_ABBR = [_][]const u8{
    "Chai.",
    "Vai.",
    "Jye.",
    "Ash.",
    "Shr.",
    "Bha.",
    "Ash.",
    "Kar.",
    "Agr.",
    "Pau.",
    "Mag.",
    "Pha.",
};

// ============================================================================
// Tests
// ============================================================================

test "indian - leap year detection" {
    // Indian year 1946 = Gregorian 2024 (leap year)
    try std.testing.expect(isLeapYear(1946));
    // Indian year 1945 = Gregorian 2023 (not leap year)
    try std.testing.expect(!isLeapYear(1945));
}

test "indian - days in month" {
    // Chaitra in non-leap year
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1945, 1));
    // Chaitra in leap year
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(1946, 1));

    // Months 2-6 always have 31 days
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(1946, 2));
    try std.testing.expectEqual(@as(u8, 31), daysInMonth(1946, 6));

    // Months 7-12 always have 30 days
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1946, 7));
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1946, 12));
}

test "indian - julian day round-trip" {
    const test_dates = [_]CalendarDate{
        CalendarDate.init(1946, 9, 22), // ~Dec 13, 2024
        CalendarDate.init(1946, 1, 1), // ~Mar 21, 2024 (Chaitra 1, leap year)
        CalendarDate.init(1945, 1, 1), // ~Mar 22, 2023 (Chaitra 1, non-leap)
        CalendarDate.init(1946, 12, 30), // End of year
    };

    for (test_dates) |date| {
        const jd = toJulianDay(date);
        const result = fromJulianDay(jd);

        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}
