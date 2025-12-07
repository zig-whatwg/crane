//! WebIDL dictionary: AdAuctionData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AdAuctionPerSellerData = @import("AdAuctionPerSellerData.zig").AdAuctionPerSellerData;

pub const AdAuctionData = struct {
    requestId: runtime.USVString,
    request: ?*const anyopaque = null,
    requests: ?[]const AdAuctionPerSellerData = null,
};
