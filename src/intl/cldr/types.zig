//! CLDR Data Types
//!
//! Type definitions for CLDR locale data used throughout the i18n library.
//! These types mirror the data extracted from CLDR JSON.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Month names in various formats
pub const MonthNames = struct {
    /// Full month names: "January", "February", etc.
    wide: [12][]const u8,
    /// Abbreviated: "Jan", "Feb", etc.
    abbreviated: [12][]const u8,
    /// Single character: "J", "F", etc.
    narrow: [12][]const u8,

    /// Default English month names
    pub const DEFAULT = MonthNames{
        .wide = .{
            "January",   "February", "March",    "April",
            "May",       "June",     "July",     "August",
            "September", "October",  "November", "December",
        },
        .abbreviated = .{
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        },
        .narrow = .{ "J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D" },
    };
};

/// Weekday names in various formats
pub const WeekdayNames = struct {
    /// Full names: "Sunday", "Monday", etc.
    wide: [7][]const u8,
    /// Abbreviated: "Sun", "Mon", etc.
    abbreviated: [7][]const u8,
    /// Single character: "S", "M", etc.
    narrow: [7][]const u8,
    /// Short form: "Su", "Mo", etc.
    short: [7][]const u8,

    /// Default English weekday names (Sunday = 0)
    pub const DEFAULT = WeekdayNames{
        .wide = .{ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" },
        .abbreviated = .{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
        .narrow = .{ "S", "M", "T", "W", "T", "F", "S" },
        .short = .{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" },
    };
};

/// Day period names (AM/PM and extended periods)
pub const DayPeriodNames = struct {
    am: []const u8,
    pm: []const u8,

    pub const DEFAULT = DayPeriodNames{
        .am = "AM",
        .pm = "PM",
    };
};

/// Era names (BC/AD or equivalent)
pub const EraNames = struct {
    /// Full era names: "Before Christ", "Anno Domini"
    wide: [2][]const u8,
    /// Abbreviated: "BC", "AD"
    abbreviated: [2][]const u8,
    /// Narrow: "B", "A"
    narrow: [2][]const u8,

    pub const DEFAULT = EraNames{
        .wide = .{ "Before Christ", "Anno Domini" },
        .abbreviated = .{ "BC", "AD" },
        .narrow = .{ "B", "A" },
    };
};

/// Date and time format patterns (CLDR/ICU pattern syntax)
pub const DateTimePatterns = struct {
    /// Full date: "EEEE, MMMM d, y"
    date_full: []const u8,
    /// Long date: "MMMM d, y"
    date_long: []const u8,
    /// Medium date: "MMM d, y"
    date_medium: []const u8,
    /// Short date: "M/d/yy"
    date_short: []const u8,

    /// Full time: "h:mm:ss a zzzz"
    time_full: []const u8,
    /// Long time: "h:mm:ss a z"
    time_long: []const u8,
    /// Medium time: "h:mm:ss a"
    time_medium: []const u8,
    /// Short time: "h:mm a"
    time_short: []const u8,

    /// Combined date-time patterns ({0} = time, {1} = date)
    datetime_full: []const u8,
    datetime_long: []const u8,
    datetime_medium: []const u8,
    datetime_short: []const u8,

    pub const DEFAULT = DateTimePatterns{
        .date_full = "EEEE, MMMM d, y",
        .date_long = "MMMM d, y",
        .date_medium = "MMM d, y",
        .date_short = "M/d/yy",
        .time_full = "h:mm:ss a zzzz",
        .time_long = "h:mm:ss a z",
        .time_medium = "h:mm:ss a",
        .time_short = "h:mm a",
        .datetime_full = "{1}, {0}",
        .datetime_long = "{1}, {0}",
        .datetime_medium = "{1}, {0}",
        .datetime_short = "{1}, {0}",
    };
};

/// Number formatting symbols
pub const NumberSymbols = struct {
    /// Decimal separator: "."
    decimal: []const u8,
    /// Grouping separator: ","
    group: []const u8,
    /// Percent sign: "%"
    percent: []const u8,
    /// Minus sign: "-"
    minus: []const u8,
    /// Plus sign: "+"
    plus: []const u8,
    /// Exponential: "E"
    exponential: []const u8,
    /// Infinity symbol: "∞"
    infinity: []const u8,
    /// Not-a-number: "NaN"
    nan: []const u8,

    pub const DEFAULT = NumberSymbols{
        .decimal = ".",
        .group = ",",
        .percent = "%",
        .minus = "-",
        .plus = "+",
        .exponential = "E",
        .infinity = "∞",
        .nan = "NaN",
    };
};

/// Currency format patterns
pub const CurrencyPatterns = struct {
    /// Standard format: "¤#,##0.00"
    standard: []const u8,
    /// Accounting format: "(¤#,##0.00)"
    accounting: []const u8,

    pub const DEFAULT = CurrencyPatterns{
        .standard = "¤#,##0.00",
        .accounting = "¤#,##0.00",
    };
};

/// Complete locale data structure
pub const LocaleData = struct {
    /// BCP 47 locale tag
    tag: []const u8,
    /// Month names
    months: MonthNames,
    /// Weekday names
    weekdays: WeekdayNames,
    /// Day periods (AM/PM)
    day_periods: DayPeriodNames,
    /// Era names
    eras: EraNames,
    /// Date/time patterns
    datetime_patterns: DateTimePatterns,
    /// Number symbols
    number_symbols: NumberSymbols,

    /// Whether this data is heap-allocated (needs deinit)
    is_allocated: bool = false,

    /// Default English locale data
    pub const DEFAULT = LocaleData{
        .tag = "en",
        .months = MonthNames.DEFAULT,
        .weekdays = WeekdayNames.DEFAULT,
        .day_periods = DayPeriodNames.DEFAULT,
        .eras = EraNames.DEFAULT,
        .datetime_patterns = DateTimePatterns.DEFAULT,
        .number_symbols = NumberSymbols.DEFAULT,
        .is_allocated = false,
    };

    /// Free heap-allocated locale data
    pub fn deinit(self: *LocaleData, allocator: Allocator) void {
        if (!self.is_allocated) return;

        // Free month names
        for (self.months.wide) |s| if (s.len > 0) allocator.free(s);
        for (self.months.abbreviated) |s| if (s.len > 0) allocator.free(s);
        for (self.months.narrow) |s| if (s.len > 0) allocator.free(s);

        // Free weekday names
        for (self.weekdays.wide) |s| if (s.len > 0) allocator.free(s);
        for (self.weekdays.abbreviated) |s| if (s.len > 0) allocator.free(s);
        for (self.weekdays.narrow) |s| if (s.len > 0) allocator.free(s);
        for (self.weekdays.short) |s| if (s.len > 0) allocator.free(s);

        // Free tag
        allocator.free(self.tag);
    }
};

/// First day of week (varies by locale)
pub const FirstDayOfWeek = enum(u3) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,
};

/// Week info for a locale
pub const WeekInfo = struct {
    /// First day of the week
    first_day: FirstDayOfWeek,
    /// Minimum days in first week of year
    min_days: u3,
    /// Weekend days (bitmask: bit 0 = Sunday, bit 6 = Saturday)
    weekend: u7,

    pub const DEFAULT = WeekInfo{
        .first_day = .sunday,
        .min_days = 1,
        .weekend = 0b1000001, // Saturday and Sunday
    };
};

// ============================================================================
// Tests
// ============================================================================

test "MonthNames.DEFAULT has correct values" {
    try std.testing.expectEqualStrings("January", MonthNames.DEFAULT.wide[0]);
    try std.testing.expectEqualStrings("Dec", MonthNames.DEFAULT.abbreviated[11]);
    try std.testing.expectEqualStrings("J", MonthNames.DEFAULT.narrow[0]);
}

test "WeekdayNames.DEFAULT has correct values" {
    try std.testing.expectEqualStrings("Sunday", WeekdayNames.DEFAULT.wide[0]);
    try std.testing.expectEqualStrings("Sat", WeekdayNames.DEFAULT.abbreviated[6]);
}

test "DateTimePatterns.DEFAULT has valid patterns" {
    // Verify patterns contain expected tokens
    try std.testing.expect(std.mem.indexOf(u8, DateTimePatterns.DEFAULT.date_full, "EEEE") != null);
    try std.testing.expect(std.mem.indexOf(u8, DateTimePatterns.DEFAULT.time_short, "h:mm") != null);
}

test "LocaleData.DEFAULT is valid" {
    const data = LocaleData.DEFAULT;
    try std.testing.expectEqualStrings("en", data.tag);
    try std.testing.expect(!data.is_allocated);
}
