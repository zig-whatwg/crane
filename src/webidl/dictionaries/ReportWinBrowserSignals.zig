//! WebIDL dictionary: ReportWinBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportingBrowserSignals = @import("ReportingBrowserSignals.zig").ReportingBrowserSignals;

pub const ReportWinBrowserSignals = struct {
    // Inherited from ReportingBrowserSignals
    base: ReportingBrowserSignals,

    adCost: ?f64 = null,
    seller: ?runtime.DOMString = null,
    madeHighestScoringOtherBid: ?bool = null,
    interestGroupName: ?runtime.DOMString = null,
    buyerReportingId: ?runtime.DOMString = null,
    modelingSignals: ?u16 = null,
    dataVersion: ?u32 = null,
    kAnonStatus: ?anyopaque = null,
};
