//! Ethiopian Calendar Implementation
//!
//! The Ethiopian calendar (Ge'ez calendar) is the principal calendar used
//! in Ethiopia and Eritrea. It is similar to the Coptic calendar but with
//! a different epoch.
//!
//! ## Structure
//!
//! - 13 months
//! - First 12 months: 30 days each
//! - 13th month (Pagumen): 5 days (6 in leap years)
//!
//! ## Months
//!
//! 1. Meskerem (30 days)
//! 2. Tekemt (30 days)
//! 3. Hedar (30 days)
//! 4. Tahsas (30 days)
//! 5. Ter (30 days)
//! 6. Yekatit (30 days)
//! 7. Megabit (30 days)
//! 8. Miazia (30 days)
//! 9. Genbot (30 days)
//! 10. Sene (30 days)
//! 11. Hamle (30 days)
//! 12. Nehasse (30 days)
//! 13. Pagumen (5-6 days)
//!
//! ## Epochs
//!
//! - Ethiopian Era (Anno Mundi): August 29, 8 CE (Julian)
//! - Amete Alem: Earlier epoch used in some contexts

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const CalendarType = @import("types.zig").CalendarType;
const Era = @import("types.zig").Era;

/// Ethiopian calendar eras
pub const ERAS = [_]Era{
    Era{
        .id = "incarnation",
        .abbr = "ዓ/ም",
        .name = "Amete Mihret",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 8,
        .gregorian_start_month = 8,
        .gregorian_start_day = 29,
    },
};

/// Ethiopian Amete Alem eras
pub const ERAS_AMETE_ALEM = [_]Era{
    Era{
        .id = "mundi",
        .abbr = "ዓ/ዓ",
        .name = "Amete Alem",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = -5493, // Earlier epoch
        .gregorian_start_month = 8,
        .gregorian_start_day = 29,
    },
};

/// Julian Day Number of Ethiopian epoch (August 29, 8 CE Julian)
const ETHIOPIC_EPOCH: i64 = 1724221;

/// Julian Day Number of Amete Alem epoch (August 29, 5493 BCE Julian)
const AMETE_ALEM_EPOCH: i64 = 1724221 - 5500 * 365 - 1375; // Approximate

/// Check if an Ethiopian year is a leap year
/// Leap years occur every 4 years (year mod 4 = 3 for Ethiopian)
pub fn isLeapYear(year: i32) bool {
    return @mod(year, 4) == 3;
}

/// Get days in a month
pub fn daysInMonth(year: i32, month: u8) u8 {
    if (month < 1 or month > 13) return 0;
    if (month <= 12) return 30;
    // Month 13 (Pagumen): 5 days, 6 in leap years
    return if (isLeapYear(year)) 6 else 5;
}

/// Get days in a year
pub fn daysInYear(year: i32) u16 {
    return if (isLeapYear(year)) 366 else 365;
}

/// Convert Ethiopian date to Julian Day Number
pub fn toJulianDay(date: CalendarDate, calendar_type: CalendarType) i64 {
    const epoch: i64 = if (calendar_type == .ethiopic_amete_alem) AMETE_ALEM_EPOCH else ETHIOPIC_EPOCH;

    const y: i64 = date.year;
    const m: i64 = date.month;
    const d: i64 = date.day;

    // Days from complete years before this year
    // Leap years are when year mod 4 == 3 (years 3, 7, 11, ...)
    // Count leap years in range [1, full_years] where year mod 4 == 3
    // Years 3, 7, 11, ... up to full_years
    // Formula: floor((full_years + 1) / 4) for the sequence 3, 7, 11...
    const full_years = y - 1;
    const leap_days = @divFloor(full_years + 1, 4);
    var days: i64 = full_years * 365 + leap_days;

    // Days from complete months (30 days each)
    days += (m - 1) * 30;

    // Add day of month (days is 0-indexed, d is 1-indexed, so add d-1)
    days += d - 1;

    return epoch + days;
}

/// Convert Julian Day Number to Ethiopian date
pub fn fromJulianDay(jd: i64, calendar_type: CalendarType) CalendarDate {
    const epoch: i64 = if (calendar_type == .ethiopic_amete_alem) AMETE_ALEM_EPOCH else ETHIOPIC_EPOCH;

    // Days since epoch (0-indexed from epoch)
    const days_since_epoch = jd - epoch;

    // The 4-year cycle for Ethiopian calendar (leap year at position 3):
    // Year 1: 365 days (mod 4 = 1)
    // Year 2: 365 days (mod 4 = 2)
    // Year 3: 366 days (mod 4 = 3, LEAP)
    // Year 4: 365 days (mod 4 = 0)
    // Total: 1461 days per cycle

    // Each 4-year cycle has 1461 days, starting at year 1, 5, 9, ...
    const cycles = @divFloor(days_since_epoch, 1461);
    var remaining = @mod(days_since_epoch, 1461);

    // Start of this cycle is year (cycles * 4 + 1)
    // Within cycle, days are distributed as: 365, 365, 366, 365
    var year: i32 = @intCast(cycles * 4 + 1);

    // Iterate through years in the cycle
    while (remaining >= daysInYear(year)) {
        remaining -= daysInYear(year);
        year += 1;
    }

    // Find month (first 12 months have 30 days each)
    var month: u8 = 1;
    while (month <= 12 and remaining >= 30) : (month += 1) {
        remaining -= 30;
    }

    // Day is 1-indexed
    const day: u8 = @intCast(remaining + 1);

    return CalendarDate{
        .year = year,
        .month = month,
        .day = day,
        .era = 0,
    };
}

/// Month names (Ge'ez/Amharic)
pub const MONTH_NAMES = [_][]const u8{
    "Meskerem",
    "Tekemt",
    "Hedar",
    "Tahsas",
    "Ter",
    "Yekatit",
    "Megabit",
    "Miazia",
    "Genbot",
    "Sene",
    "Hamle",
    "Nehasse",
    "Pagumen",
};

/// Month names (abbreviated)
pub const MONTH_NAMES_ABBR = [_][]const u8{
    "Mes.",
    "Tek.",
    "Hed.",
    "Tah.",
    "Ter",
    "Yek.",
    "Meg.",
    "Mia.",
    "Gen.",
    "Sen.",
    "Ham.",
    "Neh.",
    "Pag.",
};

// ============================================================================
// Tests
// ============================================================================

test "ethiopic - leap year detection" {
    // Years where year mod 4 = 3 are leap years
    try std.testing.expect(isLeapYear(3));
    try std.testing.expect(isLeapYear(7));
    try std.testing.expect(isLeapYear(2015)); // ~2022-2023 CE
    try std.testing.expect(!isLeapYear(2016));
    try std.testing.expect(!isLeapYear(2017));
}

test "ethiopic - days in month" {
    // First 12 months have 30 days
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(2017, 1));
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(2017, 12));

    // Month 13 (Pagumen) in non-leap year
    try std.testing.expectEqual(@as(u8, 5), daysInMonth(2016, 13));

    // Month 13 in leap year
    try std.testing.expectEqual(@as(u8, 6), daysInMonth(2015, 13));
}

test "ethiopic - julian day round-trip" {
    const test_dates = [_]CalendarDate{
        CalendarDate.init(2017, 4, 4), // ~Dec 13, 2024
        CalendarDate.init(2016, 1, 1), // ~Sep 11, 2023
        CalendarDate.init(1, 1, 1), // Ethiopian epoch
        CalendarDate.init(2015, 13, 6), // End of leap year
    };

    for (test_dates) |date| {
        const jd = toJulianDay(date, .ethiopic);
        const result = fromJulianDay(jd, .ethiopic);

        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}
