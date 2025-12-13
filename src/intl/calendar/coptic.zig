//! Coptic Calendar Implementation
//!
//! The Coptic calendar (also known as the Alexandrian calendar) is used
//! by the Coptic Orthodox Church and is the liturgical calendar of Egypt.
//!
//! ## Structure
//!
//! - 13 months
//! - First 12 months: 30 days each
//! - 13th month (Nasie/Epagomenal): 5 days (6 in leap years)
//!
//! ## Months
//!
//! 1. Thout (30 days)
//! 2. Paopi (30 days)
//! 3. Hathor (30 days)
//! 4. Koiak (30 days)
//! 5. Tobi (30 days)
//! 6. Meshir (30 days)
//! 7. Paremhat (30 days)
//! 8. Parmouti (30 days)
//! 9. Pashons (30 days)
//! 10. Paoni (30 days)
//! 11. Epip (30 days)
//! 12. Mesori (30 days)
//! 13. Nasie (5-6 days)
//!
//! ## Epoch
//!
//! The Coptic calendar epoch is August 29, 284 CE (Julian),
//! the year of Diocletian's accession (Era of the Martyrs).

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;

/// Coptic calendar era
pub const ERAS = [_]Era{
    Era{
        .id = "am",
        .abbr = "AM",
        .name = "Anno Martyrum",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 284,
        .gregorian_start_month = 8,
        .gregorian_start_day = 29,
    },
};

/// Julian Day Number of Coptic epoch (August 29, 284 CE Julian)
const COPTIC_EPOCH: i64 = 1825030;

/// Check if a Coptic year is a leap year
/// Leap years occur every 4 years (year mod 4 = 3 for Coptic)
pub fn isLeapYear(year: i32) bool {
    return @mod(year, 4) == 3;
}

/// Get days in a month
pub fn daysInMonth(year: i32, month: u8) u8 {
    if (month < 1 or month > 13) return 0;
    if (month <= 12) return 30;
    // Month 13 (Nasie): 5 days, 6 in leap years
    return if (isLeapYear(year)) 6 else 5;
}

/// Get days in a year
pub fn daysInYear(year: i32) u16 {
    return if (isLeapYear(year)) 366 else 365;
}

/// Convert Coptic date to Julian Day Number
pub fn toJulianDay(date: CalendarDate) i64 {
    const y: i64 = date.year;
    const m: i64 = date.month;
    const d: i64 = date.day;

    // Days from complete years before this year
    // Leap years are when year mod 4 == 3 (years 3, 7, 11, ...)
    // Number of leap years before year Y is: floor((Y - 1 + 1) / 4) = floor(Y / 4)
    // Because: years 3,7,11... up to Y-1 means we count 3,7,11,...
    // For Y=4: leap years passed = 1 (year 3)
    // For Y=5: leap years passed = 1 (year 3)
    // For Y=7: leap years passed = 1 (year 3)
    // For Y=8: leap years passed = 2 (years 3, 7)
    // Formula: floor((Y + 1) / 4) for years where mod 4 == 3
    const full_years = y - 1;
    // Count leap years in range [1, full_years] where year mod 4 == 3
    // Years 3, 7, 11, ... up to full_years
    // This is: floor((full_years + 1) / 4) for the sequence 3, 7, 11...
    const leap_days = @divFloor(full_years + 1, 4);
    var days: i64 = full_years * 365 + leap_days;

    // Days from complete months (30 days each)
    days += (m - 1) * 30;

    // Add day of month (days is 0-indexed, d is 1-indexed, so add d-1)
    days += d - 1;

    return COPTIC_EPOCH + days;
}

/// Convert Julian Day Number to Coptic date
pub fn fromJulianDay(jd: i64) CalendarDate {
    // Days since epoch (0-indexed from epoch)
    const days_since_epoch = jd - COPTIC_EPOCH;

    // The 4-year cycle for Coptic calendar (leap year at position 3):
    // Year 1: 365 days (mod 4 = 1)
    // Year 2: 365 days (mod 4 = 2)
    // Year 3: 366 days (mod 4 = 3, LEAP)
    // Year 4: 365 days (mod 4 = 0)
    // Total: 1461 days per cycle
    //
    // But the cycle boundaries are at years 1, 5, 9, 13...
    // So we need to find which cycle and position within cycle.

    // Use a direct calculation approach:
    // Total days = (y-1)*365 + floor((y+1)/4) + day_of_year - 1
    // Solving for y given total days is complex, so use iterative approach
    // but with correct cycle alignment.

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

/// Month names (Coptic)
pub const MONTH_NAMES = [_][]const u8{
    "Thout",
    "Paopi",
    "Hathor",
    "Koiak",
    "Tobi",
    "Meshir",
    "Paremhat",
    "Parmouti",
    "Pashons",
    "Paoni",
    "Epip",
    "Mesori",
    "Nasie",
};

// ============================================================================
// Tests
// ============================================================================

test "coptic - leap year detection" {
    // Years where year mod 4 = 3 are leap years
    try std.testing.expect(isLeapYear(3));
    try std.testing.expect(isLeapYear(7));
    try std.testing.expect(isLeapYear(1739)); // Corresponds to ~2022-2023 CE
    try std.testing.expect(!isLeapYear(1740));
    try std.testing.expect(!isLeapYear(1741));
}

test "coptic - days in month" {
    // First 12 months have 30 days
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1740, 1));
    try std.testing.expectEqual(@as(u8, 30), daysInMonth(1740, 12));

    // Month 13 (Nasie) in non-leap year
    try std.testing.expectEqual(@as(u8, 5), daysInMonth(1740, 13));

    // Month 13 in leap year
    try std.testing.expectEqual(@as(u8, 6), daysInMonth(1739, 13));
}

test "coptic - julian day round-trip" {
    const test_dates = [_]CalendarDate{
        CalendarDate.init(1741, 4, 4), // ~Dec 13, 2024
        CalendarDate.init(1740, 1, 1), // ~Sep 11, 2023
        CalendarDate.init(1, 1, 1), // Coptic epoch
        CalendarDate.init(1739, 13, 6), // End of leap year
    };

    for (test_dates) |date| {
        const jd = toJulianDay(date);
        const result = fromJulianDay(jd);

        try std.testing.expectEqual(date.year, result.year);
        try std.testing.expectEqual(date.month, result.month);
        try std.testing.expectEqual(date.day, result.day);
    }
}
