//! WebIDL dictionary: ScoringBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ScoringBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    interestGroupOwner: runtime.DOMString,
    renderURL: runtime.DOMString,
    biddingDurationMsec: u32,
    bidCurrency: runtime.DOMString,
    renderSize: ?anyopaque = null,
    dataVersion: ?u32 = null,
    crossOriginDataVersion: ?u32 = null,
    adComponents: ?anyopaque = null,
    forDebuggingOnlyInCooldownOrLockout: ?bool = null,
    creativeScanningMetadata: ?runtime.DOMString = null,
    adComponentsCreativeScanningMetadata: ?anyopaque = null,
};
