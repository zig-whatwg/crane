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
//!
//! ## References
//!
//! - ECMA-402 §9.2: Locale and Parameter Negotiation
//! - UTS 35: Unicode Locale Data Markup Language

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const Locale = parser.Locale;
const extensions = @import("extensions.zig");
const UnicodeExtensions = extensions.UnicodeExtensions;
const HourCycle = extensions.HourCycle;

/// Locale matching algorithm (ECMA-402 §9.2.1)
pub const LocaleMatcher = enum {
    /// Simple subtag-removal matching (ECMA-402 §9.2.3)
    lookup,
    /// Implementation-defined best fit algorithm (ECMA-402 §9.2.4)
    best_fit,
};

/// Options for locale resolution
pub const ResolveOptions = struct {
    /// Which matching algorithm to use
    matcher: LocaleMatcher = .best_fit,

    /// Relevant extension keys to extract
    /// If null, no extension processing is done
    relevant_extension_keys: ?[]const []const u8 = null,

    /// Fallback locale if no match found (defaults to "en")
    default_locale: []const u8 = "en",
};

/// Result of locale resolution (ECMA-402 §9.2.6)
pub const ResolvedLocale = struct {
    allocator: Allocator,

    /// The resolved locale string
    locale: []const u8,

    /// The data locale (may differ if fallback was used)
    /// This is the locale actually used for data lookup
    data_locale: []const u8,

    /// Resolved Unicode extension values
    /// Maps extension key to resolved value
    extensions: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn deinit(self: *Self) void {
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
    /// The matched locale string from available locales
    locale: ?[]const u8,
    /// Extension string if any
    extension: ?[]const u8 = null,
};

// ============================================================================
// ECMA-402 §9.2.2: BestAvailableLocale
// ============================================================================

/// BestAvailableLocale (ECMA-402 §9.2.2)
///
/// Given a set of available locales and a locale, find the best match
/// by progressively removing subtags from the right until a match is found.
///
/// ## Algorithm
///
/// 1. Let candidate be locale.
/// 2. If availableLocales contains candidate, return candidate.
/// 3. Let pos be the character index of the last "-" in candidate.
/// 4. If pos is undefined, return undefined.
/// 5. If pos ≥ 2 and candidate[pos-2] is "-", decrement pos by 2.
///    (This handles script subtags like "-Hans-" → skip over singleton)
/// 6. Let candidate be candidate[0..pos].
/// 7. Repeat from step 2.
///
/// ## Parameters
/// - `available_locales`: Set of available locale strings
/// - `locale`: The locale to match
///
/// ## Returns
/// The matched locale from available_locales, or null if no match.
pub fn bestAvailableLocale(
    available_locales: []const []const u8,
    locale: []const u8,
) ?[]const u8 {
    var candidate = locale;

    while (true) {
        // Step 2: Check if candidate is in available locales
        for (available_locales) |avail| {
            if (localeEquals(avail, candidate)) {
                return avail;
            }
        }

        // Step 3: Find last "-"
        const pos = std.mem.lastIndexOf(u8, candidate, "-") orelse return null;

        // Step 5: If the subtag before "-" is a singleton (1 char), skip it
        // This handles cases like "en-u-ca-buddhist" → skip "-u-"
        var new_pos = pos;
        if (pos >= 2 and candidate[pos - 2] == '-') {
            // Check if it's a singleton (single char between two dashes)
            new_pos = pos - 2;
        }

        // Step 6: Truncate
        candidate = candidate[0..new_pos];

        if (candidate.len == 0) return null;
    }
}

// ============================================================================
// ECMA-402 §9.2.3: LookupMatcher
// ============================================================================

/// LookupMatcher (ECMA-402 §9.2.3)
///
/// Simple subtag-removal matching. For each requested locale, try to find
/// a match in available locales using BestAvailableLocale.
///
/// ## Algorithm
///
/// 1. For each locale in requestedLocales:
///    a. Let noExtensionsLocale be locale without Unicode extension.
///    b. Let availableLocale be BestAvailableLocale(availableLocales, noExtensionsLocale).
///    c. If availableLocale is not undefined:
///       i. Set result.[[locale]] to availableLocale.
///       ii. If locale ≠ noExtensionsLocale, set result.[[extension]] to extension.
///       iii. Return result.
/// 2. Return undefined.
pub fn lookupMatcher(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) !MatchResult {
    for (requested_locales) |requested| {
        // Remove Unicode extensions for matching
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer if (no_ext.len != requested.len) allocator.free(no_ext);

        if (bestAvailableLocale(available_locales, no_ext)) |matched| {
            // Extract extension if present
            const ext = if (no_ext.len != requested.len)
                extractUnicodeExtension(requested)
            else
                null;

            return MatchResult{
                .locale = matched,
                .extension = ext,
            };
        }
    }

    return MatchResult{ .locale = null };
}

// ============================================================================
// ECMA-402 §9.2.4: BestFitMatcher
// ============================================================================

/// BestFitMatcher (ECMA-402 §9.2.4)
///
/// Implementation-defined "best fit" matching algorithm. This implementation
/// uses language distance based on common linguistic relationships.
///
/// ## Language Distance Rules (simplified)
///
/// - Norwegian: nb ↔ no (Norwegian Bokmål ↔ Norwegian)
/// - Chinese: zh ↔ zh-Hans (Simplified Chinese)
/// - Serbian: sr ↔ sr-Cyrl (Serbian Cyrillic)
/// - Azerbaijani: az ↔ az-Latn
///
/// Falls back to LookupMatcher if no special rules apply.
pub fn bestFitMatcher(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) !MatchResult {
    // Try direct lookup first with language distance
    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer if (no_ext.len != requested.len) allocator.free(no_ext);

        // Try exact/subtag match first
        if (bestAvailableLocale(available_locales, no_ext)) |matched| {
            const ext = if (no_ext.len != requested.len)
                extractUnicodeExtension(requested)
            else
                null;
            return MatchResult{ .locale = matched, .extension = ext };
        }

        // Try language distance matching
        if (try findByLanguageDistance(allocator, available_locales, no_ext)) |matched| {
            const ext = if (no_ext.len != requested.len)
                extractUnicodeExtension(requested)
            else
                null;
            return MatchResult{ .locale = matched, .extension = ext };
        }
    }

    return MatchResult{ .locale = null };
}

/// Find match using language distance rules
fn findByLanguageDistance(
    allocator: Allocator,
    available_locales: []const []const u8,
    locale: []const u8,
) !?[]const u8 {
    // Extract just the language subtag
    const dash_pos = std.mem.indexOf(u8, locale, "-");
    const lang = if (dash_pos) |pos| locale[0..pos] else locale;

    // Common language distance mappings
    const mappings = [_]struct { from: []const u8, to: []const u8 }{
        // Norwegian: nb (Bokmål) ↔ no (Norwegian)
        .{ .from = "nb", .to = "no" },
        .{ .from = "no", .to = "nb" },

        // Serbo-Croatian variants
        .{ .from = "sh", .to = "sr" }, // Serbo-Croatian → Serbian
        .{ .from = "sr", .to = "hr" }, // Serbian ↔ Croatian (mutual intelligibility)
        .{ .from = "hr", .to = "sr" },

        // Chinese simplified/traditional
        .{ .from = "cmn", .to = "zh" }, // Mandarin → Chinese

        // Indonesian/Malay (mutual intelligibility)
        .{ .from = "id", .to = "ms" },
        .{ .from = "ms", .to = "id" },

        // Filipino/Tagalog
        .{ .from = "fil", .to = "tl" },
        .{ .from = "tl", .to = "fil" },
    };

    for (mappings) |mapping| {
        if (std.mem.eql(u8, lang, mapping.from)) {
            // Try the mapped language
            var mapped: []u8 = undefined;
            if (dash_pos) |pos| {
                // Reconstruct with mapped language + rest of subtags
                mapped = try allocator.alloc(u8, mapping.to.len + locale.len - pos);
                @memcpy(mapped[0..mapping.to.len], mapping.to);
                @memcpy(mapped[mapping.to.len..], locale[pos..]);
            } else {
                mapped = try allocator.dupe(u8, mapping.to);
            }
            defer allocator.free(mapped);

            if (bestAvailableLocale(available_locales, mapped)) |matched| {
                return matched;
            }

            // Also try just the base language
            if (bestAvailableLocale(available_locales, mapping.to)) |matched| {
                return matched;
            }
        }
    }

    return null;
}

// ============================================================================
// ECMA-402 §9.2.6: ResolveLocale
// ============================================================================

/// ResolveLocale (ECMA-402 §9.2.6)
///
/// Resolve the final locale and extract relevant extension values.
///
/// ## Algorithm (simplified)
///
/// 1. Let matcher be options.[[localeMatcher]].
/// 2. If matcher is "lookup", let r be LookupMatcher(availableLocales, requestedLocales).
/// 3. Else let r be BestFitMatcher(availableLocales, requestedLocales).
/// 4. Let foundLocale be r.[[locale]].
/// 5. If foundLocale is undefined, set foundLocale to defaultLocale.
/// 6. Let result be a new Record.
/// 7. Set result.[[locale]] to foundLocale.
/// 8. For each key in relevantExtensionKeys:
///    a. Extract value from extension or use default
/// 9. Return result.
pub fn resolveLocale(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
    options: ResolveOptions,
) !ResolvedLocale {
    // Step 2-3: Run matcher
    const match_result = switch (options.matcher) {
        .lookup => try lookupMatcher(allocator, available_locales, requested_locales),
        .best_fit => try bestFitMatcher(allocator, available_locales, requested_locales),
    };

    // Step 4-5: Get found locale or default
    const found_locale = match_result.locale orelse options.default_locale;

    // Step 7: Set up result
    var result = ResolvedLocale{
        .allocator = allocator,
        .locale = try allocator.dupe(u8, found_locale),
        .data_locale = undefined,
        .extensions = std.StringHashMap([]const u8).init(allocator),
    };
    errdefer result.deinit();

    // Data locale is the matched locale (for CLDR data lookup)
    result.data_locale = try allocator.dupe(u8, found_locale);

    // Step 8: Extract relevant extension keys
    if (options.relevant_extension_keys) |keys| {
        if (match_result.extension) |ext| {
            try extractRelevantExtensions(allocator, ext, keys, &result.extensions);
        }
    }

    return result;
}

/// Extract relevant extension values from a Unicode extension string
fn extractRelevantExtensions(
    allocator: Allocator,
    extension: []const u8,
    relevant_keys: []const []const u8,
    out_map: *std.StringHashMap([]const u8),
) !void {
    // Parse extension string (format: "-u-key-value-key-value")
    var iter = std.mem.splitScalar(u8, extension, '-');

    // Skip "u" singleton if present at start
    if (iter.peek()) |first| {
        if (std.mem.eql(u8, first, "u")) {
            _ = iter.next();
        }
    }

    while (iter.next()) |part| {
        // Unicode keys are 2 characters
        if (part.len == 2) {
            // Check if this is a relevant key
            for (relevant_keys) |key| {
                if (std.mem.eql(u8, part, key)) {
                    // Collect value (3-8 char subtags following the key)
                    var value_parts = std.ArrayList(u8).init(allocator);
                    defer value_parts.deinit();
                    var first = true;

                    while (iter.peek()) |next_part| {
                        // Stop at next key (2 chars) or end
                        if (next_part.len == 2 or next_part.len < 3) break;
                        _ = iter.next();
                        if (!first) try value_parts.append('-');
                        first = false;
                        try value_parts.appendSlice(next_part);
                    }

                    if (value_parts.items.len > 0) {
                        const key_copy = try allocator.dupe(u8, key);
                        errdefer allocator.free(key_copy);
                        const value = try value_parts.toOwnedSlice();
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
///
/// Return the subset of requested locales that are supported.
///
/// ## Algorithm
///
/// 1. Let subset be a new empty List.
/// 2. For each locale in requestedLocales:
///    a. Let noExtensionsLocale be locale without Unicode extension.
///    b. Let availableLocale be BestAvailableLocale(availableLocales, noExtensionsLocale).
///    c. If availableLocale is not undefined, append locale to subset.
/// 3. Return subset.
pub fn lookupSupportedLocales(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) ![]const []const u8 {
    var result = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (result.items) |item| allocator.free(item);
        result.deinit();
    }

    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer if (no_ext.len != requested.len) allocator.free(no_ext);

        if (bestAvailableLocale(available_locales, no_ext) != null) {
            // Return the original requested locale (with extensions)
            try result.append(try allocator.dupe(u8, requested));
        }
    }

    return result.toOwnedSlice();
}

// ============================================================================
// ECMA-402 §9.2.8: BestFitSupportedLocales
// ============================================================================

/// BestFitSupportedLocales (ECMA-402 §9.2.8)
///
/// Best-fit version of supported locales. Uses language distance for matching.
pub fn bestFitSupportedLocales(
    allocator: Allocator,
    available_locales: []const []const u8,
    requested_locales: []const []const u8,
) ![]const []const u8 {
    var result = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (result.items) |item| allocator.free(item);
        result.deinit();
    }

    for (requested_locales) |requested| {
        const no_ext = try removeUnicodeExtension(allocator, requested);
        defer if (no_ext.len != requested.len) allocator.free(no_ext);

        // Try exact match first
        if (bestAvailableLocale(available_locales, no_ext) != null) {
            try result.append(try allocator.dupe(u8, requested));
            continue;
        }

        // Try language distance match
        if (try findByLanguageDistance(allocator, available_locales, no_ext) != null) {
            try result.append(try allocator.dupe(u8, requested));
        }
    }

    return result.toOwnedSlice();
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Case-insensitive locale comparison
fn localeEquals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

/// Remove Unicode extension (-u-...) from locale string
fn removeUnicodeExtension(allocator: Allocator, locale: []const u8) ![]const u8 {
    // Find "-u-" in the locale
    const ext_start = findExtensionStart(locale, 'u') orelse return allocator.dupe(u8, locale);

    // Find the end of the Unicode extension
    const ext_end = findExtensionEnd(locale, ext_start);

    // Build result without the extension
    const before = locale[0..ext_start];
    const after = if (ext_end < locale.len) locale[ext_end..] else "";

    if (after.len == 0) {
        // Remove trailing dash if present
        const trimmed = if (before.len > 0 and before[before.len - 1] == '-')
            before[0 .. before.len - 1]
        else
            before;
        return allocator.dupe(u8, trimmed);
    }

    var result = try allocator.alloc(u8, before.len + after.len);
    @memcpy(result[0..before.len], before);
    @memcpy(result[before.len..], after);
    return result;
}

/// Extract Unicode extension string from locale
fn extractUnicodeExtension(locale: []const u8) ?[]const u8 {
    const ext_start = findExtensionStart(locale, 'u') orelse return null;
    const ext_end = findExtensionEnd(locale, ext_start);
    return locale[ext_start..ext_end];
}

/// Find where an extension singleton starts
fn findExtensionStart(locale: []const u8, singleton: u8) ?usize {
    var i: usize = 0;
    while (i < locale.len) {
        if (locale[i] == '-' and i + 2 < locale.len and locale[i + 1] == singleton and locale[i + 2] == '-') {
            return i + 1; // Point to singleton
        }
        i += 1;
    }
    return null;
}

/// Find where an extension ends (at next singleton or end of string)
fn findExtensionEnd(locale: []const u8, start: usize) usize {
    var i = start + 2; // Skip singleton and following dash
    while (i < locale.len) {
        // Look for pattern "-X-" where X is a single char
        if (i + 2 < locale.len and locale[i] == '-' and locale[i + 2] == '-') {
            // Check if middle char is alphanumeric (singleton)
            if (std.ascii.isAlphanumeric(locale[i + 1])) {
                return i;
            }
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
    try std.testing.expectEqualStrings("de", bestAvailableLocale(available, "de").?);
}

test "bestAvailableLocale - fallback by removing subtags" {
    const available = &[_][]const u8{ "en", "de" };

    // en-AU falls back to en
    try std.testing.expectEqualStrings("en", bestAvailableLocale(available, "en-AU").?);

    // en-Latn-US falls back to en
    try std.testing.expectEqualStrings("en", bestAvailableLocale(available, "en-Latn-US").?);
}

test "bestAvailableLocale - no match" {
    const available = &[_][]const u8{ "en", "de" };

    try std.testing.expect(bestAvailableLocale(available, "fr") == null);
    try std.testing.expect(bestAvailableLocale(available, "ja-JP") == null);
}

test "lookupMatcher - finds match" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de", "fr" };

    const result = try lookupMatcher(allocator, available, &[_][]const u8{"en-US"});
    try std.testing.expectEqualStrings("en", result.locale.?);
}

test "lookupMatcher - with extension" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de" };

    const result = try lookupMatcher(allocator, available, &[_][]const u8{"en-u-ca-buddhist"});
    try std.testing.expectEqualStrings("en", result.locale.?);
    try std.testing.expect(result.extension != null);
}

test "lookupMatcher - no match" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de" };

    const result = try lookupMatcher(allocator, available, &[_][]const u8{"ja-JP"});
    try std.testing.expect(result.locale == null);
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

    // fr-CH not available, de is
    const result = try bestFitMatcher(allocator, available, &[_][]const u8{ "fr-CH", "de" });
    try std.testing.expectEqualStrings("de", result.locale.?);
}

test "resolveLocale - basic" {
    const allocator = std.testing.allocator;
    const available = &[_][]const u8{ "en", "de", "fr" };

    var resolved = try resolveLocale(allocator, available, &[_][]const u8{"en-US"}, .{});
    defer resolved.deinit();

    try std.testing.expectEqualStrings("en", resolved.locale);
    try std.testing.expectEqualStrings("en", resolved.data_locale);
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

    var resolved = try resolveLocale(
        allocator,
        available,
        &[_][]const u8{"en-u-ca-buddhist-nu-arab"},
        .{ .relevant_extension_keys = keys },
    );
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

    // Both should be supported (nb via distance to no, en-US via en)
    try std.testing.expectEqual(@as(usize, 2), supported.len);
}

test "removeUnicodeExtension" {
    const allocator = std.testing.allocator;

    const result1 = try removeUnicodeExtension(allocator, "en-US-u-ca-buddhist");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("en-US", result1);

    const result2 = try removeUnicodeExtension(allocator, "en-US");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("en-US", result2);

    const result3 = try removeUnicodeExtension(allocator, "en-u-ca-buddhist");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("en", result3);
}

test "localeEquals - case insensitive" {
    try std.testing.expect(localeEquals("en-US", "en-US"));
    try std.testing.expect(localeEquals("en-us", "en-US"));
    try std.testing.expect(localeEquals("EN-US", "en-us"));
    try std.testing.expect(!localeEquals("en-US", "en-GB"));
}
