//! WebIDL dictionary: XRDepthStateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const XRDepthStateInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
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
