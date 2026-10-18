//! WebIDL dictionary: AttributionConversionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AttributionConversionOptions = struct {
    aggregationService: runtime.USVString,
    epsilon: ?f64 = null,
    histogramSize: u32,
    lookbackDays: ?u32 = null,
    matchValues: ?[]const u32 = null,
    impressionSites: ?[]const runtime.USVString = null,
    impressionCallers: ?[]const runtime.USVString = null,
    credit: ?[]const f64 = null,
    value: ?u32 = null,
    maxValue: ?u32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "epsilon", "credit" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "epsilon", .{ .number = 1 } },
        .{ "matchValues", .empty_sequence },
        .{ "impressionSites", .empty_sequence },
        .{ "impressionCallers", .empty_sequence },
        .{ "value", .{ .number = 1 } },
        .{ "maxValue", .{ .number = 1 } },
    };
};
