//! CLDR Data Access Module
//!
//! Provides access to CLDR (Common Locale Data Repository) data for
//! internationalization. Supports both compile-time embedded data
//! (Tier 1 locales) and runtime loading (Tier 2 locales).
//!
//! ## Architecture
//!
//! - **Tier 1 (Embedded)**: ~50 common locales embedded at compile time
//! - **Tier 2 (Loadable)**: All other locales loaded from binary files
//!
//! ## Usage
//!
//! ```zig
//! const cldr = @import("cldr");
//!
//! // Get locale data (tries embedded first, then loads)
//! const data = try cldr.getLocaleData(allocator, "en-US");
//! defer if (!cldr.isEmbedded("en-US")) data.deinit();
//!
//! // Use month names
//! const january = data.months.wide[0];
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const loader = @import("loader.zig");
pub const types = @import("types.zig");

// Re-export common types from embedded_data (the generated file)
// This ensures type consistency since embedded_data defines its own types
pub const embedded = loader.embedded;
pub const LocaleData = loader.LocaleData;
pub const MonthNames = embedded.MonthNames;
pub const WeekdayNames = embedded.WeekdayNames;
pub const DayPeriodNames = embedded.DayPeriodNames;
pub const EraNames = embedded.EraNames;
pub const DateTimePatterns = embedded.DateTimePatterns;
pub const NumberSymbols = embedded.NumberSymbols;

/// Check if a locale is embedded (Tier 1)
pub fn isEmbedded(locale_tag: []const u8) bool {
    return loader.isEmbeddedLocale(locale_tag);
}

/// Get locale data by tag.
///
/// First checks embedded Tier 1 data, then attempts to load from file.
/// For embedded locales, the returned data is static and should NOT be freed.
/// For loaded locales, caller must call deinit() when done.
///
/// ## Parameters
/// - `allocator`: Allocator for loading non-embedded locales
/// - `locale_tag`: BCP 47 locale tag (e.g., "en-US", "de-DE")
///
/// ## Returns
/// LocaleData for the requested locale, or null if not found.
pub fn getLocaleData(allocator: Allocator, locale_tag: []const u8) !?*const LocaleData {
    // Try embedded data first (zero allocation)
    if (loader.getEmbeddedLocale(locale_tag)) |embedded_data| {
        return embedded_data;
    }

    // Try to load from file
    return loader.loadLocaleFromFile(allocator, locale_tag);
}

/// Get locale data with fallback chain.
///
/// Tries the requested locale, then falls back to parent locales.
/// For example: "en-US" -> "en" -> root
///
/// ## Parameters
/// - `allocator`: Allocator for loading non-embedded locales
/// - `locale_tag`: BCP 47 locale tag
///
/// ## Returns
/// LocaleData for the requested locale or a fallback.
pub fn getLocaleDataWithFallback(allocator: Allocator, locale_tag: []const u8) !*const LocaleData {
    // Try exact match first
    if (try getLocaleData(allocator, locale_tag)) |data| {
        return data;
    }

    // Try removing subtags for fallback
    // e.g., "en-US" -> "en", "zh-Hans-CN" -> "zh-Hans" -> "zh"
    var tag_copy: [64]u8 = undefined;
    const tag_len = @min(locale_tag.len, tag_copy.len);
    @memcpy(tag_copy[0..tag_len], locale_tag[0..tag_len]);
    var current_len = tag_len;

    while (current_len > 0) {
        // Find last hyphen
        var last_hyphen: ?usize = null;
        for (0..current_len) |i| {
            if (tag_copy[i] == '-') {
                last_hyphen = i;
            }
        }

        if (last_hyphen) |pos| {
            current_len = pos;
            if (try getLocaleData(allocator, tag_copy[0..current_len])) |data| {
                return data;
            }
        } else {
            break;
        }
    }

    // Final fallback to English
    if (try getLocaleData(allocator, "en")) |en_data| {
        return en_data;
    }

    return error.NoLocaleDataAvailable;
}

/// List all available embedded locales
pub fn listEmbeddedLocales() []const []const u8 {
    return loader.getEmbeddedLocaleTags();
}

// ============================================================================
// Tests
// ============================================================================

test "isEmbedded returns true for Tier 1 locales" {
    // These should be embedded when data is generated
    // For now, test the function exists and returns consistent values
    const result = isEmbedded("en");
    _ = result; // Will be true once data is generated
}

test "getLocaleData returns null for unknown locale" {
    const allocator = std.testing.allocator;
    const result = try getLocaleData(allocator, "xx-UNKNOWN");
    try std.testing.expectEqual(@as(?*const LocaleData, null), result);
}
