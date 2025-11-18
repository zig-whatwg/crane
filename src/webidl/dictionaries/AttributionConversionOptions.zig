//! WebIDL dictionary: AttributionConversionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AttributionConversionOptions = struct {
    aggregationService: runtime.DOMString,
    epsilon: ?f64 = null,
    histogramSize: u32,
    lookbackDays: ?u32 = null,
    matchValues: ?anyopaque = null,
    impressionSites: ?anyopaque = null,
    impressionCallers: ?anyopaque = null,
    credit: ?anyopaque = null,
    value: ?u32 = null,
    maxValue: ?u32 = null,
};
