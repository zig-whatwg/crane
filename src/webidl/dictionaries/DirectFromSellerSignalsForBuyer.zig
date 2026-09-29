//! WebIDL dictionary: DirectFromSellerSignalsForBuyer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DirectFromSellerSignalsForBuyer = struct {
    auctionSignals: ?runtime.JSValue = null,
    perBuyerSignals: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{ "auctionSignals", "perBuyerSignals" };
};
