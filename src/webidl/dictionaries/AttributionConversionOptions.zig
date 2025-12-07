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
};
