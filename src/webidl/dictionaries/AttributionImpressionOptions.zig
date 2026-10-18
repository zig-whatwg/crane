//! WebIDL dictionary: AttributionImpressionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AttributionImpressionOptions = struct {
    histogramIndex: u32,
    matchValue: ?u32 = null,
    conversionSites: ?[]const runtime.USVString = null,
    conversionCallers: ?[]const runtime.USVString = null,
    lifetimeDays: ?u32 = null,
    priority: ?i32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "matchValue", .{ .number = 0 } },
        .{ "conversionSites", .empty_sequence },
        .{ "conversionCallers", .empty_sequence },
        .{ "lifetimeDays", .{ .number = 30 } },
        .{ "priority", .{ .number = 0 } },
    };
};
