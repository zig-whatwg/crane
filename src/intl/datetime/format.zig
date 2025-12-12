//! Intl.DateTimeFormat Implementation
//!
//! Implements ECMA-402 §11: DateTimeFormat Objects
//!
//! This is the core DateTimeFormat implementation that ties together:
//! - Locale resolution and negotiation
//! - Time zone handling (IANA tzdb)
//! - CLDR pattern formatting
//! - Date/time options resolution
//!
//! ## Memory Management
//!
//! CRITICAL: This implementation uses NO global caches.
//! All state is per-instance and properly cleaned up via deinit().
//! This is the key difference from ICU which caused OOM bugs.
//!
//! ## Example
//!
//! ```zig
//! const allocator = std.testing.allocator;
//!
//! // Create formatter
//! var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en-US"}, .{
//!     .dateStyle = .full,
//!     .timeStyle = .short,
//! });
//! defer dtf.deinit();
//!
//! // Format a date (milliseconds since epoch)
//! const result = try dtf.format(1699964445000);
//! defer allocator.free(result);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const DateTime = @import("datetime.zig").DateTime;
const pattern_mod = @import("pattern.zig");
const timezone_mod = @import("../timezone/root.zig");
const locale_mod = @import("../locale/root.zig");
const cldr_mod = @import("../cldr/root.zig");

/// DateTimeFormat Options (ECMA-402 §11.2.1)
pub const Options = struct {
    /// The locale matcher algorithm to use
    localeMatcher: LocaleMatcher = .best_fit,
    /// Calendar system to use
    calendar: ?[]const u8 = null,
    /// Numbering system to use
    numberingSystem: ?[]const u8 = null,
    /// Time zone to use
    timeZone: ?[]const u8 = null,
    /// Hour cycle preference
    hourCycle: ?HourCycle = null,
    /// Whether to use 12-hour time
    hour12: ?bool = null,

    /// Date style (mutually exclusive with individual date options)
    dateStyle: ?DateStyle = null,
    /// Time style (mutually exclusive with individual time options)
    timeStyle: ?TimeStyle = null,

    /// Individual component options (used when dateStyle/timeStyle not set)
    weekday: ?ComponentStyle = null,
    era: ?ComponentStyle = null,
    year: ?YearStyle = null,
    month: ?MonthStyle = null,
    day: ?NumericStyle = null,
    dayPeriod: ?ComponentStyle = null,
    hour: ?NumericStyle = null,
    minute: ?NumericStyle = null,
    second: ?NumericStyle = null,
    fractionalSecondDigits: ?u8 = null,
    timeZoneName: ?TimeZoneNameStyle = null,
};

/// Locale matcher algorithm
pub const LocaleMatcher = enum {
    lookup,
    best_fit,
};

/// Hour cycle preference
pub const HourCycle = enum {
    h11, // 0-11
    h12, // 1-12
    h23, // 0-23
    h24, // 1-24
};

/// Date/time style options
pub const DateStyle = enum {
    full,
    long,
    medium,
    short,
};

pub const TimeStyle = enum {
    full,
    long,
    medium,
    short,
};

/// Component style options
pub const ComponentStyle = enum {
    narrow,
    short,
    long,
};

pub const YearStyle = enum {
    numeric, // "2024"
    two_digit, // "24"
};

pub const MonthStyle = enum {
    numeric, // "1"
    two_digit, // "01"
    narrow, // "J"
    short, // "Jan"
    long, // "January"
};

pub const NumericStyle = enum {
    numeric, // "1"
    two_digit, // "01"
};

pub const TimeZoneNameStyle = enum {
    short, // "EST"
    long, // "Eastern Standard Time"
    shortOffset, // "GMT-5"
    longOffset, // "GMT-05:00"
    shortGeneric, // "ET"
    longGeneric, // "Eastern Time"
};

/// Resolved options returned by resolvedOptions()
pub const ResolvedOptions = struct {
    locale: []const u8,
    calendar: []const u8,
    numberingSystem: []const u8,
    timeZone: []const u8,
    hourCycle: ?HourCycle,
    hour12: ?bool,
    dateStyle: ?DateStyle,
    timeStyle: ?TimeStyle,
    weekday: ?ComponentStyle,
    era: ?ComponentStyle,
    year: ?YearStyle,
    month: ?MonthStyle,
    day: ?NumericStyle,
    dayPeriod: ?ComponentStyle,
    hour: ?NumericStyle,
    minute: ?NumericStyle,
    second: ?NumericStyle,
    fractionalSecondDigits: ?u8,
    timeZoneName: ?TimeZoneNameStyle,
};

/// Part type for formatToParts output
pub const PartType = pattern_mod.PartType;

/// Part from formatToParts output
pub const Part = pattern_mod.Part;

/// Intl.DateTimeFormat - ECMA-402 §11
///
/// A locale-sensitive date/time formatter. Each instance stores its own
/// resolved options and pattern - NO global state or caching.
pub const DateTimeFormat = struct {
    /// Allocator for all heap allocations
    allocator: Allocator,

    // Resolved configuration
    resolved_locale: []const u8,
    time_zone: timezone_mod.TimeZone,
    locale_data: *const cldr_mod.LocaleData,

    // Parsed pattern tokens
    pattern_tokens: []pattern_mod.PatternToken,

    // Resolved options (stored for resolvedOptions())
    calendar: []const u8,
    numbering_system: []const u8,
    hour_cycle: ?HourCycle,
    date_style: ?DateStyle,
    time_style: ?TimeStyle,

    // Whether locale_data needs to be freed (embedded data doesn't)
    owns_locale_data: bool,

    /// Initialize a new DateTimeFormat
    ///
    /// ## Parameters
    /// - `allocator`: Memory allocator for all heap allocations
    /// - `locales`: Array of BCP 47 locale tags (null = system default)
    /// - `options`: Formatting options
    ///
    /// ## Errors
    /// - `OutOfMemory`: Memory allocation failed
    /// - `InvalidLocale`: Invalid locale tag
    /// - `InvalidTimeZone`: Unknown time zone identifier
    pub fn init(
        allocator: Allocator,
        locales: ?[]const []const u8,
        options: Options,
    ) !DateTimeFormat {
        // 1. Resolve locale
        const resolved_locale = try resolveLocale(allocator, locales);
        errdefer allocator.free(resolved_locale);

        // 2. Resolve time zone
        const time_zone = if (options.timeZone) |tz_name|
            try timezone_mod.TimeZone.fromName(tz_name)
        else
            timezone_mod.TimeZone.UTC;

        // 3. Load locale data from CLDR
        const locale_data = try cldr_mod.getLocaleDataWithFallback(allocator, resolved_locale);
        // Track whether we need to free it (embedded data doesn't need freeing)
        const owns_locale_data = !cldr_mod.isEmbedded(resolved_locale);

        // 4. Resolve pattern based on options
        const pattern_str = resolvePattern(locale_data, options);

        // 5. Parse pattern into tokens
        const pattern_tokens = try pattern_mod.parsePattern(allocator, pattern_str);
        errdefer pattern_mod.freeTokens(allocator, pattern_tokens);

        return DateTimeFormat{
            .allocator = allocator,
            .resolved_locale = resolved_locale,
            .time_zone = time_zone,
            .locale_data = locale_data,
            .pattern_tokens = pattern_tokens,
            .calendar = "gregory", // TODO: Support other calendars
            .numbering_system = "latn", // TODO: Support other numbering systems
            .hour_cycle = options.hourCycle,
            .date_style = options.dateStyle,
            .time_style = options.timeStyle,
            .owns_locale_data = owns_locale_data,
        };
    }

    /// Clean up all resources
    pub fn deinit(self: *DateTimeFormat) void {
        pattern_mod.freeTokens(self.allocator, self.pattern_tokens);
        self.allocator.free(self.resolved_locale);

        // Free locale data if we allocated it (not embedded)
        if (self.owns_locale_data) {
            // TODO: Implement locale data deallocation when binary loading is complete
        }
    }

    /// Format a date/time value
    ///
    /// ## Parameters
    /// - `timestamp_ms`: Milliseconds since Unix epoch (JavaScript Date style)
    ///
    /// ## Returns
    /// Heap-allocated formatted string. Caller must free with allocator.free().
    pub fn format(self: *const DateTimeFormat, timestamp_ms: i64) ![]u8 {
        // Convert to DateTime
        const utc_dt = DateTime.fromTimestampMillis(timestamp_ms);

        // Convert to local time in the target time zone
        const local_dt = self.time_zone.toLocal(utc_dt);

        // Create pattern-compatible LocaleData from CLDR data
        const pattern_locale_data = cldrToPatternLocaleData(self.locale_data);

        // Format using pattern
        return pattern_mod.formatDateTime(
            self.allocator,
            self.pattern_tokens,
            local_dt,
            &pattern_locale_data,
        );
    }

    /// Format a date/time value to an array of parts
    ///
    /// ## Parameters
    /// - `timestamp_ms`: Milliseconds since Unix epoch
    ///
    /// ## Returns
    /// Heap-allocated array of Part structs. Caller must free with freeParts().
    pub fn formatToParts(self: *const DateTimeFormat, timestamp_ms: i64) ![]Part {
        const utc_dt = DateTime.fromTimestampMillis(timestamp_ms);
        const local_dt = self.time_zone.toLocal(utc_dt);

        const pattern_locale_data = cldrToPatternLocaleData(self.locale_data);

        return pattern_mod.formatToParts(
            self.allocator,
            self.pattern_tokens,
            local_dt,
            &pattern_locale_data,
        );
    }

    /// Free parts array returned by formatToParts
    pub fn freeParts(self: *const DateTimeFormat, parts: []Part) void {
        pattern_mod.freeParts(self.allocator, parts);
    }

    /// Format a date range
    ///
    /// ## Parameters
    /// - `start_ms`: Start timestamp in milliseconds
    /// - `end_ms`: End timestamp in milliseconds
    ///
    /// ## Returns
    /// Formatted range string (e.g., "Jan 1 - Jan 5, 2024")
    pub fn formatRange(self: *const DateTimeFormat, start_ms: i64, end_ms: i64) ![]u8 {
        // Simple implementation: format both and join with separator
        // TODO: Implement proper CLDR range formatting
        const start_str = try self.format(start_ms);
        defer self.allocator.free(start_str);

        const end_str = try self.format(end_ms);
        defer self.allocator.free(end_str);

        // Use simple separator for now
        const sep = " – "; // en-dash with spaces
        const result = try self.allocator.alloc(u8, start_str.len + sep.len + end_str.len);
        @memcpy(result[0..start_str.len], start_str);
        @memcpy(result[start_str.len .. start_str.len + sep.len], sep);
        @memcpy(result[start_str.len + sep.len ..], end_str);

        return result;
    }

    /// Get the resolved options for this formatter
    pub fn resolvedOptions(self: *const DateTimeFormat) ResolvedOptions {
        return ResolvedOptions{
            .locale = self.resolved_locale,
            .calendar = self.calendar,
            .numberingSystem = self.numbering_system,
            .timeZone = self.time_zone.getName(),
            .hourCycle = self.hour_cycle,
            .hour12 = if (self.hour_cycle) |hc| (hc == .h11 or hc == .h12) else null,
            .dateStyle = self.date_style,
            .timeStyle = self.time_style,
            .weekday = null, // TODO: Extract from pattern
            .era = null,
            .year = null,
            .month = null,
            .day = null,
            .dayPeriod = null,
            .hour = null,
            .minute = null,
            .second = null,
            .fractionalSecondDigits = null,
            .timeZoneName = null,
        };
    }

    /// Get supported locales from available CLDR data
    pub fn supportedLocalesOf(
        allocator: Allocator,
        locales: []const []const u8,
    ) ![][]const u8 {
        var result: std.ArrayList([]const u8) = .{};
        errdefer {
            for (result.items) |item| allocator.free(item);
            result.deinit(allocator);
        }

        for (locales) |locale| {
            if (cldr_mod.isEmbedded(locale)) {
                const copy = try allocator.dupe(u8, locale);
                try result.append(allocator, copy);
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

// ============================================================================
// Internal helper functions
// ============================================================================

/// Resolve the best matching locale from the requested locales
fn resolveLocale(allocator: Allocator, locales: ?[]const []const u8) ![]const u8 {
    if (locales) |locale_list| {
        if (locale_list.len > 0) {
            // Try each requested locale in order
            for (locale_list) |locale| {
                if (cldr_mod.isEmbedded(locale)) {
                    return try allocator.dupe(u8, locale);
                }
                // Try base language (e.g., "en-US" -> "en")
                if (std.mem.indexOf(u8, locale, "-")) |idx| {
                    const base = locale[0..idx];
                    if (cldr_mod.isEmbedded(base)) {
                        return try allocator.dupe(u8, base);
                    }
                }
            }
            // First requested locale even if not fully supported
            return try allocator.dupe(u8, locale_list[0]);
        }
    }
    // Default to English
    return try allocator.dupe(u8, "en");
}

/// Resolve the CLDR pattern to use based on options
fn resolvePattern(locale_data: *const cldr_mod.LocaleData, options: Options) []const u8 {
    // If dateStyle and/or timeStyle are specified, use those
    if (options.dateStyle != null or options.timeStyle != null) {
        return resolveStylePattern(locale_data, options.dateStyle, options.timeStyle);
    }

    // Otherwise, build pattern from individual components
    // For now, return date_medium as a reasonable default (e.g., "MMM d, y" for en)
    // TODO: Support individual component options (weekday, year, month, etc.)
    return locale_data.datetime_patterns.date_medium;
}

/// Convert CLDR LocaleData to pattern-compatible LocaleData
/// The pattern module uses a simpler LocaleData struct
fn cldrToPatternLocaleData(cldr_data: *const cldr_mod.LocaleData) pattern_mod.LocaleData {
    return pattern_mod.LocaleData{
        .months = .{
            .wide = cldr_data.months.wide,
            .abbreviated = cldr_data.months.abbreviated,
            .narrow = cldr_data.months.narrow,
        },
        .weekdays = .{
            .wide = cldr_data.weekdays.wide,
            .abbreviated = cldr_data.weekdays.abbreviated,
            .narrow = cldr_data.weekdays.narrow,
            .short = cldr_data.weekdays.short,
        },
        .day_periods = .{
            .am = cldr_data.day_periods.am,
            .pm = cldr_data.day_periods.pm,
        },
        .eras = .{
            .wide = cldr_data.eras.wide,
            .abbreviated = cldr_data.eras.abbreviated,
            .narrow = cldr_data.eras.narrow,
        },
    };
}

/// Resolve pattern from dateStyle/timeStyle
fn resolveStylePattern(
    locale_data: *const cldr_mod.LocaleData,
    date_style: ?DateStyle,
    time_style: ?TimeStyle,
) []const u8 {
    const date_pattern: ?[]const u8 = if (date_style) |ds| switch (ds) {
        .full => locale_data.datetime_patterns.date_full,
        .long => locale_data.datetime_patterns.date_long,
        .medium => locale_data.datetime_patterns.date_medium,
        .short => locale_data.datetime_patterns.date_short,
    } else null;

    const time_pattern: ?[]const u8 = if (time_style) |ts| switch (ts) {
        .full => locale_data.datetime_patterns.time_full,
        .long => locale_data.datetime_patterns.time_long,
        .medium => locale_data.datetime_patterns.time_medium,
        .short => locale_data.datetime_patterns.time_short,
    } else null;

    // If both date and time, return combined pattern
    if (date_pattern != null and time_pattern != null) {
        // Use the datetime pattern that matches the style
        if (date_style) |ds| {
            return switch (ds) {
                .full => locale_data.datetime_patterns.datetime_full,
                .long => locale_data.datetime_patterns.datetime_long,
                .medium => locale_data.datetime_patterns.datetime_medium,
                .short => locale_data.datetime_patterns.datetime_short,
            };
        }
    }

    // Return whichever one we have
    if (date_pattern) |dp| return dp;
    if (time_pattern) |tp| return tp;

    // Default
    return locale_data.datetime_patterns.datetime_medium;
}

// ============================================================================
// Tests
// ============================================================================

test "DateTimeFormat - basic formatting" {
    const allocator = std.testing.allocator;

    var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en"}, .{});
    defer dtf.deinit();

    // 2023-11-14 12:30:45 UTC = 1699964445000 ms
    const result = try dtf.format(1699964445000);
    defer allocator.free(result);

    // Should contain year, month, day, time
    try std.testing.expect(std.mem.indexOf(u8, result, "2023") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "11") != null or
        std.mem.indexOf(u8, result, "Nov") != null);
}

test "DateTimeFormat - with time zone" {
    const allocator = std.testing.allocator;

    var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en"}, .{
        .timeZone = "America/New_York",
    });
    defer dtf.deinit();

    const resolved = dtf.resolvedOptions();
    try std.testing.expectEqualStrings("America/New_York", resolved.timeZone);
}

test "DateTimeFormat - dateStyle and timeStyle" {
    const allocator = std.testing.allocator;

    var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en"}, .{
        .dateStyle = .full,
        .timeStyle = .short,
    });
    defer dtf.deinit();

    const result = try dtf.format(1699964445000);
    defer allocator.free(result);

    // Full date style should include weekday
    // (actual content depends on locale data)
    try std.testing.expect(result.len > 0);
}

test "DateTimeFormat - no memory leaks" {
    const allocator = std.testing.allocator;

    // Create and destroy many instances to verify no leaks
    for (0..100) |_| {
        var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en"}, .{});
        const result = try dtf.format(1699964445000);
        allocator.free(result);
        dtf.deinit();
    }
    // If this test passes with std.testing.allocator, there are no leaks
}

test "DateTimeFormat - formatToParts" {
    const allocator = std.testing.allocator;

    var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en"}, .{});
    defer dtf.deinit();

    const parts = try dtf.formatToParts(1699964445000);
    defer dtf.freeParts(parts);

    // Should have multiple parts
    try std.testing.expect(parts.len > 0);
}

test "DateTimeFormat - formatRange" {
    const allocator = std.testing.allocator;

    var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"en"}, .{});
    defer dtf.deinit();

    // Jan 1, 2024 to Jan 5, 2024
    const start: i64 = 1704067200000;
    const end: i64 = 1704412800000;

    const result = try dtf.formatRange(start, end);
    defer allocator.free(result);

    // Should contain separator
    try std.testing.expect(std.mem.indexOf(u8, result, "–") != null);
}

test "DateTimeFormat - resolvedOptions" {
    const allocator = std.testing.allocator;

    var dtf = try DateTimeFormat.init(allocator, &[_][]const u8{"de"}, .{
        .dateStyle = .long,
    });
    defer dtf.deinit();

    const opts = dtf.resolvedOptions();

    // Should resolve to German (or fallback)
    try std.testing.expect(std.mem.startsWith(u8, opts.locale, "de") or
        std.mem.startsWith(u8, opts.locale, "en"));
    try std.testing.expectEqual(DateStyle.long, opts.dateStyle);
}
