//! BCP 47 Language Tag Parser
//!
//! Implements parsing of BCP 47 language tags per RFC 5646.
//!
//! ## Language Tag Structure
//!
//! ```
//! language-tag  = language ["-" script] ["-" region] *("-" variant)
//!                 *("-" extension) ["-" privateuse]
//!
//! language      = 2*3 ALPHA              ; shortest ISO 639 code
//!               / 4 ALPHA                ; reserved for future use
//!               / 5*8 ALPHA              ; registered language subtag
//!
//! script        = 4 ALPHA                ; ISO 15924 code
//! region        = 2 ALPHA                ; ISO 3166-1 code
//!               / 3 DIGIT                ; UN M.49 code
//!
//! variant       = 5*8 alphanum           ; registered variants
//!               / (DIGIT 3alphanum)
//!
//! extension     = singleton 1*("-" (2*8 alphanum))
//! singleton     = DIGIT / [A-WY-Za-wy-z] ; Single character (not 'x')
//!
//! privateuse    = "x" 1*("-" (1*8 alphanum))
//! ```
//!
//! ## References
//!
//! - RFC 5646: Tags for Identifying Languages
//! - UTS 35: Unicode Locale Data Markup Language
//! - ECMA-402 §6.2: Language Tags

const std = @import("std");
const Allocator = std.mem.Allocator;
const extensions = @import("extensions.zig");
pub const UnicodeExtensions = extensions.UnicodeExtensions;
pub const TransformExtensions = extensions.TransformExtensions;

/// Parse errors for BCP 47 language tags
pub const ParseError = error{
    /// Empty or null input
    EmptyTag,
    /// Invalid character in tag
    InvalidCharacter,
    /// Language subtag is invalid
    InvalidLanguage,
    /// Script subtag is invalid
    InvalidScript,
    /// Region subtag is invalid
    InvalidRegion,
    /// Variant subtag is invalid
    InvalidVariant,
    /// Extension is malformed
    InvalidExtension,
    /// Duplicate extension singleton found
    DuplicateExtension,
    /// Private use section is malformed
    InvalidPrivateUse,
    /// Subtag is too long (> 8 characters)
    SubtagTooLong,
    /// Memory allocation failed
    OutOfMemory,
};

/// A parsed BCP 47 language tag
///
/// ## Example
///
/// ```zig
/// const locale = try Locale.parse(allocator, "en-US-u-ca-buddhist");
/// defer locale.deinit();
///
/// std.debug.print("Language: {s}\n", .{locale.language});
/// std.debug.print("Region: {s}\n", .{locale.region.?});
/// ```
pub const Locale = struct {
    allocator: Allocator,

    /// Primary language subtag (2-3 letters, lowercase)
    /// Examples: "en", "zh", "de"
    language: []const u8,

    /// Extended language subtags (3 letters each)
    /// Rarely used, mostly for compatibility
    extlang: ?[]const u8 = null,

    /// Script subtag (4 letters, title case)
    /// Examples: "Latn", "Hans", "Cyrl"
    script: ?[]const u8 = null,

    /// Region subtag (2 letters uppercase or 3 digits)
    /// Examples: "US", "GB", "419"
    region: ?[]const u8 = null,

    /// Variant subtags
    /// Examples: "valencia", "1996"
    variants: ?[]const []const u8 = null,

    /// Unicode locale extensions (-u-)
    unicode_extensions: UnicodeExtensions = .{},

    /// Transform extensions (-t-)
    transform_extensions: TransformExtensions = .{},

    /// Private use subtag (everything after -x-)
    private_use: ?[]const u8 = null,

    /// Other extensions (singleton and values, stored as pairs)
    /// For extensions other than 'u', 't', 'x'
    other_extensions: ?[]const []const u8 = null,

    const Self = @This();

    /// Parse a BCP 47 language tag
    ///
    /// ## Parameters
    /// - `allocator`: Allocator for any heap allocations
    /// - `tag`: The BCP 47 language tag to parse
    ///
    /// ## Returns
    /// A parsed Locale struct, or an error if the tag is invalid.
    ///
    /// ## Examples
    ///
    /// ```zig
    /// // Simple language tag
    /// const en = try Locale.parse(allocator, "en");
    ///
    /// // Language + region
    /// const en_us = try Locale.parse(allocator, "en-US");
    ///
    /// // Full tag with extensions
    /// const complex = try Locale.parse(allocator, "zh-Hans-CN-u-ca-chinese");
    /// ```
    pub fn parse(allocator: Allocator, tag: []const u8) ParseError!Self {
        if (tag.len == 0) return ParseError.EmptyTag;

        // Normalize: convert to lowercase for parsing
        const normalized = allocator.alloc(u8, tag.len) catch return ParseError.OutOfMemory;
        defer allocator.free(normalized);
        for (tag, 0..) |c, i| {
            normalized[i] = std.ascii.toLower(c);
        }

        var iter = std.mem.splitScalar(u8, normalized, '-');
        var locale = Self{
            .allocator = allocator,
            .language = "",
        };
        errdefer locale.deinit();

        // Parse language (required)
        const lang_subtag = iter.next() orelse return ParseError.EmptyTag;
        if (!isValidLanguage(lang_subtag)) {
            return ParseError.InvalidLanguage;
        }
        locale.language = allocator.dupe(u8, lang_subtag) catch return ParseError.OutOfMemory;

        // Parse remaining subtags
        var variants_list = std.ArrayList([]const u8).init(allocator);
        defer variants_list.deinit();

        var other_ext_list = std.ArrayList([]const u8).init(allocator);
        defer other_ext_list.deinit();

        var seen_extensions = std.AutoHashMap(u8, void).init(allocator);
        defer seen_extensions.deinit();

        var state: enum { script_or_region_or_variant, region_or_variant, variant, extension, done } = .script_or_region_or_variant;

        while (iter.next()) |subtag| {
            if (subtag.len == 0) continue;

            switch (state) {
                .script_or_region_or_variant => {
                    if (isValidScript(subtag)) {
                        // Copy with proper case (title case)
                        var script_buf = allocator.alloc(u8, 4) catch return ParseError.OutOfMemory;
                        script_buf[0] = std.ascii.toUpper(subtag[0]);
                        for (subtag[1..], 0..) |c, i| {
                            script_buf[i + 1] = std.ascii.toLower(c);
                        }
                        locale.script = script_buf;
                        state = .region_or_variant;
                    } else if (isValidRegion(subtag)) {
                        locale.region = try normalizeRegion(allocator, subtag);
                        state = .variant;
                    } else if (isValidVariant(subtag)) {
                        variants_list.append(allocator.dupe(u8, subtag) catch return ParseError.OutOfMemory) catch return ParseError.OutOfMemory;
                        state = .variant;
                    } else if (subtag.len == 1) {
                        // Extension singleton
                        state = .extension;
                        try parseExtension(allocator, subtag[0], &iter, &locale, &other_ext_list, &seen_extensions);
                    } else {
                        return ParseError.InvalidScript;
                    }
                },
                .region_or_variant => {
                    if (isValidRegion(subtag)) {
                        locale.region = try normalizeRegion(allocator, subtag);
                        state = .variant;
                    } else if (isValidVariant(subtag)) {
                        variants_list.append(allocator.dupe(u8, subtag) catch return ParseError.OutOfMemory) catch return ParseError.OutOfMemory;
                        state = .variant;
                    } else if (subtag.len == 1) {
                        state = .extension;
                        try parseExtension(allocator, subtag[0], &iter, &locale, &other_ext_list, &seen_extensions);
                    } else {
                        return ParseError.InvalidRegion;
                    }
                },
                .variant => {
                    if (isValidVariant(subtag)) {
                        variants_list.append(allocator.dupe(u8, subtag) catch return ParseError.OutOfMemory) catch return ParseError.OutOfMemory;
                    } else if (subtag.len == 1) {
                        state = .extension;
                        try parseExtension(allocator, subtag[0], &iter, &locale, &other_ext_list, &seen_extensions);
                    } else {
                        return ParseError.InvalidVariant;
                    }
                },
                .extension => {
                    // Already in extension mode, expect singleton
                    if (subtag.len == 1) {
                        try parseExtension(allocator, subtag[0], &iter, &locale, &other_ext_list, &seen_extensions);
                    } else {
                        return ParseError.InvalidExtension;
                    }
                },
                .done => break,
            }
        }

        // Store variants if any
        if (variants_list.items.len > 0) {
            locale.variants = variants_list.toOwnedSlice() catch return ParseError.OutOfMemory;
        }

        // Store other extensions if any
        if (other_ext_list.items.len > 0) {
            locale.other_extensions = other_ext_list.toOwnedSlice() catch return ParseError.OutOfMemory;
        }

        return locale;
    }

    /// Release all memory owned by this locale
    pub fn deinit(self: *Self) void {
        if (self.language.len > 0) {
            self.allocator.free(self.language);
        }
        if (self.extlang) |e| self.allocator.free(e);
        if (self.script) |s| self.allocator.free(s);
        if (self.region) |r| self.allocator.free(r);
        if (self.variants) |variants| {
            for (variants) |v| {
                self.allocator.free(v);
            }
            self.allocator.free(variants);
        }
        if (self.private_use) |p| self.allocator.free(p);
        if (self.other_extensions) |exts| {
            for (exts) |e| {
                self.allocator.free(e);
            }
            self.allocator.free(exts);
        }
        // Free unicode extension strings
        if (self.unicode_extensions.calendar) |c| self.allocator.free(c);
        if (self.unicode_extensions.collation) |c| self.allocator.free(c);
        if (self.unicode_extensions.currency) |c| self.allocator.free(c);
        if (self.unicode_extensions.numbering_system) |n| self.allocator.free(n);
        if (self.unicode_extensions.collation_strength) |c| self.allocator.free(c);
        if (self.unicode_extensions.line_break_word) |l| self.allocator.free(l);
        if (self.unicode_extensions.region_override) |r| self.allocator.free(r);
        if (self.unicode_extensions.timezone) |t| self.allocator.free(t);
        if (self.unicode_extensions.first_day) |f| self.allocator.free(f);
        if (self.unicode_extensions.other_keywords) |kw| {
            for (kw) |k| self.allocator.free(k);
            self.allocator.free(kw);
        }
        // Free transform extension strings
        if (self.transform_extensions.source_locale) |s| self.allocator.free(s);
        if (self.transform_extensions.mechanism) |m| self.allocator.free(m);
        if (self.transform_extensions.source) |s| self.allocator.free(s);
        if (self.transform_extensions.destination) |d| self.allocator.free(d);
        if (self.transform_extensions.input_method) |i| self.allocator.free(i);
        if (self.transform_extensions.keyboard) |k| self.allocator.free(k);
        if (self.transform_extensions.translation) |t| self.allocator.free(t);
        if (self.transform_extensions.hybrid) |h| self.allocator.free(h);
        if (self.transform_extensions.other_keywords) |kw| {
            for (kw) |k| self.allocator.free(k);
            self.allocator.free(kw);
        }
        self.* = undefined;
    }

    /// Serialize locale to a string
    ///
    /// Returns a newly allocated string that must be freed by the caller.
    pub fn toString(self: Self, allocator: Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();

        // Language
        try list.appendSlice(self.language);

        // Script
        if (self.script) |script| {
            try list.append('-');
            try list.appendSlice(script);
        }

        // Region
        if (self.region) |region| {
            try list.append('-');
            try list.appendSlice(region);
        }

        // Variants
        if (self.variants) |variants| {
            for (variants) |variant| {
                try list.append('-');
                try list.appendSlice(variant);
            }
        }

        // Unicode extensions
        if (!self.unicode_extensions.isEmpty()) {
            try list.append('-');
            try list.append('u');
            try appendUnicodeExtensions(&list, self.unicode_extensions);
        }

        // Transform extensions
        if (!self.transform_extensions.isEmpty()) {
            try list.append('-');
            try list.append('t');
            try appendTransformExtensions(&list, self.transform_extensions);
        }

        // Other extensions
        if (self.other_extensions) |exts| {
            var i: usize = 0;
            while (i < exts.len) : (i += 2) {
                try list.append('-');
                try list.appendSlice(exts[i]); // singleton
                if (i + 1 < exts.len) {
                    try list.append('-');
                    try list.appendSlice(exts[i + 1]); // value
                }
            }
        }

        // Private use
        if (self.private_use) |pu| {
            try list.append('-');
            try list.append('x');
            try list.append('-');
            try list.appendSlice(pu);
        }

        return list.toOwnedSlice();
    }

    /// Get the base locale string (language[-script][-region])
    ///
    /// Returns a newly allocated string that must be freed by the caller.
    pub fn toBaseName(self: Self, allocator: Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();

        try list.appendSlice(self.language);

        if (self.script) |script| {
            try list.append('-');
            try list.appendSlice(script);
        }

        if (self.region) |region| {
            try list.append('-');
            try list.appendSlice(region);
        }

        return list.toOwnedSlice();
    }

    /// Check if this locale matches another (language, script, region only)
    pub fn matches(self: Self, other: Self) bool {
        if (!std.mem.eql(u8, self.language, other.language)) return false;

        // Script comparison
        const script_match = if (self.script) |s1| blk: {
            break :blk if (other.script) |s2| std.mem.eql(u8, s1, s2) else false;
        } else other.script == null;
        if (!script_match) return false;

        // Region comparison
        const region_match = if (self.region) |r1| blk: {
            break :blk if (other.region) |r2| std.mem.eql(u8, r1, r2) else false;
        } else other.region == null;
        return region_match;
    }

    /// Add likely subtags to maximize the locale.
    ///
    /// Uses the CLDR likely subtags data to expand a locale to its
    /// most likely full form. For example:
    /// - "en" -> "en-Latn-US"
    /// - "zh" -> "zh-Hans-CN"
    /// - "zh-TW" -> "zh-Hant-TW"
    ///
    /// ## ECMA-402 Reference
    /// This implements the AddLikelySubtags operation from UTS 35 §4.3.
    ///
    /// NOTE: Currently uses a simplified likely subtags table.
    /// Full implementation requires CLDR likelySubtags.json data.
    pub fn maximize(self: *Self) !void {
        const result = lookupLikelySubtags(self.language, self.script, self.region);

        // Add script if missing
        if (self.script == null and result.script != null) {
            self.script = self.allocator.dupe(u8, result.script.?) catch return error.OutOfMemory;
        }

        // Add region if missing
        if (self.region == null and result.region != null) {
            self.region = self.allocator.dupe(u8, result.region.?) catch return error.OutOfMemory;
        }
    }

    /// Remove likely subtags to minimize the locale.
    ///
    /// Removes script and region subtags that can be inferred from
    /// the likely subtags data. For example:
    /// - "en-Latn-US" -> "en"
    /// - "zh-Hans-CN" -> "zh"
    /// - "zh-Hant-TW" -> "zh-TW"
    ///
    /// ## ECMA-402 Reference
    /// This implements the RemoveLikelySubtags operation from UTS 35 §4.3.
    ///
    /// NOTE: Currently uses a simplified likely subtags table.
    /// Full implementation requires CLDR likelySubtags.json data.
    pub fn minimize(self: *Self) void {
        // Algorithm: Try removing subtags and see if maximizing gives the same result
        // 1. Try removing script and region
        // 2. Try removing region only
        // 3. Try removing script only

        // Get the maximized form from language only
        const lang_only = lookupLikelySubtags(self.language, null, null);

        // Check if removing both script and region would still maximize to the same
        if (self.script != null and self.region != null) {
            if (lang_only.script != null and lang_only.region != null) {
                if (std.mem.eql(u8, self.script.?, lang_only.script.?) and
                    std.mem.eql(u8, self.region.?, lang_only.region.?))
                {
                    // Can remove both
                    self.allocator.free(self.script.?);
                    self.allocator.free(self.region.?);
                    self.script = null;
                    self.region = null;
                    return;
                }
            }
        }

        // Try removing just the region
        if (self.region != null) {
            const with_script = lookupLikelySubtags(self.language, self.script, null);
            if (with_script.region != null and std.mem.eql(u8, self.region.?, with_script.region.?)) {
                self.allocator.free(self.region.?);
                self.region = null;
                return;
            }
        }

        // Try removing just the script
        if (self.script != null) {
            const with_region = lookupLikelySubtags(self.language, null, self.region);
            if (with_region.script != null and std.mem.eql(u8, self.script.?, with_region.script.?)) {
                self.allocator.free(self.script.?);
                self.script = null;
                return;
            }
        }
    }
};

// ============================================================================
// Validation Functions
// ============================================================================

fn isValidLanguage(subtag: []const u8) bool {
    // 2-3 ALPHA for ISO 639, or 4 ALPHA (reserved), or 5-8 ALPHA (registered)
    if (subtag.len < 2 or subtag.len > 8) return false;
    for (subtag) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

fn isValidScript(subtag: []const u8) bool {
    // Exactly 4 ALPHA
    if (subtag.len != 4) return false;
    for (subtag) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

fn isValidRegion(subtag: []const u8) bool {
    // 2 ALPHA or 3 DIGIT
    if (subtag.len == 2) {
        return std.ascii.isAlphabetic(subtag[0]) and std.ascii.isAlphabetic(subtag[1]);
    } else if (subtag.len == 3) {
        return std.ascii.isDigit(subtag[0]) and std.ascii.isDigit(subtag[1]) and std.ascii.isDigit(subtag[2]);
    }
    return false;
}

fn isValidVariant(subtag: []const u8) bool {
    // 5-8 alphanum OR digit followed by 3 alphanum
    if (subtag.len >= 5 and subtag.len <= 8) {
        for (subtag) |c| {
            if (!std.ascii.isAlphanumeric(c)) return false;
        }
        return true;
    } else if (subtag.len == 4) {
        if (!std.ascii.isDigit(subtag[0])) return false;
        for (subtag[1..]) |c| {
            if (!std.ascii.isAlphanumeric(c)) return false;
        }
        return true;
    }
    return false;
}

fn normalizeRegion(allocator: Allocator, subtag: []const u8) ParseError![]const u8 {
    const buf = allocator.alloc(u8, subtag.len) catch return ParseError.OutOfMemory;
    for (subtag, 0..) |c, i| {
        buf[i] = std.ascii.toUpper(c);
    }
    return buf;
}

fn parseExtension(
    allocator: Allocator,
    singleton: u8,
    iter: *std.mem.SplitIterator(u8, .scalar),
    locale: *Locale,
    other_ext_list: *std.ArrayList([]const u8),
    seen_extensions: *std.AutoHashMap(u8, void),
) ParseError!void {
    // Check for duplicate extension
    if (seen_extensions.contains(singleton)) {
        return ParseError.DuplicateExtension;
    }
    seen_extensions.put(singleton, {}) catch return ParseError.OutOfMemory;

    switch (singleton) {
        'u' => try parseUnicodeExtension(allocator, iter, locale),
        't' => try parseTransformExtension(allocator, iter, locale),
        'x' => {
            // Private use: collect all remaining subtags
            var pu_list = std.ArrayList(u8).init(allocator);
            defer pu_list.deinit();
            var first = true;
            while (iter.next()) |subtag| {
                if (subtag.len == 0) continue;
                if (subtag.len > 8) return ParseError.SubtagTooLong;
                if (!first) pu_list.append('-') catch return ParseError.OutOfMemory;
                first = false;
                pu_list.appendSlice(subtag) catch return ParseError.OutOfMemory;
            }
            if (pu_list.items.len > 0) {
                locale.private_use = pu_list.toOwnedSlice() catch return ParseError.OutOfMemory;
            }
        },
        else => {
            // Other extension: collect key-value pairs
            const singleton_str = allocator.alloc(u8, 1) catch return ParseError.OutOfMemory;
            singleton_str[0] = singleton;
            other_ext_list.append(singleton_str) catch return ParseError.OutOfMemory;

            var value_list = std.ArrayList(u8).init(allocator);
            defer value_list.deinit();
            var first = true;

            while (iter.peek()) |subtag| {
                // Stop at next singleton
                if (subtag.len == 1 and std.ascii.isAlphanumeric(subtag[0])) break;
                _ = iter.next();
                if (subtag.len == 0) continue;
                if (subtag.len > 8) return ParseError.SubtagTooLong;
                if (!first) value_list.append('-') catch return ParseError.OutOfMemory;
                first = false;
                value_list.appendSlice(subtag) catch return ParseError.OutOfMemory;
            }

            if (value_list.items.len > 0) {
                other_ext_list.append(value_list.toOwnedSlice() catch return ParseError.OutOfMemory) catch return ParseError.OutOfMemory;
            }
        },
    }
}

fn parseUnicodeExtension(
    allocator: Allocator,
    iter: *std.mem.SplitIterator(u8, .scalar),
    locale: *Locale,
) ParseError!void {
    var other_keywords = std.ArrayList([]const u8).init(allocator);
    defer other_keywords.deinit();

    while (iter.peek()) |subtag| {
        // Stop at next singleton (except 'x' which is always last)
        if (subtag.len == 1 and subtag[0] != 'x') {
            // Check if it looks like an extension singleton
            if (std.ascii.isAlphabetic(subtag[0])) break;
        }

        // Peek and process
        const current = iter.next().?;
        if (current.len == 0) continue;

        // Unicode extension key is 2 characters
        if (current.len == 2 and std.ascii.isAlphanumeric(current[0]) and std.ascii.isAlphanumeric(current[1])) {
            // This is a key, look for value
            var value_parts = std.ArrayList(u8).init(allocator);
            defer value_parts.deinit();
            var first = true;

            while (iter.peek()) |next_subtag| {
                // Stop at next key (2 chars) or singleton (1 char)
                if (next_subtag.len <= 2) break;
                _ = iter.next();
                if (!first) value_parts.append('-') catch return ParseError.OutOfMemory;
                first = false;
                value_parts.appendSlice(next_subtag) catch return ParseError.OutOfMemory;
            }

            const value = if (value_parts.items.len > 0)
                value_parts.toOwnedSlice() catch return ParseError.OutOfMemory
            else
                allocator.dupe(u8, "true") catch return ParseError.OutOfMemory;

            // Map key to extension field
            if (std.mem.eql(u8, current, "ca")) {
                locale.unicode_extensions.calendar = value;
            } else if (std.mem.eql(u8, current, "co")) {
                locale.unicode_extensions.collation = value;
            } else if (std.mem.eql(u8, current, "cu")) {
                locale.unicode_extensions.currency = value;
            } else if (std.mem.eql(u8, current, "hc")) {
                locale.unicode_extensions.hour_cycle = extensions.HourCycle.fromString(value);
                allocator.free(value);
            } else if (std.mem.eql(u8, current, "nu")) {
                locale.unicode_extensions.numbering_system = value;
            } else if (std.mem.eql(u8, current, "kn")) {
                locale.unicode_extensions.numeric = std.mem.eql(u8, value, "true");
                allocator.free(value);
            } else if (std.mem.eql(u8, current, "kf")) {
                locale.unicode_extensions.case_first = extensions.CaseFirst.fromString(value);
                allocator.free(value);
            } else if (std.mem.eql(u8, current, "ks")) {
                locale.unicode_extensions.collation_strength = value;
            } else if (std.mem.eql(u8, current, "lw")) {
                locale.unicode_extensions.line_break_word = value;
            } else if (std.mem.eql(u8, current, "rg")) {
                locale.unicode_extensions.region_override = value;
            } else if (std.mem.eql(u8, current, "tz")) {
                locale.unicode_extensions.timezone = value;
            } else if (std.mem.eql(u8, current, "fw")) {
                locale.unicode_extensions.first_day = value;
            } else {
                // Unknown key, store in other_keywords
                other_keywords.append(allocator.dupe(u8, current) catch return ParseError.OutOfMemory) catch return ParseError.OutOfMemory;
                other_keywords.append(value) catch return ParseError.OutOfMemory;
            }
        }
    }

    if (other_keywords.items.len > 0) {
        locale.unicode_extensions.other_keywords = other_keywords.toOwnedSlice() catch return ParseError.OutOfMemory;
    }
}

fn parseTransformExtension(
    allocator: Allocator,
    iter: *std.mem.SplitIterator(u8, .scalar),
    locale: *Locale,
) ParseError!void {
    var other_keywords = std.ArrayList([]const u8).init(allocator);
    defer other_keywords.deinit();

    // First subtag might be a source locale (tlang)
    var saw_key = false;

    while (iter.peek()) |subtag| {
        // Stop at next singleton
        if (subtag.len == 1 and std.ascii.isAlphabetic(subtag[0])) break;

        const current = iter.next().?;
        if (current.len == 0) continue;

        // Transform key is 2 characters starting with letter + digit
        if (current.len == 2 and std.ascii.isAlphabetic(current[0]) and std.ascii.isDigit(current[1])) {
            saw_key = true;
            var value_parts = std.ArrayList(u8).init(allocator);
            defer value_parts.deinit();
            var first = true;

            while (iter.peek()) |next_subtag| {
                if (next_subtag.len <= 2) break;
                _ = iter.next();
                if (!first) value_parts.append('-') catch return ParseError.OutOfMemory;
                first = false;
                value_parts.appendSlice(next_subtag) catch return ParseError.OutOfMemory;
            }

            const value = if (value_parts.items.len > 0)
                value_parts.toOwnedSlice() catch return ParseError.OutOfMemory
            else
                allocator.dupe(u8, "true") catch return ParseError.OutOfMemory;

            // Map transform keys
            if (std.mem.eql(u8, current, "m0")) {
                locale.transform_extensions.mechanism = value;
            } else if (std.mem.eql(u8, current, "s0")) {
                locale.transform_extensions.source = value;
            } else if (std.mem.eql(u8, current, "d0")) {
                locale.transform_extensions.destination = value;
            } else if (std.mem.eql(u8, current, "i0")) {
                locale.transform_extensions.input_method = value;
            } else if (std.mem.eql(u8, current, "k0")) {
                locale.transform_extensions.keyboard = value;
            } else if (std.mem.eql(u8, current, "t0")) {
                locale.transform_extensions.translation = value;
            } else if (std.mem.eql(u8, current, "h0")) {
                locale.transform_extensions.hybrid = value;
            } else {
                other_keywords.append(allocator.dupe(u8, current) catch return ParseError.OutOfMemory) catch return ParseError.OutOfMemory;
                other_keywords.append(value) catch return ParseError.OutOfMemory;
            }
        } else if (!saw_key and current.len >= 2 and current.len <= 8) {
            // Source locale (tlang) - before any keys
            locale.transform_extensions.source_locale = allocator.dupe(u8, current) catch return ParseError.OutOfMemory;
        }
    }

    if (other_keywords.items.len > 0) {
        locale.transform_extensions.other_keywords = other_keywords.toOwnedSlice() catch return ParseError.OutOfMemory;
    }
}

fn appendUnicodeExtensions(list: *std.ArrayList(u8), ext: UnicodeExtensions) !void {
    if (ext.calendar) |v| {
        try list.appendSlice("-ca-");
        try list.appendSlice(v);
    }
    if (ext.collation) |v| {
        try list.appendSlice("-co-");
        try list.appendSlice(v);
    }
    if (ext.currency) |v| {
        try list.appendSlice("-cu-");
        try list.appendSlice(v);
    }
    if (ext.hour_cycle) |hc| {
        try list.appendSlice("-hc-");
        try list.appendSlice(hc.toString());
    }
    if (ext.numbering_system) |v| {
        try list.appendSlice("-nu-");
        try list.appendSlice(v);
    }
    if (ext.numeric) |n| {
        try list.appendSlice("-kn-");
        try list.appendSlice(if (n) "true" else "false");
    }
    if (ext.case_first) |cf| {
        try list.appendSlice("-kf-");
        try list.appendSlice(cf.toString());
    }
    if (ext.collation_strength) |v| {
        try list.appendSlice("-ks-");
        try list.appendSlice(v);
    }
    if (ext.line_break_word) |v| {
        try list.appendSlice("-lw-");
        try list.appendSlice(v);
    }
    if (ext.region_override) |v| {
        try list.appendSlice("-rg-");
        try list.appendSlice(v);
    }
    if (ext.timezone) |v| {
        try list.appendSlice("-tz-");
        try list.appendSlice(v);
    }
    if (ext.first_day) |v| {
        try list.appendSlice("-fw-");
        try list.appendSlice(v);
    }
}

fn appendTransformExtensions(list: *std.ArrayList(u8), ext: TransformExtensions) !void {
    if (ext.source_locale) |v| {
        try list.append('-');
        try list.appendSlice(v);
    }
    if (ext.mechanism) |v| {
        try list.appendSlice("-m0-");
        try list.appendSlice(v);
    }
    if (ext.source) |v| {
        try list.appendSlice("-s0-");
        try list.appendSlice(v);
    }
    if (ext.destination) |v| {
        try list.appendSlice("-d0-");
        try list.appendSlice(v);
    }
    if (ext.input_method) |v| {
        try list.appendSlice("-i0-");
        try list.appendSlice(v);
    }
    if (ext.keyboard) |v| {
        try list.appendSlice("-k0-");
        try list.appendSlice(v);
    }
    if (ext.translation) |v| {
        try list.appendSlice("-t0-");
        try list.appendSlice(v);
    }
    if (ext.hybrid) |v| {
        try list.appendSlice("-h0-");
        try list.appendSlice(v);
    }
}

// ============================================================================
// Likely Subtags Data (Simplified)
// ============================================================================

/// Result of likely subtags lookup
const LikelySubtagsResult = struct {
    language: []const u8,
    script: ?[]const u8,
    region: ?[]const u8,
};

/// Simplified likely subtags lookup table
/// Full implementation requires CLDR likelySubtags.json data.
///
/// Reference: https://github.com/unicode-org/cldr-json/blob/main/cldr-json/cldr-core/supplemental/likelySubtags.json
fn lookupLikelySubtags(language: []const u8, script: ?[]const u8, region: ?[]const u8) LikelySubtagsResult {
    // Common likely subtags (subset of CLDR data)
    const LikelyEntry = struct {
        lang: []const u8,
        script: ?[]const u8,
        region: ?[]const u8,
        result_script: []const u8,
        result_region: []const u8,
    };

    const likely_subtags = [_]LikelyEntry{
        // Primary languages with default script and region
        .{ .lang = "en", .script = null, .region = null, .result_script = "Latn", .result_region = "US" },
        .{ .lang = "zh", .script = null, .region = null, .result_script = "Hans", .result_region = "CN" },
        .{ .lang = "zh", .script = null, .region = "TW", .result_script = "Hant", .result_region = "TW" },
        .{ .lang = "zh", .script = null, .region = "HK", .result_script = "Hant", .result_region = "HK" },
        .{ .lang = "zh", .script = null, .region = "MO", .result_script = "Hant", .result_region = "MO" },
        .{ .lang = "zh", .script = "Hant", .region = null, .result_script = "Hant", .result_region = "TW" },
        .{ .lang = "zh", .script = "Hans", .region = null, .result_script = "Hans", .result_region = "CN" },
        .{ .lang = "ja", .script = null, .region = null, .result_script = "Jpan", .result_region = "JP" },
        .{ .lang = "ko", .script = null, .region = null, .result_script = "Kore", .result_region = "KR" },
        .{ .lang = "ar", .script = null, .region = null, .result_script = "Arab", .result_region = "EG" },
        .{ .lang = "ru", .script = null, .region = null, .result_script = "Cyrl", .result_region = "RU" },
        .{ .lang = "hi", .script = null, .region = null, .result_script = "Deva", .result_region = "IN" },
        .{ .lang = "de", .script = null, .region = null, .result_script = "Latn", .result_region = "DE" },
        .{ .lang = "fr", .script = null, .region = null, .result_script = "Latn", .result_region = "FR" },
        .{ .lang = "es", .script = null, .region = null, .result_script = "Latn", .result_region = "ES" },
        .{ .lang = "pt", .script = null, .region = null, .result_script = "Latn", .result_region = "BR" },
        .{ .lang = "pt", .script = null, .region = "PT", .result_script = "Latn", .result_region = "PT" },
        .{ .lang = "it", .script = null, .region = null, .result_script = "Latn", .result_region = "IT" },
        .{ .lang = "nl", .script = null, .region = null, .result_script = "Latn", .result_region = "NL" },
        .{ .lang = "pl", .script = null, .region = null, .result_script = "Latn", .result_region = "PL" },
        .{ .lang = "uk", .script = null, .region = null, .result_script = "Cyrl", .result_region = "UA" },
        .{ .lang = "tr", .script = null, .region = null, .result_script = "Latn", .result_region = "TR" },
        .{ .lang = "vi", .script = null, .region = null, .result_script = "Latn", .result_region = "VN" },
        .{ .lang = "th", .script = null, .region = null, .result_script = "Thai", .result_region = "TH" },
        .{ .lang = "he", .script = null, .region = null, .result_script = "Hebr", .result_region = "IL" },
        .{ .lang = "fa", .script = null, .region = null, .result_script = "Arab", .result_region = "IR" },
        .{ .lang = "bn", .script = null, .region = null, .result_script = "Beng", .result_region = "BD" },
        .{ .lang = "ta", .script = null, .region = null, .result_script = "Taml", .result_region = "IN" },
        .{ .lang = "te", .script = null, .region = null, .result_script = "Telu", .result_region = "IN" },
        .{ .lang = "mr", .script = null, .region = null, .result_script = "Deva", .result_region = "IN" },
        .{ .lang = "gu", .script = null, .region = null, .result_script = "Gujr", .result_region = "IN" },
        .{ .lang = "kn", .script = null, .region = null, .result_script = "Knda", .result_region = "IN" },
        .{ .lang = "ml", .script = null, .region = null, .result_script = "Mlym", .result_region = "IN" },
        .{ .lang = "pa", .script = null, .region = null, .result_script = "Guru", .result_region = "IN" },
        .{ .lang = "sr", .script = null, .region = null, .result_script = "Cyrl", .result_region = "RS" },
        .{ .lang = "sr", .script = "Latn", .region = null, .result_script = "Latn", .result_region = "RS" },
        .{ .lang = "id", .script = null, .region = null, .result_script = "Latn", .result_region = "ID" },
        .{ .lang = "ms", .script = null, .region = null, .result_script = "Latn", .result_region = "MY" },
        .{ .lang = "fil", .script = null, .region = null, .result_script = "Latn", .result_region = "PH" },
        .{ .lang = "sw", .script = null, .region = null, .result_script = "Latn", .result_region = "TZ" },
        .{ .lang = "cs", .script = null, .region = null, .result_script = "Latn", .result_region = "CZ" },
        .{ .lang = "sk", .script = null, .region = null, .result_script = "Latn", .result_region = "SK" },
        .{ .lang = "hu", .script = null, .region = null, .result_script = "Latn", .result_region = "HU" },
        .{ .lang = "ro", .script = null, .region = null, .result_script = "Latn", .result_region = "RO" },
        .{ .lang = "bg", .script = null, .region = null, .result_script = "Cyrl", .result_region = "BG" },
        .{ .lang = "el", .script = null, .region = null, .result_script = "Grek", .result_region = "GR" },
        .{ .lang = "sv", .script = null, .region = null, .result_script = "Latn", .result_region = "SE" },
        .{ .lang = "da", .script = null, .region = null, .result_script = "Latn", .result_region = "DK" },
        .{ .lang = "no", .script = null, .region = null, .result_script = "Latn", .result_region = "NO" },
        .{ .lang = "fi", .script = null, .region = null, .result_script = "Latn", .result_region = "FI" },
        .{ .lang = "nb", .script = null, .region = null, .result_script = "Latn", .result_region = "NO" },
        .{ .lang = "nn", .script = null, .region = null, .result_script = "Latn", .result_region = "NO" },
        .{ .lang = "ca", .script = null, .region = null, .result_script = "Latn", .result_region = "ES" },
        .{ .lang = "hr", .script = null, .region = null, .result_script = "Latn", .result_region = "HR" },
        .{ .lang = "sl", .script = null, .region = null, .result_script = "Latn", .result_region = "SI" },
        .{ .lang = "et", .script = null, .region = null, .result_script = "Latn", .result_region = "EE" },
        .{ .lang = "lv", .script = null, .region = null, .result_script = "Latn", .result_region = "LV" },
        .{ .lang = "lt", .script = null, .region = null, .result_script = "Latn", .result_region = "LT" },
    };

    // Look for exact match first (language + script + region)
    for (likely_subtags) |entry| {
        if (std.mem.eql(u8, entry.lang, language)) {
            // Check script match
            const script_matches = if (script == null and entry.script == null)
                true
            else if (script != null and entry.script != null)
                std.mem.eql(u8, script.?, entry.script.?)
            else
                false;

            // Check region match
            const region_matches = if (region == null and entry.region == null)
                true
            else if (region != null and entry.region != null)
                std.mem.eql(u8, region.?, entry.region.?)
            else
                false;

            if (script_matches and region_matches) {
                return .{
                    .language = entry.lang,
                    .script = entry.result_script,
                    .region = entry.result_region,
                };
            }
        }
    }

    // Try partial match (language + script)
    if (script != null and region == null) {
        for (likely_subtags) |entry| {
            if (std.mem.eql(u8, entry.lang, language) and entry.script != null and
                std.mem.eql(u8, script.?, entry.script.?) and entry.region == null)
            {
                return .{
                    .language = entry.lang,
                    .script = entry.result_script,
                    .region = entry.result_region,
                };
            }
        }
    }

    // Try partial match (language + region)
    if (script == null and region != null) {
        for (likely_subtags) |entry| {
            if (std.mem.eql(u8, entry.lang, language) and entry.script == null and
                entry.region != null and std.mem.eql(u8, region.?, entry.region.?))
            {
                return .{
                    .language = entry.lang,
                    .script = entry.result_script,
                    .region = entry.result_region,
                };
            }
        }
    }

    // Try language-only match
    for (likely_subtags) |entry| {
        if (std.mem.eql(u8, entry.lang, language) and entry.script == null and entry.region == null) {
            return .{
                .language = entry.lang,
                .script = entry.result_script,
                .region = entry.result_region,
            };
        }
    }

    // No match found, return as-is
    return .{
        .language = language,
        .script = script,
        .region = region,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "parse simple language tag" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en");
    defer locale.deinit();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expect(locale.script == null);
    try std.testing.expect(locale.region == null);
}

test "parse language + region" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-US");
    defer locale.deinit();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("US", locale.region.?);
}

test "parse language + script + region" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh-Hans-CN");
    defer locale.deinit();

    try std.testing.expectEqualStrings("zh", locale.language);
    try std.testing.expectEqualStrings("Hans", locale.script.?);
    try std.testing.expectEqualStrings("CN", locale.region.?);
}

test "parse with unicode extension" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-US-u-ca-buddhist");
    defer locale.deinit();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("US", locale.region.?);
    try std.testing.expectEqualStrings("buddhist", locale.unicode_extensions.calendar.?);
}

test "parse with hour cycle" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-u-hc-h12");
    defer locale.deinit();

    try std.testing.expect(locale.unicode_extensions.hour_cycle == .h12);
}

test "parse case insensitive" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "EN-us");
    defer locale.deinit();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("US", locale.region.?);
}

test "toString round-trip" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh-Hans-CN");
    defer locale.deinit();

    const str = try locale.toString(allocator);
    defer allocator.free(str);

    try std.testing.expectEqualStrings("zh-Hans-CN", str);
}

test "toBaseName" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-US-u-ca-buddhist");
    defer locale.deinit();

    const base = try locale.toBaseName(allocator);
    defer allocator.free(base);

    try std.testing.expectEqualStrings("en-US", base);
}

test "invalid empty tag" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(ParseError.EmptyTag, Locale.parse(allocator, ""));
}

test "invalid language" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(ParseError.InvalidLanguage, Locale.parse(allocator, "x"));
    try std.testing.expectError(ParseError.InvalidLanguage, Locale.parse(allocator, "123"));
}

test "matches" {
    const allocator = std.testing.allocator;

    var en_us = try Locale.parse(allocator, "en-US");
    defer en_us.deinit();

    var en_us2 = try Locale.parse(allocator, "en-US");
    defer en_us2.deinit();

    var en_gb = try Locale.parse(allocator, "en-GB");
    defer en_gb.deinit();

    try std.testing.expect(en_us.matches(en_us2));
    try std.testing.expect(!en_us.matches(en_gb));
}

test "maximize - en to en-Latn-US" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en");
    defer locale.deinit();

    try locale.maximize();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("Latn", locale.script.?);
    try std.testing.expectEqualStrings("US", locale.region.?);
}

test "maximize - zh to zh-Hans-CN" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh");
    defer locale.deinit();

    try locale.maximize();

    try std.testing.expectEqualStrings("zh", locale.language);
    try std.testing.expectEqualStrings("Hans", locale.script.?);
    try std.testing.expectEqualStrings("CN", locale.region.?);
}

test "maximize - zh-TW to zh-Hant-TW" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh-TW");
    defer locale.deinit();

    try locale.maximize();

    try std.testing.expectEqualStrings("zh", locale.language);
    try std.testing.expectEqualStrings("Hant", locale.script.?);
    try std.testing.expectEqualStrings("TW", locale.region.?);
}

test "maximize - zh-Hant to zh-Hant-TW" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh-Hant");
    defer locale.deinit();

    try locale.maximize();

    try std.testing.expectEqualStrings("zh", locale.language);
    try std.testing.expectEqualStrings("Hant", locale.script.?);
    try std.testing.expectEqualStrings("TW", locale.region.?);
}

test "maximize - ja to ja-Jpan-JP" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "ja");
    defer locale.deinit();

    try locale.maximize();

    try std.testing.expectEqualStrings("ja", locale.language);
    try std.testing.expectEqualStrings("Jpan", locale.script.?);
    try std.testing.expectEqualStrings("JP", locale.region.?);
}

test "maximize - already maximized stays same" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-Latn-US");
    defer locale.deinit();

    try locale.maximize();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("Latn", locale.script.?);
    try std.testing.expectEqualStrings("US", locale.region.?);
}

test "minimize - en-Latn-US to en" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-Latn-US");
    defer locale.deinit();

    locale.minimize();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expect(locale.script == null);
    try std.testing.expect(locale.region == null);
}

test "minimize - zh-Hans-CN to zh" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh-Hans-CN");
    defer locale.deinit();

    locale.minimize();

    try std.testing.expectEqualStrings("zh", locale.language);
    try std.testing.expect(locale.script == null);
    try std.testing.expect(locale.region == null);
}

test "minimize - zh-Hant-TW to zh-TW" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "zh-Hant-TW");
    defer locale.deinit();

    locale.minimize();

    try std.testing.expectEqualStrings("zh", locale.language);
    // zh-Hant-TW minimizes to zh-TW (Hant is implied by TW)
    try std.testing.expect(locale.script == null);
    try std.testing.expectEqualStrings("TW", locale.region.?);
}

test "minimize - already minimal stays same" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en");
    defer locale.deinit();

    locale.minimize();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expect(locale.script == null);
    try std.testing.expect(locale.region == null);
}

test "parse transform extension - source locale" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-t-ja");
    defer locale.deinit();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("ja", locale.transform_extensions.source_locale.?);
}

test "parse private use extension" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-x-custom");
    defer locale.deinit();

    try std.testing.expectEqualStrings("en", locale.language);
    try std.testing.expectEqualStrings("custom", locale.private_use.?);
}

test "parse with variant" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "ca-ES-valencia");
    defer locale.deinit();

    try std.testing.expectEqualStrings("ca", locale.language);
    try std.testing.expectEqualStrings("ES", locale.region.?);
    try std.testing.expect(locale.variants != null);
    try std.testing.expect(locale.variants.?.len == 1);
    try std.testing.expectEqualStrings("valencia", locale.variants.?[0]);
}

test "parse numeric region code" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "es-419");
    defer locale.deinit();

    try std.testing.expectEqualStrings("es", locale.language);
    try std.testing.expectEqualStrings("419", locale.region.?);
}

test "toString with unicode extension roundtrip" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-US-u-ca-buddhist");
    defer locale.deinit();

    const str = try locale.toString(allocator);
    defer allocator.free(str);

    try std.testing.expectEqualStrings("en-US-u-ca-buddhist", str);
}

test "toString with transform extension roundtrip" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-t-ja");
    defer locale.deinit();

    const str = try locale.toString(allocator);
    defer allocator.free(str);

    try std.testing.expectEqualStrings("en-t-ja", str);
}

test "toString with private use roundtrip" {
    const allocator = std.testing.allocator;

    var locale = try Locale.parse(allocator, "en-x-custom-value");
    defer locale.deinit();

    const str = try locale.toString(allocator);
    defer allocator.free(str);

    try std.testing.expectEqualStrings("en-x-custom-value", str);
}
