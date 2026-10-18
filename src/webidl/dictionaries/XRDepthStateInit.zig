//! WebIDL dictionary: XRDepthStateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const XRDepthStateInit = struct {
    usagePreference: []const enums.XRDepthUsage,
    dataFormatPreference: []const enums.XRDepthDataFormat,
    depthTypeRequest: ?[]const enums.XRDepthType = null,
    matchDepthView: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "matchDepthView", .{ .boolean = true } },
    };
};
