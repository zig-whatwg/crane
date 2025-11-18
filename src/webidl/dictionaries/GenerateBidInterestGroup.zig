//! WebIDL dictionary: GenerateBidInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GenerateBidInterestGroup = struct {
    owner: runtime.DOMString,
    name: runtime.DOMString,
    enableBiddingSignalsPrioritization: ?bool = null,
    priorityVector: ?anyopaque = null,
    sellerCapabilities: ?anyopaque = null,
    executionMode: ?runtime.DOMString = null,
    biddingLogicURL: ?runtime.DOMString = null,
    biddingWasmHelperURL: ?runtime.DOMString = null,
    updateURL: ?runtime.DOMString = null,
    trustedBiddingSignalsURL: ?runtime.DOMString = null,
    trustedBiddingSignalsKeys: ?anyopaque = null,
    trustedBiddingSignalsSlotSizeMode: ?runtime.DOMString = null,
    maxTrustedBiddingSignalsURLLength: ?i32 = null,
    trustedBiddingSignalsCoordinator: ?runtime.DOMString = null,
    userBiddingSignals: ?anyopaque = null,
    ads: ?anyopaque = null,
    adComponents: ?anyopaque = null,
    adSizes: ?anyopaque = null,
    sizeGroups: ?anyopaque = null,
};
