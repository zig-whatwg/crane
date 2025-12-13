//! Intl.Locale WPT-Style Tests
//!
//! Comprehensive tests for BCP 47 locale parsing and negotiation
//! following ECMA-402 specification and Web Platform Test patterns.
//!
//! ## Test Categories
//!
//! 1. Locale parsing tests - Valid/invalid BCP 47 tags
//! 2. Locale negotiation tests - Matching algorithms
//! 3. Unicode extension tests - -u- extensions
//! 4. Canonicalization tests - Case normalization

const std = @import("std");
const intl = @import("intl");
const locale_mod = intl.locale;
const Locale = locale_mod.Locale;
const HourCycle = locale_mod.HourCycle;

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

fn assert_null(comptime T: type, value: ?T, description: []const u8) !void {
    if (value != null) {
        std.debug.print("FAIL: {s}\n  expected: null\n  actual: non-null\n", .{description});
        return error.AssertionFailed;
    }
}

// ============================================================================
// Basic Locale Parsing Tests
// ============================================================================

test "Intl.Locale: parse simple language tag" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en");
    defer loc.deinit();

    try assert_string_equals(loc.language, "en", "language");
    try assert_null([]const u8, loc.script, "script should be null");
    try assert_null([]const u8, loc.region, "region should be null");
}

test "Intl.Locale: parse language-region tag" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en-US");
    defer loc.deinit();

    try assert_string_equals(loc.language, "en", "language");
    try assert_null([]const u8, loc.script, "script should be null");
    if (loc.region) |region| {
        try assert_string_equals(region, "US", "region");
    } else {
        return error.RegionNotFound;
    }
}

test "Intl.Locale: parse language-script-region tag" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "zh-Hans-CN");
    defer loc.deinit();

    try assert_string_equals(loc.language, "zh", "language");
    if (loc.script) |script| {
        try assert_string_equals(script, "Hans", "script");
    } else {
        return error.ScriptNotFound;
    }
    if (loc.region) |region| {
        try assert_string_equals(region, "CN", "region");
    } else {
        return error.RegionNotFound;
    }
}

test "Intl.Locale: parse with script only" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "sr-Latn");
    defer loc.deinit();

    try assert_string_equals(loc.language, "sr", "language");
    if (loc.script) |script| {
        try assert_string_equals(script, "Latn", "script");
    } else {
        return error.ScriptNotFound;
    }
    try assert_null([]const u8, loc.region, "region should be null");
}

// ============================================================================
// Case Canonicalization Tests
// ============================================================================

test "Intl.Locale: canonicalize uppercase language" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "EN");
    defer loc.deinit();

    try assert_string_equals(loc.language, "en", "language should be lowercase");
}

test "Intl.Locale: canonicalize mixed case" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "eN-uS");
    defer loc.deinit();

    try assert_string_equals(loc.language, "en", "language should be lowercase");
    if (loc.region) |region| {
        try assert_string_equals(region, "US", "region should be uppercase");
    }
}

test "Intl.Locale: canonicalize script case" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "zh-HANS-cn");
    defer loc.deinit();

    if (loc.script) |script| {
        try assert_string_equals(script, "Hans", "script should be title case");
    }
    if (loc.region) |region| {
        try assert_string_equals(region, "CN", "region should be uppercase");
    }
}

// ============================================================================
// Invalid Locale Tests
// ============================================================================

test "Intl.Locale: reject empty string" {
    const allocator = std.testing.allocator;

    const result = Locale.parse(allocator, "");
    try std.testing.expectError(error.EmptyTag, result);
}

test "Intl.Locale: reject numeric-only language" {
    const allocator = std.testing.allocator;

    const result = Locale.parse(allocator, "123");
    try std.testing.expectError(error.InvalidLanguage, result);
}

test "Intl.Locale: reject too-long language" {
    const allocator = std.testing.allocator;

    const result = Locale.parse(allocator, "verylonglanguage");
    try std.testing.expectError(error.InvalidLanguage, result);
}

// ============================================================================
// Unicode Extension Tests
// ============================================================================

test "Intl.Locale: parse calendar extension" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en-u-ca-buddhist");
    defer loc.deinit();

    try assert_string_equals(loc.language, "en", "language");
    if (loc.unicode_extensions.calendar) |cal| {
        try assert_string_equals(cal, "buddhist", "calendar");
    } else {
        return error.CalendarNotFound;
    }
}

test "Intl.Locale: parse hour cycle extension" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en-u-hc-h12");
    defer loc.deinit();

    if (loc.unicode_extensions.hour_cycle) |hc| {
        try std.testing.expectEqual(HourCycle.h12, hc);
    } else {
        return error.HourCycleNotFound;
    }
}

test "Intl.Locale: parse numbering system extension" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "ar-u-nu-arab");
    defer loc.deinit();

    if (loc.unicode_extensions.numbering_system) |nu| {
        try assert_string_equals(nu, "arab", "numbering system");
    } else {
        return error.NumberingSystemNotFound;
    }
}

test "Intl.Locale: parse multiple unicode extensions" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en-u-ca-gregory-hc-h23-nu-latn");
    defer loc.deinit();

    if (loc.unicode_extensions.calendar) |cal| {
        try assert_string_equals(cal, "gregory", "calendar");
    }
    if (loc.unicode_extensions.hour_cycle) |hc| {
        try std.testing.expectEqual(HourCycle.h23, hc);
    }
    if (loc.unicode_extensions.numbering_system) |nu| {
        try assert_string_equals(nu, "latn", "numbering system");
    }
}

// ============================================================================
// Locale toString Tests
// ============================================================================

test "Intl.Locale: toString simple" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en");
    defer loc.deinit();

    const str = try loc.toString(allocator);
    defer allocator.free(str);

    try assert_string_equals(str, "en", "toString");
}

test "Intl.Locale: toString with region" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en-US");
    defer loc.deinit();

    const str = try loc.toString(allocator);
    defer allocator.free(str);

    try assert_string_equals(str, "en-US", "toString");
}

test "Intl.Locale: toString with script and region" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "zh-Hans-CN");
    defer loc.deinit();

    const str = try loc.toString(allocator);
    defer allocator.free(str);

    try assert_string_equals(str, "zh-Hans-CN", "toString");
}

// ============================================================================
// Locale Negotiation Tests
// ============================================================================

test "Intl.Locale: best available locale - exact match" {
    const available = [_][]const u8{ "en", "de", "fr" };
    const result = locale_mod.bestAvailableLocale(&available, "en");

    try assert_true(result != null, "should find exact match");
    try assert_string_equals(result.?, "en", "should be 'en'");
}

test "Intl.Locale: best available locale - fallback to base" {
    const available = [_][]const u8{ "en", "de", "fr" };
    const result = locale_mod.bestAvailableLocale(&available, "en-US");

    try assert_true(result != null, "should find fallback");
    try assert_string_equals(result.?, "en", "should fall back to 'en'");
}

test "Intl.Locale: best available locale - no match" {
    const available = [_][]const u8{ "en", "de", "fr" };
    const result = locale_mod.bestAvailableLocale(&available, "ja");

    try assert_null([]const u8, result, "should not find match");
}

test "Intl.Locale: best available locale - script fallback" {
    const available = [_][]const u8{ "zh", "zh-Hans", "zh-Hant" };
    const result = locale_mod.bestAvailableLocale(&available, "zh-Hans-CN");

    try assert_true(result != null, "should find match");
    // Should fall back through zh-Hans-CN -> zh-Hans -> zh
    try assert_true(
        std.mem.eql(u8, result.?, "zh-Hans") or std.mem.eql(u8, result.?, "zh"),
        "should be zh-Hans or zh",
    );
}

// ============================================================================
// Locale Properties Tests
// ============================================================================

test "Intl.Locale: toBaseName property" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "en-US-u-ca-buddhist");
    defer loc.deinit();

    const base = try loc.toBaseName(allocator);
    defer allocator.free(base);

    try assert_string_equals(base, "en-US", "toBaseName excludes extensions");
}

test "Intl.Locale: language property" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "de-AT");
    defer loc.deinit();

    try assert_string_equals(loc.language, "de", "language");
}

test "Intl.Locale: region property" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "de-AT");
    defer loc.deinit();

    if (loc.region) |region| {
        try assert_string_equals(region, "AT", "region");
    } else {
        return error.RegionNotFound;
    }
}

test "Intl.Locale: script property" {
    const allocator = std.testing.allocator;

    var loc = try Locale.parse(allocator, "zh-Hant-TW");
    defer loc.deinit();

    if (loc.script) |script| {
        try assert_string_equals(script, "Hant", "script");
    } else {
        return error.ScriptNotFound;
    }
}

// ============================================================================
// Common BCP 47 Tag Tests (ECMA-402 examples)
// ============================================================================

test "Intl.Locale: ECMA-402 example tags" {
    const allocator = std.testing.allocator;

    // Examples from ECMA-402 specification
    const tags = [_][]const u8{
        "de",
        "de-DE",
        "de-AT",
        "de-CH",
        "en",
        "en-US",
        "en-GB",
        "en-AU",
        "es",
        "es-ES",
        "es-MX",
        "fr",
        "fr-FR",
        "fr-CA",
        "ja",
        "ja-JP",
        "ko",
        "ko-KR",
        "pt",
        "pt-BR",
        "pt-PT",
        "ru",
        "ru-RU",
        "zh",
        "zh-CN",
        "zh-TW",
        "zh-Hans",
        "zh-Hant",
        "zh-Hans-CN",
        "zh-Hant-TW",
    };

    for (tags) |tag| {
        var loc = try Locale.parse(allocator, tag);
        loc.deinit();
    }
}

// ============================================================================
// Grandfathered and Private Use Tags
// ============================================================================

test "Intl.Locale: private use tag" {
    const allocator = std.testing.allocator;

    // Private use subtags (x-...)
    var loc = try Locale.parse(allocator, "en-x-private");
    defer loc.deinit();

    try assert_string_equals(loc.language, "en", "language");
}

// ============================================================================
// Memory Safety Tests
// ============================================================================

test "Intl.Locale: deinit does not leak" {
    const allocator = std.testing.allocator;

    for (0..100) |_| {
        var loc = try Locale.parse(allocator, "zh-Hans-CN-u-ca-buddhist-hc-h23-nu-arab");
        loc.deinit();
    }
    // If this test passes with testing.allocator, there are no leaks
}

test "Intl.Locale: multiple parses same allocator" {
    const allocator = std.testing.allocator;

    var loc1 = try Locale.parse(allocator, "en-US");
    var loc2 = try Locale.parse(allocator, "de-DE");
    var loc3 = try Locale.parse(allocator, "ja-JP");

    defer loc1.deinit();
    defer loc2.deinit();
    defer loc3.deinit();

    try assert_string_equals(loc1.language, "en", "loc1");
    try assert_string_equals(loc2.language, "de", "loc2");
    try assert_string_equals(loc3.language, "ja", "loc3");
}
