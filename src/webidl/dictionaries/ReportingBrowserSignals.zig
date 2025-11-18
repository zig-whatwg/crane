//! WebIDL dictionary: ReportingBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ReportingBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    interestGroupOwner: runtime.DOMString,
    renderURL: runtime.DOMString,
    bid: f64,
    highestScoringOtherBid: f64,
    bidCurrency: ?runtime.DOMString = null,
    highestScoringOtherBidCurrency: ?runtime.DOMString = null,
    topLevelSeller: ?runtime.DOMString = null,
    componentSeller: ?runtime.DOMString = null,
    buyerAndSellerReportingId: ?runtime.DOMString = null,
    selectedBuyerAndSellerReportingId: ?runtime.DOMString = null,
};
