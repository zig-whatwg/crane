//! WebIDL dictionary: ReportWinBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const ReportingBrowserSignals = @import("ReportingBrowserSignals.zig").ReportingBrowserSignals;

pub const ReportWinBrowserSignals = struct {
    // Inherited from ReportingBrowserSignals
    base: ReportingBrowserSignals,

    adCost: ?f64 = null,
    seller: ?runtime.USVString = null,
    madeHighestScoringOtherBid: ?bool = null,
    interestGroupName: ?runtime.DOMString = null,
    buyerReportingId: ?runtime.DOMString = null,
    modelingSignals: ?u16 = null,
    dataVersion: ?u32 = null,
    kAnonStatus: ?enums.KAnonStatus = null,
};
