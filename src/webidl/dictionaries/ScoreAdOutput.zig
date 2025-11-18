//! WebIDL dictionary: ScoreAdOutput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ScoreAdOutput = struct {
    desirability: f64,
    bid: ?f64 = null,
    bidCurrency: ?runtime.DOMString = null,
    incomingBidInSellerCurrency: ?f64 = null,
    allowComponentAuction: ?bool = null,
};
