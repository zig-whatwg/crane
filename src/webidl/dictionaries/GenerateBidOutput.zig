//! WebIDL dictionary: GenerateBidOutput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AdRender = @import("AdRender.zig").AdRender;

pub const GenerateBidOutput = struct {
    bid: ?f64 = null,
    bidCurrency: ?runtime.DOMString = null,
    render: ?*const anyopaque = null,
    ad: ?runtime.JSValue = null,
    selectedBuyerAndSellerReportingId: ?runtime.USVString = null,
    adComponents: ?[]const *const anyopaque = null,
    adCost: ?f64 = null,
    modelingSignals: ?f64 = null,
    allowComponentAuction: ?bool = null,
    targetNumAdComponents: ?u32 = null,
    numMandatoryAdComponents: ?u32 = null,
};
