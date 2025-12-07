//! WebIDL dictionary: GenerateBidInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuctionAd = @import("AuctionAd.zig").AuctionAd;
const AuctionAdInterestGroupSize = @import("AuctionAdInterestGroupSize.zig").AuctionAdInterestGroupSize;

pub const GenerateBidInterestGroup = struct {
    owner: runtime.USVString,
    name: runtime.USVString,
    enableBiddingSignalsPrioritization: ?bool = null,
    priorityVector: ?[]const struct { key: runtime.DOMString, value: f64 } = null,
    sellerCapabilities: ?[]const struct { key: runtime.USVString, value: []const runtime.DOMString } = null,
    executionMode: ?runtime.DOMString = null,
    biddingLogicURL: ?runtime.USVString = null,
    biddingWasmHelperURL: ?runtime.USVString = null,
    updateURL: ?runtime.USVString = null,
    trustedBiddingSignalsURL: ?runtime.USVString = null,
    trustedBiddingSignalsKeys: ?[]const runtime.USVString = null,
    trustedBiddingSignalsSlotSizeMode: ?runtime.DOMString = null,
    maxTrustedBiddingSignalsURLLength: ?i32 = null,
    trustedBiddingSignalsCoordinator: ?runtime.USVString = null,
    userBiddingSignals: ?runtime.JSValue = null,
    ads: ?[]const AuctionAd = null,
    adComponents: ?[]const AuctionAd = null,
    adSizes: ?[]const struct { key: runtime.DOMString, value: AuctionAdInterestGroupSize } = null,
    sizeGroups: ?[]const struct { key: runtime.DOMString, value: []const runtime.DOMString } = null,
};
