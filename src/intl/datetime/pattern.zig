//! CLDR/ICU Pattern-Based DateTime Formatting Engine
//!
//! Implements UTS #35 (CLDR) pattern syntax for date/time formatting.
//! Converts DateTime + Pattern → formatted string.
//!
//! ## Pattern Syntax (UTS #35)
//!
//! Date fields:
//! - `y`, `yy`, `yyyy` - Year (1-4 digits)
//! - `M`, `MM` - Month number (1-2 digits)
//! - `MMM` - Month abbreviated name
//! - `MMMM` - Month wide name
//! - `MMMMM` - Month narrow name
//! - `d`, `dd` - Day of month (1-2 digits)
//! - `E`, `EE`, `EEE` - Weekday abbreviated
//! - `EEEE` - Weekday wide name
//! - `EEEEE` - Weekday narrow name
//!
//! Time fields:
//! - `H`, `HH` - Hour 0-23 (1-2 digits)
//! - `h`, `hh` - Hour 1-12 (1-2 digits)
//! - `m`, `mm` - Minute (1-2 digits)
//! - `s`, `ss` - Second (1-2 digits)
//! - `S`, `SS`, `SSS` - Fractional seconds
//! - `a` - AM/PM marker
//!
//! Era and other:
//! - `G`, `GG`, `GGG` - Era abbreviated (AD/BC)
//! - `GGGG` - Era wide (Anno Domini)
//! - `GGGGG` - Era narrow (A)
//!
//! Literals:
//! - `'...'` - Quoted literal text
//! - `''` - Escaped single quote
//!
//! ## Example
//!
//! ```zig
//! const allocator = std.testing.allocator;
//! const pattern = "yyyy-MM-dd HH:mm:ss";
//! const tokens = try parsePattern(allocator, pattern);
//! defer freeTokens(allocator, tokens);
//!
//! const datetime = DateTime.fromTimestamp(1699964445); // 2023-11-14 12:30:45
//! const result = try formatDateTime(allocator, tokens, datetime, &locale_data);
//! defer allocator.free(result);
//! // result = "2023-11-14 12:30:45"
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const List = infra.List;
const DateTime = @import("datetime.zig").DateTime;

// ============================================================================
// Pattern Token Types
// ============================================================================

/// Year format options
pub const YearFormat = enum {
    /// Single digit year (minimum digits)
    numeric,
    /// 2-digit year (yy)
    two_digit,
    /// 4-digit year (yyyy)
    full,

    /// Number of digits for formatting
    pub fn minDigits(self: YearFormat) u8 {
        return switch (self) {
            .numeric => 1,
            .two_digit => 2,
            .full => 4,
        };
    }
};

/// Month format options
pub const MonthFormat = enum {
    /// Single digit month (1-12)
    numeric,
    /// 2-digit month (01-12)
    two_digit,
    /// Abbreviated name (Jan, Feb, etc.)
    abbreviated,
    /// Wide name (January, February, etc.)
    wide,
    /// Narrow name (J, F, etc.)
    narrow,
};

/// Day format options
pub const DayFormat = enum {
    /// Single digit day (1-31)
    numeric,
    /// 2-digit day (01-31)
    two_digit,
};

/// Weekday format options
pub const WeekdayFormat = enum {
    /// Abbreviated name (Mon, Tue, etc.)
    abbreviated,
    /// Wide name (Monday, Tuesday, etc.)
    wide,
    /// Narrow name (M, T, etc.)
    narrow,
    /// Short name (Mo, Tu, etc.) - same as abbreviated in many locales
    short,
};

/// Hour format options
pub const HourFormat = struct {
    /// Whether this is 12-hour (h) or 24-hour (H) format
    cycle: HourCycle,
    /// Whether to pad with leading zero
    two_digit: bool,

    pub const HourCycle = enum {
        /// 12-hour clock (1-12)
        h12,
        /// 24-hour clock (0-23)
        h23,
        /// 12-hour clock starting at 0 (0-11)
        h11,
        /// 24-hour clock starting at 1 (1-24)
        h24,
    };
};

/// Minute format options
pub const MinuteFormat = enum {
    /// Single digit (0-59)
    numeric,
    /// 2-digit (00-59)
    two_digit,
};

/// Second format options
pub const SecondFormat = enum {
    /// Single digit (0-59)
    numeric,
    /// 2-digit (00-59)
    two_digit,
};

/// Fractional second format (milliseconds, etc.)
pub const FractionalSecondFormat = struct {
    /// Number of digits (1-9)
    digits: u8,
};

/// Day period format (AM/PM)
pub const DayPeriodFormat = enum {
    /// Abbreviated (AM, PM)
    abbreviated,
    /// Wide (ante meridiem, post meridiem) - rare
    wide,
    /// Narrow (a, p)
    narrow,
};

/// Era format options
pub const EraFormat = enum {
    /// Abbreviated (AD, BC)
    abbreviated,
    /// Wide (Anno Domini, Before Christ)
    wide,
    /// Narrow (A, B)
    narrow,
};

/// Time zone format options
pub const TimeZoneFormat = enum {
    /// Short specific (PST)
    short_specific,
    /// Long specific (Pacific Standard Time)
    long_specific,
    /// Short generic (PT)
    short_generic,
    /// Long generic (Pacific Time)
    long_generic,
    /// ISO 8601 basic (-0800)
    iso_basic,
    /// ISO 8601 extended (-08:00)
    iso_extended,
};

/// Pattern token - represents one element in a parsed pattern
pub const PatternToken = union(enum) {
    /// Literal text to output directly
    literal: []const u8,
    /// Year field
    year: YearFormat,
    /// Month field
    month: MonthFormat,
    /// Day of month field
    day: DayFormat,
    /// Day of week field
    weekday: WeekdayFormat,
    /// Hour field
    hour: HourFormat,
    /// Minute field
    minute: MinuteFormat,
    /// Second field
    second: SecondFormat,
    /// Fractional seconds
    fractional_second: FractionalSecondFormat,
    /// AM/PM marker
    day_period: DayPeriodFormat,
    /// Era (AD/BC)
    era: EraFormat,
    /// Time zone
    time_zone: TimeZoneFormat,
};

// ============================================================================
// Pattern Parser
// ============================================================================

/// Pattern parsing errors
pub const PatternError = error{
    /// Unterminated quoted literal
    UnterminatedQuote,
    /// Invalid pattern character
    InvalidPatternCharacter,
    /// Memory allocation failed
    OutOfMemory,
};

/// Parse a CLDR/ICU pattern string into tokens.
///
/// ## Pattern Syntax
/// - Field symbols: y, M, d, E, H, h, m, s, S, a, G, z, etc.
/// - Literals: 'text' or '' for single quote
/// - Unquoted characters: passed through as literals
///
/// ## Parameters
/// - `allocator`: Memory allocator for token storage
/// - `pattern`: Pattern string to parse
///
/// ## Returns
/// Array of PatternTokens. Caller owns the memory.
pub fn parsePattern(allocator: Allocator, pattern: []const u8) PatternError![]PatternToken {
    var tokens = List(PatternToken).init(allocator);
    errdefer {
        for (tokens.items()) |token| {
            switch (token) {
                .literal => |s| allocator.free(s),
                else => {},
            }
        }
        tokens.deinit();
    }

    var i: usize = 0;
    while (i < pattern.len) {
        const c = pattern[i];

        if (c == '\'') {
            // Quoted literal
            const literal = try parseQuotedLiteral(allocator, pattern, &i);
            try tokens.append(.{ .literal = literal });
        } else if (isPatternChar(c)) {
            // Field symbol - count consecutive occurrences
            const start = i;
            while (i < pattern.len and pattern[i] == c) : (i += 1) {}
            const count = i - start;

            const token = parseFieldSymbol(c, count);
            try tokens.append(token);
        } else {
            // Unquoted literal character - collect consecutive literals
            const start = i;
            while (i < pattern.len and !isPatternChar(pattern[i]) and pattern[i] != '\'') : (i += 1) {}

            const literal = try allocator.dupe(u8, pattern[start..i]);
            try tokens.append(.{ .literal = literal });
        }
    }

    return tokens.toOwnedSlice();
}

/// Free pattern tokens
pub fn freeTokens(allocator: Allocator, tokens: []PatternToken) void {
    for (tokens) |token| {
        switch (token) {
            .literal => |s| allocator.free(s),
            else => {},
        }
    }
    allocator.free(tokens);
}

/// Check if character is a pattern field symbol
fn isPatternChar(c: u8) bool {
    return switch (c) {
        'y', 'Y', 'u', 'U', 'r' => true, // Year
        'Q', 'q' => true, // Quarter
        'M', 'L' => true, // Month
        'w', 'W' => true, // Week
        'd', 'D', 'F', 'g' => true, // Day
        'E', 'e', 'c' => true, // Weekday
        'a', 'b', 'B' => true, // Period
        'h', 'H', 'k', 'K' => true, // Hour
        'm' => true, // Minute
        's' => true, // Second
        'S' => true, // Fractional second
        'A' => true, // Millisecond of day
        'z', 'Z', 'O', 'v', 'V', 'X', 'x' => true, // Time zone
        'G' => true, // Era
        else => false,
    };
}

/// Parse a quoted literal from the pattern
fn parseQuotedLiteral(allocator: Allocator, pattern: []const u8, pos: *usize) PatternError![]const u8 {
    var i = pos.* + 1; // Skip opening quote

    // Check for escaped quote ''
    if (i < pattern.len and pattern[i] == '\'') {
        pos.* = i + 1;
        return try allocator.dupe(u8, "'");
    }

    // Find closing quote
    var literal_parts = List(u8).init(allocator);
    defer literal_parts.deinit();

    while (i < pattern.len) {
        if (pattern[i] == '\'') {
            // Check for escaped quote within literal
            if (i + 1 < pattern.len and pattern[i + 1] == '\'') {
                try literal_parts.append('\'');
                i += 2;
            } else {
                // End of quoted literal
                pos.* = i + 1;
                return try literal_parts.toOwnedSlice();
            }
        } else {
            try literal_parts.append(pattern[i]);
            i += 1;
        }
    }

    return PatternError.UnterminatedQuote;
}

/// Parse a field symbol into a PatternToken
fn parseFieldSymbol(c: u8, count: usize) PatternToken {
    return switch (c) {
        // Year
        'y', 'Y' => blk: {
            if (count == 2) {
                break :blk .{ .year = .two_digit };
            } else if (count >= 4) {
                break :blk .{ .year = .full };
            } else {
                break :blk .{ .year = .numeric };
            }
        },

        // Month
        'M', 'L' => blk: {
            if (count == 1) {
                break :blk .{ .month = .numeric };
            } else if (count == 2) {
                break :blk .{ .month = .two_digit };
            } else if (count == 3) {
                break :blk .{ .month = .abbreviated };
            } else if (count == 4) {
                break :blk .{ .month = .wide };
            } else {
                break :blk .{ .month = .narrow };
            }
        },

        // Day
        'd' => blk: {
            if (count >= 2) {
                break :blk .{ .day = .two_digit };
            } else {
                break :blk .{ .day = .numeric };
            }
        },

        // Weekday
        'E', 'e', 'c' => blk: {
            if (count <= 3) {
                break :blk .{ .weekday = .abbreviated };
            } else if (count == 4) {
                break :blk .{ .weekday = .wide };
            } else if (count == 5) {
                break :blk .{ .weekday = .narrow };
            } else {
                break :blk .{ .weekday = .short };
            }
        },

        // Hour (24-hour)
        'H' => .{ .hour = .{
            .cycle = .h23,
            .two_digit = count >= 2,
        } },

        // Hour (0-11)
        'K' => .{ .hour = .{
            .cycle = .h11,
            .two_digit = count >= 2,
        } },

        // Hour (12-hour)
        'h' => .{ .hour = .{
            .cycle = .h12,
            .two_digit = count >= 2,
        } },

        // Hour (1-24)
        'k' => .{ .hour = .{
            .cycle = .h24,
            .two_digit = count >= 2,
        } },

        // Minute
        'm' => blk: {
            if (count >= 2) {
                break :blk .{ .minute = .two_digit };
            } else {
                break :blk .{ .minute = .numeric };
            }
        },

        // Second
        's' => blk: {
            if (count >= 2) {
                break :blk .{ .second = .two_digit };
            } else {
                break :blk .{ .second = .numeric };
            }
        },

        // Fractional second
        'S' => .{ .fractional_second = .{
            .digits = @intCast(@min(count, 9)),
        } },

        // Day period (AM/PM)
        'a' => blk: {
            if (count <= 3) {
                break :blk .{ .day_period = .abbreviated };
            } else if (count == 4) {
                break :blk .{ .day_period = .wide };
            } else {
                break :blk .{ .day_period = .narrow };
            }
        },

        // Era
        'G' => blk: {
            if (count <= 3) {
                break :blk .{ .era = .abbreviated };
            } else if (count == 4) {
                break :blk .{ .era = .wide };
            } else {
                break :blk .{ .era = .narrow };
            }
        },

        // Time zone
        'z' => blk: {
            if (count < 4) {
                break :blk .{ .time_zone = .short_specific };
            } else {
                break :blk .{ .time_zone = .long_specific };
            }
        },

        'Z' => blk: {
            if (count < 4) {
                break :blk .{ .time_zone = .iso_basic };
            } else {
                break :blk .{ .time_zone = .long_specific };
            }
        },

        'v' => blk: {
            if (count < 4) {
                break :blk .{ .time_zone = .short_generic };
            } else {
                break :blk .{ .time_zone = .long_generic };
            }
        },

        'X', 'x' => .{ .time_zone = .iso_extended },

        // Default: treat as literal (shouldn't happen with isPatternChar)
        else => .{ .literal = &[_]u8{c} },
    };
}

// ============================================================================
// Locale Data Interface
// ============================================================================

/// Month names for a locale
pub const MonthNames = struct {
    /// Wide month names (January, February, etc.)
    wide: [12][]const u8,
    /// Abbreviated month names (Jan, Feb, etc.)
    abbreviated: [12][]const u8,
    /// Narrow month names (J, F, etc.)
    narrow: [12][]const u8,
};

/// Weekday names for a locale
pub const WeekdayNames = struct {
    /// Wide weekday names (Sunday, Monday, etc.)
    wide: [7][]const u8,
    /// Abbreviated weekday names (Sun, Mon, etc.)
    abbreviated: [7][]const u8,
    /// Narrow weekday names (S, M, etc.)
    narrow: [7][]const u8,
    /// Short weekday names (Su, Mo, etc.)
    short: [7][]const u8,
};

/// Day period names
pub const DayPeriodNames = struct {
    /// AM marker
    am: []const u8,
    /// PM marker
    pm: []const u8,
};

/// Era names
pub const EraNames = struct {
    /// Wide era names (Before Christ, Anno Domini)
    wide: [2][]const u8,
    /// Abbreviated era names (BC, AD)
    abbreviated: [2][]const u8,
    /// Narrow era names (B, A)
    narrow: [2][]const u8,
};

/// Locale data for date/time formatting
pub const LocaleData = struct {
    /// Month names
    months: MonthNames,
    /// Weekday names
    weekdays: WeekdayNames,
    /// Day periods (AM/PM)
    day_periods: DayPeriodNames,
    /// Era names
    eras: EraNames,

    /// Default English (en-US) locale data
    pub const english = LocaleData{
        .months = .{
            .wide = .{
                "January", "February", "March",     "April",   "May",      "June",
                "July",    "August",   "September", "October", "November", "December",
            },
            .abbreviated = .{
                "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
            },
            .narrow = .{
                "J", "F", "M", "A", "M", "J",
                "J", "A", "S", "O", "N", "D",
            },
        },
        .weekdays = .{
            .wide = .{
                "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
            },
            .abbreviated = .{
                "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
            },
            .narrow = .{
                "S", "M", "T", "W", "T", "F", "S",
            },
            .short = .{
                "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa",
            },
        },
        .day_periods = .{
            .am = "AM",
            .pm = "PM",
        },
        .eras = .{
            .wide = .{ "Before Christ", "Anno Domini" },
            .abbreviated = .{ "BC", "AD" },
            .narrow = .{ "B", "A" },
        },
    };

    /// German (de-DE) locale data
    pub const german = LocaleData{
        .months = .{
            .wide = .{
                "Januar", "Februar", "März",     "April",   "Mai",      "Juni",
                "Juli",   "August",  "September", "Oktober", "November", "Dezember",
            },
            .abbreviated = .{
                "Jan.", "Feb.", "März", "Apr.", "Mai",  "Juni",
                "Juli", "Aug.", "Sep.",  "Okt.", "Nov.", "Dez.",
            },
            .narrow = .{
                "J", "F", "M", "A", "M", "J",
                "J", "A", "S", "O", "N", "D",
            },
        },
        .weekdays = .{
            .wide = .{
                "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag",
            },
            .abbreviated = .{
                "So.", "Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa.",
            },
            .narrow = .{
                "S", "M", "D", "M", "D", "F", "S",
            },
            .short = .{
                "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa",
            },
        },
        .day_periods = .{
            .am = "AM",
            .pm = "PM",
        },
        .eras = .{
            .wide = .{ "v. Chr.", "n. Chr." },
            .abbreviated = .{ "v. Chr.", "n. Chr." },
            .narrow = .{ "v", "n" },
        },
    };

    /// Japanese (ja-JP) locale data
    pub const japanese = LocaleData{
        .months = .{
            .wide = .{
                "1月", "2月", "3月", "4月",  "5月",  "6月",
                "7月", "8月", "9月", "10月", "11月", "12月",
            },
            .abbreviated = .{
                "1月", "2月", "3月", "4月",  "5月",  "6月",
                "7月", "8月", "9月", "10月", "11月", "12月",
            },
            .narrow = .{
                "1", "2", "3", "4",  "5",  "6",
                "7", "8", "9", "10", "11", "12",
            },
        },
        .weekdays = .{
            .wide = .{
                "日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日",
            },
            .abbreviated = .{
                "日", "月", "火", "水", "木", "金", "土",
            },
            .narrow = .{
                "日", "月", "火", "水", "木", "金", "土",
            },
            .short = .{
                "日", "月", "火", "水", "木", "金", "土",
            },
        },
        .day_periods = .{
            .am = "午前",
            .pm = "午後",
        },
        .eras = .{
            .wide = .{ "紀元前", "西暦" },
            .abbreviated = .{ "BC", "AD" },
            .narrow = .{ "B", "A" },
        },
    };

    /// French (fr-FR) locale data
    pub const french = LocaleData{
        .months = .{
            .wide = .{
                "janvier", "février", "mars",      "avril",   "mai",      "juin",
                "juillet", "août",    "septembre", "octobre", "novembre", "décembre",
            },
            .abbreviated = .{
                "janv.", "févr.", "mars",  "avr.", "mai",  "juin",
                "juil.", "août",  "sept.", "oct.", "nov.", "déc.",
            },
            .narrow = .{
                "J", "F", "M", "A", "M", "J",
                "J", "A", "S", "O", "N", "D",
            },
        },
        .weekdays = .{
            .wide = .{
                "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi",
            },
            .abbreviated = .{
                "dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam.",
            },
            .narrow = .{
                "D", "L", "M", "M", "J", "V", "S",
            },
            .short = .{
                "di", "lu", "ma", "me", "je", "ve", "sa",
            },
        },
        .day_periods = .{
            .am = "AM",
            .pm = "PM",
        },
        .eras = .{
            .wide = .{ "avant Jésus-Christ", "après Jésus-Christ" },
            .abbreviated = .{ "av. J.-C.", "ap. J.-C." },
            .narrow = .{ "av.", "ap." },
        },
    };

    /// Spanish (es-ES) locale data
    pub const spanish = LocaleData{
        .months = .{
            .wide = .{
                "enero", "febrero", "marzo",      "abril",   "mayo",      "junio",
                "julio", "agosto",  "septiembre", "octubre", "noviembre", "diciembre",
            },
            .abbreviated = .{
                "ene", "feb", "mar", "abr", "may", "jun",
                "jul", "ago", "sep", "oct", "nov", "dic",
            },
            .narrow = .{
                "E", "F", "M", "A", "M", "J",
                "J", "A", "S", "O", "N", "D",
            },
        },
        .weekdays = .{
            .wide = .{
                "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado",
            },
            .abbreviated = .{
                "dom", "lun", "mar", "mié", "jue", "vie", "sáb",
            },
            .narrow = .{
                "D", "L", "M", "X", "J", "V", "S",
            },
            .short = .{
                "do", "lu", "ma", "mi", "ju", "vi", "sá",
            },
        },
        .day_periods = .{
            .am = "a. m.",
            .pm = "p. m.",
        },
        .eras = .{
            .wide = .{ "antes de Cristo", "después de Cristo" },
            .abbreviated = .{ "a. C.", "d. C." },
            .narrow = .{ "a", "d" },
        },
    };
};

// ============================================================================
// Formatter
// ============================================================================

/// Format a DateTime using parsed pattern tokens.
///
/// ## Parameters
/// - `allocator`: Memory allocator for result string
/// - `tokens`: Parsed pattern tokens from parsePattern
/// - `datetime`: DateTime to format
/// - `locale_data`: Locale-specific names (months, weekdays, etc.)
///
/// ## Returns
/// Formatted string. Caller owns the memory.
pub fn formatDateTime(
    allocator: Allocator,
    tokens: []const PatternToken,
    datetime: DateTime,
    locale_data: *const LocaleData,
) Allocator.Error![]u8 {
    var result = List(u8).init(allocator);
    errdefer result.deinit();

    for (tokens) |token| {
        try formatToken(&result, token, datetime, locale_data);
    }

    return result.toOwnedSlice();
}

/// Format a single token
fn formatToken(
    result: *List(u8),
    token: PatternToken,
    datetime: DateTime,
    locale_data: *const LocaleData,
) Allocator.Error!void {
    switch (token) {
        .literal => |s| {
            try result.appendSlice(s);
        },

        .year => |format| {
            try formatYear(result, datetime.year, format);
        },

        .month => |format| {
            try formatMonth(result, datetime.month, format, locale_data);
        },

        .day => |format| {
            try formatDay(result, datetime.day, format);
        },

        .weekday => |format| {
            const dow = datetime.dayOfWeek();
            try formatWeekday(result, dow, format, locale_data);
        },

        .hour => |format| {
            try formatHour(result, datetime.hour, format);
        },

        .minute => |format| {
            try formatMinute(result, datetime.minute, format);
        },

        .second => |format| {
            try formatSecond(result, datetime.second, format);
        },

        .fractional_second => |format| {
            try formatFractionalSecond(result, datetime.nanosecond, format);
        },

        .day_period => |format| {
            try formatDayPeriod(result, datetime.hour, format, locale_data);
        },

        .era => |format| {
            try formatEra(result, datetime.year, format, locale_data);
        },

        .time_zone => |format| {
            try formatTimeZone(result, format);
        },
    }
}

fn formatYear(result: *List(u8), year: i32, format: YearFormat) Allocator.Error!void {
    var buf: [16]u8 = undefined;
    const abs_year: u32 = @intCast(if (year < 0) -year else year);

    switch (format) {
        .two_digit => {
            // Last 2 digits
            const two_digit = @mod(abs_year, 100);
            const len = std.fmt.formatIntBuf(&buf, two_digit, 10, .lower, .{ .width = 2, .fill = '0' });
            try result.appendSlice(buf[0..len]);
        },
        .full => {
            // 4+ digits
            const len = std.fmt.formatIntBuf(&buf, abs_year, 10, .lower, .{ .width = 4, .fill = '0' });
            try result.appendSlice(buf[0..len]);
        },
        .numeric => {
            // Minimum digits
            const len = std.fmt.formatIntBuf(&buf, abs_year, 10, .lower, .{});
            try result.appendSlice(buf[0..len]);
        },
    }
}

fn formatMonth(result: *List(u8), month: u8, format: MonthFormat, locale_data: *const LocaleData) Allocator.Error!void {
    switch (format) {
        .numeric => {
            var buf: [4]u8 = undefined;
            const len = std.fmt.formatIntBuf(&buf, month, 10, .lower, .{});
            try result.appendSlice(buf[0..len]);
        },
        .two_digit => {
            var buf: [4]u8 = undefined;
            const len = std.fmt.formatIntBuf(&buf, month, 10, .lower, .{ .width = 2, .fill = '0' });
            try result.appendSlice(buf[0..len]);
        },
        .abbreviated => {
            if (month >= 1 and month <= 12) {
                try result.appendSlice(locale_data.months.abbreviated[month - 1]);
            }
        },
        .wide => {
            if (month >= 1 and month <= 12) {
                try result.appendSlice(locale_data.months.wide[month - 1]);
            }
        },
        .narrow => {
            if (month >= 1 and month <= 12) {
                try result.appendSlice(locale_data.months.narrow[month - 1]);
            }
        },
    }
}

fn formatDay(result: *List(u8), day: u8, format: DayFormat) Allocator.Error!void {
    var buf: [4]u8 = undefined;
    switch (format) {
        .numeric => {
            const len = std.fmt.formatIntBuf(&buf, day, 10, .lower, .{});
            try result.appendSlice(buf[0..len]);
        },
        .two_digit => {
            const len = std.fmt.formatIntBuf(&buf, day, 10, .lower, .{ .width = 2, .fill = '0' });
            try result.appendSlice(buf[0..len]);
        },
    }
}

fn formatWeekday(result: *List(u8), dow: u8, format: WeekdayFormat, locale_data: *const LocaleData) Allocator.Error!void {
    if (dow >= 7) return;

    switch (format) {
        .abbreviated => try result.appendSlice(locale_data.weekdays.abbreviated[dow]),
        .wide => try result.appendSlice(locale_data.weekdays.wide[dow]),
        .narrow => try result.appendSlice(locale_data.weekdays.narrow[dow]),
        .short => try result.appendSlice(locale_data.weekdays.short[dow]),
    }
}

fn formatHour(result: *List(u8), hour: u8, format: HourFormat) Allocator.Error!void {
    var display_hour: u8 = hour;

    switch (format.cycle) {
        .h12 => {
            // 1-12
            display_hour = if (hour == 0) 12 else if (hour > 12) hour - 12 else hour;
        },
        .h11 => {
            // 0-11
            display_hour = if (hour >= 12) hour - 12 else hour;
        },
        .h23 => {
            // 0-23 (no change)
        },
        .h24 => {
            // 1-24
            display_hour = if (hour == 0) 24 else hour;
        },
    }

    var buf: [4]u8 = undefined;
    if (format.two_digit) {
        const len = std.fmt.formatIntBuf(&buf, display_hour, 10, .lower, .{ .width = 2, .fill = '0' });
        try result.appendSlice(buf[0..len]);
    } else {
        const len = std.fmt.formatIntBuf(&buf, display_hour, 10, .lower, .{});
        try result.appendSlice(buf[0..len]);
    }
}

fn formatMinute(result: *List(u8), minute: u8, format: MinuteFormat) Allocator.Error!void {
    var buf: [4]u8 = undefined;
    switch (format) {
        .numeric => {
            const len = std.fmt.formatIntBuf(&buf, minute, 10, .lower, .{});
            try result.appendSlice(buf[0..len]);
        },
        .two_digit => {
            const len = std.fmt.formatIntBuf(&buf, minute, 10, .lower, .{ .width = 2, .fill = '0' });
            try result.appendSlice(buf[0..len]);
        },
    }
}

fn formatSecond(result: *List(u8), second: u8, format: SecondFormat) Allocator.Error!void {
    var buf: [4]u8 = undefined;
    switch (format) {
        .numeric => {
            const len = std.fmt.formatIntBuf(&buf, second, 10, .lower, .{});
            try result.appendSlice(buf[0..len]);
        },
        .two_digit => {
            const len = std.fmt.formatIntBuf(&buf, second, 10, .lower, .{ .width = 2, .fill = '0' });
            try result.appendSlice(buf[0..len]);
        },
    }
}

fn formatFractionalSecond(result: *List(u8), nanosecond: u32, format: FractionalSecondFormat) Allocator.Error!void {
    // Convert nanoseconds to the requested precision
    var buf: [16]u8 = undefined;
    const len = std.fmt.formatIntBuf(&buf, nanosecond, 10, .lower, .{ .width = 9, .fill = '0' });

    // Take only the requested number of digits
    const digits = @min(format.digits, @as(u8, @intCast(len)));
    try result.appendSlice(buf[0..digits]);
}

fn formatDayPeriod(result: *List(u8), hour: u8, format: DayPeriodFormat, locale_data: *const LocaleData) Allocator.Error!void {
    const is_pm = hour >= 12;
    _ = format; // All formats use same names for now (simplified)

    if (is_pm) {
        try result.appendSlice(locale_data.day_periods.pm);
    } else {
        try result.appendSlice(locale_data.day_periods.am);
    }
}

fn formatEra(result: *List(u8), year: i32, format: EraFormat, locale_data: *const LocaleData) Allocator.Error!void {
    const era_index: usize = if (year < 1) 0 else 1; // BC = 0, AD = 1

    switch (format) {
        .abbreviated => try result.appendSlice(locale_data.eras.abbreviated[era_index]),
        .wide => try result.appendSlice(locale_data.eras.wide[era_index]),
        .narrow => try result.appendSlice(locale_data.eras.narrow[era_index]),
    }
}

fn formatTimeZone(result: *List(u8), format: TimeZoneFormat) Allocator.Error!void {
    // For now, output UTC since we don't have timezone data
    // This will be expanded when timezone support is added
    switch (format) {
        .short_specific => try result.appendSlice("UTC"),
        .long_specific => try result.appendSlice("Coordinated Universal Time"),
        .short_generic => try result.appendSlice("UTC"),
        .long_generic => try result.appendSlice("Coordinated Universal Time"),
        .iso_basic => try result.appendSlice("+0000"),
        .iso_extended => try result.appendSlice("+00:00"),
    }
}

// ============================================================================
// formatToParts
// ============================================================================

/// Part type for formatToParts output
pub const PartType = enum {
    /// Literal text
    literal,
    /// Year
    year,
    /// Month
    month,
    /// Day
    day,
    /// Weekday
    weekday,
    /// Hour
    hour,
    /// Minute
    minute,
    /// Second
    second,
    /// Fractional second
    fractional_second,
    /// Day period (AM/PM)
    day_period,
    /// Era
    era,
    /// Time zone
    time_zone,
};

/// A single part from formatToParts
pub const Part = struct {
    /// Type of this part
    type: PartType,
    /// Formatted value
    value: []const u8,
};

/// Format a DateTime to parts using parsed pattern tokens.
///
/// Similar to formatDateTime but returns separate parts for each field,
/// matching the behavior of Intl.DateTimeFormat.formatToParts().
///
/// ## Parameters
/// - `allocator`: Memory allocator for result
/// - `tokens`: Parsed pattern tokens from parsePattern
/// - `datetime`: DateTime to format
/// - `locale_data`: Locale-specific names
///
/// ## Returns
/// Array of Parts. Caller owns the memory for both the array and values.
pub fn formatToParts(
    allocator: Allocator,
    tokens: []const PatternToken,
    datetime: DateTime,
    locale_data: *const LocaleData,
) Allocator.Error![]Part {
    var parts = List(Part).init(allocator);
    errdefer {
        for (parts.items()) |part| {
            allocator.free(part.value);
        }
        parts.deinit();
    }

    for (tokens) |token| {
        // Format the token to a temporary buffer
        var temp = List(u8).init(allocator);
        defer temp.deinit();

        try formatToken(&temp, token, datetime, locale_data);

        if (temp.len > 0) {
            const value = try temp.toOwnedSlice();
            errdefer allocator.free(value);

            const part_type: PartType = switch (token) {
                .literal => .literal,
                .year => .year,
                .month => .month,
                .day => .day,
                .weekday => .weekday,
                .hour => .hour,
                .minute => .minute,
                .second => .second,
                .fractional_second => .fractional_second,
                .day_period => .day_period,
                .era => .era,
                .time_zone => .time_zone,
            };

            try parts.append(.{
                .type = part_type,
                .value = value,
            });
        }
    }

    return parts.toOwnedSlice();
}

/// Free parts array
pub fn freeParts(allocator: Allocator, parts: []Part) void {
    for (parts) |part| {
        allocator.free(part.value);
    }
    allocator.free(parts);
}

// ============================================================================
// Tests
// ============================================================================

test "parsePattern - simple date pattern" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy-MM-dd");
    defer freeTokens(allocator, tokens);

    try std.testing.expectEqual(@as(usize, 5), tokens.len);

    // yyyy
    try std.testing.expectEqual(PatternToken{ .year = .full }, tokens[0]);
    // -
    try std.testing.expectEqualStrings("-", tokens[1].literal);
    // MM
    try std.testing.expectEqual(PatternToken{ .month = .two_digit }, tokens[2]);
    // -
    try std.testing.expectEqualStrings("-", tokens[3].literal);
    // dd
    try std.testing.expectEqual(PatternToken{ .day = .two_digit }, tokens[4]);
}

test "parsePattern - time pattern" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "HH:mm:ss");
    defer freeTokens(allocator, tokens);

    try std.testing.expectEqual(@as(usize, 5), tokens.len);
}

test "parsePattern - quoted literal" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy 'at' HH:mm");
    defer freeTokens(allocator, tokens);

    try std.testing.expectEqual(@as(usize, 6), tokens.len);
    try std.testing.expectEqualStrings("at", tokens[2].literal);
}

test "parsePattern - escaped quote" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy''MM");
    defer freeTokens(allocator, tokens);

    try std.testing.expectEqual(@as(usize, 3), tokens.len);
    try std.testing.expectEqualStrings("'", tokens[1].literal);
}

test "parsePattern - month formats" {
    const allocator = std.testing.allocator;

    const tokens_m = try parsePattern(allocator, "M");
    defer freeTokens(allocator, tokens_m);
    try std.testing.expectEqual(MonthFormat.numeric, tokens_m[0].month);

    const tokens_mm = try parsePattern(allocator, "MM");
    defer freeTokens(allocator, tokens_mm);
    try std.testing.expectEqual(MonthFormat.two_digit, tokens_mm[0].month);

    const tokens_mmm = try parsePattern(allocator, "MMM");
    defer freeTokens(allocator, tokens_mmm);
    try std.testing.expectEqual(MonthFormat.abbreviated, tokens_mmm[0].month);

    const tokens_mmmm = try parsePattern(allocator, "MMMM");
    defer freeTokens(allocator, tokens_mmmm);
    try std.testing.expectEqual(MonthFormat.wide, tokens_mmmm[0].month);

    const tokens_mmmmm = try parsePattern(allocator, "MMMMM");
    defer freeTokens(allocator, tokens_mmmmm);
    try std.testing.expectEqual(MonthFormat.narrow, tokens_mmmmm[0].month);
}

test "formatDateTime - simple date" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy-MM-dd");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 12,
        .minute = 30,
        .second = 45,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2023-11-14", result);
}

test "formatDateTime - full datetime" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy-MM-dd HH:mm:ss");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 12,
        .minute = 30,
        .second = 45,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2023-11-14 12:30:45", result);
}

test "formatDateTime - 12-hour with AM/PM" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "h:mm a");
    defer freeTokens(allocator, tokens);

    // Morning
    const morning = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 9,
        .minute = 30,
        .second = 0,
        .nanosecond = 0,
    };
    const morning_result = try formatDateTime(allocator, tokens, morning, &LocaleData.english);
    defer allocator.free(morning_result);
    try std.testing.expectEqualStrings("9:30 AM", morning_result);

    // Afternoon
    const afternoon = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 14,
        .minute = 30,
        .second = 0,
        .nanosecond = 0,
    };
    const afternoon_result = try formatDateTime(allocator, tokens, afternoon, &LocaleData.english);
    defer allocator.free(afternoon_result);
    try std.testing.expectEqualStrings("2:30 PM", afternoon_result);
}

test "formatDateTime - month names" {
    const allocator = std.testing.allocator;

    // Wide month
    const tokens_wide = try parsePattern(allocator, "MMMM d, yyyy");
    defer freeTokens(allocator, tokens_wide);

    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens_wide, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("November 14, 2023", result);
}

test "formatDateTime - weekday names" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "EEEE, MMMM d, yyyy");
    defer freeTokens(allocator, tokens);

    // 2023-11-14 is a Tuesday
    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Tuesday, November 14, 2023", result);
}

test "formatDateTime - fractional seconds" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "HH:mm:ss.SSS");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 12,
        .minute = 30,
        .second = 45,
        .nanosecond = 123456789,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("12:30:45.123", result);
}

test "formatDateTime - two-digit year" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yy/MM/dd");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("23/11/14", result);
}

test "formatDateTime - era" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "y G");
    defer freeTokens(allocator, tokens);

    // AD year
    const ad = DateTime{ .year = 2023, .month = 1, .day = 1, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    const ad_result = try formatDateTime(allocator, tokens, ad, &LocaleData.english);
    defer allocator.free(ad_result);
    try std.testing.expectEqualStrings("2023 AD", ad_result);

    // BC year (year 0 and below is BC)
    const bc = DateTime{ .year = 0, .month = 1, .day = 1, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    const bc_result = try formatDateTime(allocator, tokens, bc, &LocaleData.english);
    defer allocator.free(bc_result);
    try std.testing.expectEqualStrings("0 BC", bc_result);
}

test "formatToParts - basic" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy-MM-dd");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const parts = try formatToParts(allocator, tokens, datetime, &LocaleData.english);
    defer freeParts(allocator, parts);

    try std.testing.expectEqual(@as(usize, 5), parts.len);

    try std.testing.expectEqual(PartType.year, parts[0].type);
    try std.testing.expectEqualStrings("2023", parts[0].value);

    try std.testing.expectEqual(PartType.literal, parts[1].type);
    try std.testing.expectEqualStrings("-", parts[1].value);

    try std.testing.expectEqual(PartType.month, parts[2].type);
    try std.testing.expectEqualStrings("11", parts[2].value);

    try std.testing.expectEqual(PartType.literal, parts[3].type);
    try std.testing.expectEqualStrings("-", parts[3].value);

    try std.testing.expectEqual(PartType.day, parts[4].type);
    try std.testing.expectEqualStrings("14", parts[4].value);
}

test "formatDateTime - midnight 12-hour" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "h:mm a");
    defer freeTokens(allocator, tokens);

    // Midnight (hour 0) should display as 12 AM
    const midnight = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };
    const result = try formatDateTime(allocator, tokens, midnight, &LocaleData.english);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("12:00 AM", result);
}

test "formatDateTime - noon 12-hour" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "h:mm a");
    defer freeTokens(allocator, tokens);

    // Noon (hour 12) should display as 12 PM
    const noon = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 12,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };
    const result = try formatDateTime(allocator, tokens, noon, &LocaleData.english);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("12:00 PM", result);
}

test "formatDateTime - German locale" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "EEEE, d. MMMM yyyy");
    defer freeTokens(allocator, tokens);

    // 2023-11-14 is a Tuesday (Dienstag in German)
    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.german);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Dienstag, 14. November 2023", result);
}

test "formatDateTime - Japanese locale" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "yyyy年M月d日 EEEE");
    defer freeTokens(allocator, tokens);

    // 2023-11-14 is a Tuesday (火曜日 in Japanese)
    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.japanese);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2023年11月14日 火曜日", result);
}

test "formatDateTime - Japanese AM/PM" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "a h:mm");
    defer freeTokens(allocator, tokens);

    const morning = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 9,
        .minute = 30,
        .second = 0,
        .nanosecond = 0,
    };
    const morning_result = try formatDateTime(allocator, tokens, morning, &LocaleData.japanese);
    defer allocator.free(morning_result);
    try std.testing.expectEqualStrings("午前 9:30", morning_result);

    const afternoon = DateTime{
        .year = 2023,
        .month = 1,
        .day = 1,
        .hour = 14,
        .minute = 30,
        .second = 0,
        .nanosecond = 0,
    };
    const afternoon_result = try formatDateTime(allocator, tokens, afternoon, &LocaleData.japanese);
    defer allocator.free(afternoon_result);
    try std.testing.expectEqualStrings("午後 2:30", afternoon_result);
}

test "formatDateTime - French locale" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "EEEE d MMMM yyyy");
    defer freeTokens(allocator, tokens);

    // 2023-11-14 is a Tuesday (mardi in French)
    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.french);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("mardi 14 novembre 2023", result);
}

test "formatDateTime - Spanish locale with era" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "d 'de' MMMM 'de' yyyy G");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 3,
        .day = 15,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.spanish);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("15 de marzo de 2023 d. C.", result);
}

test "formatDateTime - complex pattern with literals" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "'Date:' yyyy-MM-dd 'Time:' HH:mm:ss");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 6,
        .day = 15,
        .hour = 14,
        .minute = 30,
        .second = 45,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Date: 2023-06-15 Time: 14:30:45", result);
}

test "formatToParts - with weekday and month names" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "EEEE, MMMM d");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = 2023,
        .month = 11,
        .day = 14,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const parts = try formatToParts(allocator, tokens, datetime, &LocaleData.english);
    defer freeParts(allocator, parts);

    try std.testing.expectEqual(@as(usize, 5), parts.len);

    try std.testing.expectEqual(PartType.weekday, parts[0].type);
    try std.testing.expectEqualStrings("Tuesday", parts[0].value);

    try std.testing.expectEqual(PartType.literal, parts[1].type);
    try std.testing.expectEqualStrings(", ", parts[1].value);

    try std.testing.expectEqual(PartType.month, parts[2].type);
    try std.testing.expectEqualStrings("November", parts[2].value);

    try std.testing.expectEqual(PartType.literal, parts[3].type);
    try std.testing.expectEqualStrings(" ", parts[3].value);

    try std.testing.expectEqual(PartType.day, parts[4].type);
    try std.testing.expectEqualStrings("14", parts[4].value);
}

test "parsePattern - standalone L month format" {
    const allocator = std.testing.allocator;

    // L is standalone month (same handling as M for now)
    const tokens = try parsePattern(allocator, "LLLL yyyy");
    defer freeTokens(allocator, tokens);

    try std.testing.expectEqual(@as(usize, 3), tokens.len);
    try std.testing.expectEqual(MonthFormat.wide, tokens[0].month);
}

test "parsePattern - hour cycles" {
    const allocator = std.testing.allocator;

    // H = 0-23
    const tokens_h23 = try parsePattern(allocator, "HH");
    defer freeTokens(allocator, tokens_h23);
    try std.testing.expectEqual(HourFormat.HourCycle.h23, tokens_h23[0].hour.cycle);

    // h = 1-12
    const tokens_h12 = try parsePattern(allocator, "hh");
    defer freeTokens(allocator, tokens_h12);
    try std.testing.expectEqual(HourFormat.HourCycle.h12, tokens_h12[0].hour.cycle);

    // K = 0-11
    const tokens_h11 = try parsePattern(allocator, "KK");
    defer freeTokens(allocator, tokens_h11);
    try std.testing.expectEqual(HourFormat.HourCycle.h11, tokens_h11[0].hour.cycle);

    // k = 1-24
    const tokens_h24 = try parsePattern(allocator, "kk");
    defer freeTokens(allocator, tokens_h24);
    try std.testing.expectEqual(HourFormat.HourCycle.h24, tokens_h24[0].hour.cycle);
}

test "formatDateTime - negative year (BCE)" {
    const allocator = std.testing.allocator;

    const tokens = try parsePattern(allocator, "y GGGG");
    defer freeTokens(allocator, tokens);

    const datetime = DateTime{
        .year = -44, // 44 BCE (Julius Caesar's assassination)
        .month = 3,
        .day = 15,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    const result = try formatDateTime(allocator, tokens, datetime, &LocaleData.english);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("44 Before Christ", result);
}
