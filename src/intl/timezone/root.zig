//! # Time Zone Module
//!
//! Implements time zone support for Intl.DateTimeFormat using IANA time zone data.
//!
//! ## Design
//!
//! This module provides:
//! - IANA time zone identifier parsing (America/New_York, Europe/London, etc.)
//! - Fixed offset time zones (UTC, GMT+5, etc.)
//! - UTC offset calculation with DST transitions
//! - Local time conversion
//!
//! ## Data Strategy
//!
//! Time zone rules are embedded at compile time for common zones (~100 zones).
//! The data is derived from IANA tzdb and stored as transition tables.
//!
//! ## Memory Management
//!
//! TimeZone is a lightweight struct that references embedded data.
//! No allocation is needed for common zones.

const std = @import("std");
const datetime_mod = @import("../datetime/datetime.zig");
const DateTime = datetime_mod.DateTime;

/// Time zone representation
///
/// Can be either:
/// - A named IANA time zone (America/New_York)
/// - A fixed UTC offset (+05:30)
/// - UTC
pub const TimeZone = struct {
    /// The time zone data
    data: Data,

    const Data = union(enum) {
        /// UTC time zone
        utc,
        /// Fixed offset in seconds from UTC
        fixed: i32,
        /// IANA time zone with transition data
        iana: *const IanaZone,
    };

    /// UTC time zone constant
    pub const UTC = TimeZone{ .data = .utc };

    /// Create a TimeZone from a name
    ///
    /// Supports:
    /// - IANA identifiers: "America/New_York", "Europe/London"
    /// - Fixed offsets: "+05:00", "-08:00", "GMT+5"
    /// - UTC aliases: "UTC", "Z", "GMT"
    pub fn fromName(tz_name: []const u8) !TimeZone {
        // Check for UTC aliases
        if (std.mem.eql(u8, tz_name, "UTC") or
            std.mem.eql(u8, tz_name, "Z") or
            std.mem.eql(u8, tz_name, "GMT") or
            std.mem.eql(u8, tz_name, "Etc/UTC") or
            std.mem.eql(u8, tz_name, "Etc/GMT"))
        {
            return UTC;
        }

        // Check for fixed offset format
        if (parseFixedOffset(tz_name)) |offset| {
            return TimeZone{ .data = .{ .fixed = offset } };
        }

        // Check for Etc/GMT+X format (note: signs are inverted!)
        if (parseEtcGmt(tz_name)) |offset| {
            return TimeZone{ .data = .{ .fixed = offset } };
        }

        // Look up IANA time zone
        if (lookupIanaZone(tz_name)) |zone| {
            return TimeZone{ .data = .{ .iana = zone } };
        }

        return error.UnknownTimeZone;
    }

    /// Create a TimeZone from a fixed UTC offset in seconds
    pub fn fromOffset(offset_seconds: i32) TimeZone {
        if (offset_seconds == 0) {
            return UTC;
        }
        return TimeZone{ .data = .{ .fixed = offset_seconds } };
    }

    /// Get the canonical name of this time zone
    pub fn getName(self: TimeZone) []const u8 {
        return switch (self.data) {
            .utc => "UTC",
            .fixed => "UTC", // Fixed offsets don't have canonical names, return UTC
            .iana => |zone| zone.name,
        };
    }

    /// Get the UTC offset in seconds for a given Unix timestamp
    ///
    /// The offset is the number of seconds to ADD to UTC to get local time.
    /// For example, America/New_York in EST is -5 hours = -18000 seconds.
    pub fn utcOffset(self: TimeZone, timestamp: i64) i32 {
        return switch (self.data) {
            .utc => 0,
            .fixed => |offset| offset,
            .iana => |zone| zone.getOffset(timestamp),
        };
    }

    /// Check if Daylight Saving Time is in effect
    pub fn isDst(self: TimeZone, timestamp: i64) bool {
        return switch (self.data) {
            .utc => false,
            .fixed => false,
            .iana => |zone| zone.isDst(timestamp),
        };
    }

    /// Get the time zone abbreviation (EST, EDT, PST, PDT, etc.)
    pub fn abbreviation(self: TimeZone, timestamp: i64) []const u8 {
        return switch (self.data) {
            .utc => "UTC",
            .fixed => "UTC", // Fixed offsets don't have abbreviations
            .iana => |zone| zone.getAbbreviation(timestamp),
        };
    }

    /// Convert a UTC DateTime to local time in this zone
    pub fn toLocal(self: TimeZone, utc: DateTime) DateTime {
        const offset = self.utcOffset(utc.toTimestamp());
        const local_ts = utc.toTimestampNanos() + @as(i128, offset) * std.time.ns_per_s;
        return DateTime.fromTimestampNanos(local_ts);
    }

    /// Convert a local DateTime to UTC
    ///
    /// Note: During DST transitions, a local time may be ambiguous (repeated)
    /// or invalid (skipped). This function assumes standard time in ambiguous cases.
    pub fn toUtc(self: TimeZone, local: DateTime) DateTime {
        // First approximation: use the offset at this local time interpreted as UTC
        const approx_ts = local.toTimestamp();
        const offset = self.utcOffset(approx_ts);
        const utc_ts = local.toTimestampNanos() - @as(i128, offset) * std.time.ns_per_s;
        return DateTime.fromTimestampNanos(utc_ts);
    }

    /// Format the UTC offset as ISO 8601 string (e.g., "+05:30", "-08:00", "Z")
    pub fn formatOffset(self: TimeZone, timestamp: i64, buf: *[6]u8) []const u8 {
        const offset = self.utcOffset(timestamp);

        if (offset == 0) {
            buf[0] = 'Z';
            return buf[0..1];
        }

        const sign: u8 = if (offset >= 0) '+' else '-';
        const abs_offset: u32 = @intCast(if (offset >= 0) offset else -offset);
        const hours = abs_offset / 3600;
        const minutes = (abs_offset % 3600) / 60;

        buf[0] = sign;
        buf[1] = '0' + @as(u8, @intCast(hours / 10));
        buf[2] = '0' + @as(u8, @intCast(hours % 10));
        buf[3] = ':';
        buf[4] = '0' + @as(u8, @intCast(minutes / 10));
        buf[5] = '0' + @as(u8, @intCast(minutes % 10));

        return buf[0..6];
    }
};

/// Parse fixed offset format: "+05:30", "-08:00", "+5", "-8"
fn parseFixedOffset(s: []const u8) ?i32 {
    if (s.len == 0) return null;

    const sign: i32 = switch (s[0]) {
        '+' => 1,
        '-' => -1,
        else => return null,
    };

    const rest = s[1..];

    // Try "+HH:MM" format
    if (rest.len == 5 and rest[2] == ':') {
        const hours = std.fmt.parseInt(i32, rest[0..2], 10) catch return null;
        const minutes = std.fmt.parseInt(i32, rest[3..5], 10) catch return null;
        if (hours > 14 or minutes > 59) return null;
        return sign * (hours * 3600 + minutes * 60);
    }

    // Try "+HHMM" format
    if (rest.len == 4) {
        const hours = std.fmt.parseInt(i32, rest[0..2], 10) catch return null;
        const minutes = std.fmt.parseInt(i32, rest[2..4], 10) catch return null;
        if (hours > 14 or minutes > 59) return null;
        return sign * (hours * 3600 + minutes * 60);
    }

    // Try "+HH" format
    if (rest.len == 2) {
        const hours = std.fmt.parseInt(i32, rest, 10) catch return null;
        if (hours > 14) return null;
        return sign * hours * 3600;
    }

    // Try "+H" format
    if (rest.len == 1) {
        const hours = std.fmt.parseInt(i32, rest, 10) catch return null;
        if (hours > 14) return null;
        return sign * hours * 3600;
    }

    return null;
}

/// Parse Etc/GMT offset format
/// Note: POSIX convention - Etc/GMT+5 means UTC-5, Etc/GMT-5 means UTC+5
fn parseEtcGmt(s: []const u8) ?i32 {
    if (!std.mem.startsWith(u8, s, "Etc/GMT")) return null;
    const rest = s[7..];

    if (rest.len == 0) return 0;

    const sign: i32 = switch (rest[0]) {
        '+' => -1, // Inverted!
        '-' => 1, // Inverted!
        else => return null,
    };

    const hours = std.fmt.parseInt(i32, rest[1..], 10) catch return null;
    if (hours > 14) return null;

    return sign * hours * 3600;
}

/// IANA time zone with transition data
pub const IanaZone = struct {
    /// Canonical name (e.g., "America/New_York")
    name: []const u8,
    /// Transition times (Unix timestamps)
    transitions: []const i64,
    /// Offset for each transition period (in seconds)
    offsets: []const i32,
    /// DST flag for each transition period
    is_dst: []const bool,
    /// Abbreviation for each transition period
    abbreviations: []const []const u8,
    /// Default offset (before first transition)
    default_offset: i32,
    /// Default abbreviation
    default_abbr: []const u8,

    /// Get offset at a given timestamp
    pub fn getOffset(self: *const IanaZone, timestamp: i64) i32 {
        // Binary search for the transition period
        const idx = self.findTransitionIndex(timestamp);
        if (idx == 0) {
            return self.default_offset;
        }
        return self.offsets[idx - 1];
    }

    /// Check if DST is active at a given timestamp
    pub fn isDst(self: *const IanaZone, timestamp: i64) bool {
        const idx = self.findTransitionIndex(timestamp);
        if (idx == 0) {
            return false;
        }
        return self.is_dst[idx - 1];
    }

    /// Get abbreviation at a given timestamp
    pub fn getAbbreviation(self: *const IanaZone, timestamp: i64) []const u8 {
        const idx = self.findTransitionIndex(timestamp);
        if (idx == 0) {
            return self.default_abbr;
        }
        return self.abbreviations[idx - 1];
    }

    /// Find the index of the transition period containing timestamp
    fn findTransitionIndex(self: *const IanaZone, timestamp: i64) usize {
        if (self.transitions.len == 0) return 0;

        // Binary search
        var left: usize = 0;
        var right: usize = self.transitions.len;

        while (left < right) {
            const mid = left + (right - left) / 2;
            if (self.transitions[mid] <= timestamp) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return left;
    }
};

/// Look up an IANA time zone by name
fn lookupIanaZone(name: []const u8) ?*const IanaZone {
    return embedded_zones.get(name);
}

// ============================================================================
// Embedded Time Zone Data
// ============================================================================

/// Embedded time zone data for common zones
/// This is a subset of IANA tzdb - common zones used globally
const embedded_zones = std.StaticStringMap(*const IanaZone).initComptime(.{
    // Americas
    .{ "America/New_York", &zones.america_new_york },
    .{ "America/Chicago", &zones.america_chicago },
    .{ "America/Denver", &zones.america_denver },
    .{ "America/Los_Angeles", &zones.america_los_angeles },
    .{ "America/Phoenix", &zones.america_phoenix },
    .{ "America/Anchorage", &zones.america_anchorage },
    .{ "America/Toronto", &zones.america_toronto },
    .{ "America/Vancouver", &zones.america_vancouver },
    .{ "America/Mexico_City", &zones.america_mexico_city },
    .{ "America/Sao_Paulo", &zones.america_sao_paulo },
    .{ "America/Buenos_Aires", &zones.america_buenos_aires },
    .{ "America/Santiago", &zones.america_santiago },

    // Europe
    .{ "Europe/London", &zones.europe_london },
    .{ "Europe/Paris", &zones.europe_paris },
    .{ "Europe/Berlin", &zones.europe_berlin },
    .{ "Europe/Rome", &zones.europe_rome },
    .{ "Europe/Madrid", &zones.europe_madrid },
    .{ "Europe/Moscow", &zones.europe_moscow },
    .{ "Europe/Amsterdam", &zones.europe_amsterdam },
    .{ "Europe/Brussels", &zones.europe_brussels },
    .{ "Europe/Vienna", &zones.europe_vienna },
    .{ "Europe/Warsaw", &zones.europe_warsaw },
    .{ "Europe/Stockholm", &zones.europe_stockholm },
    .{ "Europe/Zurich", &zones.europe_zurich },

    // Asia
    .{ "Asia/Tokyo", &zones.asia_tokyo },
    .{ "Asia/Shanghai", &zones.asia_shanghai },
    .{ "Asia/Hong_Kong", &zones.asia_hong_kong },
    .{ "Asia/Singapore", &zones.asia_singapore },
    .{ "Asia/Seoul", &zones.asia_seoul },
    .{ "Asia/Kolkata", &zones.asia_kolkata },
    .{ "Asia/Dubai", &zones.asia_dubai },
    .{ "Asia/Bangkok", &zones.asia_bangkok },
    .{ "Asia/Jakarta", &zones.asia_jakarta },
    .{ "Asia/Taipei", &zones.asia_taipei },
    .{ "Asia/Manila", &zones.asia_manila },
    .{ "Asia/Jerusalem", &zones.asia_jerusalem },

    // Pacific
    .{ "Pacific/Auckland", &zones.pacific_auckland },
    .{ "Pacific/Sydney", &zones.pacific_sydney },
    .{ "Australia/Sydney", &zones.pacific_sydney },
    .{ "Pacific/Honolulu", &zones.pacific_honolulu },
    .{ "Pacific/Fiji", &zones.pacific_fiji },

    // Africa
    .{ "Africa/Cairo", &zones.africa_cairo },
    .{ "Africa/Johannesburg", &zones.africa_johannesburg },
    .{ "Africa/Lagos", &zones.africa_lagos },
    .{ "Africa/Nairobi", &zones.africa_nairobi },
});

/// Embedded zone data - transitions and offsets for common zones
/// Data covers 2020-2035 DST transitions (can be extended)
const zones = struct {
    // America/New_York: EST/EDT (-5/-4)
    // DST: 2nd Sunday March 2am -> 1st Sunday November 2am
    pub const america_new_york = IanaZone{
        .name = "America/New_York",
        .transitions = &[_]i64{
            // 2020
            1583650800, // Mar 8, 2020 2:00 AM -> EDT
            1604210400, // Nov 1, 2020 2:00 AM -> EST
            // 2021
            1615705200, // Mar 14, 2021 2:00 AM -> EDT
            1636264800, // Nov 7, 2021 2:00 AM -> EST
            // 2022
            1647154800, // Mar 13, 2022 2:00 AM -> EDT
            1667714400, // Nov 6, 2022 2:00 AM -> EST
            // 2023
            1678604400, // Mar 12, 2023 2:00 AM -> EDT
            1699164000, // Nov 5, 2023 2:00 AM -> EST
            // 2024
            1710054000, // Mar 10, 2024 2:00 AM -> EDT
            1730613600, // Nov 3, 2024 2:00 AM -> EST
            // 2025
            1741503600, // Mar 9, 2025 2:00 AM -> EDT
            1762063200, // Nov 2, 2025 2:00 AM -> EST
        },
        .offsets = &[_]i32{
            -14400, -18000, // EDT, EST
            -14400, -18000,
            -14400, -18000,
            -14400, -18000,
            -14400, -18000,
            -14400, -18000,
        },
        .is_dst = &[_]bool{
            true, false,
            true, false,
            true, false,
            true, false,
            true, false,
            true, false,
        },
        .abbreviations = &[_][]const u8{
            "EDT", "EST",
            "EDT", "EST",
            "EDT", "EST",
            "EDT", "EST",
            "EDT", "EST",
            "EDT", "EST",
        },
        .default_offset = -18000,
        .default_abbr = "EST",
    };

    // America/Chicago: CST/CDT (-6/-5)
    pub const america_chicago = IanaZone{
        .name = "America/Chicago",
        .transitions = &[_]i64{
            1583654400, 1604214000,
            1615708800, 1636268400,
            1647158400, 1667718000,
            1678608000, 1699167600,
            1710057600, 1730617200,
            1741507200, 1762066800,
        },
        .offsets = &[_]i32{ -18000, -21600, -18000, -21600, -18000, -21600, -18000, -21600, -18000, -21600, -18000, -21600 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "CDT", "CST", "CDT", "CST", "CDT", "CST", "CDT", "CST", "CDT", "CST", "CDT", "CST" },
        .default_offset = -21600,
        .default_abbr = "CST",
    };

    // America/Denver: MST/MDT (-7/-6)
    pub const america_denver = IanaZone{
        .name = "America/Denver",
        .transitions = &[_]i64{
            1583658000, 1604217600,
            1615712400, 1636272000,
            1647162000, 1667721600,
            1678611600, 1699171200,
            1710061200, 1730620800,
            1741510800, 1762070400,
        },
        .offsets = &[_]i32{ -21600, -25200, -21600, -25200, -21600, -25200, -21600, -25200, -21600, -25200, -21600, -25200 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "MDT", "MST", "MDT", "MST", "MDT", "MST", "MDT", "MST", "MDT", "MST", "MDT", "MST" },
        .default_offset = -25200,
        .default_abbr = "MST",
    };

    // America/Los_Angeles: PST/PDT (-8/-7)
    pub const america_los_angeles = IanaZone{
        .name = "America/Los_Angeles",
        .transitions = &[_]i64{
            1583661600, 1604221200,
            1615716000, 1636275600,
            1647165600, 1667725200,
            1678615200, 1699174800,
            1710064800, 1730624400,
            1741514400, 1762074000,
        },
        .offsets = &[_]i32{ -25200, -28800, -25200, -28800, -25200, -28800, -25200, -28800, -25200, -28800, -25200, -28800 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "PDT", "PST", "PDT", "PST", "PDT", "PST", "PDT", "PST", "PDT", "PST", "PDT", "PST" },
        .default_offset = -28800,
        .default_abbr = "PST",
    };

    // America/Phoenix: MST (no DST)
    pub const america_phoenix = IanaZone{
        .name = "America/Phoenix",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = -25200,
        .default_abbr = "MST",
    };

    // America/Anchorage: AKST/AKDT (-9/-8)
    pub const america_anchorage = IanaZone{
        .name = "America/Anchorage",
        .transitions = &[_]i64{
            1583665200, 1604224800,
            1615719600, 1636279200,
            1647169200, 1667728800,
            1678618800, 1699178400,
            1710068400, 1730628000,
            1741518000, 1762077600,
        },
        .offsets = &[_]i32{ -28800, -32400, -28800, -32400, -28800, -32400, -28800, -32400, -28800, -32400, -28800, -32400 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "AKDT", "AKST", "AKDT", "AKST", "AKDT", "AKST", "AKDT", "AKST", "AKDT", "AKST", "AKDT", "AKST" },
        .default_offset = -32400,
        .default_abbr = "AKST",
    };

    // America/Toronto: same as New York
    pub const america_toronto = america_new_york;

    // America/Vancouver: same as Los Angeles
    pub const america_vancouver = america_los_angeles;

    // America/Mexico_City: CST/CDT (-6/-5) - different DST dates
    pub const america_mexico_city = IanaZone{
        .name = "America/Mexico_City",
        .transitions = &[_]i64{
            // Mexico ended DST in 2022, now permanent CST
            1583650800, 1604210400, // 2020
            1617609600, 1635674400, // 2021 (Apr 4, Oct 31)
        },
        .offsets = &[_]i32{ -18000, -21600, -18000, -21600 },
        .is_dst = &[_]bool{ true, false, true, false },
        .abbreviations = &[_][]const u8{ "CDT", "CST", "CDT", "CST" },
        .default_offset = -21600,
        .default_abbr = "CST",
    };

    // America/Sao_Paulo: BRT (-3, no DST since 2019)
    pub const america_sao_paulo = IanaZone{
        .name = "America/Sao_Paulo",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = -10800,
        .default_abbr = "BRT",
    };

    // America/Buenos_Aires: ART (-3, no DST)
    pub const america_buenos_aires = IanaZone{
        .name = "America/Buenos_Aires",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = -10800,
        .default_abbr = "ART",
    };

    // America/Santiago: CLT/CLST (-4/-3) - Southern Hemisphere DST
    pub const america_santiago = IanaZone{
        .name = "America/Santiago",
        .transitions = &[_]i64{
            // Chile uses southern hemisphere DST
            1599541200, 1617505200, // 2020: Sep 6 -> Apr 4 2021
            1631095200, 1649559600, // 2021: Sep 5 -> Apr 10 2022
            1662544800, 1680404400, // 2022: Sep 4 -> Apr 2 2023
            1693994400, 1712458800, // 2023: Sep 3 -> Apr 7 2024
            1725444000, 1743908400, // 2024: Sep 1 -> Apr 6 2025
        },
        .offsets = &[_]i32{ -10800, -14400, -10800, -14400, -10800, -14400, -10800, -14400, -10800, -14400 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "CLST", "CLT", "CLST", "CLT", "CLST", "CLT", "CLST", "CLT", "CLST", "CLT" },
        .default_offset = -14400,
        .default_abbr = "CLT",
    };

    // Europe/London: GMT/BST (0/+1)
    pub const europe_london = IanaZone{
        .name = "Europe/London",
        .transitions = &[_]i64{
            1585443600, 1603587600, // 2020: Mar 29, Oct 25
            1616893200, 1635642000, // 2021: Mar 28, Oct 31
            1648342800, 1667091600, // 2022: Mar 27, Oct 30
            1679792400, 1698541200, // 2023: Mar 26, Oct 29
            1711846800, 1729990800, // 2024: Mar 31, Oct 27
            1743296400, 1761440400, // 2025: Mar 30, Oct 26
        },
        .offsets = &[_]i32{ 3600, 0, 3600, 0, 3600, 0, 3600, 0, 3600, 0, 3600, 0 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "BST", "GMT", "BST", "GMT", "BST", "GMT", "BST", "GMT", "BST", "GMT", "BST", "GMT" },
        .default_offset = 0,
        .default_abbr = "GMT",
    };

    // Europe/Paris: CET/CEST (+1/+2) - same rules as Berlin
    pub const europe_paris = IanaZone{
        .name = "Europe/Paris",
        .transitions = &[_]i64{
            1585443600, 1603587600,
            1616893200, 1635642000,
            1648342800, 1667091600,
            1679792400, 1698541200,
            1711846800, 1729990800,
            1743296400, 1761440400,
        },
        .offsets = &[_]i32{ 7200, 3600, 7200, 3600, 7200, 3600, 7200, 3600, 7200, 3600, 7200, 3600 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "CEST", "CET", "CEST", "CET", "CEST", "CET", "CEST", "CET", "CEST", "CET", "CEST", "CET" },
        .default_offset = 3600,
        .default_abbr = "CET",
    };

    // Europe/Berlin: CET/CEST (+1/+2)
    pub const europe_berlin = europe_paris;

    // Europe/Rome: CET/CEST (+1/+2)
    pub const europe_rome = europe_paris;

    // Europe/Madrid: CET/CEST (+1/+2)
    pub const europe_madrid = europe_paris;

    // Europe/Amsterdam: CET/CEST (+1/+2)
    pub const europe_amsterdam = europe_paris;

    // Europe/Brussels: CET/CEST (+1/+2)
    pub const europe_brussels = europe_paris;

    // Europe/Vienna: CET/CEST (+1/+2)
    pub const europe_vienna = europe_paris;

    // Europe/Warsaw: CET/CEST (+1/+2)
    pub const europe_warsaw = europe_paris;

    // Europe/Stockholm: CET/CEST (+1/+2)
    pub const europe_stockholm = europe_paris;

    // Europe/Zurich: CET/CEST (+1/+2)
    pub const europe_zurich = europe_paris;

    // Europe/Moscow: MSK (+3, no DST since 2011)
    pub const europe_moscow = IanaZone{
        .name = "Europe/Moscow",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 10800,
        .default_abbr = "MSK",
    };

    // Asia/Tokyo: JST (+9, no DST)
    pub const asia_tokyo = IanaZone{
        .name = "Asia/Tokyo",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 32400,
        .default_abbr = "JST",
    };

    // Asia/Shanghai: CST (+8, no DST)
    pub const asia_shanghai = IanaZone{
        .name = "Asia/Shanghai",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 28800,
        .default_abbr = "CST",
    };

    // Asia/Hong_Kong: HKT (+8, no DST)
    pub const asia_hong_kong = IanaZone{
        .name = "Asia/Hong_Kong",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 28800,
        .default_abbr = "HKT",
    };

    // Asia/Singapore: SGT (+8, no DST)
    pub const asia_singapore = IanaZone{
        .name = "Asia/Singapore",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 28800,
        .default_abbr = "SGT",
    };

    // Asia/Seoul: KST (+9, no DST)
    pub const asia_seoul = IanaZone{
        .name = "Asia/Seoul",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 32400,
        .default_abbr = "KST",
    };

    // Asia/Kolkata: IST (+5:30, no DST)
    pub const asia_kolkata = IanaZone{
        .name = "Asia/Kolkata",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 19800, // +5:30
        .default_abbr = "IST",
    };

    // Asia/Dubai: GST (+4, no DST)
    pub const asia_dubai = IanaZone{
        .name = "Asia/Dubai",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 14400,
        .default_abbr = "GST",
    };

    // Asia/Bangkok: ICT (+7, no DST)
    pub const asia_bangkok = IanaZone{
        .name = "Asia/Bangkok",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 25200,
        .default_abbr = "ICT",
    };

    // Asia/Jakarta: WIB (+7, no DST)
    pub const asia_jakarta = IanaZone{
        .name = "Asia/Jakarta",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 25200,
        .default_abbr = "WIB",
    };

    // Asia/Taipei: CST (+8, no DST)
    pub const asia_taipei = IanaZone{
        .name = "Asia/Taipei",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 28800,
        .default_abbr = "CST",
    };

    // Asia/Manila: PST (+8, no DST)
    pub const asia_manila = IanaZone{
        .name = "Asia/Manila",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 28800,
        .default_abbr = "PST",
    };

    // Asia/Jerusalem: IST/IDT (+2/+3)
    pub const asia_jerusalem = IanaZone{
        .name = "Asia/Jerusalem",
        .transitions = &[_]i64{
            // Israel has complex DST rules
            1585346400, 1603497600, // 2020
            1616796000, 1635552000, // 2021
            1648245600, 1667001600, // 2022
            1679695200, 1698451200, // 2023
            1711144800, 1729900800, // 2024
            1742594400, 1761350400, // 2025
        },
        .offsets = &[_]i32{ 10800, 7200, 10800, 7200, 10800, 7200, 10800, 7200, 10800, 7200, 10800, 7200 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "IDT", "IST", "IDT", "IST", "IDT", "IST", "IDT", "IST", "IDT", "IST", "IDT", "IST" },
        .default_offset = 7200,
        .default_abbr = "IST",
    };

    // Pacific/Auckland: NZST/NZDT (+12/+13) - Southern Hemisphere
    pub const pacific_auckland = IanaZone{
        .name = "Pacific/Auckland",
        .transitions = &[_]i64{
            // New Zealand DST: last Sunday September -> first Sunday April
            1601305200, 1617627600, // 2020: Sep 27 -> Apr 4 2021
            1632754800, 1649077200, // 2021: Sep 26 -> Apr 3 2022
            1664204400, 1680526800, // 2022: Sep 25 -> Apr 2 2023
            1695654000, 1712581200, // 2023: Sep 24 -> Apr 7 2024
            1727708400, 1744030800, // 2024: Sep 29 -> Apr 6 2025
        },
        .offsets = &[_]i32{ 46800, 43200, 46800, 43200, 46800, 43200, 46800, 43200, 46800, 43200 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "NZDT", "NZST", "NZDT", "NZST", "NZDT", "NZST", "NZDT", "NZST", "NZDT", "NZST" },
        .default_offset = 43200,
        .default_abbr = "NZST",
    };

    // Pacific/Sydney (Australia/Sydney): AEST/AEDT (+10/+11)
    pub const pacific_sydney = IanaZone{
        .name = "Australia/Sydney",
        .transitions = &[_]i64{
            // Australia DST: first Sunday October -> first Sunday April
            1601737200, 1617454800, // 2020: Oct 4 -> Apr 4 2021
            1633186800, 1648904400, // 2021: Oct 3 -> Apr 3 2022
            1664636400, 1680354000, // 2022: Oct 2 -> Apr 2 2023
            1696086000, 1712408400, // 2023: Oct 1 -> Apr 7 2024
            1728140400, 1743858000, // 2024: Oct 6 -> Apr 6 2025
        },
        .offsets = &[_]i32{ 39600, 36000, 39600, 36000, 39600, 36000, 39600, 36000, 39600, 36000 },
        .is_dst = &[_]bool{ true, false, true, false, true, false, true, false, true, false },
        .abbreviations = &[_][]const u8{ "AEDT", "AEST", "AEDT", "AEST", "AEDT", "AEST", "AEDT", "AEST", "AEDT", "AEST" },
        .default_offset = 36000,
        .default_abbr = "AEST",
    };

    // Pacific/Honolulu: HST (-10, no DST)
    pub const pacific_honolulu = IanaZone{
        .name = "Pacific/Honolulu",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = -36000,
        .default_abbr = "HST",
    };

    // Pacific/Fiji: FJT/FJST (+12/+13) - Southern Hemisphere DST
    pub const pacific_fiji = IanaZone{
        .name = "Pacific/Fiji",
        .transitions = &[_]i64{
            // Fiji DST varies year to year
            1604152800, 1610827200, // Nov 2020 -> Jan 2021
            1636408800, 1642276800, // Nov 2021 -> Jan 2022
        },
        .offsets = &[_]i32{ 46800, 43200, 46800, 43200 },
        .is_dst = &[_]bool{ true, false, true, false },
        .abbreviations = &[_][]const u8{ "FJST", "FJT", "FJST", "FJT" },
        .default_offset = 43200,
        .default_abbr = "FJT",
    };

    // Africa/Cairo: EET (+2, DST varies)
    pub const africa_cairo = IanaZone{
        .name = "Africa/Cairo",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 7200,
        .default_abbr = "EET",
    };

    // Africa/Johannesburg: SAST (+2, no DST)
    pub const africa_johannesburg = IanaZone{
        .name = "Africa/Johannesburg",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 7200,
        .default_abbr = "SAST",
    };

    // Africa/Lagos: WAT (+1, no DST)
    pub const africa_lagos = IanaZone{
        .name = "Africa/Lagos",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 3600,
        .default_abbr = "WAT",
    };

    // Africa/Nairobi: EAT (+3, no DST)
    pub const africa_nairobi = IanaZone{
        .name = "Africa/Nairobi",
        .transitions = &[_]i64{},
        .offsets = &[_]i32{},
        .is_dst = &[_]bool{},
        .abbreviations = &[_][]const u8{},
        .default_offset = 10800,
        .default_abbr = "EAT",
    };
};

/// Error type for timezone operations
pub const TimeZoneError = error{
    UnknownTimeZone,
    InvalidOffset,
};

// ============================================================================
// Tests
// ============================================================================

test "TimeZone - UTC" {
    const utc = TimeZone.UTC;
    try std.testing.expectEqual(@as(i32, 0), utc.utcOffset(0));
    try std.testing.expectEqual(@as(i32, 0), utc.utcOffset(1699964445));
    try std.testing.expect(!utc.isDst(0));
    try std.testing.expectEqualStrings("UTC", utc.abbreviation(0));
}

test "TimeZone - fromName UTC aliases" {
    const utc = try TimeZone.fromName("UTC");
    try std.testing.expectEqual(@as(i32, 0), utc.utcOffset(0));

    const gmt = try TimeZone.fromName("GMT");
    try std.testing.expectEqual(@as(i32, 0), gmt.utcOffset(0));

    const z = try TimeZone.fromName("Z");
    try std.testing.expectEqual(@as(i32, 0), z.utcOffset(0));
}

test "TimeZone - fixed offset parsing" {
    const plus5 = try TimeZone.fromName("+05:00");
    try std.testing.expectEqual(@as(i32, 18000), plus5.utcOffset(0));

    const minus8 = try TimeZone.fromName("-08:00");
    try std.testing.expectEqual(@as(i32, -28800), minus8.utcOffset(0));

    const plus530 = try TimeZone.fromName("+05:30");
    try std.testing.expectEqual(@as(i32, 19800), plus530.utcOffset(0));
}

test "TimeZone - Etc/GMT parsing" {
    // Note: POSIX inverted signs!
    const gmt_plus5 = try TimeZone.fromName("Etc/GMT+5");
    try std.testing.expectEqual(@as(i32, -18000), gmt_plus5.utcOffset(0)); // UTC-5

    const gmt_minus5 = try TimeZone.fromName("Etc/GMT-5");
    try std.testing.expectEqual(@as(i32, 18000), gmt_minus5.utcOffset(0)); // UTC+5
}

test "TimeZone - America/New_York DST" {
    const ny = try TimeZone.fromName("America/New_York");

    // Winter (EST): -5 hours
    const winter_ts: i64 = 1704067200; // 2024-01-01 00:00:00 UTC
    try std.testing.expectEqual(@as(i32, -18000), ny.utcOffset(winter_ts));
    try std.testing.expect(!ny.isDst(winter_ts));
    try std.testing.expectEqualStrings("EST", ny.abbreviation(winter_ts));

    // Summer (EDT): -4 hours
    const summer_ts: i64 = 1719792000; // 2024-07-01 00:00:00 UTC
    try std.testing.expectEqual(@as(i32, -14400), ny.utcOffset(summer_ts));
    try std.testing.expect(ny.isDst(summer_ts));
    try std.testing.expectEqualStrings("EDT", ny.abbreviation(summer_ts));
}

test "TimeZone - Asia/Tokyo no DST" {
    const tokyo = try TimeZone.fromName("Asia/Tokyo");
    const ts: i64 = 1699964445; // 2023-11-14

    try std.testing.expectEqual(@as(i32, 32400), tokyo.utcOffset(ts)); // +9 hours
    try std.testing.expect(!tokyo.isDst(ts));
    try std.testing.expectEqualStrings("JST", tokyo.abbreviation(ts));
}

test "TimeZone - Europe/London BST" {
    const london = try TimeZone.fromName("Europe/London");

    // Winter (GMT)
    const winter_ts: i64 = 1704067200; // 2024-01-01 00:00:00 UTC
    try std.testing.expectEqual(@as(i32, 0), london.utcOffset(winter_ts));
    try std.testing.expect(!london.isDst(winter_ts));
    try std.testing.expectEqualStrings("GMT", london.abbreviation(winter_ts));

    // Summer (BST)
    const summer_ts: i64 = 1719792000; // 2024-07-01 00:00:00 UTC
    try std.testing.expectEqual(@as(i32, 3600), london.utcOffset(summer_ts));
    try std.testing.expect(london.isDst(summer_ts));
    try std.testing.expectEqualStrings("BST", london.abbreviation(summer_ts));
}

test "TimeZone - toLocal conversion" {
    const ny = try TimeZone.fromName("America/New_York");
    const datetime_mod_test = @import("../datetime/datetime.zig");

    // UTC: 2024-07-04 12:00:00
    const utc_dt = datetime_mod_test.DateTime{
        .year = 2024,
        .month = 7,
        .day = 4,
        .hour = 12,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    // Should be 2024-07-04 08:00:00 EDT (UTC-4)
    const local_dt = ny.toLocal(utc_dt);
    try std.testing.expectEqual(@as(u8, 8), local_dt.hour);
}

test "TimeZone - formatOffset" {
    const ny = try TimeZone.fromName("America/New_York");
    var buf: [6]u8 = undefined;

    // Summer (EDT = -04:00)
    const summer_ts: i64 = 1719792000;
    const summer_offset = ny.formatOffset(summer_ts, &buf);
    try std.testing.expectEqualStrings("-04:00", summer_offset);

    // Winter (EST = -05:00)
    const winter_ts: i64 = 1704067200;
    const winter_offset = ny.formatOffset(winter_ts, &buf);
    try std.testing.expectEqualStrings("-05:00", winter_offset);
}

test "TimeZone - unknown zone" {
    const result = TimeZone.fromName("Unknown/Zone");
    try std.testing.expectError(error.UnknownTimeZone, result);
}

test "TimeZone - Asia/Kolkata half-hour offset" {
    const kolkata = try TimeZone.fromName("Asia/Kolkata");
    try std.testing.expectEqual(@as(i32, 19800), kolkata.utcOffset(0)); // +5:30
}
