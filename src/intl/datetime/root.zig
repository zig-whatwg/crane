//! DateTime Formatting Module
//!
//! Implements date/time formatting according to ECMA-402 and CLDR/UTS #35.
//!
//! ## Components
//!
//! - `DateTime`: Core date/time representation with calendar calculations
//! - `pattern`: CLDR pattern parsing and formatting engine
//! - `LocaleData`: Locale-specific month/weekday/era names
//!
//! ## Supported Locales
//!
//! Built-in locale data for:
//! - `LocaleData.english` (en-US)
//! - `LocaleData.german` (de-DE)
//! - `LocaleData.japanese` (ja-JP)
//! - `LocaleData.french` (fr-FR)
//! - `LocaleData.spanish` (es-ES)
//!
//! ## Example
//!
//! ```zig
//! const datetime = @import("datetime");
//! const DateTime = datetime.DateTime;
//! const pattern = datetime.pattern;
//!
//! const allocator = std.testing.allocator;
//!
//! // Parse a CLDR pattern
//! const tokens = try pattern.parsePattern(allocator, "yyyy-MM-dd HH:mm:ss");
//! defer pattern.freeTokens(allocator, tokens);
//!
//! // Create a DateTime
//! const dt = DateTime.fromTimestamp(1699964445); // 2023-11-14 12:30:45
//!
//! // Format to string
//! const result = try pattern.formatDateTime(allocator, tokens, dt, &pattern.LocaleData.english);
//! defer allocator.free(result);
//! // result = "2023-11-14 12:30:45"
//!
//! // Or format to parts
//! const parts = try pattern.formatToParts(allocator, tokens, dt, &pattern.LocaleData.english);
//! defer pattern.freeParts(allocator, parts);
//!
//! // Use different locale
//! const de_result = try pattern.formatDateTime(allocator, tokens, dt, &pattern.LocaleData.german);
//! defer allocator.free(de_result);
//! ```

const std = @import("std");

// Core DateTime type
pub const datetime = @import("datetime.zig");
pub const DateTime = datetime.DateTime;

// Pattern-based formatting
pub const pattern = @import("pattern.zig");

// Re-export pattern types for convenience
pub const PatternToken = pattern.PatternToken;
pub const PatternError = pattern.PatternError;
pub const LocaleData = pattern.LocaleData;
pub const Part = pattern.Part;
pub const PartType = pattern.PartType;

// Re-export format option types
pub const YearFormat = pattern.YearFormat;
pub const MonthFormat = pattern.MonthFormat;
pub const DayFormat = pattern.DayFormat;
pub const WeekdayFormat = pattern.WeekdayFormat;
pub const HourFormat = pattern.HourFormat;
pub const MinuteFormat = pattern.MinuteFormat;
pub const SecondFormat = pattern.SecondFormat;
pub const FractionalSecondFormat = pattern.FractionalSecondFormat;
pub const DayPeriodFormat = pattern.DayPeriodFormat;
pub const EraFormat = pattern.EraFormat;
pub const TimeZoneFormat = pattern.TimeZoneFormat;

// Re-export locale data types
pub const MonthNames = pattern.MonthNames;
pub const WeekdayNames = pattern.WeekdayNames;
pub const DayPeriodNames = pattern.DayPeriodNames;
pub const EraNames = pattern.EraNames;

// Re-export main functions
pub const parsePattern = pattern.parsePattern;
pub const freeTokens = pattern.freeTokens;
pub const formatDateTime = pattern.formatDateTime;
pub const formatToParts = pattern.formatToParts;
pub const freeParts = pattern.freeParts;

test {
    _ = datetime;
    _ = pattern;
}
