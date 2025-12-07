//! WebIDL dictionary: BiddingBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const BiddingBrowserSignals = struct {
    topWindowHostname: runtime.DOMString,
    seller: runtime.USVString,
    joinCount: i32,
    bidCount: i32,
    recency: i32,
    adComponentsLimit: i32,
    multiBidLimit: u16,
    requestedSize: ?[]const struct { key: runtime.DOMString, value: runtime.DOMString } = null,
    topLevelSeller: ?runtime.USVString = null,
    prevWinsMs: ?[]const typedefs.PreviousWin = null,
    wasmHelper: ?v8.JSValue = null,
    dataVersion: ?u32 = null,
    crossOriginDataVersion: ?u32 = null,
    forDebuggingOnlyInCooldownOrLockout: ?bool = null,
};
