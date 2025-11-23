//! WebIDL dictionary: AttributionConversionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AttributionConversionOptions = struct {
    aggregationService: runtime.USVString,
    epsilon: ?f64 = null,
    histogramSize: u32,
    lookbackDays: ?u32 = null,
    matchValues: ?*const anyopaque = null,
    impressionSites: ?*const anyopaque = null,
    impressionCallers: ?*const anyopaque = null,
    credit: ?*const anyopaque = null,
    value: ?u32 = null,
    maxValue: ?u32 = null,
};
