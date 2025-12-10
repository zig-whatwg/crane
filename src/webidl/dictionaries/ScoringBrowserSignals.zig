//! WebIDL dictionary: ScoringBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ScoringBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    interestGroupOwner: runtime.USVString,
    renderURL: runtime.USVString,
    biddingDurationMsec: u32,
    bidCurrency: runtime.DOMString,
    renderSize: ?[]const struct { key: runtime.DOMString, value: runtime.DOMString } = null,
    dataVersion: ?u32 = null,
    crossOriginDataVersion: ?u32 = null,
    adComponents: ?[]const runtime.USVString = null,
    forDebuggingOnlyInCooldownOrLockout: ?bool = null,
    creativeScanningMetadata: ?runtime.USVString = null,
    adComponentsCreativeScanningMetadata: ?[]const runtime.JSValue = null,
};
