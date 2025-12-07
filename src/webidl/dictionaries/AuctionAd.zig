//! WebIDL dictionary: AuctionAd
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AuctionAd = struct {
    renderURL: runtime.USVString,
    sizeGroup: ?runtime.USVString = null,
    metadata: ?v8.JSValue = null,
    buyerReportingId: ?runtime.USVString = null,
    buyerAndSellerReportingId: ?runtime.USVString = null,
    selectableBuyerAndSellerReportingIds: ?[]const runtime.USVString = null,
    allowedReportingOrigins: ?[]const runtime.USVString = null,
    adRenderId: ?runtime.DOMString = null,
    creativeScanningMetadata: ?runtime.USVString = null,
};
