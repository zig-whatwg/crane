//! Calendar Type Definitions
//!
//! Common types used across all calendar implementations.

const std = @import("std");

/// Calendar date with year, month, day components.
/// Does not include time information.
pub const CalendarDate = struct {
    /// Year (can be negative for BCE dates)
    year: i32,
    /// Month of year (1-based: 1-12 for most calendars, 1-13 for Hebrew leap years)
    month: u8,
    /// Day of month (1-based)
    day: u8,
    /// Optional era index for calendars with multiple eras
    era: ?u8 = null,

    /// Create a calendar date
    pub fn init(year: i32, month: u8, day: u8) CalendarDate {
        return .{ .year = year, .month = month, .day = day, .era = null };
    }

    /// Create a calendar date with era
    pub fn initWithEra(year: i32, month: u8, day: u8, era: u8) CalendarDate {
        return .{ .year = year, .month = month, .day = day, .era = era };
    }

    /// Compare two dates
    pub fn compare(self: CalendarDate, other: CalendarDate) std.math.Order {
        if (self.year != other.year) {
            return std.math.order(self.year, other.year);
        }
        if (self.month != other.month) {
            return std.math.order(self.month, other.month);
        }
        return std.math.order(self.day, other.day);
    }

    /// Check equality
    pub fn eql(self: CalendarDate, other: CalendarDate) bool {
        return self.year == other.year and self.month == other.month and self.day == other.day;
    }
};

/// Supported calendar types per ECMA-402 and CLDR
pub const CalendarType = enum {
    /// Gregorian (ISO 8601) calendar - default
    gregorian,
    /// Buddhist calendar (Thai Buddhist)
    buddhist,
    /// Japanese Imperial calendar with eras
    japanese,
    /// Islamic (Hijri) lunar calendar - algorithmic
    islamic,
    /// Islamic civil/tabular calendar
    islamic_civil,
    /// Islamic tabular calendar (Thursday epoch)
    islamic_tbla,
    /// Islamic Umm al-Qura calendar (Saudi Arabia)
    islamic_umalqura,
    /// Islamic RGSA (reformist)
    islamic_rgsa,
    /// Persian (Solar Hijri) calendar
    persian,
    /// Hebrew (Jewish) calendar
    hebrew,
    /// Chinese traditional calendar
    chinese,
    /// Korean Dangi calendar
    dangi,
    /// Republic of China (Minguo) calendar
    roc,
    /// Coptic calendar
    coptic,
    /// Ethiopian calendar
    ethiopic,
    /// Ethiopian Amete Alem calendar
    ethiopic_amete_alem,
    /// Indian National calendar
    indian,

    /// Parse calendar type from string identifier
    pub fn fromString(name: []const u8) ?CalendarType {
        // Canonical names
        if (std.mem.eql(u8, name, "gregory") or std.mem.eql(u8, name, "gregorian")) {
            return .gregorian;
        } else if (std.mem.eql(u8, name, "buddhist")) {
            return .buddhist;
        } else if (std.mem.eql(u8, name, "japanese")) {
            return .japanese;
        } else if (std.mem.eql(u8, name, "islamic") or std.mem.eql(u8, name, "islamicc")) {
            return .islamic;
        } else if (std.mem.eql(u8, name, "islamic-civil")) {
            return .islamic_civil;
        } else if (std.mem.eql(u8, name, "islamic-tbla")) {
            return .islamic_tbla;
        } else if (std.mem.eql(u8, name, "islamic-umalqura")) {
            return .islamic_umalqura;
        } else if (std.mem.eql(u8, name, "islamic-rgsa")) {
            return .islamic_rgsa;
        } else if (std.mem.eql(u8, name, "persian")) {
            return .persian;
        } else if (std.mem.eql(u8, name, "hebrew")) {
            return .hebrew;
        } else if (std.mem.eql(u8, name, "chinese")) {
            return .chinese;
        } else if (std.mem.eql(u8, name, "dangi")) {
            return .dangi;
        } else if (std.mem.eql(u8, name, "roc")) {
            return .roc;
        } else if (std.mem.eql(u8, name, "coptic")) {
            return .coptic;
        } else if (std.mem.eql(u8, name, "ethiopic")) {
            return .ethiopic;
        } else if (std.mem.eql(u8, name, "ethiopic-amete-alem")) {
            return .ethiopic_amete_alem;
        } else if (std.mem.eql(u8, name, "indian")) {
            return .indian;
        }
        return null;
    }

    /// Get canonical string identifier
    pub fn toString(self: CalendarType) []const u8 {
        return switch (self) {
            .gregorian => "gregory",
            .buddhist => "buddhist",
            .japanese => "japanese",
            .islamic => "islamic",
            .islamic_civil => "islamic-civil",
            .islamic_tbla => "islamic-tbla",
            .islamic_umalqura => "islamic-umalqura",
            .islamic_rgsa => "islamic-rgsa",
            .persian => "persian",
            .hebrew => "hebrew",
            .chinese => "chinese",
            .dangi => "dangi",
            .roc => "roc",
            .coptic => "coptic",
            .ethiopic => "ethiopic",
            .ethiopic_amete_alem => "ethiopic-amete-alem",
            .indian => "indian",
        };
    }
};

/// Era definition for calendars with multiple eras
pub const Era = struct {
    /// Era identifier (e.g., "reiwa", "heisei" for Japanese)
    id: []const u8,
    /// Localized era name (abbreviated)
    abbr: []const u8,
    /// Localized era name (wide)
    name: []const u8,
    /// Start year of era (in the calendar's own year system)
    start_year: i32,
    /// End year of era (null if current era)
    end_year: ?i32,
    /// Gregorian year this era started
    gregorian_start_year: i32,
    /// Gregorian month this era started
    gregorian_start_month: u8,
    /// Gregorian day this era started
    gregorian_start_day: u8,

    /// Check if a year falls within this era
    pub fn containsYear(self: Era, year: i32) bool {
        if (year < self.start_year) return false;
        if (self.end_year) |end| {
            return year <= end;
        }
        return true; // Current era, no end
    }

    /// Convert era year to Gregorian year
    pub fn toGregorianYear(self: Era, era_year: i32) i32 {
        return self.gregorian_start_year + era_year - 1;
    }

    /// Convert Gregorian year to era year
    pub fn fromGregorianYear(self: Era, gregorian_year: i32) i32 {
        return gregorian_year - self.gregorian_start_year + 1;
    }
};

/// Calendar-related errors
pub const CalendarError = error{
    /// Calendar type not supported
    UnsupportedCalendar,
    /// Invalid date value
    InvalidDate,
    /// Date out of range for calendar
    DateOutOfRange,
    /// Era not found
    EraNotFound,
};

// ============================================================================
// Tests
// ============================================================================

test "CalendarType - fromString" {
    try std.testing.expectEqual(CalendarType.gregorian, CalendarType.fromString("gregory").?);
    try std.testing.expectEqual(CalendarType.gregorian, CalendarType.fromString("gregorian").?);
    try std.testing.expectEqual(CalendarType.buddhist, CalendarType.fromString("buddhist").?);
    try std.testing.expectEqual(CalendarType.japanese, CalendarType.fromString("japanese").?);
    try std.testing.expectEqual(CalendarType.islamic, CalendarType.fromString("islamic").?);
    try std.testing.expectEqual(CalendarType.islamic_umalqura, CalendarType.fromString("islamic-umalqura").?);
    try std.testing.expect(CalendarType.fromString("invalid") == null);
}

test "CalendarType - toString" {
    try std.testing.expectEqualStrings("gregory", CalendarType.gregorian.toString());
    try std.testing.expectEqualStrings("buddhist", CalendarType.buddhist.toString());
    try std.testing.expectEqualStrings("japanese", CalendarType.japanese.toString());
}

test "CalendarDate - compare" {
    const date1 = CalendarDate.init(2024, 1, 1);
    const date2 = CalendarDate.init(2024, 1, 2);
    const date3 = CalendarDate.init(2024, 1, 1);

    try std.testing.expectEqual(std.math.Order.lt, date1.compare(date2));
    try std.testing.expectEqual(std.math.Order.gt, date2.compare(date1));
    try std.testing.expectEqual(std.math.Order.eq, date1.compare(date3));
    try std.testing.expect(date1.eql(date3));
}

test "Era - containsYear" {
    const reiwa = Era{
        .id = "reiwa",
        .abbr = "R",
        .name = "令和",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 2019,
        .gregorian_start_month = 5,
        .gregorian_start_day = 1,
    };

    try std.testing.expect(reiwa.containsYear(1));
    try std.testing.expect(reiwa.containsYear(5));
    try std.testing.expect(!reiwa.containsYear(0));
}

test "Era - year conversion" {
    const reiwa = Era{
        .id = "reiwa",
        .abbr = "R",
        .name = "令和",
        .start_year = 1,
        .end_year = null,
        .gregorian_start_year = 2019,
        .gregorian_start_month = 5,
        .gregorian_start_day = 1,
    };

    try std.testing.expectEqual(@as(i32, 2019), reiwa.toGregorianYear(1));
    try std.testing.expectEqual(@as(i32, 2024), reiwa.toGregorianYear(6));
    try std.testing.expectEqual(@as(i32, 1), reiwa.fromGregorianYear(2019));
    try std.testing.expectEqual(@as(i32, 6), reiwa.fromGregorianYear(2024));
}
