//! WebIDL dictionary: AdAuctionDataConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AdAuctionOneSeller = @import("AdAuctionOneSeller.zig").AdAuctionOneSeller;
const AdAuctionDataBuyerConfig = @import("AdAuctionDataBuyerConfig.zig").AdAuctionDataBuyerConfig;

pub const AdAuctionDataConfig = struct {
    seller: ?runtime.USVString = null,
    coordinatorOrigin: ?runtime.USVString = null,
    sellers: ?[]const AdAuctionOneSeller = null,
    requestSize: ?u32 = null,
    perBuyerConfig: ?[]const struct { key: runtime.USVString, value: AdAuctionDataBuyerConfig } = null,
};
