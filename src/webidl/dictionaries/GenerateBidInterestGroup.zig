//! WebIDL dictionary: GenerateBidInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GenerateBidInterestGroup = struct {
    owner: runtime.USVString,
    name: runtime.USVString,
    enableBiddingSignalsPrioritization: ?bool = null,
    priorityVector: ?*const anyopaque = null,
    sellerCapabilities: ?*const anyopaque = null,
    executionMode: ?runtime.DOMString = null,
    biddingLogicURL: ?runtime.USVString = null,
    biddingWasmHelperURL: ?runtime.USVString = null,
    updateURL: ?runtime.USVString = null,
    trustedBiddingSignalsURL: ?runtime.USVString = null,
    trustedBiddingSignalsKeys: ?*const anyopaque = null,
    trustedBiddingSignalsSlotSizeMode: ?runtime.DOMString = null,
    maxTrustedBiddingSignalsURLLength: ?i32 = null,
    trustedBiddingSignalsCoordinator: ?runtime.USVString = null,
    userBiddingSignals: ?*const anyopaque = null,
    ads: ?*const anyopaque = null,
    adComponents: ?*const anyopaque = null,
    adSizes: ?*const anyopaque = null,
    sizeGroups: ?*const anyopaque = null,
};
