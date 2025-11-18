//! WebIDL dictionary: ReportResultBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportingBrowserSignals = @import("ReportingBrowserSignals.zig").ReportingBrowserSignals;

pub const ReportResultBrowserSignals = struct {
    // Inherited from ReportingBrowserSignals
    base: ReportingBrowserSignals,

    desirability: f64,
    topLevelSellerSignals: ?runtime.DOMString = null,
    modifiedBid: ?f64 = null,
    dataVersion: ?u32 = null,
};
