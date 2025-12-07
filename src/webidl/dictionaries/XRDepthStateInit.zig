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
};
