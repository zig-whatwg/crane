//! Islamic (Hijri) Calendar Implementation
//!
//! The Islamic calendar is a lunar calendar with 12 months of 29-30 days.
//! Multiple variants exist:
//!
//! ## Variants
//!
//! - `islamic` - Astronomical/observational (algorithmic approximation)
//! - `islamic-civil` - Civil/tabular calendar (Thursday epoch)
//! - `islamic-tbla` - Tabular calendar (Thursday epoch, alternate)
//! - `islamic-umalqura` - Umm al-Qura (Saudi Arabia official calendar)
//!
//! ## Epoch
//!
//! The Islamic calendar epoch is the Hijra (migration of Prophet Muhammad
//! from Mecca to Medina): July 16, 622 CE (Julian) = 1 Muharram 1 AH.
//!
//! ## Months
//!
//! 1. Muharram (30 days)
//! 2. Safar (29 days)
//! 3. Rabi' al-Awwal (30 days)
//! 4. Rabi' al-Thani (29 days)
//! 5. Jumada al-Awwal (30 days)
//! 6. Jumada al-Thani (29 days)
//! 7. Rajab (30 days)
//! 8. Sha'ban (29 days)
//! 9. Ramadan (30 days)
//! 10. Shawwal (29 days)
//! 11. Dhu al-Qa'dah (30 days)
//! 12. Dhu al-Hijjah (29/30 days - 30 in leap years)

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const CalendarType = @import("types.zig").CalendarType;
const Era = @import("types.zig").Era;

/// Islamic calendar era
pub const ERAS = [_]Era{
    Era{
        .id = "ah",
        .abbr = "AH",
        .name = "Anno Hegirae",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 622,
        .gregorian_start_month = 7,
        .gregorian_start_day = 16,
    },
};

/// Julian Day Number of Islamic epoch (July 16, 622 CE Julian)
const ISLAMIC_EPOCH: i64 = 1948440;

/// Days per month in non-leap year
const DAYS_PER_MONTH = [_]u8{ 30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29 };

/// Leap year pattern in 30-year cycle (civil calendar)
/// Years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 are leap years
const LEAP_YEARS_IN_CYCLE = [_]u8{ 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 };

/// Check if a year is a leap year
pub fn isLeapYear(year: i32, calendar_type: CalendarType) bool {
    _ = calendar_type; // All variants use same leap year rule for now
    const year_in_cycle = @mod(year, 30);
    for (LEAP_YEARS_IN_CYCLE) |leap_year| {
        if (year_in_cycle == leap_year) return true;
    }
    return false;
}

/// Get days in a month
pub fn daysInMonth(year: i32, month: u8, calendar_type: CalendarType) u8 {
    if (month < 1 or month > 12) return 0;
    if (month == 12 and isLeapYear(year, calendar_type)) return 30;
    return DAYS_PER_MONTH[month - 1];
}

/// Get days in a year
pub fn daysInYear(year: i32, calendar_type: CalendarType) u16 {
    return if (isLeapYear(year, calendar_type)) 355 else 354;
}

/// Convert Islamic date to Julian Day Number (civil/tabular variant)
pub fn toJulianDay(date: CalendarDate, calendar_type: CalendarType) i64 {
    _ = calendar_type; // Using civil calendar algorithm

    const y: i64 = date.year;
    const m: i64 = date.month;
    const d: i64 = date.day;

    // Number of complete 30-year cycles
    const cycles = @divFloor(y - 1, 30);
    const year_in_cycle = @mod(y - 1, 30);

    // Days from complete cycles (30 years = 10631 days)
    var days: i64 = cycles * 10631;

    // Days from complete years in current cycle
    days += year_in_cycle * 354;

    // Add leap days for years in current cycle
    var leap_days: i64 = 0;
    for (LEAP_YEARS_IN_CYCLE) |ly| {
        if (ly <= year_in_cycle) {
            leap_days += 1;
        }
    }
    days += leap_days;

    // Days from complete months
    // Sum: 30+29+30+29+... = 29*m + floor(m/2) for months 1..m-1
    days += 29 * (m - 1) + @divFloor(m, 2);

    // Add day of month
    days += d;

    return ISLAMIC_EPOCH + days - 1;
}

/// Convert Julian Day Number to Islamic date (civil/tabular variant)
pub fn fromJulianDay(jd: i64, calendar_type: CalendarType) CalendarDate {
    _ = calendar_type; // Using civil calendar algorithm

    // Days since epoch
    const days = jd - ISLAMIC_EPOCH + 1;

    // Calculate 30-year cycle
    const cycles = @divFloor(days, 10631);
    var remaining_days = @mod(days, 10631);

    // Year within cycle
    var year: i64 = cycles * 30;

    // Find year within cycle
    var y: i64 = 1;
    while (y <= 30) : (y += 1) {
        const year_days: i64 = if (isLeapYear(@intCast(y), .islamic_civil)) 355 else 354;
        if (remaining_days <= year_days) break;
        remaining_days -= year_days;
        year += 1;
    }

    // Calculate month
    var month: u8 = 1;
    while (month <= 12) : (month += 1) {
        const month_days = daysInMonth(@intCast(year + 1), month, .islamic_civil);
        if (remaining_days <= month_days) break;
        remaining_days -= month_days;
    }

    return CalendarDate{
        .year = @intCast(year + 1),
        .month = month,
        .day = @intCast(remaining_days),
        .era = 0,
    };
}

/// Month names (Arabic)
pub const MONTH_NAMES = [_][]const u8{
    "Muharram",
    "Safar",
    "Rabiʻ al-Awwal",
    "Rabiʻ al-Thani",
    "Jumada al-Awwal",
    "Jumada al-Thani",
    "Rajab",
    "Shaʻban",
    "Ramadan",
    "Shawwal",
    "Dhu al-Qaʻdah",
    "Dhu al-Hijjah",
};

/// Month names (abbreviated)
pub const MONTH_NAMES_ABBR = [_][]const u8{
    "Muh.",
    "Saf.",
    "Rab. I",
    "Rab. II",
    "Jum. I",
    "Jum. II",
    "Raj.",
    "Sha.",
    "Ram.",
    "Shaw.",
    "Dhuʻl-Q.",
    "Dhuʻl-H.",
};

// ============================================================================
// Tests
// ============================================================================

test "islamic - leap year detection" {
    // Year 2 in any 30-year cycle is a leap year
    try std.testing.expect(isLeapYear(2, .islamic_civil));
    try std.testing.expect(isLeapYear(32, .islamic_civil)); // 2 + 30

    // Year 5 is a leap year
    try std.testing.expect(isLeapYear(5, .islamic_civil));

    // Year 1 is not a leap year
    try std.testing.expect(!isLeapYear(1, .islamic_civil));
    try std.testing.expect(!isLeapYear(3, .islamic_civil));
}

test "islamic - days in month" {
    // Regular months
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1445, 1, .islamic_civil)); // Muharram
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(1445, 2, .islamic_civil)); // Safar
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1445, 9, .islamic_civil)); // Ramadan

    // 1445 mod 30 = 5, which IS in the leap year list (2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29)
    // 1446 mod 30 = 6, which is NOT in the leap year list
    try std.testing.expect(isLeapYear(1445, .islamic_civil));
    try std.testing.expect(!isLeapYear(1446, .islamic_civil));

    // Dhu al-Hijjah in leap year (1445)
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1445, 12, .islamic_civil));

    // Dhu al-Hijjah in non-leap year (1446)
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(1446, 12, .islamic_civil));
}

test "islamic - julian day round-trip" {
    const test_dates = [_]CalendarDate{
        CalendarDate.init(1445, 6, 1), // ~Dec 2023
        CalendarDate.init(1446, 1, 1), // ~Jul 2024
        CalendarDate.init(1, 1, 1), // Epoch
        CalendarDate.init(1400, 12, 29), // End of year 1400
    };

    for (test_dates) |date| {
        const jd = toJulianDay(date, .islamic_civil);
        const result = fromJulianDay(jd, .islamic_civil);

        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}

test "islamic - known date conversions" {
    // The Islamic epoch: 1 Muharram 1 AH = July 16, 622 CE (Julian)
    // JD 1948440 (approximate, varies by calculation method)
    const epoch_date = CalendarDate.init(1, 1, 1);
    const epoch_jd = toJulianDay(epoch_date, .islamic_civil);

    // Should be close to the epoch constant
    try std.testing.expect(@abs(epoch_jd - ISLAMIC_EPOCH) <= 1);
}
