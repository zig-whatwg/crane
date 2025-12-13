//! Japanese Imperial Calendar Implementation
//!
//! The Japanese calendar uses Gregorian calendar rules but with eras
//! (元号, gengō) that begin with each new emperor's reign.
//!
//! ## Current Eras (since Meiji)
//!
//! - 明治 (Meiji): 1868-09-08 to 1912-07-30
//! - 大正 (Taishō): 1912-07-30 to 1926-12-25
//! - 昭和 (Shōwa): 1926-12-25 to 1989-01-07
//! - 平成 (Heisei): 1989-01-08 to 2019-04-30
//! - 令和 (Reiwa): 2019-05-01 to present
//!
//! Years are counted from 1 at the start of each era.

const std = @import("std");
const CalendarDate = @import("types.zig").CalendarDate;
const Era = @import("types.zig").Era;
const gregorian = @import("gregorian.zig");

/// Japanese calendar eras (modern, since Meiji)
pub const ERAS = [_]Era{
    // Meiji
    Era{
        .id = "meiji",
        .abbr = "M",
        .name = "明治",
        .start_year = 1,
        .end_year = 45,
        .gregorian_start_year = 1868,
        .gregorian_start_month = 9,
        .gregorian_start_day = 8,
    },
    // Taishō
    Era{
        .id = "taisho",
        .abbr = "T",
        .name = "大正",
        .start_year = 1,
        .end_year = 15,
        .gregorian_start_year = 1912,
        .gregorian_start_month = 7,
        .gregorian_start_day = 30,
    },
    // Shōwa
    Era{
        .id = "showa",
        .abbr = "S",
        .name = "昭和",
        .start_year = 1,
        .end_year = 64,
        .gregorian_start_year = 1926,
        .gregorian_start_month = 12,
        .gregorian_start_day = 25,
    },
    // Heisei
    Era{
        .id = "heisei",
        .abbr = "H",
        .name = "平成",
        .start_year = 1,
        .end_year = 31,
        .gregorian_start_year = 1989,
        .gregorian_start_month = 1,
        .gregorian_start_day = 8,
    },
    // Reiwa
    Era{
        .id = "reiwa",
        .abbr = "R",
        .name = "令和",
        .start_year = 1,
        .end_year = null, // Current era
        .gregorian_start_year = 2019,
        .gregorian_start_month = 5,
        .gregorian_start_day = 1,
    },
};

/// Find era index for a Gregorian date
fn findEraForGregorianDate(year: i32, month: u8, day: u8) ?usize {
    // Search from newest to oldest
    var i: usize = ERAS.len;
    while (i > 0) {
        i -= 1;
        const era = ERAS[i];
        // Check if date is on or after era start
        if (year > era.gregorian_start_year) {
            return i;
        } else if (year == era.gregorian_start_year) {
            if (month > era.gregorian_start_month) {
                return i;
            } else if (month == era.gregorian_start_month and day >= era.gregorian_start_day) {
                return i;
            }
        }
    }
    return null; // Before Meiji era
}

/// Convert Gregorian year to Japanese era year
fn toEraYear(gregorian_year: i32, gregorian_month: u8, gregorian_day: u8) struct { year: i32, era: u8 } {
    if (findEraForGregorianDate(gregorian_year, gregorian_month, gregorian_day)) |era_idx| {
        const era = ERAS[era_idx];
        const era_year = gregorian_year - era.gregorian_start_year + 1;
        return .{ .year = era_year, .era = @intCast(era_idx) };
    }
    // Before Meiji: return Gregorian year with era 0
    return .{ .year = gregorian_year, .era = 0 };
}

/// Check if a year is a leap year
pub fn isLeapYear(year: i32) bool {
    return gregorian.isLeapYear(year);
}

/// Get days in month
pub fn daysInMonth(year: i32, month: u8) u8 {
    return gregorian.daysInMonth(year, month);
}

/// Convert Japanese date to Julian Day Number
///
/// Japanese dates use Gregorian rules, just with era-based year counting.
/// For conversion, we need to know the era to get the absolute year.
pub fn toJulianDay(date: CalendarDate) i64 {
    // If era is specified, convert era year to Gregorian year
    const gregorian_year = if (date.era) |era_idx| blk: {
        if (era_idx < ERAS.len) {
            const era = ERAS[era_idx];
            break :blk era.gregorian_start_year + date.year - 1;
        }
        break :blk date.year;
    } else date.year;

    const gregorian_date = CalendarDate{
        .year = gregorian_year,
        .month = date.month,
        .day = date.day,
        .era = null,
    };
    return gregorian.toJulianDay(gregorian_date);
}

/// Convert Julian Day Number to Japanese date
pub fn fromJulianDay(jd: i64) CalendarDate {
    const greg = gregorian.fromJulianDay(jd);
    const era_info = toEraYear(greg.year, greg.month, greg.day);

    return CalendarDate{
        .year = era_info.year,
        .month = greg.month,
        .day = greg.day,
        .era = era_info.era,
    };
}

/// Convert Gregorian date to Japanese date
pub fn fromGregorian(date: CalendarDate) CalendarDate {
    const era_info = toEraYear(date.year, date.month, date.day);
    return CalendarDate{
        .year = era_info.year,
        .month = date.month,
        .day = date.day,
        .era = era_info.era,
    };
}

/// Convert Japanese date to Gregorian date
pub fn toGregorian(date: CalendarDate) CalendarDate {
    const gregorian_year = if (date.era) |era_idx| blk: {
        if (era_idx < ERAS.len) {
            const era = ERAS[era_idx];
            break :blk era.gregorian_start_year + date.year - 1;
        }
        break :blk date.year;
    } else date.year;

    return CalendarDate{
        .year = gregorian_year,
        .month = date.month,
        .day = date.day,
        .era = if (gregorian_year < 1) 0 else 1,
    };
}

/// Get the era for a given Japanese date
pub fn getEra(date: CalendarDate) ?Era {
    if (date.era) |era_idx| {
        if (era_idx < ERAS.len) {
            return ERAS[era_idx];
        }
    }
    return null;
}

/// Get era index by name
pub fn findEraByName(name: []const u8) ?usize {
    for (ERAS, 0..) |era, i| {
        if (std.mem.eql(u8, era.id, name) or
            std.mem.eql(u8, era.abbr, name) or
            std.mem.eql(u8, era.name, name))
        {
            return i;
        }
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "japanese - era detection" {
    // Reiwa era (2019-05-01 onwards)
    const reiwa_start = findEraForGregorianDate(2019, 5, 1);
    try std.testing.expectEqual(@as(?usize, 4), reiwa_start); // Reiwa is index 4

    // Last day of Heisei (2019-04-30)
    const heisei_end = findEraForGregorianDate(2019, 4, 30);
    try std.testing.expectEqual(@as(?usize, 3), heisei_end); // Heisei is index 3

    // Showa era (1926-12-25)
    const showa_start = findEraForGregorianDate(1926, 12, 25);
    try std.testing.expectEqual(@as(?usize, 2), showa_start); // Showa is index 2
}

test "japanese - year conversion" {
    // 2024 = Reiwa 6
    const info = toEraYear(2024, 1, 1);
    try std.testing.expectEqual(@as(i32, 6), info.year);
    try std.testing.expectEqual(@as(u8, 4), info.era); // Reiwa era

    // 1989-01-08 = Heisei 1 (first day of Heisei)
    const heisei_1 = toEraYear(1989, 1, 8);
    try std.testing.expectEqual(@as(i32, 1), heisei_1.year);
    try std.testing.expectEqual(@as(u8, 3), heisei_1.era); // Heisei era
}

test "japanese - julian day round-trip" {
    // Test round-trip through Julian Day
    const test_dates = [_]struct { greg_year: i32, month: u8, day: u8, era: u8, era_year: i32 }{
        .{ .greg_year = 2024, .month = 12, .day = 13, .era = 4, .era_year = 6 }, // Reiwa 6
        .{ .greg_year = 2019, .month = 5, .day = 1, .era = 4, .era_year = 1 }, // Reiwa 1 start
        .{ .greg_year = 2019, .month = 4, .day = 30, .era = 3, .era_year = 31 }, // Heisei 31 end
        .{ .greg_year = 1989, .month = 1, .day = 8, .era = 3, .era_year = 1 }, // Heisei 1 start
    };

    for (test_dates) |td| {
        const greg_date = CalendarDate.init(td.greg_year, td.month, td.day);
        const jd = gregorian.toJulianDay(greg_date);
        const jp_date = fromJulianDay(jd);

        try std.testing.expectEqual(td.era_year, jp_date.year);
        try std.testing.expectEqual(td.era, jp_date.era.?);
        try std.testing.expectEqual(td.month, jp_date.month);
        try std.testing.expectEqual(td.day, jp_date.day);
    }
}

test "japanese - era lookup" {
    try std.testing.expectEqual(@as(?usize, 4), findEraByName("reiwa"));
    try std.testing.expectEqual(@as(?usize, 4), findEraByName("R"));
    try std.testing.expectEqual(@as(?usize, 4), findEraByName("令和"));
    try std.testing.expectEqual(@as(?usize, 3), findEraByName("heisei"));
    try std.testing.expect(findEraByName("invalid") == null);
}
