//! Intl.NumberFormat WPT-Style Tests
//!
//! Comprehensive tests for number formatting implementation following
//! ECMA-402 specification and Web Platform Test patterns.
//!
//! ## Test Categories
//!
//! 1. Number symbol tests - decimal, grouping separators
//! 2. Locale-specific formatting tests
//! 3. Special values tests - NaN, Infinity
//! 4. Edge cases - large numbers, precision

const std = @import("std");
const intl = @import("intl");
const cldr = intl.cldr;
const cldr_embedded = cldr.embedded;

// ============================================================================
// Test Utilities
// ============================================================================

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

// ============================================================================
// Number Symbols Tests
// ============================================================================

test "Intl.NumberFormat: English number symbols" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ",", "grouping separator");
    try assert_string_equals(locale_data.number_symbols.percent, "%", "percent sign");
    try assert_string_equals(locale_data.number_symbols.minus, "-", "minus sign");
    try assert_string_equals(locale_data.number_symbols.plus, "+", "plus sign");
    try assert_string_equals(locale_data.number_symbols.exponential, "E", "exponential");
    try assert_string_equals(locale_data.number_symbols.infinity, "∞", "infinity");
    try assert_string_equals(locale_data.number_symbols.nan, "NaN", "NaN");
}

test "Intl.NumberFormat: German number symbols" {
    const locale_data = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;

    // German swaps decimal and grouping separators
    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal separator (comma)");
    try assert_string_equals(locale_data.number_symbols.group, ".", "grouping separator (dot)");
}

test "Intl.NumberFormat: French number symbols" {
    const locale_data = cldr_embedded.getLocale("fr") orelse return error.LocaleNotFound;

    // French uses comma for decimal and narrow non-breaking space for grouping
    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal separator (comma)");
    // French uses narrow no-break space (U+202F) or thin space for grouping
    try assert_true(locale_data.number_symbols.group.len > 0, "grouping separator exists");
}

test "Intl.NumberFormat: Arabic number symbols" {
    const locale_data = cldr_embedded.getLocale("ar") orelse return error.LocaleNotFound;

    // Arabic uses . for decimal, , for grouping (may use Arabic numerals)
    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ",", "grouping separator");
}

test "Intl.NumberFormat: Swiss German number symbols" {
    const locale_data = cldr_embedded.getLocale("de-CH") orelse return error.LocaleNotFound;

    // Swiss German uses ' (RIGHT SINGLE QUOTATION MARK U+2019) for grouping, . for decimal
    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, "’", "grouping separator (apostrophe)");
}

test "Intl.NumberFormat: Italian number symbols" {
    const locale_data = cldr_embedded.getLocale("it") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ".", "grouping separator");
}

test "Intl.NumberFormat: Spanish number symbols" {
    const locale_data = cldr_embedded.getLocale("es") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ".", "grouping separator");
}

test "Intl.NumberFormat: Portuguese number symbols" {
    const locale_data = cldr_embedded.getLocale("pt") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ".", "grouping separator");
}

test "Intl.NumberFormat: Russian number symbols" {
    const locale_data = cldr_embedded.getLocale("ru") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ",", "decimal separator");
    // Russian uses non-breaking space for grouping
    try assert_true(locale_data.number_symbols.group.len > 0, "grouping separator exists");
}

test "Intl.NumberFormat: Japanese number symbols" {
    const locale_data = cldr_embedded.getLocale("ja") orelse return error.LocaleNotFound;

    // Japanese uses . for decimal and , for grouping
    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ",", "grouping separator");
}

test "Intl.NumberFormat: Chinese number symbols" {
    const locale_data = cldr_embedded.getLocale("zh") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ",", "grouping separator");
}

test "Intl.NumberFormat: Korean number symbols" {
    const locale_data = cldr_embedded.getLocale("ko") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.decimal, ".", "decimal separator");
    try assert_string_equals(locale_data.number_symbols.group, ",", "grouping separator");
}

// ============================================================================
// NaN and Infinity Symbol Tests
// ============================================================================

test "Intl.NumberFormat: English NaN and Infinity" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.nan, "NaN", "NaN");
    try assert_string_equals(locale_data.number_symbols.infinity, "∞", "infinity");
}

test "Intl.NumberFormat: Russian NaN" {
    const locale_data = cldr_embedded.getLocale("ru") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.nan, "не число", "Russian NaN");
}

test "Intl.NumberFormat: Arabic NaN" {
    const locale_data = cldr_embedded.getLocale("ar") orelse return error.LocaleNotFound;

    // Arabic NaN uses NO-BREAK SPACE (U+00A0) between words
    try assert_string_equals(locale_data.number_symbols.nan, "ليس\u{00A0}رقمًا", "Arabic NaN");
}

test "Intl.NumberFormat: Chinese Traditional NaN" {
    const locale_data = cldr_embedded.getLocale("zh-Hant") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.nan, "非數值", "Chinese Traditional NaN");
}

// ============================================================================
// Regional Variant Number Symbol Tests
// ============================================================================

test "Intl.NumberFormat: en-US vs en-GB" {
    const en_us = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    const en_gb = cldr_embedded.getLocale("en-GB") orelse return error.LocaleNotFound;

    // Both US and UK use same number symbols
    try assert_string_equals(en_us.number_symbols.decimal, en_gb.number_symbols.decimal, "decimal should match");
    try assert_string_equals(en_us.number_symbols.group, en_gb.number_symbols.group, "group should match");
}

test "Intl.NumberFormat: es vs es-MX" {
    const es = cldr_embedded.getLocale("es") orelse return error.LocaleNotFound;
    const es_mx = cldr_embedded.getLocale("es-MX") orelse return error.LocaleNotFound;

    // Spain uses comma for decimal, Mexico uses dot
    try assert_string_equals(es.number_symbols.decimal, ",", "Spain decimal");
    try assert_string_equals(es_mx.number_symbols.decimal, ".", "Mexico decimal");
}

test "Intl.NumberFormat: pt vs pt-PT" {
    const pt = cldr_embedded.getLocale("pt") orelse return error.LocaleNotFound;
    const pt_pt = cldr_embedded.getLocale("pt-PT") orelse return error.LocaleNotFound;

    // Both use comma for decimal
    try assert_string_equals(pt.number_symbols.decimal, ",", "Brazil decimal");
    try assert_string_equals(pt_pt.number_symbols.decimal, ",", "Portugal decimal");
}

test "Intl.NumberFormat: de vs de-AT vs de-CH" {
    const de = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;
    const de_at = cldr_embedded.getLocale("de-AT") orelse return error.LocaleNotFound;
    const de_ch = cldr_embedded.getLocale("de-CH") orelse return error.LocaleNotFound;

    // Germany and Austria: comma decimal, dot grouping
    try assert_string_equals(de.number_symbols.decimal, ",", "Germany decimal");
    try assert_string_equals(de_at.number_symbols.decimal, ",", "Austria decimal");

    // Switzerland: dot decimal, apostrophe grouping (U+2019 RIGHT SINGLE QUOTATION MARK)
    try assert_string_equals(de_ch.number_symbols.decimal, ".", "Switzerland decimal");
    try assert_string_equals(de_ch.number_symbols.group, "’", "Switzerland grouping");
}

// ============================================================================
// Exponential Notation Tests
// ============================================================================

test "Intl.NumberFormat: English exponential" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;

    try assert_string_equals(locale_data.number_symbols.exponential, "E", "exponential");
}

test "Intl.NumberFormat: Swedish exponential" {
    const locale_data = cldr_embedded.getLocale("sv-SE") orelse return error.LocaleNotFound;

    // Swedish uses ×10^ for exponential
    try assert_string_equals(locale_data.number_symbols.exponential, "×10^", "Swedish exponential");
}

test "Intl.NumberFormat: Australian exponential" {
    const locale_data = cldr_embedded.getLocale("en-AU") orelse return error.LocaleNotFound;

    // Australian English uses lowercase 'e'
    try assert_string_equals(locale_data.number_symbols.exponential, "e", "Australian exponential");
}

// ============================================================================
// Plus and Minus Sign Tests
// ============================================================================

test "Intl.NumberFormat: plus and minus signs across locales" {
    const locales = [_][]const u8{
        "en", "de", "fr", "es", "it", "pt", "zh", "ja", "ko",
    };

    for (locales) |locale_tag| {
        const locale_data = cldr_embedded.getLocale(locale_tag) orelse continue;
        try assert_true(locale_data.number_symbols.plus.len > 0, locale_tag);
        try assert_true(locale_data.number_symbols.minus.len > 0, locale_tag);
    }
}

// ============================================================================
// Percent Sign Tests
// ============================================================================

test "Intl.NumberFormat: percent signs" {
    const en = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    try assert_string_equals(en.number_symbols.percent, "%", "English percent");

    // Arabic has special percent (with RTL marks)
    const ar = cldr_embedded.getLocale("ar") orelse return error.LocaleNotFound;
    try assert_true(ar.number_symbols.percent.len > 0, "Arabic percent exists");
}

// ============================================================================
// Comprehensive Locale Coverage Tests
// ============================================================================

test "Intl.NumberFormat: all locales have required symbols" {
    for (cldr_embedded.embedded_locales) |locale| {
        try assert_true(locale.number_symbols.decimal.len > 0, locale.tag);
        try assert_true(locale.number_symbols.group.len > 0, locale.tag);
        try assert_true(locale.number_symbols.percent.len > 0, locale.tag);
        try assert_true(locale.number_symbols.minus.len > 0, locale.tag);
        try assert_true(locale.number_symbols.plus.len > 0, locale.tag);
        try assert_true(locale.number_symbols.exponential.len > 0, locale.tag);
        try assert_true(locale.number_symbols.infinity.len > 0, locale.tag);
        try assert_true(locale.number_symbols.nan.len > 0, locale.tag);
    }
}

test "Intl.NumberFormat: infinity symbol is universal" {
    // Most locales use ∞ for infinity
    var infinity_count: usize = 0;
    for (cldr_embedded.embedded_locales) |locale| {
        if (std.mem.eql(u8, locale.number_symbols.infinity, "∞")) {
            infinity_count += 1;
        }
    }
    // Most locales should use ∞
    try assert_true(infinity_count > 25, "Most locales use ∞ for infinity");
}

// ============================================================================
// Basic Number Formatting Tests (using benchmark logic)
// ============================================================================

fn formatDecimalNumber(buf: []u8, value: f64, locale_data: *const cldr_embedded.LocaleData) []const u8 {
    var idx: usize = 0;
    const symbols = locale_data.number_symbols;

    // Handle special cases
    if (std.math.isNan(value)) {
        return symbols.nan;
    }
    if (std.math.isInf(value)) {
        return symbols.infinity;
    }

    // Handle negative
    var abs_value = value;
    if (value < 0) {
        for (symbols.minus) |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
        abs_value = -value;
    }

    // Integer part
    const int_part: u64 = @intFromFloat(@floor(abs_value));
    var temp: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&temp, "{d}", .{int_part}) catch "0";
    for (int_str) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }

    // Decimal part
    const frac_part = abs_value - @floor(abs_value);
    if (frac_part > 0.000001) {
        for (symbols.decimal) |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }

        var remaining = frac_part;
        var digits: u8 = 0;
        while (digits < 3 and remaining > 0.000001) {
            remaining *= 10;
            const digit: u8 = @intFromFloat(@floor(remaining));
            remaining -= @floor(remaining);
            if (idx >= buf.len) break;
            buf[idx] = '0' + digit;
            idx += 1;
            digits += 1;
        }
    }

    return buf[0..idx];
}

test "Intl.NumberFormat: format positive integer" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, 1234, locale_data);
    try assert_string_equals(result, "1234", "positive integer");
}

test "Intl.NumberFormat: format negative integer" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, -1234, locale_data);
    try assert_string_equals(result, "-1234", "negative integer");
}

test "Intl.NumberFormat: format decimal" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, 123.456, locale_data);
    try assert_true(std.mem.startsWith(u8, result, "123."), "decimal starts with 123.");
}

test "Intl.NumberFormat: format German decimal" {
    const locale_data = cldr_embedded.getLocale("de") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, 123.456, locale_data);
    // German uses comma as decimal separator
    try assert_true(std.mem.indexOf(u8, result, ",") != null, "German uses comma for decimal");
}

test "Intl.NumberFormat: format NaN" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, std.math.nan(f64), locale_data);
    try assert_string_equals(result, "NaN", "NaN");
}

test "Intl.NumberFormat: format Infinity" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, std.math.inf(f64), locale_data);
    try assert_string_equals(result, "∞", "Infinity");
}

test "Intl.NumberFormat: format zero" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    const result = formatDecimalNumber(&buf, 0.0, locale_data);
    try assert_string_equals(result, "0", "zero");
}

test "Intl.NumberFormat: format negative zero" {
    const locale_data = cldr_embedded.getLocale("en") orelse return error.LocaleNotFound;
    var buf: [64]u8 = undefined;

    // Negative zero should still format as -0
    const result = formatDecimalNumber(&buf, -0.0, locale_data);
    // Note: -0.0 == 0.0 in IEEE 754, so this tests implementation detail
    try assert_string_equals(result, "0", "negative zero (behaves as zero)");
}
