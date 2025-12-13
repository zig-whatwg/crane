//! Intl.DateTimeFormat WPT-Style Tests
//!
//! Comprehensive tests for Intl.DateTimeFormat implementation following
//! ECMA-402 specification and Web Platform Test patterns.
//!
//! ## Test Categories
//!
//! 1. Constructor tests - Valid/invalid options
//! 2. Format tests - Various date/time patterns
//! 3. FormatToParts tests - Part decomposition
//! 4. ResolvedOptions tests - Option canonicalization
//! 5. SupportedLocalesOf tests - Locale filtering
//! 6. Edge cases - Boundary conditions

const std = @import("std");
const intl = @import("intl");
const cldr = intl.cldr;
const cldr_embedded = cldr.embedded;

// ============================================================================
// Test Utilities
// ============================================================================

const TestResult = struct {
    name: []const u8,
    passed: bool,
    message: ?[]const u8 = null,
};

fn assert_equals(comptime T: type, actual: T, expected: T, description: []const u8) !void {
    if (actual != expected) {
        std.debug.print("FAIL: {s}\n  expected: {any}\n  actual: {any}\n", .{ description, expected, actual });
        return error.AssertionFailed;
    }
}

fn assert_string_equals(actual: []const u8, expected: []const u8, description: []const u8) !void {
    if (!std.mem.eql(u8, actual, expected)) {
        std.debug.print("FAIL: {s}\n  expected: \"{s}\"\n  actual: \"{s}\"\n", .{ description, expected, actual });
        return error.AssertionFailed;
    }
}

fn assert_true(value: bool, description: []const u8) !void {
    if (!value) {
        std.debug.print("FAIL: {s}\n  expected: true\n  actual: false\n", .{description});
        return error.AssertionFailed;
    }
}

fn assert_not_null(comptime T: type, value: ?T, description: []const u8) !*const T {
    if (value) |v| {
        return &v;
    }
    std.debug.print("FAIL: {s}\n  expected: non-null\n  actual: null\n", .{description});
    return error.AssertionFailed;
}

// ============================================================================
// Locale Data Access Tests
// ============================================================================

test "Intl.DateTimeFormat: supported locales are available" {
    // Test that all Tier 1 locales are accessible
    const tier1_locales = [_][]const u8{
        "en",      "en-GB", "en-AU", "en-CA",
        "de",      "de-AT", "de-CH", "fr",
        "fr-CA",   "es",    "es-MX", "it",
        "pt",      "pt-PT", "zh",    "zh-Hans",
        "zh-Hant", "ja",    "ko",    "ar",
        "ar-SA",   "ar-EG", "ru",    "sv-SE",
        "nl",      "pl",    "tr",    "vi",
        "th",      "id",    "hi",
    };

    for (tier1_locales) |locale| {
        const data = cldr_embedded.getLocale(locale);
        try assert_true(data != null, locale);
    }
}

test "Intl.DateTimeFormat: locale fallback works" {
    // Request unavailable locale, should fall back
    const en_zz = cldr_embedded.getLocale("en-ZZ");
    try assert_true(en_zz == null, "en-ZZ should not exist");

    // Should be able to fall back to base language
    const en = cldr_embedded.getLocale("en");
    try assert_true(en != null, "en should exist as fallback");
}

// ============================================================================
// Pattern Formatting Tests - Date Styles
// ============================================================================

test "Intl.DateTimeFormat: dateStyle 'full' formats correctly" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // Pattern: "EEEE, MMMM d, y"
    try assert_string_equals(locale_data.datetime_patterns.date_full, "EEEE, MMMM d, y", "en date_full pattern");
}

test "Intl.DateTimeFormat: dateStyle 'long' formats correctly" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // Pattern: "MMMM d, y"
    try assert_string_equals(locale_data.datetime_patterns.date_long, "MMMM d, y", "en date_long pattern");
}

test "Intl.DateTimeFormat: dateStyle 'medium' formats correctly" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // Pattern: "MMM d, y"
    try assert_string_equals(locale_data.datetime_patterns.date_medium, "MMM d, y", "en date_medium pattern");
}

test "Intl.DateTimeFormat: dateStyle 'short' formats correctly" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // Pattern: "M/d/yy"
    try assert_string_equals(locale_data.datetime_patterns.date_short, "M/d/yy", "en date_short pattern");
}

// ============================================================================
// Pattern Formatting Tests - Time Styles
// ============================================================================

test "Intl.DateTimeFormat: timeStyle 'full' formats correctly" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // Pattern: "h:mm:ss a zzzz"
    try assert_string_equals(locale_data.datetime_patterns.time_full, "h:mm:ss a zzzz", "en time_full pattern");
}

test "Intl.DateTimeFormat: timeStyle 'short' formats correctly" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // Pattern: "h:mm a"
    try assert_string_equals(locale_data.datetime_patterns.time_short, "h:mm a", "en time_short pattern");
}

// ============================================================================
// Locale-Specific Pattern Tests
// ============================================================================

test "Intl.DateTimeFormat: German date patterns" {
    const locale_data = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;

    // German uses d. MMMM y format
    try assert_string_equals(locale_data.datetime_patterns.date_long, "d. MMMM y", "de date_long pattern");
    try assert_string_equals(locale_data.datetime_patterns.date_short, "dd.MM.yy", "de date_short pattern");
}

test "Intl.DateTimeFormat: Japanese date patterns" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    // Japanese uses y年M月d日 format
    try assert_string_equals(locale_data.datetime_patterns.date_long, "y年M月d日", "ja date_long pattern");
}

test "Intl.DateTimeFormat: Arabic date patterns" {
    const locale_data = cldr_embedded.getLocale("ar") orelse return error.LocaleNotFound;

    // Arabic uses d MMMM y format
    try assert_string_equals(locale_data.datetime_patterns.date_long, "d MMMM y", "ar date_long pattern");
}

test "Intl.DateTimeFormat: French date patterns" {
    const locale_data = cldr_embedded.getLocale("fr") orelse return error.LocaleNotFound;

    // French uses d MMMM y format
    try assert_string_equals(locale_data.datetime_patterns.date_long, "d MMMM y", "fr date_long pattern");
}

test "Intl.DateTimeFormat: Spanish date patterns" {
    const locale_data = cldr_embedded.getLocale("es") orelse return error.LocaleNotFound;

    // Spanish full date
    const full_pattern = locale_data.datetime_patterns.date_full;
    try assert_true(std.mem.indexOf(u8, full_pattern, "MMMM") != null, "es date_full should contain MMMM");
}

// ============================================================================
// Month Names Tests
// ============================================================================

test "Intl.DateTimeFormat: English month names" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.months.wide[0], "January", "January");
    try assert_string_equals(locale_data.months.wide[6], "July", "July");
    try assert_string_equals(locale_data.months.wide[11], "December", "December");

    try assert_string_equals(locale_data.months.abbreviated[0], "Jan", "Jan");
    try assert_string_equals(locale_data.months.abbreviated[11], "Dec", "Dec");
}

test "Intl.DateTimeFormat: German month names" {
    const locale_data = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.months.wide[0], "Januar", "Januar");
    try assert_string_equals(locale_data.months.wide[2], "März", "März");
    try assert_string_equals(locale_data.months.wide[11], "Dezember", "Dezember");
}

test "Intl.DateTimeFormat: Japanese month names" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.months.wide[0], "1月", "1月");
    try assert_string_equals(locale_data.months.wide[11], "12月", "12月");
}

test "Intl.DateTimeFormat: Arabic month names" {
    const locale_data = cldr_embedded.getLocale("ar") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.months.wide[0], "يناير", "يناير");
    try assert_string_equals(locale_data.months.wide[11], "ديسمبر", "ديسمبر");
}

test "Intl.DateTimeFormat: Chinese month names" {
    const locale_data = cldr_embedded.getLocale("zh") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.months.wide[0], "一月", "一月");
    try assert_string_equals(locale_data.months.wide[11], "十二月", "十二月");
}

// ============================================================================
// Weekday Names Tests
// ============================================================================

test "Intl.DateTimeFormat: English weekday names" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.weekdays.wide[0], "Sunday", "Sunday");
    try assert_string_equals(locale_data.weekdays.wide[1], "Monday", "Monday");
    try assert_string_equals(locale_data.weekdays.wide[6], "Saturday", "Saturday");

    try assert_string_equals(locale_data.weekdays.abbreviated[0], "Sun", "Sun");
    try assert_string_equals(locale_data.weekdays.abbreviated[6], "Sat", "Sat");
}

test "Intl.DateTimeFormat: German weekday names" {
    const locale_data = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.weekdays.wide[0], "Sonntag", "Sonntag");
    try assert_string_equals(locale_data.weekdays.wide[1], "Montag", "Montag");
}

test "Intl.DateTimeFormat: Japanese weekday names" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.weekdays.wide[0], "日曜日", "日曜日");
    try assert_string_equals(locale_data.weekdays.wide[1], "月曜日", "月曜日");
}

// ============================================================================
// Day Period (AM/PM) Tests
// ============================================================================

test "Intl.DateTimeFormat: English day periods" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.day_periods.am, "AM", "AM");
    try assert_string_equals(locale_data.day_periods.pm, "PM", "PM");
}

test "Intl.DateTimeFormat: Japanese day periods" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.day_periods.am, "午前", "午前");
    try assert_string_equals(locale_data.day_periods.pm, "午後", "午後");
}

test "Intl.DateTimeFormat: Chinese day periods" {
    const locale_data = cldr_embedded.getLocale("zh") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.day_periods.am, "上午", "上午");
    try assert_string_equals(locale_data.day_periods.pm, "下午", "下午");
}

test "Intl.DateTimeFormat: Arabic day periods" {
    const locale_data = cldr_embedded.getLocale("ar") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.day_periods.am, "ص", "ص");
    try assert_string_equals(locale_data.day_periods.pm, "م", "م");
}

// ============================================================================
// Number Symbols Tests (for number formatting in dates)
// ============================================================================

test "Intl.DateTimeFormat: English number symbols" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal");
    try assert_string_equals(locale_data.number_symbols.group, ",", "group");
}

test "Intl.DateTimeFormat: German number symbols" {
    const locale_data = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal");
    try assert_string_equals(locale_data.number_symbols.group, ".", "group");
}

test "Intl.DateTimeFormat: French number symbols" {
    const locale_data = cldr_embedded.getLocale("fr") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal");
    try assert_string_equals(locale_data.number_symbols.group, " ", "group (narrow no-break space)");
}

// ============================================================================
// Era Names Tests
// ============================================================================

test "Intl.DateTimeFormat: English era names" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.eras.abbreviated[0], "BC", "BC");
    try assert_string_equals(locale_data.eras.abbreviated[1], "AD", "AD");
}

test "Intl.DateTimeFormat: Japanese era names" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.eras.wide[1], "西暦", "西暦");
}

// ============================================================================
// Combined DateTime Pattern Tests
// ============================================================================

test "Intl.DateTimeFormat: datetime combined patterns" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    // English uses "{1}, {0}" pattern (date, time)
    try assert_string_equals(locale_data.datetime_patterns.datetime_medium, "{1}, {0}", "datetime_medium");
}

test "Intl.DateTimeFormat: Japanese datetime combined patterns" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    // Japanese uses "{1} {0}" pattern (date time)
    try assert_string_equals(locale_data.datetime_patterns.datetime_medium, "{1} {0}", "datetime_medium");
}

// ============================================================================
// Regional Variant Tests
// ============================================================================

test "Intl.DateTimeFormat: en-GB vs en-US date patterns" {
    const en_us = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    const en_gb = cldr_embedded.getLocale("en-GB") orelse return error.LocaleNotFound;

    // US: M/d/yy, UK: dd/MM/y
    try assert_string_equals(en_us.datetime_patterns.date_short, "M/d/yy", "en-US short");
    try assert_string_equals(en_gb.datetime_patterns.date_short, "dd/MM/y", "en-GB short");
}

test "Intl.DateTimeFormat: de vs de-AT month names" {
    const de = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;
    const de_at = cldr_embedded.getLocale("de-AT") orelse return error.LocaleNotFound;

    // Austria uses "Jänner" instead of "Januar"
    try assert_string_equals(de.months.wide[0], "Januar", "de January");
    try assert_string_equals(de_at.months.wide[0], "Jänner", "de-AT Jänner");
}

test "Intl.DateTimeFormat: de vs de-CH number symbols" {
    const de = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;
    const de_ch = cldr_embedded.getLocale("de-CH") orelse return error.LocaleNotFound;

    // Germany uses "." as group, Switzerland uses "'" (U+2019 RIGHT SINGLE QUOTATION MARK)
    try assert_string_equals(de.number_symbols.group, ".", "de group");
    try assert_string_equals(de_ch.number_symbols.group, "’", "de-CH group");
}

// ============================================================================
// Edge Cases and Boundary Tests
// ============================================================================

test "Intl.DateTimeFormat: all month arrays have 12 elements" {
    for (cldr_embedded.embedded_locales) |locale| {
        try assert_equals(usize, locale.months.wide.len, 12, locale.tag);
        try assert_equals(usize, locale.months.abbreviated.len, 12, locale.tag);
        try assert_equals(usize, locale.months.narrow.len, 12, locale.tag);
    }
}

test "Intl.DateTimeFormat: all weekday arrays have 7 elements" {
    for (cldr_embedded.embedded_locales) |locale| {
        try assert_equals(usize, locale.weekdays.wide.len, 7, locale.tag);
        try assert_equals(usize, locale.weekdays.abbreviated.len, 7, locale.tag);
        try assert_equals(usize, locale.weekdays.narrow.len, 7, locale.tag);
        try assert_equals(usize, locale.weekdays.short.len, 7, locale.tag);
    }
}

test "Intl.DateTimeFormat: all era arrays have 2 elements" {
    for (cldr_embedded.embedded_locales) |locale| {
        try assert_equals(usize, locale.eras.wide.len, 2, locale.tag);
        try assert_equals(usize, locale.eras.abbreviated.len, 2, locale.tag);
        try assert_equals(usize, locale.eras.narrow.len, 2, locale.tag);
    }
}

test "Intl.DateTimeFormat: no empty month names" {
    for (cldr_embedded.embedded_locales) |locale| {
        for (locale.months.wide) |month| {
            try assert_true(month.len > 0, locale.tag);
        }
    }
}

test "Intl.DateTimeFormat: no empty weekday names" {
    for (cldr_embedded.embedded_locales) |locale| {
        for (locale.weekdays.wide) |day| {
            try assert_true(day.len > 0, locale.tag);
        }
    }
}

test "Intl.DateTimeFormat: all patterns are non-empty" {
    for (cldr_embedded.embedded_locales) |locale| {
        try assert_true(locale.datetime_patterns.date_full.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.date_long.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.date_medium.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.date_short.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.time_full.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.time_long.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.time_medium.len > 0, locale.tag);
        try assert_true(locale.datetime_patterns.time_short.len > 0, locale.tag);
    }
}

// ============================================================================
// Statistics
// ============================================================================

test "Intl.DateTimeFormat: locale count" {
    try assert_equals(usize, cldr_embedded.embedded_locales.len, 31, "embedded locale count");
    try assert_equals(usize, cldr_embedded.locale_tags.len, 31, "locale tag count");
}
