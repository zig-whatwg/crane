//! ECMA-402 Locale Negotiation Algorithms
//!
//! Implements locale matching and negotiation per ECMA-402 §9.2.
//!
//! ## Algorithms
//!
//! - BestAvailableLocale (§9.2.2): Find best match by removing subtags
//! - LookupMatcher (§9.2.3): Simple subtag-removal matching
//! - BestFitMatcher (§9.2.4): Implementation-defined best fit algorithm
//! - ResolveLocale (§9.2.6): Resolve final locale and options
//! - LookupSupportedLocales (§9.2.7): Return subset of supported locales
//! - BestFitSupportedLocales (§9.2.8): Best-fit version of supported locales

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const Locale = parser.Locale;
const extensions = @import("extensions.zig");

/// Locale matching algorithm (ECMA-402 §9.2.1)
pub const LocaleMatcher = enum {
    /// Simple subtag-removal matching (ECMA-402 §9.2.3)
    lookup,
    /// Implementation-defined best fit algorithm (ECMA-402 §9.2.4)
    best_fit,
};

/// Options for locale resolution
pub const ResolveOptions = struct {
    matcher: LocaleMatcher = .best_fit,
    relevant_extension_keys: ?[]const []const u8 = null,
    default_locale: []const u8 = "en",
};

/// Result of locale resolution (ECMA-402 §9.2.6)
pub const ResolvedLocale = struct {
    allocator: Allocator,
    locale: []const u8,
    data_locale: []const u8,
    extensions: std.StringHashMap([]const u8),

    pub fn deinit(self: *ResolvedLocale) void {
        self.allocator.free(self.locale);
        if (!std.mem.eql(u8, self.locale, self.data_locale)) {
            self.allocator.free(self.data_locale);
        }
        var ext_iter = self.extensions.iterator();
        while (ext_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.extensions.deinit();
        self.* = undefined;
    }
};

/// Result from matcher algorithms
pub const MatchResult = struct {
    locale: ?[]const u8,
    extension: ?[]const u8 = null,
};

// ============================================================================
// ECMA-402 §9.2.2: BestAvailableLocale
// ============================================================================

/// BestAvailableLocale (ECMA-402 §9.2.2)
///
/// Given a set of available locales and a locale, find the best match
/// by progressively removing subtags from the right until a match is found.
pub fn bestAvailableLocale(available_locales: []const []const u8, locale: []const u8) ?[]const u8 {
    var candidate = locale;

    while (true) {
        for (available_locales) |avail| {
            if (localeEquals(avail, candidate)) return avail;
        }

        const pos = std.mem.lastIndexOf(u8, candidate, "-") orelse return null;
        var new_pos = pos;
        if (pos >= 2 and candidate[pos - 2] == '-') new_pos = pos - 2;
        candidate = candidate[0..new_pos];
        if (candidate.len == 0) return null;
    }
}

// ============================================================================
// ECMA-402 §9.2.3: LookupMatcher
// ============================================================================

/// LookupMatcher (ECMA-402 §9.2.3)
pub fn lookupMatcher(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) !MatchResult {
    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer allocator.free(no_ext);

        if (bestAvailableLocale(available_locales, no_ext)) |matched| {
            const ext = if (no_ext.len != requested.len) extractUnicodeExtension(requested) else null;
            return MatchResult{ .locale = matched, .extension = ext };
        }
    }
    return MatchResult{ .locale = null };
}

// ============================================================================
// ECMA-402 §9.2.4: BestFitMatcher
// ============================================================================

/// BestFitMatcher (ECMA-402 §9.2.4)
pub fn bestFitMatcher(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) !MatchResult {
    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer allocator.free(no_ext);

        if (bestAvailableLocale(available_locales, no_ext)) |matched| {
            const ext = if (no_ext.len != requested.len) extractUnicodeExtension(requested) else null;
            return MatchResult{ .locale = matched, .extension = ext };
        }

        if (try findByLanguageDistance(allocator, available_locales, no_ext)) |matched| {
            const ext = if (no_ext.len != requested.len) extractUnicodeExtension(requested) else null;
            return MatchResult{ .locale = matched, .extension = ext };
        }
    }
    return MatchResult{ .locale = null };
}

fn findByLanguageDistance(allocator: Allocator, available_locales: []const []const u8, locale: []const u8) !?[]const u8 {
    const dash_pos = std.mem.indexOf(u8, locale, "-");
    const lang = if (dash_pos) |pos| locale[0..pos] else locale;

    const mappings = [_]struct { from: []const u8, to: []const u8 }{
        .{ .from = "nb", .to = "no" },
        .{ .from = "no", .to = "nb" },
        .{ .from = "id", .to = "ms" },
        .{ .from = "ms", .to = "id" },
        .{ .from = "fil", .to = "tl" },
        .{ .from = "tl", .to = "fil" },
    };

    for (mappings) |mapping| {
        if (std.mem.eql(u8, lang, mapping.from)) {
            var mapped: []u8 = undefined;
            if (dash_pos) |pos| {
                mapped = try allocator.alloc(u8, mapping.to.len + locale.len - pos);
                @memcpy(mapped[0..mapping.to.len], mapping.to);
                @memcpy(mapped[mapping.to.len..], locale[pos..]);
            } else {
                mapped = try allocator.dupe(u8, mapping.to);
            }
            defer allocator.free(mapped);

            if (bestAvailableLocale(available_locales, mapped)) |matched| return matched;
            if (bestAvailableLocale(available_locales, mapping.to)) |matched| return matched;
        }
    }
    return null;
}

// ============================================================================
// ECMA-402 §9.2.6: ResolveLocale
// ============================================================================

/// ResolveLocale (ECMA-402 §9.2.6)
pub fn resolveLocale(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
    options: ResolveOptions,
) !ResolvedLocale {
    const match_result = switch (options.matcher) {
        .lookup => try lookupMatcher(allocator, available_locales, requested_locales),
        .best_fit => try bestFitMatcher(allocator, available_locales, requested_locales),
    };

    const found_locale = match_result.locale orelse options.default_locale;

    var result = ResolvedLocale{
        .allocator = allocator,
        .locale = try allocator.dupe(u8, found_locale),
        .data_locale = undefined,
        .extensions = std.StringHashMap([]const u8).init(allocator),
    };
    errdefer result.deinit();

    result.data_locale = try allocator.dupe(u8, found_locale);

    if (options.relevant_extension_keys) |keys| {
        if (match_result.extension) |ext| {
            try extractRelevantExtensions(allocator, ext, keys, &result.extensions);
        }
    }

    return result;
}

fn extractRelevantExtensions(
    allocator: Allocator,
    extension: []const u8,
    relevant_keys: []const []const u8,
    out_map: *std.StringHashMap([]const u8),
) !void {
    var iter = std.mem.splitScalar(u8, extension, '-');
    if (iter.peek()) |first| {
        if (std.mem.eql(u8, first, "u")) _ = iter.next();
    }

    while (iter.next()) |part| {
        if (part.len == 2) {
            for (relevant_keys) |key| {
                if (std.mem.eql(u8, part, key)) {
                    var value_buf: [64]u8 = undefined;
                    var value_pos: usize = 0;
                    var first = true;

                    while (iter.peek()) |next_part| {
                        if (next_part.len == 2 or next_part.len < 3) break;
                        _ = iter.next();
                        if (!first) {
                            value_buf[value_pos] = '-';
                            value_pos += 1;
                        }
                        first = false;
                        @memcpy(value_buf[value_pos..][0..next_part.len], next_part);
                        value_pos += next_part.len;
                    }

                    if (value_pos > 0) {
                        const key_copy = try allocator.dupe(u8, key);
                        errdefer allocator.free(key_copy);
                        const value = try allocator.dupe(u8, value_buf[0..value_pos]);
                        try out_map.put(key_copy, value);
                    }
                    break;
                }
            }
        }
    }
}

// ============================================================================
// ECMA-402 §9.2.7: LookupSupportedLocales
// ============================================================================

/// LookupSupportedLocales (ECMA-402 §9.2.7)
pub fn lookupSupportedLocales(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) ![]const []const u8 {
    var result_buf: [64][]const u8 = undefined;
    var result_count: usize = 0;

    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer allocator.free(no_ext);

        if (bestAvailableLocale(available_locales, no_ext) != null) {
            if (result_count >= result_buf.len) break;
            result_buf[result_count] = try allocator.dupe(u8, requested);
            result_count += 1;
        }
    }

    const result = try allocator.alloc([]const u8, result_count);
    @memcpy(result, result_buf[0..result_count]);
    return result;
}

// ============================================================================
// ECMA-402 §9.2.8: BestFitSupportedLocales
// ============================================================================

/// BestFitSupportedLocales (ECMA-402 §9.2.8)
pub fn bestFitSupportedLocales(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) ![]const []const u8 {
    var result_buf: [64][]const u8 = undefined;
    var result_count: usize = 0;

    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer allocator.free(no_ext);

        if (bestAvailableLocale(available_locales, no_ext) != null) {
            if (result_count >= result_buf.len) break;
            result_buf[result_count] = try allocator.dupe(u8, requested);
            result_count += 1;
            continue;
        }

        if (try findByLanguageDistance(allocator, available_locales, no_ext) != null) {
            if (result_count >= result_buf.len) break;
            result_buf[result_count] = try allocator.dupe(u8, requested);
            result_count += 1;
        }
    }

    const result = try allocator.alloc([]const u8, result_count);
    @memcpy(result, result_buf[0..result_count]);
    return result;
}

// ============================================================================
// Utility Functions
// ============================================================================

fn localeEquals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

fn removeUnicodeExtension(allocator: Allocator, locale: []const u8) ![]const u8 {
    const ext_start = findExtensionStart(locale, 'u') orelse return allocator.dupe(u8, locale);
    const ext_end = findExtensionEnd(locale, ext_start);

    const before = locale[0..ext_start];
    const after = if (ext_end < locale.len) locale[ext_end..] else "";

    if (after.len == 0) {
        const trimmed = if (before.len > 0 and before[before.len - 1] == '-') before[0 .. before.len - 1] else before;
        return allocator.dupe(u8, trimmed);
    }

    var result = try allocator.alloc(u8, before.len + after.len);
    @memcpy(result[0..before.len], before);
    @memcpy(result[before.len..], after);
    return result;
}

fn extractUnicodeExtension(locale: []const u8) ?[]const u8 {
    const ext_start = findExtensionStart(locale, 'u') orelse return null;
    const ext_end = findExtensionEnd(locale, ext_start);
    return locale[ext_start..ext_end];
}

fn findExtensionStart(locale: []const u8, singleton: u8) ?usize {
    var i: usize = 0;
    while (i < locale.len) {
        if (locale[i] == '-' and i + 2 < locale.len and locale[i + 1] == singleton and locale[i + 2] == '-') {
            return i + 1;
        }
        i += 1;
    }
    return null;
}

fn findExtensionEnd(locale: []const u8, start: usize) usize {
    var i = start + 2;
    while (i < locale.len) {
        if (i + 2 < locale.len and locale[i] == '-' and locale[i + 2] == '-') {
            if (std.ascii.isAlphanumeric(locale[i + 1])) return i;
        }
        i += 1;
    }
    return locale.len;
}

// ============================================================================
// Tests
// ============================================================================

test "bestAvailableLocale - exact match" {
    const available = &[_][]const u8{ "en", "en-US", "de", "fr" };
    try std.testing.expectEqualStrings("en-US", bestAvailableLocale(available, "en-US").?);
    try std.testing.expectEqualStrings("en", bestAvailableLocale(available, "en").?);
}

test "bestAvailableLocale - fallback by removing subtags" {
    const available = &[_][]const u8{ "en", "de" };
    try std.testing.expectEqualStrings("en", bestAvailableLocale(available, "en-AU").?);
    try std.testing.expectEqualStrings("en", bestAvailableLocale(available, "en-Latn-US").?);
}

test "bestAvailableLocale - no match" {
    const available = &[_][]const u8{ "en", "de" };
    try std.testing.expect(bestAvailableLocale(available, "fr") == null);
}

test "lookupMatcher - finds match" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de", "fr" };
    const result = try lookupMatcher(allocator, available, &[_][]const u8{"en-US"});
    try std.testing.expectEqualStrings("en", result.locale.?);
}

test "bestFitMatcher - Norwegian nb matches no" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "no", "de" };
    const result = try bestFitMatcher(allocator, available, &[_][]const u8{"nb"});
    try std.testing.expectEqualStrings("no", result.locale.?);
}

test "bestFitMatcher - multiple requested" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "de", "en" };
    const result = try bestFitMatcher(allocator, available, &[_][]const u8{ "fr-CH", "de" });
    try std.testing.expectEqualStrings("de", result.locale.?);
}

test "resolveLocale - basic" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de", "fr" };
    var resolved = try resolveLocale(allocator, available, &[_][]const u8{"en-US"}, .{});
    defer resolved.deinit();
    try std.testing.expectEqualStrings("en", resolved.locale);
}

test "resolveLocale - with default fallback" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de" };
    var resolved = try resolveLocale(allocator, available, &[_][]const u8{"ja-JP"}, .{ .default_locale = "en" });
    defer resolved.deinit();
    try std.testing.expectEqualStrings("en", resolved.locale);
}

test "resolveLocale - with relevant extensions" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de" };
    const keys = &[_][]const u8{ "ca", "nu" };
    var resolved = try resolveLocale(allocator, available, &[_][]const u8{"en-u-ca-buddhist-nu-arab"}, .{ .relevant_extension_keys = keys });
    defer resolved.deinit();
    try std.testing.expectEqualStrings("en", resolved.locale);
    try std.testing.expectEqualStrings("buddhist", resolved.extensions.get("ca").?);
    try std.testing.expectEqualStrings("arab", resolved.extensions.get("nu").?);
}

test "lookupSupportedLocales" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de", "fr" };
    const requested = &[_][]const u8{ "en-US", "ja-JP", "de-DE" };
    const supported = try lookupSupportedLocales(allocator, available, requested);
    defer {
        for (supported) |s| allocator.free(s);
        allocator.free(supported);
    }
    try std.testing.expectEqual(@as(usize, 2), supported.len);
    try std.testing.expectEqualStrings("en-US", supported[0]);
    try std.testing.expectEqualStrings("de-DE", supported[1]);
}

test "bestFitSupportedLocales - with language distance" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "no" };
    const requested = &[_][]const u8{ "nb", "en-US" };
    const supported = try bestFitSupportedLocales(allocator, available, requested);
    defer {
        for (supported) |s| allocator.free(s);
        allocator.free(supported);
    }
    try std.testing.expectEqual(@as(usize, 2), supported.len);
}

test "localeEquals - case insensitive" {
    try std.testing.expect(localeEquals("en-US", "en-US"));
    try std.testing.expect(localeEquals("en-us", "en-US"));
    try std.testing.expect(localeEquals("EN-US", "en-us"));
    try std.testing.expect(!localeEquals("en-US", "en-GB"));
}
