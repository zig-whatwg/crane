//! WebIDL dictionary: ScoreAdOutput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ScoreAdOutput = struct {
    desirability: f64,
    bid: ?f64 = null,
    bidCurrency: ?runtime.DOMString = null,
    incomingBidInSellerCurrency: ?f64 = null,
    allowComponentAuction: ?bool = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "desirability", "bid", "incomingBidInSellerCurrency" };
};
