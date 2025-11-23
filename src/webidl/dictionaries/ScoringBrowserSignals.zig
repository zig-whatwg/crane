//! WebIDL dictionary: ScoringBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ScoringBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    interestGroupOwner: runtime.USVString,
    renderURL: runtime.USVString,
    biddingDurationMsec: u32,
    bidCurrency: runtime.DOMString,
    renderSize: ?*const anyopaque = null,
    dataVersion: ?u32 = null,
    crossOriginDataVersion: ?u32 = null,
    adComponents: ?*const anyopaque = null,
    forDebuggingOnlyInCooldownOrLockout: ?bool = null,
    creativeScanningMetadata: ?runtime.USVString = null,
    adComponentsCreativeScanningMetadata: ?*const anyopaque = null,
};
