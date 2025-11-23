//! WebIDL dictionary: AdAuctionPerSellerData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AdAuctionPerSellerData = struct {
    seller: runtime.USVString,
    request: ?*const anyopaque = null,
    @"error": ?runtime.DOMString = null,
};
