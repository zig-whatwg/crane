//! WebIDL dictionary: AdAuctionDataConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AdAuctionDataConfig = struct {
    seller: ?runtime.DOMString = null,
    coordinatorOrigin: ?runtime.DOMString = null,
    sellers: ?anyopaque = null,
    requestSize: ?u32 = null,
    perBuyerConfig: ?anyopaque = null,
};
