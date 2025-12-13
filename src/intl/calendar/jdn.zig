//! Julian Day Number Utilities
//!
//! Provides common JDN conversion utilities used across calendar implementations.
//! Julian Day Number (JDN) is an integer counting days since November 24, 4714 BCE
//! (proleptic Gregorian calendar), which is the beginning of the Julian Period.
//!
//! JDN is used as an intermediate format for converting between calendar systems.

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const CalendarType = @import("types.zig").CalendarType;
const gregorian = @import("gregorian.zig");
const buddhist = @import("buddhist.zig");
const japanese = @import("japanese.zig");
const islamic = @import("islamic.zig");
const persian = @import("persian.zig");
const hebrew = @import("hebrew.zig");
const roc = @import("roc.zig");
const coptic = @import("coptic.zig");
const ethiopic = @import("ethiopic.zig");
const indian = @import("indian.zig");

/// Convert a date from any calendar to Julian Day Number
pub fn toJulianDayNumber(date: CalendarDate, calendar_type: CalendarType) i64 {
    return switch (calendar_type) {
        .gregorian => gregorian.toJulianDay(date),
        .buddhist => buddhist.toJulianDay(date),
        .japanese => japanese.toJulianDay(date),
        .islamic, .islamic_civil, .islamic_tbla => islamic.toJulianDay(date, calendar_type),
        .islamic_umalqura, .islamic_rgsa => islamic.toJulianDay(date, calendar_type),
        .persian => persian.toJulianDay(date),
        .hebrew => hebrew.toJulianDay(date),
        .roc => roc.toJulianDay(date),
        .coptic => coptic.toJulianDay(date),
        .ethiopic, .ethiopic_amete_alem => ethiopic.toJulianDay(date, calendar_type),
        .indian => indian.toJulianDay(date),
        .chinese, .dangi => gregorian.toJulianDay(date), // Simplified
    };
}

/// Convert Julian Day Number to a date in any calendar
pub fn fromJulianDayNumber(jd: i64, calendar_type: CalendarType) CalendarDate {
    return switch (calendar_type) {
        .gregorian => gregorian.fromJulianDay(jd),
        .buddhist => buddhist.fromJulianDay(jd),
        .japanese => japanese.fromJulianDay(jd),
        .islamic, .islamic_civil, .islamic_tbla => islamic.fromJulianDay(jd, calendar_type),
        .islamic_umalqura, .islamic_rgsa => islamic.fromJulianDay(jd, calendar_type),
        .persian => persian.fromJulianDay(jd),
        .hebrew => hebrew.fromJulianDay(jd),
        .roc => roc.fromJulianDay(jd),
        .coptic => coptic.fromJulianDay(jd),
        .ethiopic, .ethiopic_amete_alem => ethiopic.fromJulianDay(jd, calendar_type),
        .indian => indian.fromJulianDay(jd),
        .chinese, .dangi => gregorian.fromJulianDay(jd), // Simplified
    };
}

/// Convert a date between any two calendar systems
pub fn convertDate(date: CalendarDate, from_calendar: CalendarType, to_calendar: CalendarType) CalendarDate {
    if (from_calendar == to_calendar) {
        return date;
    }
    const jd = toJulianDayNumber(date, from_calendar);
    return fromJulianDayNumber(jd, to_calendar);
}

/// Well-known Julian Day Numbers for reference
pub const WELL_KNOWN_JDN = struct {
    /// Unix epoch: January 1, 1970 (Gregorian)
    pub const UNIX_EPOCH: i64 = 2440588;

    /// J2000.0: January 1, 2000, 12:00 TT (Gregorian)
    pub const J2000: i64 = 2451545;

    /// Gregorian calendar reform: October 15, 1582
    pub const GREGORIAN_REFORM: i64 = 2299161;

    /// Julian calendar epoch: January 1, 4713 BCE (proleptic Julian)
    pub const JULIAN_EPOCH: i64 = 0;
};

// ============================================================================
// Tests
// ============================================================================

test "jdn - convert gregorian to buddhist" {
    const gregorian_date = CalendarDate.init(2024, 1, 1);
    const buddhist_date = convertDate(gregorian_date, .gregorian, .buddhist);

    try std.testing.expectEqual(@as(i32, 2567), buddhist_date.year);
    try std.testing.expectEqual(@as(u8, 1), buddhist_date.month);
    try std.testing.expectEqual(@as(u8, 1), buddhist_date.day);
}

test "jdn - convert gregorian to roc" {
    const gregorian_date = CalendarDate.init(2024, 1, 1);
    const roc_date = convertDate(gregorian_date, .gregorian, .roc);

    try std.testing.expectEqual(@as(i32, 113), roc_date.year);
    try std.testing.expectEqual(@as(u8, 1), roc_date.month);
    try std.testing.expectEqual(@as(u8, 1), roc_date.day);
}

test "jdn - round-trip between calendars" {
    const original = CalendarDate.init(2024, 12, 13);

    // Gregorian -> Buddhist -> Gregorian
    const buddhist_date = convertDate(original, .gregorian, .buddhist);
    const back_from_buddhist = convertDate(buddhist_date, .buddhist, .gregorian);
    try std.testing.expectEqual(original.year, back_from_buddhist.year);
    try std.testing.expectEqual(original.month, back_from_buddhist.month);
    try std.testing.expectEqual(original.day, back_from_buddhist.day);

    // Gregorian -> ROC -> Gregorian
    const roc_date = convertDate(original, .gregorian, .roc);
    const back_from_roc = convertDate(roc_date, .roc, .gregorian);
    try std.testing.expectEqual(original.year, back_from_roc.year);
    try std.testing.expectEqual(original.month, back_from_roc.month);
    try std.testing.expectEqual(original.day, back_from_roc.day);
}

test "jdn - well-known dates" {
    // Unix epoch
    const unix_epoch = gregorian.fromJulianDay(WELL_KNOWN_JDN.UNIX_EPOCH);
    try std.testing.expectEqual(@as(i32, 1970), unix_epoch.year);
    try std.testing.expectEqual(@as(u8, 1), unix_epoch.month);
    try std.testing.expectEqual(@as(u8, 1), unix_epoch.day);

    // J2000
    const j2000 = gregorian.fromJulianDay(WELL_KNOWN_JDN.J2000);
    try std.testing.expectEqual(@as(i32, 2000), j2000.year);
    try std.testing.expectEqual(@as(u8, 1), j2000.month);
    try std.testing.expectEqual(@as(u8, 1), j2000.day);
}
