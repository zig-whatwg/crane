//! WebIDL dictionary: ReportingBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ReportingBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    interestGroupOwner: runtime.USVString,
    renderURL: runtime.USVString,
    bid: f64,
    highestScoringOtherBid: f64,
    bidCurrency: ?runtime.DOMString = null,
    highestScoringOtherBidCurrency: ?runtime.DOMString = null,
    topLevelSeller: ?runtime.USVString = null,
    componentSeller: ?runtime.USVString = null,
    buyerAndSellerReportingId: ?runtime.USVString = null,
    selectedBuyerAndSellerReportingId: ?runtime.USVString = null,
};
