//! Unicode and Transform Extensions for BCP 47
//!
//! Implements parsing and handling of:
//! - Unicode locale extensions (-u-): UTS 35 §3.6
//! - Transform extensions (-t-): UTS 35 §3.7
//!
//! ## Unicode Extension Keys
//!
//! Common keys (prefixed with -u-):
//! - ca: Calendar (buddhist, chinese, gregory, etc.)
//! - co: Collation (phonebk, pinyin, standard, etc.)
//! - cu: Currency (USD, EUR, etc.)
//! - hc: Hour cycle (h11, h12, h23, h24)
//! - nu: Numbering system (arab, latn, etc.)
//! - kn: Numeric collation (true, false)
//! - kf: Case first (upper, lower, false)
//!
//! ## Examples
//!
//! ```
//! en-u-ca-buddhist      // English with Buddhist calendar
//! en-u-hc-h12-nu-arab   // English with 12-hour cycle and Arabic numerals
//! en-t-ja               // English, transformed from Japanese
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Hour cycle preference for time formatting
pub const HourCycle = enum {
    /// 12-hour clock, 0-11 (rare)
    h11,
    /// 12-hour clock, 1-12 (common in US)
    h12,
    /// 24-hour clock, 0-23 (common in Europe)
    h23,
    /// 24-hour clock, 1-24 (rare)
    h24,

    pub fn fromString(s: []const u8) ?HourCycle {
        if (std.mem.eql(u8, s, "h11")) return .h11;
        if (std.mem.eql(u8, s, "h12")) return .h12;
        if (std.mem.eql(u8, s, "h23")) return .h23;
        if (std.mem.eql(u8, s, "h24")) return .h24;
        return null;
    }

    pub fn toString(self: HourCycle) []const u8 {
        return switch (self) {
            .h11 => "h11",
            .h12 => "h12",
            .h23 => "h23",
            .h24 => "h24",
        };
    }
};

/// Case ordering for collation
pub const CaseFirst = enum {
    /// Uppercase sorts first
    upper,
    /// Lowercase sorts first
    lower,
    /// Default ordering
    false_,

    pub fn fromString(s: []const u8) ?CaseFirst {
        if (std.mem.eql(u8, s, "upper")) return .upper;
        if (std.mem.eql(u8, s, "lower")) return .lower;
        if (std.mem.eql(u8, s, "false")) return .false_;
        return null;
    }

    pub fn toString(self: CaseFirst) []const u8 {
        return switch (self) {
            .upper => "upper",
            .lower => "lower",
            .false_ => "false",
        };
    }
};

/// Unicode locale extensions (-u-)
///
/// Stores parsed Unicode extension keywords from BCP 47 tags.
/// All string fields are owned by the parent Locale and freed in its deinit.
pub const UnicodeExtensions = struct {
    /// Calendar type (ca): buddhist, chinese, gregory, hebrew, islamic, etc.
    calendar: ?[]const u8 = null,

    /// Collation type (co): phonebk, pinyin, standard, stroke, etc.
    collation: ?[]const u8 = null,

    /// Currency (cu): USD, EUR, JPY, etc.
    currency: ?[]const u8 = null,

    /// Hour cycle (hc): h11, h12, h23, h24
    hour_cycle: ?HourCycle = null,

    /// Numbering system (nu): arab, latn, thai, etc.
    numbering_system: ?[]const u8 = null,

    /// Numeric collation (kn): true, false
    numeric: ?bool = null,

    /// Case first (kf): upper, lower, false
    case_first: ?CaseFirst = null,

    /// Collation strength (ks): level1, level2, level3, level4, identic
    collation_strength: ?[]const u8 = null,

    /// Line break word (lw): normal, breakall, keepall, phrase
    line_break_word: ?[]const u8 = null,

    /// Region override (rg): uszzzz, gbzzzz, etc.
    region_override: ?[]const u8 = null,

    /// Time zone (tz): uslax, usnyc, etc.
    timezone: ?[]const u8 = null,

    /// First day of week (fw): sun, mon, etc.
    first_day: ?[]const u8 = null,

    /// Raw unparsed keys for unknown extensions
    /// Key-value pairs stored as: [key0, val0, key1, val1, ...]
    other_keywords: ?[]const []const u8 = null,

    const Self = @This();

    /// Check if any extension is set
    pub fn isEmpty(self: Self) bool {
        return self.calendar == null and
            self.collation == null and
            self.currency == null and
            self.hour_cycle == null and
            self.numbering_system == null and
            self.numeric == null and
            self.case_first == null and
            self.collation_strength == null and
            self.line_break_word == null and
            self.region_override == null and
            self.timezone == null and
            self.first_day == null and
            self.other_keywords == null;
    }
};

/// Transform extensions (-t-)
///
/// Transform extensions indicate that the locale is a transformation
/// of another locale or language.
pub const TransformExtensions = struct {
    /// Source locale for the transformation
    source_locale: ?[]const u8 = null,

    /// Mechanism used for transformation (m0)
    mechanism: ?[]const u8 = null,

    /// Source (s0): keyboard, etc.
    source: ?[]const u8 = null,

    /// Destination (d0): fwidth, hwidth, etc.
    destination: ?[]const u8 = null,

    /// Input method (i0): handwrit, pinyin, etc.
    input_method: ?[]const u8 = null,

    /// Keyboard (k0): 101key, dvorak, etc.
    keyboard: ?[]const u8 = null,

    /// Translation type (t0): und, etc.
    translation: ?[]const u8 = null,

    /// Hybrid locale (h0): hybrid, etc.
    hybrid: ?[]const u8 = null,

    /// Other transform keywords
    other_keywords: ?[]const []const u8 = null,

    const Self = @This();

    /// Check if any extension is set
    pub fn isEmpty(self: Self) bool {
        return self.source_locale == null and
            self.mechanism == null and
            self.source == null and
            self.destination == null and
            self.input_method == null and
            self.keyboard == null and
            self.translation == null and
            self.hybrid == null and
            self.other_keywords == null;
    }
};

/// Private use extensions (-x-)
pub const PrivateUseExtension = struct {
    /// Raw value after -x-
    value: []const u8,
};

test "HourCycle.fromString" {
    try std.testing.expectEqual(HourCycle.h11, HourCycle.fromString("h11").?);
    try std.testing.expectEqual(HourCycle.h12, HourCycle.fromString("h12").?);
    try std.testing.expectEqual(HourCycle.h23, HourCycle.fromString("h23").?);
    try std.testing.expectEqual(HourCycle.h24, HourCycle.fromString("h24").?);
    try std.testing.expect(HourCycle.fromString("invalid") == null);
}

test "CaseFirst.fromString" {
    try std.testing.expectEqual(CaseFirst.upper, CaseFirst.fromString("upper").?);
    try std.testing.expectEqual(CaseFirst.lower, CaseFirst.fromString("lower").?);
    try std.testing.expectEqual(CaseFirst.false_, CaseFirst.fromString("false").?);
    try std.testing.expect(CaseFirst.fromString("invalid") == null);
}

test "UnicodeExtensions.isEmpty" {
    const empty = UnicodeExtensions{};
    try std.testing.expect(empty.isEmpty());

    const with_calendar = UnicodeExtensions{ .calendar = "buddhist" };
    try std.testing.expect(!with_calendar.isEmpty());
}

test "TransformExtensions.isEmpty" {
    const empty = TransformExtensions{};
    try std.testing.expect(empty.isEmpty());

    const with_source = TransformExtensions{ .source_locale = "ja" };
    try std.testing.expect(!with_source.isEmpty());
}
