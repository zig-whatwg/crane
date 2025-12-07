//! WebIDL dictionary: AttributionImpressionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const AttributionImpressionOptions = struct {
    histogramIndex: u32,
    matchValue: ?u32 = null,
    conversionSites: ?[]const runtime.USVString = null,
    conversionCallers: ?[]const runtime.USVString = null,
    lifetimeDays: ?u32 = null,
    priority: ?i32 = null,
};
