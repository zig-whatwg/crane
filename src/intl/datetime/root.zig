//! DateTime Formatting Module
//!
//! Implements date/time formatting according to ECMA-402 and CLDR/UTS #35.
//!
//! ## Components
//!
//! - `DateTime`: Core date/time representation with calendar calculations
//! - `pattern`: CLDR pattern parsing and formatting engine
//! - `LocaleData`: Locale-specific month/weekday/era names
//! - `TimeZone`: Time zone support (see `timezone` module)
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
//! const TimeZone = datetime.TimeZone;
//!
//! const allocator = std.testing.allocator;
//!
//! // Parse a CLDR pattern
//! const tokens = try pattern.parsePattern(allocator, "yyyy-MM-dd HH:mm:ss");
//! defer pattern.freeTokens(allocator, tokens);
//!
//! // Create a DateTime (UTC)
//! const dt = DateTime.fromTimestamp(1699964445); // 2023-11-14 12:30:45 UTC
//!
//! // Convert to local time in a specific timezone
//! const ny_tz = try TimeZone.fromName("America/New_York");
//! const local_dt = ny_tz.toLocal(dt);
//!
//! // Format to string
//! const result = try pattern.formatDateTime(allocator, tokens, local_dt, &pattern.LocaleData.english);
//! defer allocator.free(result);
//!
//! // Or format to parts
//! const parts = try pattern.formatToParts(allocator, tokens, dt, &pattern.LocaleData.english);
//! defer pattern.freeParts(allocator, parts);
//! ```

const std = @import("std");

// Core DateTime type
pub const datetime = @import("datetime.zig");
pub const DateTime = datetime.DateTime;

// Time zone support (re-exported from timezone module)
pub const timezone = @import("../timezone/root.zig");
pub const TimeZone = timezone.TimeZone;
pub const IanaZone = timezone.IanaZone;
pub const TimeZoneError = timezone.TimeZoneError;

// Pattern-based formatting
pub const pattern = @import("pattern.zig");

// Intl.DateTimeFormat implementation
pub const format = @import("format.zig");
pub const DateTimeFormat = format.DateTimeFormat;
pub const DateTimeFormatOptions = format.Options;

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
    _ = format;
}
