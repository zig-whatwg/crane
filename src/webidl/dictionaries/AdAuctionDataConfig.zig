//! WebIDL dictionary: AdAuctionDataConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AdAuctionDataConfig = struct {
    seller: ?runtime.USVString = null,
    coordinatorOrigin: ?runtime.USVString = null,
    sellers: ?*const anyopaque = null,
    requestSize: ?u32 = null,
    perBuyerConfig: ?*const anyopaque = null,
};
