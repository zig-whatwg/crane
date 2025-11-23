//! WebIDL dictionary: BiddingBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BiddingBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    seller: runtime.USVString,
    joinCount: i32,
    bidCount: i32,
    recency: i32,
    adComponentsLimit: i32,
    multiBidLimit: u16,
    requestedSize: ?*const anyopaque = null,
    topLevelSeller: ?runtime.USVString = null,
    prevWinsMs: ?*const anyopaque = null,
    wasmHelper: ?*const anyopaque = null,
    dataVersion: ?u32 = null,
    crossOriginDataVersion: ?u32 = null,
    forDebuggingOnlyInCooldownOrLockout: ?bool = null,
};
