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
};
