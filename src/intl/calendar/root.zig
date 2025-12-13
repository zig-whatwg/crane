//! Calendar Systems Module
//!
//! Implements non-Gregorian calendar systems required by ECMA-402.
//! All conversions use Julian Day Number (JDN) as an intermediate format.
//!
//! ## Supported Calendars
//!
//! - `gregorian` - Gregorian calendar (default)
//! - `buddhist` - Buddhist calendar (Thai Buddhist)
//! - `japanese` - Japanese Imperial calendar with era support
//! - `islamic` - Islamic (Hijri) lunar calendar
//! - `islamic-civil` - Islamic civil/tabular calendar
//! - `islamic-umalqura` - Saudi Arabia (Umm al-Qura) calendar
//! - `persian` - Persian/Solar Hijri calendar
//! - `hebrew` - Hebrew/Jewish calendar
//! - `chinese` - Chinese traditional calendar
//! - `roc` - Republic of China (Minguo) calendar
//! - `coptic` - Coptic calendar
//! - `ethiopic` - Ethiopian calendar
//! - `indian` - Indian National calendar
//!
//! ## Conversion Strategy
//!
//! All calendar conversions use Julian Day Number (JDN) as intermediate:
//! 1. Source calendar → JDN
//! 2. JDN → Target calendar
//!
//! This simplifies cross-calendar conversions and ensures consistency.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Re-export calendar types
pub const CalendarDate = @import("types.zig").CalendarDate;
pub const CalendarType = @import("types.zig").CalendarType;
pub const Era = @import("types.zig").Era;
pub const CalendarError = @import("types.zig").CalendarError;

// Import individual calendar implementations
pub const gregorian = @import("gregorian.zig");
pub const buddhist = @import("buddhist.zig");
pub const japanese = @import("japanese.zig");
pub const islamic = @import("islamic.zig");
pub const persian = @import("persian.zig");
pub const hebrew = @import("hebrew.zig");
pub const roc = @import("roc.zig");
pub const coptic = @import("coptic.zig");
pub const ethiopic = @import("ethiopic.zig");
pub const indian = @import("indian.zig");

// Re-export JDN conversion utilities
pub const jdn = @import("jdn.zig");
pub const toJulianDayNumber = jdn.toJulianDayNumber;
pub const fromJulianDayNumber = jdn.fromJulianDayNumber;

/// Calendar interface - unifies all calendar operations
pub const Calendar = struct {
    calendar_type: CalendarType,

    pub fn init(calendar_type: CalendarType) Calendar {
        return .{ .calendar_type = calendar_type };
    }

    /// Create a calendar from a string identifier
    pub fn fromString(name: []const u8) CalendarError!Calendar {
        const cal_type = CalendarType.fromString(name) orelse return CalendarError.UnsupportedCalendar;
        return Calendar.init(cal_type);
    }

    /// Get the calendar type identifier string
    pub fn getName(self: Calendar) []const u8 {
        return self.calendar_type.toString();
    }

    /// Convert a calendar date to Gregorian
    pub fn toGregorian(self: Calendar, date: CalendarDate) CalendarDate {
        const julian_day = self.toJulianDay(date);
        return gregorian.fromJulianDay(julian_day);
    }

    /// Convert a Gregorian date to this calendar
    pub fn fromGregorian(self: Calendar, date: CalendarDate) CalendarDate {
        const julian_day = gregorian.toJulianDay(date);
        return self.fromJulianDay(julian_day);
    }

    /// Convert to Julian Day Number
    pub fn toJulianDay(self: Calendar, date: CalendarDate) i64 {
        return switch (self.calendar_type) {
            .gregorian => gregorian.toJulianDay(date),
            .buddhist => buddhist.toJulianDay(date),
            .japanese => japanese.toJulianDay(date),
            .islamic, .islamic_civil, .islamic_tbla => islamic.toJulianDay(date, self.calendar_type),
            .islamic_umalqura, .islamic_rgsa => islamic.toJulianDay(date, self.calendar_type),
            .persian => persian.toJulianDay(date),
            .hebrew => hebrew.toJulianDay(date),
            .roc => roc.toJulianDay(date),
            .coptic => coptic.toJulianDay(date),
            .ethiopic, .ethiopic_amete_alem => ethiopic.toJulianDay(date, self.calendar_type),
            .indian => indian.toJulianDay(date),
            .chinese, .dangi => gregorian.toJulianDay(date), // Simplified: use Gregorian for now
        };
    }

    /// Convert from Julian Day Number
    pub fn fromJulianDay(self: Calendar, julian_day: i64) CalendarDate {
        return switch (self.calendar_type) {
            .gregorian => gregorian.fromJulianDay(julian_day),
            .buddhist => buddhist.fromJulianDay(julian_day),
            .japanese => japanese.fromJulianDay(julian_day),
            .islamic, .islamic_civil, .islamic_tbla => islamic.fromJulianDay(julian_day, self.calendar_type),
            .islamic_umalqura, .islamic_rgsa => islamic.fromJulianDay(julian_day, self.calendar_type),
            .persian => persian.fromJulianDay(julian_day),
            .hebrew => hebrew.fromJulianDay(julian_day),
            .roc => roc.fromJulianDay(julian_day),
            .coptic => coptic.fromJulianDay(julian_day),
            .ethiopic, .ethiopic_amete_alem => ethiopic.fromJulianDay(julian_day, self.calendar_type),
            .indian => indian.fromJulianDay(julian_day),
            .chinese, .dangi => gregorian.fromJulianDay(julian_day), // Simplified: use Gregorian for now
        };
    }

    /// Check if a year is a leap year in this calendar
    pub fn isLeapYear(self: Calendar, year: i32) bool {
        return switch (self.calendar_type) {
            .gregorian => gregorian.isLeapYear(year),
            .buddhist => gregorian.isLeapYear(year - 543), // Buddhist years offset
            .japanese => gregorian.isLeapYear(year), // Uses Gregorian
            .islamic, .islamic_civil, .islamic_tbla => islamic.isLeapYear(year, self.calendar_type),
            .islamic_umalqura, .islamic_rgsa => islamic.isLeapYear(year, self.calendar_type),
            .persian => persian.isLeapYear(year),
            .hebrew => hebrew.isLeapYear(year),
            .roc => gregorian.isLeapYear(year + 1911), // ROC years offset
            .coptic => coptic.isLeapYear(year),
            .ethiopic, .ethiopic_amete_alem => ethiopic.isLeapYear(year),
            .indian => indian.isLeapYear(year),
            .chinese, .dangi => gregorian.isLeapYear(year),
        };
    }

    /// Get the number of days in a month
    pub fn daysInMonth(self: Calendar, year: i32, month: u8) u8 {
        return switch (self.calendar_type) {
            .gregorian => gregorian.daysInMonth(year, month),
            .buddhist => gregorian.daysInMonth(year - 543, month),
            .japanese => gregorian.daysInMonth(year, month),
            .islamic, .islamic_civil, .islamic_tbla => islamic.daysInMonth(year, month, self.calendar_type),
            .islamic_umalqura, .islamic_rgsa => islamic.daysInMonth(year, month, self.calendar_type),
            .persian => persian.daysInMonth(year, month),
            .hebrew => hebrew.daysInMonth(year, month),
            .roc => gregorian.daysInMonth(year + 1911, month),
            .coptic => coptic.daysInMonth(year, month),
            .ethiopic, .ethiopic_amete_alem => ethiopic.daysInMonth(year, month),
            .indian => indian.daysInMonth(year, month),
            .chinese, .dangi => gregorian.daysInMonth(year, month),
        };
    }

    /// Get the number of months in a year
    pub fn monthsInYear(self: Calendar, year: i32) u8 {
        return switch (self.calendar_type) {
            .hebrew => if (hebrew.isLeapYear(year)) 13 else 12,
            else => 12,
        };
    }

    /// Get the day of week (0 = Sunday, 6 = Saturday)
    pub fn dayOfWeek(self: Calendar, date: CalendarDate) u8 {
        const julian_day = self.toJulianDay(date);
        // JDN 0 was a Monday, so we offset to make Sunday = 0
        return @intCast(@mod(julian_day + 1, 7));
    }

    /// Get eras supported by this calendar
    pub fn getEras(self: Calendar) []const Era {
        return switch (self.calendar_type) {
            .japanese => &japanese.ERAS,
            .roc => &roc.ERAS,
            .buddhist => &buddhist.ERAS,
            .gregorian => &gregorian.ERAS,
            .coptic => &coptic.ERAS,
            .ethiopic => &ethiopic.ERAS,
            .ethiopic_amete_alem => &ethiopic.ERAS_AMETE_ALEM,
            else => &gregorian.ERAS, // Default to Gregorian eras
        };
    }

    /// Get the current era for a date
    pub fn getEra(self: Calendar, date: CalendarDate) ?Era {
        const eras = self.getEras();
        // Find the era that contains this date
        for (eras) |era| {
            if (era.containsYear(date.year)) {
                return era;
            }
        }
        return if (eras.len > 0) eras[eras.len - 1] else null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Calendar - create from string" {
    const cal = try Calendar.fromString("gregorian");
    try std.testing.expectEqual(CalendarType.gregorian, cal.calendar_type);

    const buddhist_cal = try Calendar.fromString("buddhist");
    try std.testing.expectEqual(CalendarType.buddhist, buddhist_cal.calendar_type);

    const result = Calendar.fromString("invalid");
    try std.testing.expectError(CalendarError.UnsupportedCalendar, result);
}

test "Calendar - gregorian round-trip" {
    const cal = Calendar.init(.gregorian);
    const date = CalendarDate{ .year = 2024, .month = 12, .day = 13 };

    const julian_day = cal.toJulianDay(date);
    const result = cal.fromJulianDay(julian_day);

    try std.testing.expectEqual(date.year, result.year);
    try std.testing.expectEqual(date.month, result.month);
    try std.testing.expectEqual(date.day, result.day);
}

test "Calendar - buddhist conversion" {
    const gregorian_cal = Calendar.init(.gregorian);
    const buddhist_cal = Calendar.init(.buddhist);

    // 2024 CE = 2567 BE
    const gregorian_date = CalendarDate{ .year = 2024, .month = 1, .day = 1 };
    const julian_day = gregorian_cal.toJulianDay(gregorian_date);
    const buddhist_date = buddhist_cal.fromJulianDay(julian_day);

    try std.testing.expectEqual(@as(i32, 2567), buddhist_date.year);
    try std.testing.expectEqual(@as(u8, 1), buddhist_date.month);
    try std.testing.expectEqual(@as(u8, 1), buddhist_date.day);
}

test "Calendar - day of week" {
    const cal = Calendar.init(.gregorian);

    // 2024-12-13 is a Friday (day 5, 0-indexed from Sunday)
    const date = CalendarDate{ .year = 2024, .month = 12, .day = 13 };
    const dow = cal.dayOfWeek(date);

    try std.testing.expectEqual(@as(u8, 5), dow); // Friday
}

test "Calendar - leap year detection" {
    const cal = Calendar.init(.gregorian);

    try std.testing.expect(cal.isLeapYear(2000)); // Divisible by 400
    try std.testing.expect(!cal.isLeapYear(1900)); // Divisible by 100 but not 400
    try std.testing.expect(cal.isLeapYear(2024)); // Divisible by 4
    try std.testing.expect(!cal.isLeapYear(2023)); // Not divisible by 4
}

test {
    // Import all submodules for testing
    _ = @import("types.zig");
    _ = @import("gregorian.zig");
    _ = @import("buddhist.zig");
    _ = @import("japanese.zig");
    _ = @import("islamic.zig");
    _ = @import("persian.zig");
    _ = @import("hebrew.zig");
    _ = @import("roc.zig");
    _ = @import("coptic.zig");
    _ = @import("ethiopic.zig");
    _ = @import("indian.zig");
    _ = @import("jdn.zig");
}
