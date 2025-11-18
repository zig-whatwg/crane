//! WebIDL dictionary: GenerateBidOutput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GenerateBidOutput = struct {
    bid: ?f64 = null,
    bidCurrency: ?runtime.DOMString = null,
    render: ?anyopaque = null,
    ad: ?anyopaque = null,
    selectedBuyerAndSellerReportingId: ?runtime.DOMString = null,
    adComponents: ?anyopaque = null,
    adCost: ?f64 = null,
    modelingSignals: ?f64 = null,
    allowComponentAuction: ?bool = null,
    targetNumAdComponents: ?u32 = null,
    numMandatoryAdComponents: ?u32 = null,
};
