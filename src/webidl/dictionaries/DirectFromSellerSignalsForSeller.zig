//! WebIDL dictionary: DirectFromSellerSignalsForSeller
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DirectFromSellerSignalsForSeller = struct {
    auctionSignals: ?runtime.JSValue = null,
    sellerSignals: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{ "auctionSignals", "sellerSignals" };
};
